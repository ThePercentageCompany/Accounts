import 'package:idb_shim/idb_browser.dart';
import 'offline_store.dart';

OfflineStore platformOfflineStore() => IndexedOfflineStore(idbFactoryBrowser);
