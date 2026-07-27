import '../../../core/models/video_models.dart';
import 'app_settings.dart';

VideoSource selectVideoSource(
  List<VideoSource> sources,
  VideoQualityPreference preference,
) {
  if (sources.isEmpty) {
    throw ArgumentError.value(sources, 'sources', '视频源不能为空');
  }

  final ranked = sources
      .map((source) => (source: source, height: _height(source.label)))
      .toList(growable: false);
  final withHeight = ranked.where((item) => item.height != null).toList();
  if (withHeight.isEmpty) {
    return sources.last;
  }

  withHeight.sort((left, right) => left.height!.compareTo(right.height!));
  final target = preference.targetHeight;
  if (target == null) {
    return withHeight.last.source;
  }
  final atOrBelow = withHeight.where((item) => item.height! <= target).toList();
  if (atOrBelow.isNotEmpty) {
    return atOrBelow.last.source;
  }
  // 如果网站只提供高于目标的源，最低可用档仍比直接失败更合理。
  return withHeight.first.source;
}

int? _height(String label) {
  final normalized = label.toLowerCase();
  if (normalized.contains('8k')) {
    return 4320;
  }
  if (normalized.contains('4k')) {
    return 2160;
  }
  final match = RegExp(
    r'(\d{3,4})\s*p?',
    caseSensitive: false,
  ).firstMatch(label);
  return match == null ? null : int.tryParse(match.group(1)!);
}
