#!/usr/bin/env bash

set -euo pipefail

me=$(basename "$0")
TMP_FLAG=$(mktemp)
TMP_EDIT=$(mktemp)
HELPER=$(mktemp)
SELECTED_FILE=$(mktemp)
STATE_FILE=$(mktemp)

# Cleanup on exit/interrupt
trap 'rm -f "$TMP_FLAG" "$TMP_EDIT" "$HELPER" "$SELECTED_FILE" "$STATE_FILE"' EXIT INT TERM

# Auto-detect shell and history file
if [[ -n "${HISTFILE:-}" && -f "$HISTFILE" ]]; then
  :
elif [[ "${SHELL:-}" == */zsh ]]; then
  HISTFILE="$HOME/.zsh_history"
elif [[ "${SHELL:-}" == */bash ]]; then
  HISTFILE="$HOME/.bash_history"
else
  for f in "$HOME/.zsh_history" "$HOME/.bash_history"; do
    if [[ -f "$f" ]]; then
      HISTFILE="$f"
      break
    fi
  done
fi

if [[ ! -f "${HISTFILE:-}" ]]; then
  echo "No history file found" >&2
  exit 1
fi

export HISTFILE COPY_CMD TMP_EDIT TMUX

# Escape script name for sed regex
me_escaped=$(printf '%s' "$me" | sed 's/[]\/$*.^+?{}()|[]/\\&/g')

# Build history pipeline based on shell format
if [[ "$HISTFILE" == *.zsh_history ]]; then
  # zsh: : <timestamp>:0;<command>
  # Format as: <human_time>;<command> with deduplication
  history_pipe="tac \"$HISTFILE\" | sed -E '/$me_escaped/d' | awk -F';' '
    BEGIN { OFS=\";\" }
    {
      cmd = \$0
      sub(/^: [0-9]+:0;/, \"\", cmd)
      ts = \$0
      sub(/^: /, \"\", ts)
      sub(/:0;.*/, \"\", ts)
      if (!seen[cmd]++) {
        printf \"%s;%s\\n\", strftime(\"%Y-%m-%d %H:%M\", ts), cmd
      }
    }
  '"
  fzf_display_opts=(--with-nth 2.. --delimiter ';')
else
  # bash or other: simple line-based with deduplication
  history_pipe="tac \"$HISTFILE\" | sed -E '/$me_escaped/d' | awk '!seen[\$0]++'"
  fzf_display_opts=()
fi

# Write helper script for bindings (avoids quoting hell with {})
cat > "$HELPER" << 'ENDHELPER'
#!/usr/bin/env bash
histfile="$1"
action="$2"
read -r line

if [[ "$histfile" == *.zsh_history ]]; then
  cmd=$(printf '%s' "$line" | cut -d';' -f2-)
else
  cmd="$line"
fi

case "$action" in
  copy)
    printf '%s' "$cmd" | tr -d '\n' | eval "$COPY_CMD"
    ;;
  edit)
    printf '%s\n' "$cmd" > "$TMP_EDIT"
    "${EDITOR:-vi}" "$TMP_EDIT"
    ;;
  execute)
    if [[ "${TMUX:-}" ]]; then
      tmux run-shell "bash -c $(printf '%q' "$cmd")"
    else
      bash -c "$cmd" > /dev/null 2>&1 &
    fi
    ;;
esac
ENDHELPER
chmod +x "$HELPER"

# fzf options
fzf_opts=(
  -m
  --preview "echo {}"
  --preview-window "wrap:50%"
  --header "Enter: execute | Ctrl-Y: copy | Ctrl-E: edit | Ctrl-O: execute (keep open)"
  --bind "ctrl-y:execute-silent(echo {} | $HELPER \"$HISTFILE\" copy; echo y > \"$TMP_FLAG\")+accept"
  --bind "ctrl-e:execute(echo {} | $HELPER \"$HISTFILE\" edit)+abort"
  --bind "ctrl-o:execute-silent(echo {} | $HELPER \"$HISTFILE\" execute)"
)

# Save script state to file for popup to source
declare -p HISTFILE SELECTED_FILE TMP_FLAG TMP_EDIT HELPER COPY_CMD TMUX me_escaped history_pipe > "$STATE_FILE"
declare -p fzf_opts fzf_display_opts >> "$STATE_FILE"

# Run fzf in a tmux popup (isolated from parent pane) to prevent tty output leakage
if [[ "${TMUX:-}" && -z "${NVIM:-}" ]]; then
  POPUP_SCRIPT=$(mktemp)
  # Append popup script to existing trap
  trap 'rm -f "$TMP_FLAG" "$TMP_EDIT" "$HELPER" "$SELECTED_FILE" "$STATE_FILE" "$POPUP_SCRIPT"' EXIT INT TERM
  cat > "$POPUP_SCRIPT" << EOF
#!/usr/bin/env bash
source "$STATE_FILE"
eval "\$history_pipe" | fzf "\${fzf_opts[@]}" "\${fzf_display_opts[@]}" > "\$SELECTED_FILE" || true
EOF
  chmod +x "$POPUP_SCRIPT"
  tmux display-popup -d "#{pane_current_path}" -w 70% -h 70% -E "$POPUP_SCRIPT" || true
else
  eval "$history_pipe" | fzf "${fzf_opts[@]}" "${fzf_display_opts[@]}" > "$SELECTED_FILE" || true
fi

selected=$(<"$SELECTED_FILE")

# Handle Ctrl-E edit result
if [[ -s "$TMP_EDIT" ]]; then
  selected=$(cat "$TMP_EDIT")
fi

# Handle Ctrl-Y clipboard copy
if [[ -f "$TMP_FLAG" ]] && [[ "$(<"$TMP_FLAG")" == "y" ]]; then
  echo "Copied to clipboard with ctrl-y. Halting script."
  exit 0
fi

if [[ -z "${selected:-}" ]]; then
  exit 0
fi

# Extract command (strip timestamp prefix for zsh format)
if [[ "$HISTFILE" == *.zsh_history ]]; then
  selected=$(echo "$selected" | cut -d';' -f2-)
fi

# Join multiple selections with &&
if [[ "$(echo "$selected" | wc -l)" -gt 1 ]]; then
  selected=$(echo "$selected" | sed -z 's/\n/ && /g; s/ && $//')
fi

if [[ -n "$selected" ]]; then
  if [[ "${TMUX:-}" ]]; then
    tmux send-keys "$selected"
    tmux send-keys C-m
  else
    bash -c "$selected"
  fi
fi
