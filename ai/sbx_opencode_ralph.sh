#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <iterations>"
  exit 1
fi

project_name="${PWD##*/}"
project_name="${project_name//[^[:alnum:]-]/-}"
sandbox_name="opencode-${project_name}"

for ((i=1; i<=$1; i++)); do
  sbx run "$sandbox_name" -- run --command "ralph" -m ollama/qwen3.5 || echo "go on"

done
