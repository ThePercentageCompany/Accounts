#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo 'Install Flutter stable (3.35 or later), then run this script again.'; exit 1; }
flutter create --platforms=android,ios,web --org=com.thepercentage --project-name=tpc_invoice .
# flutter create may add its default counter test; it is not part of this app.
if [ -f test/widget_test.dart ]; then rm test/widget_test.dart; fi
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format lib test
flutter analyze
flutter test
printf '%s\n' 'Ready. Run: flutter run -d chrome (local demo). See SETUP.md for Google-only connected mode.'
