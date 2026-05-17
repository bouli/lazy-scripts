#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <iterations>"
  exit 1
fi

for ((i=1; i<=$1; i++)); do
  cline --auto-approve true -v "@PRD.md @progress.txt \
1. Read the @PRD.md and @progress.txt file. \
2. Read ALL tasks. Find the next incomplete task and implement it. \
3. Commit your changes in the local repository. \
4. Update @progress.txt with what you did. \
ONLY DO ONE TASK AT A TIME.
  If the PRD is complete, output <promise>COMPLETE</promise>, otherwise, clean the session and run this same prompt again."

  if [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
    echo "PRD complete after $i iterations."
    exit 0
  fi
done
