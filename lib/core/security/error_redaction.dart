String redactSensitiveText(Object? value, {int maxLength = 600}) {
  var text = value?.toString() ?? '未知错误';
  text = text.replaceAllMapped(
    RegExp(
      r'''([?&](?:v-acctoken|acctoken|token|access_token|auth|signature|password|passwd|email)=)[^&#\s"']+''',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}<redacted>',
  );
  text = text.replaceAllMapped(
    RegExp(r'(PHPSESSID=)[^;\s]+', caseSensitive: false),
    (match) => '${match.group(1)}<redacted>',
  );
  text = text.replaceAllMapped(
    RegExp(
      r'(Authorization\s*[:=]\s*(?:Bearer\s+)?)[^\s,;]+',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}<redacted>',
  );
  text = text.replaceAllMapped(
    RegExp(r'(Cookie\s*[:=]\s*)[^\r\n]+', caseSensitive: false),
    (match) => '${match.group(1)}<redacted>',
  );
  text = text.replaceAllMapped(
    RegExp(
      r'''((?:"?(?:password|passwd|email)"?\s*[:=]\s*)["']?)[^"',;\s&}\]]+''',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}<redacted>',
  );
  if (text.length <= maxLength) {
    return text;
  }
  return '${text.substring(0, maxLength)}…';
}
