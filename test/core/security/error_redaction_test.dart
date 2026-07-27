import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/core/security/error_redaction.dart';

void main() {
  test('异常文本会隐藏视频令牌、Cookie、授权信息和账号字段', () {
    final source = [
      'https://example.com/video.mp4?v-acctoken=temporary-value',
      'PHPSESSID=short-session',
      'Authorization: Bearer access-value',
      'Cookie: name=value; another=value',
      'email=user@example.com&password=plain-text',
      '{"email":"json@example.com","password":"json-secret"}',
    ].join('\n');

    final redacted = redactSensitiveText(source);

    expect(redacted, contains('v-acctoken=<redacted>'));
    expect(redacted, contains('PHPSESSID=<redacted>'));
    expect(redacted, contains('Authorization: Bearer <redacted>'));
    expect(redacted, contains('Cookie: <redacted>'));
    expect(redacted, contains('email=<redacted>'));
    expect(redacted, contains('password=<redacted>'));
    expect(redacted, isNot(contains('temporary-value')));
    expect(redacted, isNot(contains('short-session')));
    expect(redacted, isNot(contains('access-value')));
    expect(redacted, isNot(contains('user@example.com')));
    expect(redacted, isNot(contains('json-secret')));
  });

  test('异常文本会限制持久化长度', () {
    expect(redactSensitiveText('x' * 20, maxLength: 8), 'xxxxxxxx…');
  });
}
