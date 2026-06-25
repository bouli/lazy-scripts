#!/bin/bash

mv ./.claude ./.agents | True

project_name="${PWD##*/}"
project_name="${project_name//[^[:alnum:]-]/-}"
sandbox_name="codex-${project_name}"

if sbx secret ls | grep -qi "openai"; then\
    echo "using the open ai config you have in sbx";\
else\
    sbx secret set -g openai --oauth;\
fi

sbx create --name "$sandbox_name" codex . || echo "starting codex in sandbox"
sbx run "$sandbox_name"
