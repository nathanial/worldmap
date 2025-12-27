#!/bin/bash
# Build and run tests for Worldmap
# Sets LEAN_CC for proper macOS framework linking

set -e

export LEAN_CC=/usr/bin/clang

echo "Building tests..."
lake build worldmap_tests

echo ""
echo "Running tests..."
.lake/build/bin/worldmap_tests
