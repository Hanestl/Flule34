import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class SiteAvatar extends StatelessWidget {
  const SiteAvatar({
    super.key,
    required this.imageUrl,
    this.radius = 24,
    this.fallbackIcon = Icons.person_outline,
  });

  static const _headers = <String, String>{
    'Referer': 'https://rule34video.com/',
    'User-Agent': 'Flule34 Android/1.4.4',
  };

  final String? imageUrl;
  final double radius;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final diameter = radius * 2;
    final fallback = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(child: Icon(fallbackIcon, size: radius * 1.05)),
    );
    final url = imageUrl?.trim();
    return ClipOval(
      child: SizedBox.square(
        dimension: diameter,
        child: url == null || url.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: url,
                httpHeaders: _headers,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 120),
                placeholder: (context, _) => fallback,
                errorWidget: (context, _, _) => fallback,
              ),
      ),
    );
  }
}
