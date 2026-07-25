import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/features/onboarding/adult_gate.dart';

void main() {
  testWidgets('首次确认后不等待持久化即可进入应用', (tester) async {
    final write = Completer<void>();
    final store = _MemoryAdultConfirmationStore(write: write);

    await tester.pumpWidget(
      MaterialApp(
        home: AdultGate(
          store: store,
          child: const Scaffold(body: Text('首页已显示')),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('我已年满法定成年年龄'));
    await tester.pump();

    expect(find.text('首页已显示'), findsOneWidget);
    expect(write.isCompleted, isFalse);

    write.complete();
    await tester.pump();
  });

  testWidgets('持久化失败时进入应用并给出可见提示', (tester) async {
    final write = Completer<void>();
    final store = _MemoryAdultConfirmationStore(write: write);

    await tester.pumpWidget(
      MaterialApp(
        home: AdultGate(
          store: store,
          child: const Scaffold(body: Text('首页已显示')),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('我已年满法定成年年龄'));
    await tester.pump();
    write.completeError(StateError('write failed'));
    await tester.pump();
    await tester.pump();

    expect(find.text('首页已显示'), findsOneWidget);
    expect(find.textContaining('年龄确认未能保存'), findsOneWidget);
  });
}

final class _MemoryAdultConfirmationStore implements AdultConfirmationStore {
  _MemoryAdultConfirmationStore({required this.write});

  final Completer<void> write;

  @override
  Future<bool?> readConfirmed() async => false;

  @override
  Future<void> writeConfirmed(bool value) => write.future;
}
