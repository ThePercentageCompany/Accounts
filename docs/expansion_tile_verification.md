# ExpansionTile release failure investigation

Verified on 2026-10-06 with Flutter 3.47.2 / Dart 3.13.2 on Windows.

## Confirmed root cause

The failure is a PageStorage type collision, not an unbounded-height error.
ExpansionTile / Expansible stores an expansion **bool**. ScrollPosition stores
its offset as a **double**. PageStorage addresses are constructed from ancestor
PageStorageKeys; independent ScrollControllers do not give independent storage
addresses.

The report page's vertical SingleChildScrollView has `PageStorageKey(_path)`.
The exact trend tile previously had no storage key, and its viewports had only
ordinary Keys. Consequently tile state and viewport offsets could use the same
storage address. The ledger and statement tiles already had storage keys, but
ReportGrid's two viewports inherited those keys without their own addresses.
Collapsing, reopening, changing scroll positions, or recreating a viewport then
allowed an expansion flag to be read as a scroll offset (or vice versa).

The production-widget diagnostic entrypoint was compiled with `--release` and
run in headless Chrome. The pre-storage-fix run reproduced this exception:

```text
PROBE ERROR [width=320 rows=0 scale=1]:
TypeError: true: type 'bool' is not a subtype of type 'double?'

    at Object.Jd (main.dart.js:4741:30)
    at CX.a8e (main.dart.js:83747:14)
    at rf.Wh (main.dart.js:84218:3)
    at rf.by (main.dart.js:84250:3)
    at hK.FW (main.dart.js:78193:9)
    at hK.eO (main.dart.js:78159:6)
    at Qu.rZ (main.dart.js:78011:17)
    at Qu.dG (main.dart.js:77906:24)
    at Qu.iV (main.dart.js:78166:31)
    at Qu.x7 (main.dart.js:78110:10)
```

This is the release JS stack as emitted, with the local server prefix omitted.
The corresponding framework code is `ScrollPosition.restoreScrollOffset`,
which casts `PageStorage.readState(context.storageContext)` to `double?`.
Widget tests reproduced the same type error on actual FinancialReportBody tiles.
The full captured release log is `build/expansion-probe-storage-before.log`.

The audit also reproduced an unsupported date-format exception with metadata
pattern `yyyy-MM-dd EEEEEE` (`intl` does not support short weekdays). Its release
trace is in `build/expansion-probe-format-before.log`. A separate 300% text-scale
test found an 84-pixel legend Row overflow. Both are addressed independently.

## Implemented changes and tile audit

| Widget / file | Change or audit result |
| --- | --- |
| `report_trends.dart` | Separate storage keys for tile and horizontal viewport. Exact table has finite column width and naturally measured height in the existing page scroller. Removed the estimated-height inner vertical scroller. Legend labels wrap at large text sizes. Nonfinite chart inputs show an unavailable state; drawing coordinates are normalized to avoid overflow when subtracting large finite extrema. Exact signed amounts retain ReportFormat formatting. |
| `report_grid.dart` | Separate, stable storage keys for horizontal and vertical offsets, including the column schema. Existing bounded ListView and independent controllers retained. This shared component fixes ledger, statement and monthly-breakdown viewports. |
| `financial_report_body.dart` | Monthly breakdown gets its own tile storage key. Existing per-account ledger and per-group statement keys retained. Empty trends now reach ReportTrends' explicit empty state. |
| `workspace_dashboard.dart` | Empty trends now show the existing explicit empty state. Parent remains a naturally sized Column within the report page's bounded-width vertical scroll view. |
| `mobile_components.dart` | RecordCard's inner tile has a separate PageStorageKey derived from its record key. Detail children use natural height; horizontal Row flex is constrained. No unbounded vertical flex or child viewport found. |
| `system_settings_panel.dart` | System settings tile gets a distinct storage key. ListTile and text children have natural height; no child viewport. |
| `shared_workspace.dart` | Each workspace section tile gets a distinct storage key. The navigation ListView is already bounded by the bottom sheet's existing height; children are ordinary ListTiles. Permission filters and navigation callbacks retained. |
| `report_format.dart` | Catch only UnsupportedError and FormatException from date formatting, log the configuration error with its stack, and retain the date with ISO display. Null/invalid dates and money retain the existing em dash. No broad catch or replacement error UI. |

All seven ExpansionTile call sites were inspected. `CrossAxisAlignment.stretch`
was retained. No blanket shrinkWrap, clipping, fixed-height, or flex replacement
was applied. ReportGrid's paged/lazy scrolling requirements differ from the exact
trend table's naturally sized rows, so those layouts remain separate.

## Regression and release verification

Focused tests cover actual financial tiles, restored offsets after viewport
destruction/recreation, repeated animations, page scrolling, horizontal scrolling,
navigation push/pop, disposal, resizing, portrait/landscape dimensions, and 300%
text. Trend inputs include empty, single-row and 120-row datasets, null dates and
amounts, nonfinite input, negative values, long date formatting and unsupported
date-format metadata. Existing workspace, saved-record and settings tests also run.

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub`: 232 passed, one existing browser-only skip.
- Final Chrome web-release diagnostic matrix: 18 scenarios plus invalid-data /
  unsupported-format scenario, zero Flutter or browser exceptions.
- Final Edge web-release diagnostic matrix: the same 18 scenarios plus
  invalid-data / unsupported-format scenario, zero Flutter or browser exceptions.
- Main application `flutter build web --release --no-pub --no-wasm-dry-run
  --output build/app-release-verification`: succeeded.

The release harness uses the real ReportTrends, FinancialReportBody, RecordCard,
SystemSettingsPanel and ReportGrid, with isolated fixtures and no backend writes.
It expands/collapses three times, scrolls all mounted viewports, validates finite
viewport dimensions and extents, resizes, changes browser orientation dimensions,
and removes/remounts the screen. It retains Flutter's normal error reporting and
error UI while adding full release trace logging. Debug widget tests detect
RenderFlex overflows that release builds would otherwise omit.

Reproduce the diagnostic checks with:

```powershell
flutter build web --release --no-pub --no-wasm-dry-run -t tool/expansion_release_probe.dart --output build/expansion-probe-final
node scripts/check_expansion_release.mjs "C:/Program Files/Google/Chrome/Application/chrome.exe" build/expansion-probe-final
node scripts/check_expansion_release.mjs "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" build/expansion-probe-final
```

Platform limits: Windows native release could not be built because Visual Studio
with the C++ desktop workload is absent. No Android device/emulator was connected;
Android command-line tools and license setup are incomplete. iOS requires a macOS
toolchain unavailable on this host. Native mobile rotation and native desktop
release execution were therefore not verified. Browser resizing and mobile-sized
Flutter widget layouts were verified; these do not replace native device checks.
No authenticated production tenant or deployed site was accessed or changed.
