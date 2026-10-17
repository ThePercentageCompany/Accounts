import 'package:flutter/foundation.dart';
import '../cache/cache_store.dart';
import '../offline/offline_store.dart';
import '../offline/preferences_store.dart';
import 'saas_api.dart';

SaasApi createWorkspaceApi() => SaasApi(
    offlineStore: createOfflineStore(),
    cacheStore: kIsWeb ? createCacheStore() : PreferencesCacheStore());
