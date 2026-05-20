// アプリ全体が例外なく起動できることを確認する smoke test。
//
// W1 の方針（テスト方針: ハイブリッド）に従い、UI の詳細な振る舞いは手動確認とし、
// このファイルでは「ProviderScope + MaterialApp + MainPageWidget の組み合わせで
// クラッシュなく初回描画される」ことだけを確認する。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sample/main.dart';

void main() {
  testWidgets('App launches without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    // 初回フレーム後に MaterialApp と内部の Stack が組み立てられる
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
