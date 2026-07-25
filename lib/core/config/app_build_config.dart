abstract final class AppBuildConfig {
  static const updateApiUrl = String.fromEnvironment('FLULE34_UPDATE_API_URL');
  static const repositoryUrl = String.fromEnvironment('FLULE34_REPOSITORY_URL');
  static const flutterVersion = String.fromEnvironment(
    'FLULE34_FLUTTER_VERSION',
    defaultValue: '未注入',
  );
  static const gitCommit = String.fromEnvironment(
    'GIT_COMMIT',
    defaultValue: '未注入',
  );
  static const buildTime = String.fromEnvironment(
    'BUILD_TIME',
    defaultValue: '未注入',
  );

  static Uri? get updateApiUri => _httpsUri(updateApiUrl);
  static Uri? get repositoryUri => _httpsUri(repositoryUrl);

  static Uri? _httpsUri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return null;
    }
    return uri;
  }
}
