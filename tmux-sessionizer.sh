#!/usr/bin/env bash
selected_name=$1

custom_paths=("$HOME/vault/" "$HOME/dotfiles" "$HOME/wl" "$HOME/tf")

if [ -z $selected_name ]; then
  if [[ $# -eq 1 ]]; then
      selected=$1
  else
    selected=$( (printf "%s\n" "${custom_paths[@]}"; find $HOME/projects  $HOME/projects/plugins/  -mindepth 1 -maxdepth 1 -type d -not -path '*/.*') | sed -E "s|$HOME/||" |   fzf --preview '')
  fi

  if [[ -z $selected ]]; then
      exit 0
  fi

  selected_name=$(basename "$selected" | tr . _)
  tmux_running=$(pgrep tmux)
fi


if [[ -z $TMUX ]] && [[ -z $tmux_running ]]; then
    tmux new-session -s $selected_name -c $HOME/$selected
    exit 0
fi

if ! tmux has-session -t=$selected_name 2> /dev/null; then
    tmux new-session -ds $selected_name -c $HOME/$selected
fi

if [[ -z $TMUX ]]; then
    tmux attach -t $selected_name
else
    tmux switch-client -t $selected_name
fi
