part of 'task_workspace.dart';

class TaskCard extends StatelessWidget {
  const TaskCard(
      {super.key, required this.task, required this.onTap, this.onEdit});
  final Map<String, dynamic> task;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) {
    final due = DateTime.tryParse('${task['dueDate']}');
    final today = taskToday();
    final dueLabel = due == null
        ? 'No due date'
        : taskDate(due) == taskDate(today)
            ? 'Due today'
            : taskDate(due) == taskDate(today.add(const Duration(days: 1)))
                ? 'Tomorrow'
                : DateFormat('d MMM yyyy').format(due);
    final overdue =
        due != null && due.isBefore(today) && task['status'] != 'COMPLETED';
    return Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            onTap: onTap,
            child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(taskLabel('${task['priority']}'),
                                style: TextStyle(
                                    color: taskColor('${task['priority']}'),
                                    fontWeight: FontWeight.w600))),
                        PopupMenuButton<String>(
                            tooltip: 'Task actions',
                            onSelected: (v) =>
                                v == 'edit' ? onEdit?.call() : onTap(),
                            itemBuilder: (_) => [
                                  const PopupMenuItem(
                                      value: 'open', child: Text('Open task')),
                                  if (onEdit != null)
                                    const PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Edit / reassign'))
                                ])
                      ]),
                      Text('${task['title']}',
                          style: Theme.of(context).textTheme.titleMedium),
                      if ('${task['project'] ?? ''}'.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('${task['project']}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall)),
                      if ('${task['tags'] ?? ''}'.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('${task['tags']}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall)),
                      const SizedBox(height: 10),
                      Text('${task['assigneeName'] ?? ''}',
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      Text(
                          '$dueLabel${'${task['endTime'] ?? ''}'.isEmpty ? '' : ' · ${task['endTime']}'}${overdue ? ' · Overdue' : ''}',
                          style: TextStyle(
                              color: overdue
                                  ? Theme.of(context).colorScheme.error
                                  : null)),
                      const SizedBox(height: 8),
                      Text(taskLabel('${task['status']}'),
                          style: TextStyle(
                              color: taskColor('${task['status']}'),
                              fontWeight: FontWeight.w600)),
                    ]))));
  }
}

class _TaskSkeleton extends StatelessWidget {
  const _TaskSkeleton();
  @override
  Widget build(BuildContext context) => Semantics(
      label: 'Loading tasks',
      child: Card(
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final width in [220.0, 150.0, 90.0])
                      Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                              width: width,
                              height: 16,
                              decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4))))
                  ]))));
}

Future<T?> _taskSurface<T>(BuildContext context, Widget child,
    {bool drawer = false}) {
  if (MediaQuery.sizeOf(context).width < 768 ||
      MediaQuery.sizeOf(context).height < 600) {
    return Navigator.of(context).push<T>(
        MaterialPageRoute(fullscreenDialog: true, builder: (_) => child));
  }
  return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close task',
      pageBuilder: (context, a, b) => SafeArea(
          child: Align(
              alignment: drawer ? Alignment.centerRight : Alignment.center,
              child: Material(
                  clipBehavior: Clip.antiAlias,
                  borderRadius: BorderRadius.circular(drawer ? 0 : 16),
                  child: SizedBox(
                      width: drawer ? 780 : 680,
                      height: MediaQuery.sizeOf(context).height - 48,
                      child: child)))));
}
