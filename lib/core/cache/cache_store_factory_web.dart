import 'package:idb_shim/idb_browser.dart';
import 'package:tpc_invoice/core/cache/cache_store.dart';

CacheStore platformCacheStore() => IndexedCacheStore(idbFactoryBrowser);
