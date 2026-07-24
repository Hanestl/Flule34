import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/core/session/session_store.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  test('用户身份和完整 Cookie 可以从安全存储恢复并清除', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    final uri = Uri.parse('https://rule34video.com/');

    await harness.sessionStore.load();
    await harness.sessionStore.cookieJar.saveFromResponse(uri, [
      Cookie('PHPSESSID', 'session-value')
        ..path = '/'
        ..secure = true
        ..httpOnly = true,
    ]);
    await harness.sessionStore.authenticate('2421071');

    final restored = SessionStore(
      cookieJar: harness.newCookieJar(),
      secretStore: harness.secretStore,
      database: harness.database,
    );
    addTearDown(restored.dispose);
    await restored.load();

    expect(restored.currentUserId, '2421071');
    expect(await restored.cookieHeaderFor(uri), 'PHPSESSID=session-value');
    expect(await harness.database.findAccount('2421071'), isNotNull);

    await restored.clear();

    expect(restored.isLoggedIn, isFalse);
    expect(await restored.cookieHeaderFor(uri), isNull);
  });

  test('非法用户 ID 不会建立会话', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();

    await expectLater(
      harness.sessionStore.authenticate('invalid-user'),
      throwsArgumentError,
    );
    expect(harness.sessionStore.isLoggedIn, isFalse);
  });
}
