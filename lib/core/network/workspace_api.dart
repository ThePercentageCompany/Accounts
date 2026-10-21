import '../cache/cache_store.dart';
import '../offline/offline_store.dart';
import 'saas_api.dart';

SaasApi createWorkspaceApi() =>
    SaasApi(offlineStore: createOfflineStore(), cacheStore: createCacheStore());
