#!/usr/bin/env python3
import json
import os
import sys

params = json.load(sys.stdin)
path = params["path"]
content = params["content"]

os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as f:
    f.write(content)
    f.write("\n")

print(json.dumps({"path": path}))
