#!/bin/bash
set -e

REMOTE=landvps
REMOTE_DIR='~/mysite-infrastructure'

# Warn if uncommitted changes exist — they won't be deployed
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Warning: uncommitted changes detected — deploy will use last commit only"
  echo ""
fi

echo "==> Push to GitHub"
git push || {
  echo "Nothing to push or push failed — check remote status with: git status"
  exit 1
}

echo ""
echo "==> Deploy to $REMOTE"
ssh $REMOTE "
  cd $REMOTE_DIR &&
  git pull &&
  docker compose up -d &&
  docker compose exec nginx nginx -s reload
"

echo ""
echo "==> Done"
