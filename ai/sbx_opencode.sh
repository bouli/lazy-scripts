#!/bin/bash
set -e

project_name="${PWD##*/}"
project_name="${project_name//[^[:alnum:]-]/-}"
sandbox_name="opencode-${project_name}"

sbx rm "$sandbox_name" || echo "Starting..."

sbx create --name "$sandbox_name" opencode . || echo "Starting..."
sbx policy allow network "$sandbox_name" localhost:11434
sbx run "$sandbox_name"
