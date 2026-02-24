#!/usr/bin/env bash
selected_name=$1

custom_paths=("$HOME/vault/" "$HOME/dotfiles" )

# When showing tmux sesions, I want them organised by latest first
if [ -z $selected_name ]; then
  if [[ $# -eq 1 ]]; then
      selected=$1
  else
    sessions=$(tmux ls -F "#{session_activity}(#{session_name}" | sort -n | cut -d "(" -f 2 2> /dev/null) 
    sessions=$(echo "$sessions" | sed -E "s/(.*):(.*)/\2/")
    directories=$(printf "%s\n" "${custom_paths[@]}"; find $HOME/projects $HOME/projects/plugins/ $HOME/projects/CVS -mindepth 1 -maxdepth 1 -type d -not -path '*/.*' 2> /dev/null)

    # tmuxify all directories 
    directories=$(echo "$directories" | xargs -I {} sh -c "echo {} | tr . _" | sed -E "s|$HOME/||" | sed 's|/*$||')
    existing=$(echo "$directories" | grep -wE "$sessions" | sed -E "s/(.*)/\1/")
    if [[ -n $existing ]]; then
      non_existing=$(echo "$directories" | grep -v "$existing")
      echo "non_existing: $non_existing"

      existing_colour=$(echo "$existing" | sed -E $'s/(.*)/\e[1;92m\\1\e[0m/')
      
      selected=$(printf "$existing_colour\n$non_existing" | tr _ . | fzf --ansi --tmux 70%)
    else
      selected=$(printf "$directories" | tr . _ | fzf --ansi --tmux 70%)
    fi
  fi

  echo "selected: $selected"
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
