import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/core/media/video_source_quality.dart';

void main() {
  test('视频源高度解析优先明确格式并避免把宽度当高度', () {
    expect(parseVideoSourceHeight('1080p'), 1080);
    expect(parseVideoSourceHeight('2160p (4K)'), 2160);
    expect(parseVideoSourceHeight('1920x1080'), 1080);
    expect(parseVideoSourceHeight('1280×540'), 540);
    expect(parseVideoSourceHeight('1080'), 1080);
    expect(
      parseVideoSourceHeight(
        'MP4',
        url: 'https://cdn.example.com/video_720p.mp4?token=1',
      ),
      720,
    );
    expect(parseVideoSourceHeight('Full HD'), isNull);
  });
}
