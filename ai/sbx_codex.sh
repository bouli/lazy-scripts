if sbx secret ls | grep -qi "openai"; then\
    echo "using the open ai config you have in sbx";\
else\
    sbx secret set -g openai --oauth;\
fi

sbx create --name codex-${PWD##*/} codex . || echo "starting codex in sandbox"
sbx run codex-${PWD##*/}
