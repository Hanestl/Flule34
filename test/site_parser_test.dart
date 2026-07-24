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

  test('解析账号播放列表及统计信息', () {
    const source = '''
      <div class="item thumb playlist_77">
        <a class="th" href="/my/playlists/77/" title="稍后整理">
          <img data-original="/playlist.jpg" alt="稍后整理">
        </a>
        <div class="title">稍后整理</div>
        <div>12 videos · 3,456 views</div>
      </div>
    ''';

    final playlists = SiteParser.playlists(source);

    expect(playlists, hasLength(1));
    expect(playlists.single.id, '77');
    expect(playlists.single.title, '稍后整理');
    expect(playlists.single.path, '/my/playlists/77/');
    expect(playlists.single.videoCount, 12);
    expect(playlists.single.views, 3456);
    expect(
      playlists.single.thumbnailUrl,
      'https://rule34video.com/playlist.jpg',
    );
  });
}
