#!/bin/bash
set -e
export LEAN_CC=/usr/bin/clang
lake build "$@"
