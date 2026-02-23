#!/bin/bash
set -e

cd "$(dirname "$0")"
echo "🚀 Initializing all dotfiles..."

for dir in */ ; do
  if [[ -f "$dir/init.sh" ]]; then
    echo "👉 Running $dir/init.sh"
    bash "$dir/init.sh"
  fi
done

# Hidden directories (.config/)
for dir in .*/ ; do
  [[ "$dir" == "./" || "$dir" == "../" ]] && continue
  if [[ -f "$dir/init.sh" ]]; then
    echo "👉 Running $dir/init.sh"
    bash "$dir/init.sh"
  fi
done

echo "✅ All done!"
