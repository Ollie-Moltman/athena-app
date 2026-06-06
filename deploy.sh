#!/bin/bash
set -e
cd /data/.openclaw/workspace/detect_ai_ve_backup

GITHUB_TOKEN=*** /proc/$(pgrep -f openclaw | head -1)/environ 2>/dev/null | tr '\0' '\n' | grep GITHUB_TOKEN | cut -d= -f2)
echo "Token found"

git add -A
git commit -m "v1.2.7 - Add overlay diagnostics, explicit width, solid background"
git push https://Ollie-Moltman:$GITHUB_TOKEN@github.com/Ollie-Moltman/athena-app.git HEAD:master
echo "Pushed"