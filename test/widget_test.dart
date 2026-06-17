// アプリ全体が例外なく起動できることを確認する smoke test。
//
// W3: BookRepository を FakeBookRepository で override
// W5: ReviewRepository も FakeReviewRepository で override
// W9: SettingsRepository も _FakeSettingsRepository で override

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sample/main.dart';
import 'package:sample/models/book.dart';
import 'package:sample/models/review.dart';
import 'package:sample/providers/book_list_provider.dart';
import 'package:sample/providers/reading_goal_provider.dart';
import 'package:sample/providers/review_list_provider.dart';
import 'package:sample/services/book_repository.dart';
import 'package:sample/services/review_repository.dart';
import 'package:sample/services/settings_repository.dart';

/// テスト用の in-memory な BookRepository 実装。
class _FakeBookRepository implements BookRepository {
  final Map<String, Book> _store = {};

  @override
  Future<void> init() async {}

  @override
  List<Book> getAll() => _store.values.toList();

  @override
  bool exists(String id) => _store.containsKey(id);

  @override
  Book? findById(String id) => _store[id];

  @override
  Future<void> save(Book book) async {
    _store[book.id] = book;
  }

  @override
  Future<void> remove(String id) async {
    _store.remove(id);
  }

  @override
  Future<void> clear() async {
    _store.clear();
  }
}

/// テスト用の in-memory な ReviewRepository 実装。
class _FakeReviewRepository implements ReviewRepository {
  final Map<String, Review> _store = {};

  @override
  Future<void> init() async {}

  @override
  List<Review> getByBookId(String bookId) =>
      _store.values.where((r) => r.bookId == bookId).toList();

  @override
  List<Review> getAll() => _store.values.toList();

  @override
  Review? findById(String id) => _store[id];

  @override
  Future<void> save(Review review) async {
    _store[review.id] = review;
  }

  @override
  Future<void> remove(String id) async {
    _store.remove(id);
  }

  @override
  Future<void> removeByBookId(String bookId) async {
    _store.removeWhere((_, r) => r.bookId == bookId);
  }

  @override
  Future<void> clear() async {
    _store.clear();
  }
}

/// テスト用の in-memory な SettingsRepository 実装（W9 で追加、W12 拡張）。
class _FakeSettingsRepository implements SettingsRepository {
  int? _goal;
  List<String> _customTags = const [];

  @override
  int? get monthlyGoal => _goal;

  @override
  Future<void> setMonthlyGoal(int? goal) async {
    _goal = goal;
  }

  @override
  List<String> get customTagNames => _customTags;

  @override
  Future<void> addCustomTag(String name) async {
    final t = name.trim();
    if (t.isEmpty || _customTags.contains(t)) return;
    _customTags = [..._customTags, t];
  }

  @override
  Future<void> removeCustomTag(String name) async {
    _customTags = _customTags.where((t) => t != name).toList();
  }

  @override
  Future<void> renameCustomTag(String oldName, String newName) async {
    final t = newName.trim();
    if (t.isEmpty || t == oldName) return;
    _customTags = _customTags
        .map((x) => x == oldName ? t : x)
        .toSet()
        .toList(growable: false);
  }
}

void main() {
  testWidgets('App launches without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepositoryProvider.overrideWithValue(_FakeBookRepository()),
          reviewRepositoryProvider.overrideWithValue(_FakeReviewRepository()),
          settingsRepositoryProvider
              .overrideWithValue(_FakeSettingsRepository()),
        ],
        child: const MyApp(),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);

    // W8 で DiscoverPage が、W9 で HomePage が、楽天 API の
    // レート制限対策で Future.delayed(1100ms) を仕掛ける。テスト終了時に
    // タイマーが残っていると _verifyInvariants で落ちるため、十分な時間を
    // 進めて全タイマーを発火させてから抜ける。
    // 4 セクション × 1.1s = 4.4s + 余裕 → 6 秒進める。
    await tester.pump(const Duration(seconds: 6));
  });
}
