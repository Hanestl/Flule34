import 'package:flutter_test/flutter_test.dart';
import 'package:flule34/core/api/site_parser.dart';
import 'package:flule34/core/models/video_models.dart';

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
        <div class="time">2:34</div>
        <div class="thumb_title">Example video</div>
        <div class="thumb_info">
          <div class="added">23 minutes ago</div>
          <div class="rating">100% (2)</div>
          <div class="views">1.2K</div>
        </div>
      </div>
    ''';

    final videos = SiteParser.videoList(source);

    expect(videos, hasLength(1));
    expect(videos.single.id, '1234567');
    expect(videos.single.slug, 'example-video');
    expect(videos.single.title, 'Example video');
    expect(videos.single.thumbnailUrl, 'https://rule34video.com/thumbnail.jpg');
    expect(videos.single.previewUrl, 'https://rule34video.com/preview.mp4');
    expect(videos.single.duration, '2:34');
    expect(videos.single.publishedLabel, '23 minutes ago');
    expect(videos.single.rating, 100);
    expect(videos.single.ratingVotes, 2);
    expect(videos.single.views, 1200);
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

  test('解析成员资料中的名称、头像和订阅数', () {
    const source = '''
      <div class="channel_logo">
        <div class="avatar">
          <img src="/contents/avatars/98000/98965.png" alt="">
        </div>
        <h2 class="title">Oppai3Dporn</h2>
        <div class="subscribers_count">25K <span>Subscribers</span></div>
      </div>
    ''';

    final profile = SiteParser.memberProfile(source, '98965');

    expect(profile, isNotNull);
    expect(profile!.id, '98965');
    expect(profile.displayName, 'Oppai3Dporn');
    expect(
      profile.avatarUrl,
      'https://rule34video.com/contents/avatars/98000/98965.png',
    );
    expect(profile.subscribersLabel, '25K Subscribers');
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

  test('解析账号订阅实体并识别类型', () {
    const source = '''
      <div class="item">
        <a href="/models/example-artist/" title="Example Artist">
          <img data-original="/artist.jpg" alt="Example Artist">
        </a>
      </div>
      <div class="item">
        <a href="/categories/123/example-category/">Example Category</a>
      </div>
    ''';

    final subscriptions = SiteParser.subscriptions(source);

    expect(subscriptions, hasLength(2));
    expect(subscriptions.first.kind.name, 'model');
    expect(subscriptions.first.path, '/models/example-artist/');
    expect(subscriptions.last.kind.name, 'category');
    expect(subscriptions.last.title, 'Example Category');
  });

  test('解析发现目录实体并去重', () {
    const source = '''
      <div class="item">
        <a href="/models/example-artist/" title="Example Artist">
          <img data-original="/artist.jpg" alt="Example Artist">
        </a>
        <span>42 videos</span>
      </div>
      <a href="/models/example-artist/">重复链接</a>
    ''';

    final items = SiteParser.contentCollections(source, DiscoveryKind.model);

    expect(items, hasLength(1));
    expect(items.single.id, 'example-artist');
    expect(items.single.title, 'Example Artist');
    expect(items.single.total, 42);
    expect(items.single.path, '/models/example-artist/');
  });

  test('解析视频元数据投票项、评分票数和评论', () {
    const source = '''
      <script type="application/ld+json">
        {"@type":"VideoObject","name":"Example","uploadDate":"2026-07-24"}
      </script>
      <div class="action_rating">
        <div class="voters count">94% (1,234)</div>
      </div>
      <a href="#tab_comments">Comments (2)</a>
      <span class="js-video-vote-chip"
            data-item-type="category"
            data-item-id="199"
            data-up-score="8"
            data-down-score="2">
        <a href="/categories/3d/"><span>3D</span></a>
      </span>
      <span class="js-video-vote-chip"
            data-item-type="model"
            data-item-id="639">
        <a href="/models/example-artist/">
          <img alt="Example Artist">
        </a>
      </span>
      <div id="video_comments_video_comments_items">
        <div class="item" data-comment-id="77">
          <div class="user-logo"><img src="/avatar.jpg"></div>
          <div class="comment-info">
            <div class="inner"><a href="/members/42/">Tester</a></div>
          </div>
          <div class="date"><span>2 days ago</span></div>
          <div class="coment-text">A useful comment.</div>
        </div>
      </div>
      <div class="item thumb video_456">
        <a class="th js-open-popup" href="/video/456/related/" title="Related">
          <img class="thumb" data-original="/related.jpg" alt="Related">
        </a>
        <div class="time">1:23</div>
        <div class="thumb_title">Related</div>
      </div>
    ''';

    final details = SiteParser.videoDetails(
      source: source,
      fallback: const VideoItem(id: '123', title: 'Example', slug: 'example'),
    );

    expect(details.ratingVotes, 1234);
    expect(details.commentCount, 2);
    expect(details.metadataItems, hasLength(2));
    expect(details.metadataItems.first.id, '199');
    expect(details.metadataItems.first.upScore, 8);
    expect(details.categories, ['3D']);
    expect(details.models, ['Example Artist']);
    expect(details.comments.single.id, '77');
    expect(details.comments.single.author, 'Tester');
    expect(details.comments.single.memberPath, '/members/42/');
    expect(details.video.publishedLabel, '2026-07-24');
    expect(details.relatedVideos.single.id, '456');
    expect(
      details.comments.single.avatarUrl,
      'https://rule34video.com/avatar.jpg',
    );
  });

  test('识别 HTTP 200 异步操作中的服务端错误', () {
    expect(
      SiteParser.asyncActionError('<error>IP already voted</error>'),
      'IP already voted',
    );
    expect(SiteParser.asyncActionError('<success/>'), isNull);
  });
}
