import 'package:idb_shim/idb_client_memory.dart';
import 'offline_store.dart';

OfflineStore platformOfflineStore() =>
    IndexedOfflineStore(newIdbFactoryMemory());
