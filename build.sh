#!/bin/bash
set -e
export LEAN_CC=/usr/bin/clang
export LIBRARY_PATH=/opt/homebrew/lib:$LIBRARY_PATH
lake build "$@"
