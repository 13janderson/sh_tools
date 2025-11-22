#!/bin/bash
me=$(basename "$0")

TMP_FLAG=$(mktemp)

# Change this for your shell, you may also need to change the below sed filtering to remove noise from history files
# the below works for zsh_history
HISTFILE=$HOME/.zsh_history
selected=$(tac $HISTFILE | sed -E "/$me/d" | sed -E 's/(: [0-9]*:0;)(.*)/\2/' | awk '!seen[$0]++' | fzf -m --bind "ctrl-y:execute-silent(echo {} | wl-copy; echo y > $TMP_FLAG)+accept")
echo "$selected"

if [[ -f "$TMP_FLAG" ]]; then
  yanked=$(<"$TMP_FLAG")  
  rm $TMP_FLAG > /dev/null 2>&1
  if [[ $yanked == "y" ]]; then
    echo "Copied to clipboard with ctrl-y. Halting script."
    exit 0
  fi
fi

rm $TMP_FLAG > /dev/null 2>&1

selected=$(echo "$selected" | awk '{printf "%s && ", $0}' | sed 's/&& $//')

if [[ -n "$selected" ]]; then
  # Send keys to current tmux window and hit enter, I love tmux.
  # only do this if we are inside a tmux session
  if [ "$TMUX" ]; then
    tmux send-keys "$selected" C-m
  else
    eval $selected
  fi
fi

