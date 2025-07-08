#!/bin/bash
set -e

echo "🚀 Initializing all dotfiles..."

for dir in */ ; do
  if [[ -f "$dir/init.sh" ]]; then
    echo "👉 Running $dir/init.sh"
    bash "$dir/init.sh"
  fi
done

echo "✅ All done!"
