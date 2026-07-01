#!/usr/bin/env bash
selected=$1

custom_paths=("$HOME/vault/" "$HOME/dotfiles" )

if [ -z "$selected" ]; then
  sessions=$(tmux ls -F "#{session_activity}(#{session_name}" | sort -n | cut -d "(" -f 2 2> /dev/null)
  sessions=$(echo "$sessions" | sed -E "s/(.*):(.*)/\2/")

  directories=$(printf "%s\n" "${custom_paths[@]}"; find "$HOME/projects" "$HOME/projects/plugins/" "$HOME/projects/CVS" -mindepth 1 -maxdepth 1 -type d -not -path '*/.*' 2> /dev/null)

  # Remove $HOME prefix and trailing slashes for display
  directories=$(echo "$directories" | sed -E "s|$HOME/||" | sed 's|/*$||')

  # Pre-compute session paths and basename counts to avoid O(n²) subshells
  declare -A session_paths basename_counts
  while IFS= read -r s; do
    session_paths["$s"]=$(tmux display-message -p -t "$s" '#{pane_current_path}' 2> /dev/null)
  done <<< "$sessions"
  while IFS= read -r dir; do
    b="${dir##*/}"
    ((basename_counts["$b"]++))
  done <<< "$directories"

  existing=""
  non_existing=""
  while IFS= read -r dir; do
    b="${dir##*/}"
    dir_session="${b//./_}"
    if [[ -n "${session_paths[$dir_session]+x}" ]]; then
      if [[ "${basename_counts[$b]}" -gt 1 ]]; then
        [[ "${session_paths[$dir_session]}" == "$HOME/$dir" ]] && existing+="$dir"$'\n' || non_existing+="$dir"$'\n'
      else
        existing+="$dir"$'\n'
      fi
    else
      non_existing+="$dir"$'\n'
    fi
  done <<< "$directories"
  existing="${existing%$'\n'}"
  non_existing="${non_existing%$'\n'}"

  if [[ -n $existing ]]; then
    existing_colour=$(echo "$existing" | sed -E $'s/(.*)/\e[1;92m\\1\e[0m/')

    # Allow multiple selections when sessions plural already exist
    selected=$( { echo "$existing_colour"; echo "$non_existing"; } | fzf -m --ansi --tmux 70%)

    # Assume that the use case for this is selecting multiple sessions for deletion. Thus assume
    # that when multiple sessions are selected, then the intention is to delete those sessions
    count=$(echo "$selected" | wc -l)
    if [[ count -gt 1 ]]; then
      printf '\e[0;32myes\n\e[0;31mno\n' | fzf --no-sort --layout=reverse --ansi --tmux 40% --prompt "Delete $count sessions?" | grep -x 'yes' && \
        printf "Deleting sessions: $(echo "$selected" | tr '\n' ' ')\n" && echo "$selected" | xargs -I {} sh -c 'tmux kill-session -t "$(basename "{}" | tr . _ )"'
    fi
  else
    selected=$(echo "$directories" | fzf --ansi --tmux 70%)
  fi
fi

if [[ -z $selected ]]; then
    exit 0
fi

# Session name uses underscores instead of dots (tmux session naming restriction)
selected_name=$(basename "$selected" | tr . _)
tmux_running=$(pgrep -x tmux)

if [[ -z $TMUX ]] && [[ -z $tmux_running ]]; then
    pth="$HOME/$selected"

    tmux new-session -s "$selected_name" -c "$pth"
    exit 0
fi

if ! tmux has-session -t="$selected_name" 2> /dev/null; then
    pth="$HOME/$selected"
    tmux new-session -ds "$selected_name" -c "$pth"
fi

if [[ -z $TMUX ]]; then
    tmux attach -t "$selected_name"
else
    tmux switch-client -t "$selected_name"
fi
