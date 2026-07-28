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

  test('解析播放列表编辑表单', () {
    const source = '''
      <form action="/edit-playlist/42/">
        <input name="title" value="精选列表">
        <textarea name="description">只保留高质量视频</textarea>
        <input type="hidden" name="is_private" value="0">
        <input type="checkbox" name="is_private" value="1" checked>
      </form>
    ''';

    final form = SiteParser.playlistForm(source);

    expect(form.title, '精选列表');
    expect(form.description, '只保留高质量视频');
    expect(form.isPrivate, isTrue);
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
          <img src="data:image/gif;base64,placeholder"
               data-original="/contents/avatars/98000/98965.png"
               alt="">
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

  test('解析账号订阅实体并识别类型', () {
    const source = '''
      <div class="item">
        <a href="/models/example-artist/" title="Example Artist">
          <img data-original="/contents/models/87/artist.jpg"
               alt="Example Artist">
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
    expect(
      subscriptions.first.thumbnailUrl,
      'https://rule34video.com/contents/models/87/artist.jpg',
    );
    expect(subscriptions.last.kind.name, 'category');
    expect(subscriptions.last.title, 'Example Category');
  });

  test('解析发现目录实体并去重', () {
    const source = '''
      <div class="item">
        <a href="/models/example-artist/" title="Example Artist">
          <img data-original="/contents/models/87/artist.jpg"
               alt="Example Artist">
        </a>
        <span>42 videos</span>
      </div>
      <a href="/models/example-artist/">重复链接</a>
    ''';

    final items = SiteParser.contentCollections(source, DiscoveryKind.model);

    expect(items, hasLength(1));
    expect(items.single.id, 'example-artist');
    expect(items.single.filterId, '87');
    expect(items.single.title, 'Example Artist');
    expect(items.single.total, 42);
    expect(items.single.path, '/models/example-artist/');
  });

  test('直接解析艺术家详情页头像', () {
    const source = '''
      <div class="brand_image">
        <div class="brand_image_wrapper">
          <img src="/contents/models/446/juicyneko.jpg" alt="Juicyneko">
        </div>
      </div>
    ''';

    expect(
      SiteParser.collectionAvatar(source),
      'https://rule34video.com/contents/models/446/juicyneko.jpg',
    );
  });

  test('动态解析4K视频源并规范化清晰度', () {
    const source = '''
      <link rel="canonical" href="/video/123/example/">
      <script>
        flashvars = {
          video_url: 'https://cdn.example.com/example_360.mp4',
          video_url_text: '360p',
          video_alt_url3: 'https://cdn.example.com/example_1080p.mp4',
          video_alt_url3_text: '1080p',
          video_alt_url4: 'https://cdn.example.com/example_2160p.mp4',
          video_alt_url4_text: '4k'
        };
      </script>
    ''';

    final details = SiteParser.videoDetails(
      source: source,
      fallback: const VideoItem(id: '123', title: 'Example', slug: 'example'),
    );

    expect(details.sources.map((item) => item.label), [
      '360p',
      '1080p',
      '2160p (4K)',
    ]);
    expect(details.sources.last.isHd, isTrue);
  });

  test('收藏状态只读取当前视频主操作区', () {
    const unrelated = '''
      <a class="delete button_fav">Delete from Favorites</a>
      <div id="tab_video_info">
        <a class="button_fav">Add to Favorites</a>
      </div>
    ''';
    const current = '''
      <div id="tab_video_info">
        <a class="delete button_fav">Delete from Favorites</a>
      </div>
    ''';
    const fallback = VideoItem(id: '123', title: 'Example', slug: 'example');

    expect(
      SiteParser.videoDetails(source: unrelated, fallback: fallback).isFavorite,
      isFalse,
    );
    expect(
      SiteParser.videoDetails(source: current, fallback: fallback).isFavorite,
      isTrue,
    );
  });

  test('解析账号播放列表', () {
    const source = '''
      <div class="item">
        <a href="/my/playlists/42/example/" title="Example playlist">
          <img src="/playlist.jpg" alt="Example playlist">
        </a>
        <span>12 videos</span>
        <span>345 views</span>
      </div>
    ''';

    final playlists = SiteParser.playlists(source);

    expect(playlists, hasLength(1));
    expect(playlists.single.id, '42');
    expect(playlists.single.videoCount, 12);
    expect(playlists.single.views, 345);
  });

  test('播放列表名称优先于封面中的首个视频名称', () {
    const source = '''
      <div class="item">
        <a class="thumb" href="/my/playlists/42/selected/" title="首个视频">
          <img src="/video.jpg" alt="首个视频">
        </a>
        <div class="title">
          <a href="/my/playlists/42/selected/">真正的播放列表名称</a>
        </div>
        <span>3 videos</span>
      </div>
    ''';

    final playlist = SiteParser.playlists(source).single;

    expect(playlist.title, '真正的播放列表名称');
  });

  test('播放列表卡片把标题、视频数和浏览量分别解析', () {
    const source = '''
      <div class="item thumb">
        <a class="th" href="/playlists/2744709/test1104/">
          <div class="img wrap_image">
            <img src="/video1.jpg" alt="第一个视频">
          </div>
          <div class="thumb_title">test1</div>
          <div class="thumb_info">
            <div class="added">3 videos</div>
            <div class="views">3</div>
          </div>
        </a>
      </div>
    ''';

    final playlist = SiteParser.playlists(source).single;

    expect(playlist.title, 'test1');
    expect(playlist.videoCount, 3);
    expect(playlist.views, 3);
  });

  test('视频详情解析已经加入的播放列表 ID', () {
    const source = '''
      <ul class="btn-favourites">
        <li id="delete_playlist_42">
          <a class="delete" data-fav-type="10" data-playlist-id="42"></a>
        </li>
        <li id="add_playlist_42" class="hidden">
          <a href="#add_to_playlist" data-fav-type="10" data-playlist-id="42"></a>
        </li>
        <li id="delete_playlist_77" class="hidden">
          <a class="delete" data-fav-type="10" data-playlist-id="77"></a>
        </li>
        <li id="add_playlist_77">
          <a href="#add_to_playlist" data-fav-type="10" data-playlist-id="77"></a>
        </li>
      </ul>
    ''';

    final details = SiteParser.videoDetails(
      source: source,
      fallback: const VideoItem(id: '123', title: 'Example', slug: 'example'),
    );

    expect(details.playlistIds, {'42'});
  });

  test('解析视频元数据投票项、评分票数和评论', () {
    const source = '''
      <script type="application/ld+json">
        {"@type":"VideoObject","name":"Example","uploadDate":"2026-07-24"}
      </script>
      <div class="action_rating">
        <div class="voters count">94% (1,234)</div>
      </div>
      <div class="col">
        <div class="label">Uploaded by</div>
        <a href="/members/42/">
          <img src="/uploader.jpg" alt="Example Uploader">
          <span class="verified-status"></span>
        </a>
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
          <img src="/contents/models/639/artist.jpg" alt="Example Artist">
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
    expect(details.metadataItems, hasLength(2));
    expect(details.metadataItems.first.id, '199');
    expect(details.metadataItems.first.upScore, 8);
    expect(details.categories, ['3D']);
    expect(details.models, ['Example Artist']);
    expect(
      details.metadataItems.last.thumbnailUrl,
      'https://rule34video.com/contents/models/639/artist.jpg',
    );
    expect(details.video.publishedLabel, '2026-07-24');
    expect(details.relatedVideos.single.id, '456');
    expect(details.uploader?.id, '42');
    expect(details.uploader?.name, 'Example Uploader');
    expect(details.uploader?.avatarUrl, 'https://rule34video.com/uploader.jpg');
    expect(details.uploader?.verified, isTrue);
    expect(
      SiteParser.isVideoDetailsPage(
        '<link rel="canonical" href="/video/123/example/">',
        '123',
      ),
      isTrue,
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
