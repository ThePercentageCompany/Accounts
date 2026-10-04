#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo 'Install Flutter stable (3.35 or later), then run this script again.'; exit 1; }
flutter create --platforms=android,ios,web --org=com.thepercentage --project-name=tpc_invoice .
flutter pub get
dart format lib test
flutter analyze
flutter test
printf '%s\n' 'Dependencies checked. See SETUP.md for shared API configuration and operator preview. Production integration is still in progress.'
