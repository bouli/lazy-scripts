#!/bin/bash

rm -r ~/sandbox
uv init ~/sandbox
uv sync --directory ~/sandbox
code ~/sandbox
