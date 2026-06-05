#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <iterations>"
  exit 1
fi

if [ -z "$2" ]; then
  sleeping_time=0
else
  sleeping_time=$2
fi

for ((i=1; i<=$1; i++)); do
  sbx run codex-${PWD##*/} -- exec "use skill ralph @.agents/PRD.md @.agents/issues @.agents/PROGRESS.md"
  sleep $sleeping_time
done
