import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flule34/core/models/account_models.dart';
import 'package:flule34/core/session/session_store.dart';
import 'package:flule34/features/profile/account_page.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  testWidgets('账号切换后不会显示前一个账号迟到的资料', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('1001');
    final api = _SwitchingProfileApi(harness.sessionStore);

    await tester.pumpWidget(MaterialApp(home: AccountPage(api: api)));
    await tester.pump();

    await harness.sessionStore.authenticate('2002');
    await tester.pump();
    api.complete('1001', 'Alice');
    api.complete('2002', 'Bob');
    await tester.pumpAndSettle();

    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('用户 ID：2002'), findsOneWidget);
    expect(find.text('Alice'), findsNothing);
  });
}

final class _SwitchingProfileApi extends Rule34VideoApi {
  _SwitchingProfileApi(SessionStore sessionStore)
    : super(sessionStore: sessionStore);

  final Map<String, Completer<MemberProfile>> _profiles = {};

  @override
  Future<MemberProfile> loadCurrentUserProfile({bool force = false}) {
    final userId = sessionStore.currentUserId!;
    return _profiles.putIfAbsent(userId, Completer<MemberProfile>.new).future;
  }

  void complete(String userId, String displayName) {
    _profiles[userId]!.complete(
      MemberProfile(id: userId, displayName: displayName),
    );
  }

  @override
  void close() {}
}
