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

  return withHeight.reduce((best, candidate) {
    final bestDistance = (best.height! - target).abs();
    final candidateDistance = (candidate.height! - target).abs();
    if (candidateDistance != bestDistance) {
      return candidateDistance < bestDistance ? candidate : best;
    }
    return candidate.height! > best.height! ? candidate : best;
  }).source;
}

int? _height(String label) {
  final match = RegExp(
    r'(\d{3,4})\s*p?',
    caseSensitive: false,
  ).firstMatch(label);
  return match == null ? null : int.tryParse(match.group(1)!);
}
