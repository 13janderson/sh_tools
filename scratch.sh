#!/usr/bin/env bash
# Open nvim as scratch buffer

tmux_running=$(pgrep tmux)

if [[ $TMUX ]] && [[ $tmux_running ]]; then
  tmux display-popup -E "nvim --noplugin -c 'lua OpenScratch()'"
else
  nvim --noplugin -c 'lua OpenScratch()'
fi
