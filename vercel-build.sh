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

echo "Fetching project dependencies..."
flutter pub get

echo "Generating Freezed & JSON serialization files..."
dart run build_runner build --delete-conflicting-outputs || true

echo "Building Flutter Web release..."
CLIENT_ID="${GOOGLE_CLIENT_ID:-110697421185-klclvve50ibedrqjc830doqrenp44hif.apps.googleusercontent.com}"
ADMIN_EMAIL="${MASTER_ADMIN_EMAIL:-thepercentagecompany1@gmail.com}"
CONNECTED_FLAG="${CONNECTED:-true}"

flutter build web --release \
  --dart-define=CONNECTED=$CONNECTED_FLAG \
  --dart-define=GOOGLE_CLIENT_ID=$CLIENT_ID \
  --dart-define=MASTER_ADMIN_EMAIL=$ADMIN_EMAIL

echo "=== Build Complete! Output generated in build/web ==="
