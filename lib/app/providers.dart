import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/rule34video_api.dart';
import '../core/session/session_store.dart';

final sessionStoreProvider = Provider<SessionStore>((ref) {
  final store = SessionStore();
  ref.onDispose(store.dispose);
  return store;
});

final rule34VideoApiProvider = Provider<Rule34VideoApi>((ref) {
  final api = Rule34VideoApi(sessionStore: ref.watch(sessionStoreProvider));
  ref.onDispose(api.close);
  return api;
});

final appInitializationProvider = FutureProvider<void>((ref) {
  return ref.read(sessionStoreProvider).load();
});
