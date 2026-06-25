#!/bin/bash

mv ./.agents ./.claude | True

project_name="${PWD##*/}"
project_name="${project_name//[^[:alnum:]-]/-}"
sandbox_name="claude-${project_name}"
#sbx secret set -g anthropic
if sbx secret ls | grep -qi "anthropic"; then\
    echo "using the open ai config you have in sbx";\
else\
    sbx secret set -g anthropic --oauth;\
fi

sbx create --name "$sandbox_name" claude . || echo "starting claude in sandbox"
sbx run "$sandbox_name"
