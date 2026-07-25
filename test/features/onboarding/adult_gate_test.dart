import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/features/onboarding/adult_gate.dart';

void main() {
  testWidgets('旧年龄确认键会迁移且不会再次拦截', (tester) async {
    final preferences = _MemoryAdultConfirmationPreferences({
      'adult_confirmed': true,
    });

    await tester.pumpWidget(
      MaterialApp(
        home: AdultGate(
          store: SharedPreferencesAdultConfirmationStore(
            preferences: preferences,
          ),
          child: const Scaffold(body: Text('首页已显示')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('首页已显示'), findsOneWidget);
    expect(preferences.values['flule34.onboarding.adult_confirmed'], isTrue);
    expect(preferences.values['adult_confirmed'], isNull);
  });

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

final class _MemoryAdultConfirmationPreferences
    implements AdultConfirmationPreferences {
  _MemoryAdultConfirmationPreferences(Map<String, bool> values)
    : values = Map<String, bool>.of(values);

  final Map<String, bool> values;

  @override
  Future<bool?> getBool(String key) async => values[key];

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> setBool(String key, bool value) async {
    values[key] = value;
  }
}

final class _MemoryAdultConfirmationStore implements AdultConfirmationStore {
  _MemoryAdultConfirmationStore({required this.write});

  final Completer<void> write;

  @override
  Future<bool?> readConfirmed() async => false;

  @override
  Future<void> writeConfirmed(bool value) => write.future;
}
