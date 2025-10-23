#!/usr/bin/env bash
# Open nvim as scratch buffer
nvim_open_scratch=

tmux_running=$(pgrep tmux)

if [[ $TMUX ]] && [[ $tmux_running ]]; then
  tmux display-popup -E "nvim -c 'lua OpenScratch()'"
else
  nvim -c 'lua OpenScratch()'
fi
