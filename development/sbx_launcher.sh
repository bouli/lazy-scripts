#!/bin/bash
set -e

sbx rm current-ai || echo "Starting..."

sbx create --name current-ai opencode .
sbx policy allow network current-ai localhost:11434
sbx run current-ai
