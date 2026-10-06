// Controlled release fixture; no credentials, production API, or real records.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'package:tpc_invoice/core/offline/offline_store.dart';
import 'package:tpc_invoice/core/offline/offline_outbox.dart';
import 'package:tpc_invoice/core/cache/read_cache.dart';
import 'package:tpc_invoice/core/cache/cache_store.dart';

void main() => runApp(const MaterialApp(home: Probe()));

class Probe extends StatefulWidget {
  const Probe({super.key});
  @override
  State<Probe> createState() => _ProbeState();
}

class _ProbeState extends State<Probe> {
  final messages = <String>[];
  final store = createOfflineStore();
  late OfflineOutbox one, two;
  int requests = 0;
  List<Map<String, dynamic>> rows = [];
  void check(bool condition, String label) {
    if (!condition) throw StateError(label);
    debugPrint('OFFLINE PROBE $label');
    if (mounted) setState(() => messages.add(label));
  }

  OfflineOutbox box(String scope) => OfflineOutbox(
        store: store,
        scope: scope,
        automatic: false,
        isCurrent: () => true,
        verifyIdentity: () async {},
        changed: (_) {},
        send: (op) async {
          requests++;
          await store.change(scope, (p) {
            p['probeSubmissions'] = (p['probeSubmissions'] as int? ?? 0) + 1;
          });
          await Future<void>.delayed(const Duration(milliseconds: 500));
          return {
            'results': [
              {
                'operationId': op['operationId'],
                'status': 'APPLIED',
                'recordId': 'server-probe',
                'version': 1
              }
            ]
          };
        },
      );
  @override
  void initState() {
    super.initState();
    unawaited(run());
  }

  Future<void> run() async {
    try {
      final cacheStore = createCacheStore();
      final account = 'release-${DateTime.now().microsecondsSinceEpoch}';
      final cache = ReadCache(store: cacheStore, automatic: false);
      cache.configure(scope: account, account: account);
      var reads = 0;
      Future<Map<String, dynamic>> slowRead() async {
        reads++;
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        return {
          'records': [
            {'recordId': 'fixture', 'name': 'Cached customer'}
          ]
        };
      }

      final cold = Stopwatch()..start();
      await cache.read('/v1/companies/fixture/records/Customers', slowRead);
      check(reads == 1,
          'cold usable data ${cold.elapsedMilliseconds}ms; requests=$reads');
      final repeatRead = Stopwatch()..start();
      await cache.read('/v1/companies/fixture/records/Customers', slowRead);
      check(reads == 1,
          'cached repeat navigation ${repeatRead.elapsedMilliseconds}ms; additional requests=0');
      cache.dispose();
      final scope = 'release-fixture';
      one = box(scope);
      two = box(scope);
      await one.reload();
      if (one.pending.isNotEmpty) {
        check(one.overlay('Customers', []).single['name'] == 'Offline customer',
            'pending write survived real page reload');
      } else if (!web.window.location.search.contains('sync')) {
        final watch = Stopwatch()..start();
        await one.enqueue('Customers', 'create', {'name': 'Offline customer'},
            expectedVersion: 0);
        check(requests == 0,
            'local save ${watch.elapsedMilliseconds}ms; network requests=0');
        await two.reload();
        check(two.pending.length == 1,
            'second coordinator reads committed IndexedDB write');
        final repeat = Stopwatch()..start();
        rows = two.overlay('Customers', []);
        await Future<void>.delayed(Duration.zero);
        check(rows.length == 1,
            'repeat local read ${repeat.elapsedMilliseconds}ms; network requests=0');
      }
      // Leave the first run queued so the browser driver can reload offline.
      if (web.window.location.search.contains('sync')) {
        await Future.wait([one.sync(), two.sync()]);
        // A different tab may own the lock; wait for its acknowledgement.
        await Future<void>.delayed(const Duration(seconds: 1));
        await two.reload();
        check(two.data['probeSubmissions'] == 1 && two.pending.isEmpty,
            'exclusive Web Lock: one submission, acknowledged queue empty');
      }
      if (mounted) setState(() => rows = one.overlay('Customers', []));
      await Future<void>.delayed(const Duration(seconds: 2));
      web.document.title = 'PROBE COMPLETE errors=0';
    } catch (error, stack) {
      debugPrint('OFFLINE PROBE ERROR $error\n$stack');
      web.document.title = 'PROBE COMPLETE errors=1';
      rethrow;
    }
  }

  @override
  void dispose() {
    one.dispose();
    two.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Offline release fixture')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          for (final message in messages) Text(message),
          for (final row in rows)
            ExpansionTile(title: Text('${row['name']}'), children: const [
              Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                      'Saved on this device. Server numbering and totals remain authoritative.'))
            ]),
        ]),
      );
}
