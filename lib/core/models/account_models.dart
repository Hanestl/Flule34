import 'package:flutter/foundation.dart';

@immutable
final class MemberProfile {
  const MemberProfile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.subscribersLabel,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? subscribersLabel;
}
