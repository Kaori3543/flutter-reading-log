/// 本を検索する画面。
///
/// W2 で導入。楽天 Books API でキーワード検索し、結果を ListView で表示する。
/// W3 で「結果タップ → 本棚に登録」のフローを追加予定（現在は SnackBar の
/// 案内だけ）。
///
/// Flutter 特性として活用:
/// - Navigator.push でこのページに遷移する（MainPageWidget の FAB から）
/// - async/await + FutureBuilder で API レスポンスのローディング表示
/// - TextField + onSubmitted でエンターキー入力に対応
library;

import 'package:flutter/material.dart';
import 'package:sample/list/BookListItem.dart';
import 'package:sample/models/book.dart';
import 'package:sample/services/rakuten_api.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  final _api = RakutenApi();

  /// 現在の検索 Future。null なら未検索状態（初期画面）。
  Future<List<Book>>? _searchFuture;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _runSearch() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searchFuture = _api.searchBooks(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('本を検索'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // 検索バー
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'タイトル / 著者 / キーワード',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _runSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _runSearch,
                  child: const Text('検索'),
                ),
              ],
            ),
          ),
          // 結果表示
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_searchFuture == null) {
      // 未検索: 案内テキストだけ表示
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '上の検索バーに本のタイトル・著者・キーワードを入力して\n「検索」を押してください',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    return FutureBuilder<List<Book>>(
      future: _searchFuture,
      builder: (context, snapshot) {
        // ローディング中
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        // エラー（applicationId 未設定 / 通信失敗 / パース失敗 など）
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '検索に失敗しました\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }
        // 結果あり
        final books = snapshot.data ?? [];
        if (books.isEmpty) {
          return const Center(
            child: Text('該当する本が見つかりませんでした'),
          );
        }
        return ListView.builder(
          itemCount: books.length,
          itemBuilder: (context, index) {
            final book = books[index];
            return BookListItem(
              book: book,
              onPressed: () {
                // W3 で「本棚に追加」フローを実装予定。
                // 現在は SnackBar の案内だけ。
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '「${book.title}」を本棚に追加する機能は W3 で実装予定です',
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
