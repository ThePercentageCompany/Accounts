import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/features/tasks/domain/task_link.dart';

void main() {
  final company = 'c' * 43;
  final task = 't' * 43;

  test('shared link opens the explicit task route without private query data',
      () {
    final link = TaskLink(company, task);
    final url =
        link.url(Uri.parse('https://example.com/app/?code=private#old'));
    expect(url.fragment, '/tasks/$company/$task');
    expect(url.query, isEmpty);
    expect(url.path, '/app/');
    final parsed = TaskLink.parse(url.toString())!;
    expect(parsed.companyId, company);
    expect(parsed.taskId, task);
    expect(TaskLink.parse(parsed.route)!.taskId, task);
  });

  test('existing shared and notification links still resolve', () {
    for (final value in [
      'task=$company:$task',
      'https://example.com/#task=$company:$task',
      'task=$company:$task:notification',
    ]) {
      expect(TaskLink.parse(value)!.taskId, task);
    }
  });

  test('malformed routes cannot select a task', () {
    for (final value in [
      '/',
      '/tasks/company/task',
      '/tasks/$company/$task/extra',
      'task=$company:',
      '/tasks/$company/${'!' * 43}',
    ]) {
      expect(TaskLink.parse(value), isNull);
    }
  });
}
