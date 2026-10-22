import 'dart:async';

/// Coalesces invalidations, not business records. Older events for different
/// sections still matter, so a workspace-wide revision watermark is unsafe.
class WorkspaceChangeBuffer {
  WorkspaceChangeBuffer(
    this.onChange, {
    this.delay = const Duration(milliseconds: 120),
    this.capacity = 512,
  });

  final void Function(Set<String> sections) onChange;
  final Duration delay;
  final int capacity;
  final _seen = <String>{};
  final _sections = <String>{};
  Timer? _timer;
  bool _all = false;
  bool _disposed = false;

  void add(Map<String, dynamic> event) {
    if (_disposed) return;
    final id = event['id'];
    if (id != null) {
      if (!_seen.add('$id')) return;
      if (_seen.length > capacity) _seen.remove(_seen.first);
    }
    final sections = event['sections'];
    if (sections is! List ||
        sections.isEmpty ||
        sections.any((section) => section is! String)) {
      _all = true;
    } else {
      _sections.addAll(sections.cast<String>());
    }
    // Bound latency during a continuous event stream; do not restart the timer.
    _timer ??= Timer(delay, flush);
  }

  void flush() {
    _timer?.cancel();
    _timer = null;
    if (_disposed || (!_all && _sections.isEmpty)) return;
    final sections = _all ? <String>{} : Set<String>.of(_sections);
    _all = false;
    _sections.clear();
    onChange(sections);
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _sections.clear();
    _seen.clear();
  }
}
