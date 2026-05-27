#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <iterations>"
  exit 1
fi

for ((i=1; i<=$1; i++)); do
  sbx run current-ai -- run --command "ralph" -m ollama/qwen3.5 || echo "go on"

done
