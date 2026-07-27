import 'package:flutter/foundation.dart';

@immutable
final class MemberProfile {
  const MemberProfile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.subscribersLabel,
    this.coverUrl,
    this.verified = false,
    this.details = const {},
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? subscribersLabel;
  final String? coverUrl;
  final bool verified;
  final Map<String, String> details;
}
