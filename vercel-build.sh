#!/bin/bash
set -e

echo "=== Setting up Flutter SDK for Vercel Build ==="

if [ ! -d "$HOME/flutter" ]; then
  echo "Cloning Flutter repository (stable branch)..."
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
fi

export PATH="$HOME/flutter/bin:$PATH"

echo "Checking Flutter version:"
flutter --version

flutter config --no-analytics
flutter config --enable-web

bash scripts/build-shared-web.sh
echo 'Shared-backend preview build complete.'
