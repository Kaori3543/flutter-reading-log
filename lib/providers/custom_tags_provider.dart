/// ユーザーが定義したタグ名（本に紐付かないタグ）の Riverpod provider（W12）。
///
/// 本に紐付くタグ（Book.tags）とは別に、タグ管理画面で「+ 新規タグ」で
/// 作ったタグ名を保持する。本詳細のタグ編集ダイアログでは、
/// この一覧と Book.tags から集計した一覧をマージして候補として表示する。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'reading_goal_provider.dart' show settingsRepositoryProvider;
import '../services/settings_repository.dart';

class CustomTagsNotifier extends StateNotifier<List<String>> {
  CustomTagsNotifier(this._repo) : super(_repo.customTagNames);

  final SettingsRepository _repo;

  Future<void> addTag(String name) async {
    await _repo.addCustomTag(name);
    state = _repo.customTagNames;
  }

  Future<void> removeTag(String name) async {
    await _repo.removeCustomTag(name);
    state = _repo.customTagNames;
  }

  Future<void> renameTag(String oldName, String newName) async {
    await _repo.renameCustomTag(oldName, newName);
    state = _repo.customTagNames;
  }
}

/// ユーザー定義タグの provider。
/// 状態は `List<String>`。
final customTagsProvider =
    StateNotifierProvider<CustomTagsNotifier, List<String>>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return CustomTagsNotifier(repo);
});
