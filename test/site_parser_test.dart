import 'package:flutter_test/flutter_test.dart';
import 'package:flule34/core/api/site_parser.dart';

void main() {
  test('解析列表中的视频卡片', () {
    const source = '''
      <div class="item thumb video_1">
        <a class="th js-open-popup"
           href="https://rule34video.com/video/1234567/example-video/"
           title="Example video">
          <div class="img wrap_image" data-preview="/preview.mp4">
            <img class="thumb" data-original="/thumbnail.jpg" alt="Example video">
          </div>
        </a>
        <div class="thumb_title">2:34</div>
      </div>
    ''';

    final videos = SiteParser.videoList(source);

    expect(videos, hasLength(1));
    expect(videos.single.id, '1234567');
    expect(videos.single.slug, 'example-video');
    expect(videos.single.title, 'Example video');
    expect(videos.single.thumbnailUrl, 'https://rule34video.com/thumbnail.jpg');
    expect(videos.single.previewUrl, 'https://rule34video.com/preview.mp4');
  });

  test('从页面上下文解析稳定用户 ID', () {
    const source = '''
      <script>
        pageContext = { userId: '2421071', locale: 'en' };
      </script>
    ''';

    expect(SiteParser.userId(source), '2421071');
    expect(SiteParser.userId('<html>logged out</html>'), isNull);
  });
}
