#!/usr/bin/env bash
# Wraps src/game.html (an HTML fragment) into a standalone index.html.
set -euo pipefail
cd "$(dirname "$0")"
{
  echo '<!doctype html>'
  echo '<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">'
  sed -n '1,/<\/style>/p' src/game.html
  echo '</head><body>'
  sed -n '/<\/style>/,$p' src/game.html | tail -n +2
  echo '</body></html>'
} > index.html
echo "built index.html"
