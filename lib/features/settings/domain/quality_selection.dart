import '../../../core/models/video_models.dart';
import '../../../core/media/video_source_quality.dart';
import 'app_settings.dart';

VideoSource selectVideoSource(
  List<VideoSource> sources,
  VideoQualityPreference preference,
) {
  if (sources.isEmpty) {
    throw ArgumentError.value(sources, 'sources', '视频源不能为空');
  }

  final ranked = sources
      .map(
        (source) => (
          source: source,
          height: parseVideoSourceHeight(source.label, url: source.url),
        ),
      )
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
