import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/app/providers.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';
import 'package:flule34/shared/video_card.dart';

void main() {
  testWidgets('视频卡片按网页信息架构展示元数据', (tester) async {
    final container = ProviderContainer(
      overrides: [
        appSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: VideoCard(
              video: VideoItem(
                id: '123',
                title: 'MOM BREAKER',
                slug: 'mom-breaker',
                duration: '2:34',
                publishedLabel: '23 minutes ago',
                rating: 100,
                ratingVotes: 2,
                views: 256,
              ),
              onTap: _noop,
            ),
          ),
        ),
      ),
    );

    expect(find.text('MOM BREAKER'), findsOneWidget);
    expect(find.text('23 minutes ago'), findsOneWidget);
    expect(find.text('100% (2)'), findsOneWidget);
    expect(find.text('256'), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_fill), findsNothing);

    final durationPosition = tester.widget<Positioned>(
      find
          .ancestor(of: find.text('2:34'), matching: find.byType(Positioned))
          .first,
    );
    expect(durationPosition.left, 8);
    expect(durationPosition.right, isNull);
  });
}

void _noop() {}

final class _MemorySettingsStore implements AppSettingsStore {
  @override
  Future<bool?> readBool(String key) async => null;

  @override
  Future<String?> readString(String key) async => null;

  @override
  Future<void> writeBool(String key, bool value) async {}

  @override
  Future<void> writeString(String key, String value) async {}
}
