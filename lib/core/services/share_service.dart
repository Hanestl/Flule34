import 'package:share_plus/share_plus.dart';

import '../models/video_models.dart';

abstract interface class ShareService {
  Future<void> shareVideo(VideoItem video);
}

final class PlatformShareService implements ShareService {
  @override
  Future<void> shareVideo(VideoItem video) async {
    final url = Uri.parse('https://rule34video.com').resolve(video.detailPath);
    await SharePlus.instance.share(
      ShareParams(
        title: video.title,
        subject: video.title,
        text: '${video.title}\n$url',
      ),
    );
  }
}
