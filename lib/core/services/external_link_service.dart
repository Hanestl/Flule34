import 'package:url_launcher/url_launcher.dart';

final class ExternalLinkException implements Exception {
  const ExternalLinkException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract final class ExternalLinkService {
  static Future<void> open(Uri uri) async {
    if (uri.scheme != 'https') {
      throw const ExternalLinkException('只允许打开 HTTPS 链接。');
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw ExternalLinkException('无法打开链接：$uri');
    }
  }
}
