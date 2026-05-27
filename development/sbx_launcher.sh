#!/bin/bash
set -e

sbx rm opencode-${PWD##*/} || echo "Starting..."

sbx create --name opencode-${PWD##*/} opencode . || echo "Starting..."
sbx policy allow network opencode-${PWD##*/} localhost:11434
sbx run opencode-${PWD##*/}
