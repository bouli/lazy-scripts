#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <iterations>"
  exit 1
fi


sbx rm current-ai || echo "Starting..."

sbx create --name current-ai opencode $1
sbx policy allow network current-ai localhost:11434
sbx run current-ai
