import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/core/security/error_redaction.dart';

void main() {
  test('异常文本会隐藏视频令牌、Cookie 和授权信息', () {
    final source = [
      'https://example.com/video.mp4?v-acctoken=temporary-value',
      'PHPSESSID=short-session',
      'Authorization: Bearer access-value',
      'Cookie: name=value; another=value',
    ].join('\n');

    final redacted = redactSensitiveText(source);

    expect(redacted, contains('v-acctoken=<redacted>'));
    expect(redacted, contains('PHPSESSID=<redacted>'));
    expect(redacted, contains('Authorization: Bearer <redacted>'));
    expect(redacted, contains('Cookie: <redacted>'));
    expect(redacted, isNot(contains('temporary-value')));
    expect(redacted, isNot(contains('short-session')));
    expect(redacted, isNot(contains('access-value')));
  });

  test('异常文本会限制持久化长度', () {
    expect(redactSensitiveText('x' * 20, maxLength: 8), 'xxxxxxxx…');
  });
}
