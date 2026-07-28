import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/shared/scroll_to_top_overlay.dart';

void main() {
  testWidgets('滚动超过一屏后显示按钮并可平滑回到顶部', (tester) async {
    final scrollController = ScrollController();
    final overlayController = ScrollToTopController();
    addTearDown(scrollController.dispose);
    addTearDown(overlayController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ScrollToTopOverlay(
          controller: overlayController,
          child: Scaffold(
            body: ListView.builder(
              controller: scrollController,
              itemExtent: 80,
              itemCount: 40,
              itemBuilder: (context, index) => Text('项目 $index'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0,
    );

    scrollController.jumpTo(800);
    await tester.pump();

    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
    );
    await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
    await tester.pumpAndSettle();

    expect(scrollController.offset, 0);
  });

  testWidgets('全屏抑制状态会隐藏回到顶部按钮', (tester) async {
    final scrollController = ScrollController();
    final overlayController = ScrollToTopController();
    addTearDown(scrollController.dispose);
    addTearDown(overlayController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ScrollToTopOverlay(
          controller: overlayController,
          child: Scaffold(
            body: ListView.builder(
              controller: scrollController,
              itemExtent: 80,
              itemCount: 40,
              itemBuilder: (context, index) => Text('项目 $index'),
            ),
          ),
        ),
      ),
    );
    scrollController.jumpTo(800);
    await tester.pump();
    overlayController.setSuppressed(true);
    await tester.pump();

    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0,
    );
  });
}
