#!/usr/bin/env bash
selected_name=$1

custom_paths=("$HOME/vault/" "$HOME/dotfiles" )

if [ -z $selected_name ]; then
  if [[ $# -eq 1 ]]; then
      selected=$1
  else
    sessions=$(tmux ls -F "#{session_activity}(#{session_name}" | sort -n | cut -d "(" -f 2 2> /dev/null) 
    sessions=$(echo "$sessions" | sed -E "s/(.*):(.*)/\2/")

    directories=$(printf "%s\n" "${custom_paths[@]}"; find $HOME/projects $HOME/projects/plugins/ $HOME/projects/CVS -mindepth 1 -maxdepth 1 -type d -not -path '*/.*' 2> /dev/null)

    # Remove $HOME prefix and trailing slashes for display
    directories=$(echo "$directories" | sed -E "s|$HOME/||" | sed 's|/*$||')

    existing=$(echo "$directories" | grep -wE "$sessions" | sed -E "s/(.*)/\1/")
    if [[ -n $existing ]]; then
      non_existing=$(echo "$directories" | grep -v "$existing")

      existing_colour=$(echo "$existing" | sed -E $'s/(.*)/\e[1;92m\\1\e[0m/')

      # Allow multiple selections when sessions plural already exist
      selected=$(printf "$existing_colour\n$non_existing" | fzf -m --ansi --tmux 70%)

      # Assume that the use case for this is selecting multiple sessions for deletion. Thus assume
      # that when multiple sessions are selected, then the intention is to delete those sessions
      count=$(echo "$selected" | wc -l)
      if [[ count -gt 1 ]]; then
        printf "\e[0;32myes\n\e[0;31mno" | fzf --no-sort --layout=reverse --ansi --height=40% --prompt "Delete $count sessions?" | grep -x 'yes' && \
          # printf "Deleting sessions: $(echo "$selected" | tr '\n' ' ')\n" && echo "$selected" | xargs -I {} sh -c "echo $(basename "{}" | tr . _ ) && tmux kill-session -t $(basename "{}" | tr . _) >> xargs.log"
          printf "Deleting sessions: $(echo "$selected" | tr '\n' ' ')\n" && echo "$selected" | xargs -I {} sh -c 'tmux kill-session -t "$(basename "{}" | tr . _ )"'
      fi
    else
      selected=$(printf "$directories" | fzf --ansi --tmux 70%)
    fi
  fi

  if [[ -z $selected ]]; then
      exit 0
  fi

  # Session name uses underscores instead of dots (tmux session naming restriction)
  selected_name=$(basename "$selected" | tr . _)
  tmux_running=$(pgrep tmux)
fi

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
    tmux attach -t $selected_name
else
    tmux switch-client -t $selected_name
fi
