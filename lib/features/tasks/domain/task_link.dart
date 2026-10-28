/// An authenticated task destination. The URL never grants task access.
class TaskLink {
  const TaskLink(this.companyId, this.taskId);
  final String companyId;
  final String taskId;

  String get route => '/tasks/$companyId/$taskId';

  Uri url(Uri app) => app.replace(query: '', fragment: route);

  static TaskLink? parse(String value) {
    final uri = value.startsWith('task=') ? null : Uri.tryParse(value);
    if (uri == null && !value.startsWith('task=')) return null;
    final destination = uri?.hasFragment == true ? uri!.fragment : value;
    final List<String> parts;
    if (destination.startsWith('task=')) {
      parts = destination.substring(5).split(':');
      if (parts.length != 2 && parts.length != 3) return null;
    } else if (destination.startsWith('/tasks/')) {
      parts = destination.substring(7).split('/');
      if (parts.length != 2) return null;
    } else {
      return null;
    }
    final validId = RegExp(r'^[A-Za-z0-9_-]{43}$');
    if (!validId.hasMatch(parts[0]) || !validId.hasMatch(parts[1])) return null;
    return TaskLink(parts[0], parts[1]);
  }
}
