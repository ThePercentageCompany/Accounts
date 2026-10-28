import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/features/tasks/presentation/task_workspace.dart';

void main() {
  testWidgets('tag copy icon and label both trigger copying', (tester) async {
    var copies = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Align(
                alignment: Alignment.topLeft,
                child:
                    TaskTagChip(tag: 'Follow up', onCopy: () => copies++)))));

    // Chip labels ignore pointer events; the enclosing ActionChip handles taps
    // at both positions, including the trailing copy icon.
    await tester.tapAt(tester.getCenter(find.byIcon(CupertinoIcons.doc_on_doc)));
    await tester.pump();
    expect(copies, 1);

    await tester.tapAt(tester.getCenter(find.text('Follow up')));
    await tester.pump();
    expect(copies, 2);
    expect(tester.takeException(), isNull);
  });
}
