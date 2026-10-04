import 'package:idb_shim/idb_browser.dart';
import 'cache_store.dart';

CacheStore platformCacheStore() => IndexedCacheStore(idbFactoryBrowser);
