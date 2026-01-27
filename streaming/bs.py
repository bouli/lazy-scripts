#!/usr/bin/env python3

import os
import sys

def complete_white_space(text):
    white_space = (35-len(text))/2
    text = (int(white_space)*" ") + text
    return text

public_dir = os.path.join(os.path.dirname(os.path.realpath(__file__)), "public")
if not os.path.exists(public_dir):
    os.mkdir(public_dir)
lines = []
line = ""
for word in sys.argv[1:]:
    if line == "":
         line = word
    elif len(line + " " + word) < 35:
        line += " "+word
    else:
        line = complete_white_space(line)
        lines.append(line)
        line = word

if line != "":
    if len(lines)>0:
        line = complete_white_space(line)
    lines.append(line)

with open(os.path.join(public_dir,"message.txt"),"+w") as f:
    f.write("\n".join(lines))
