/// 月間読書目標の Riverpod provider（W9 で追加）。
///
/// SettingsRepository を介して hive に永続化された月間目標（冊数）を読み書き
/// する。UI 層からは [readingGoalProvider] を watch して現在の目標を取得し、
/// `notifier.setGoal(N)` で書き換える。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_repository.dart';

/// 設定リポジトリの provider。main() で override しておく。
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  throw UnimplementedError(
    'settingsRepositoryProvider must be overridden in main() '
    'with an initialized SettingsRepository',
  );
});

class ReadingGoalNotifier extends StateNotifier<int?> {
  ReadingGoalNotifier(this._repo) : super(_repo.monthlyGoal);

  final SettingsRepository _repo;

  /// 目標を設定する（null を渡すと削除＝目標未設定状態に戻す）。
  Future<void> setGoal(int? goal) async {
    await _repo.setMonthlyGoal(goal);
    state = goal;
  }
}

/// 月間読書目標を保持する provider。状態は `int?`（null は未設定）。
final readingGoalProvider =
    StateNotifierProvider<ReadingGoalNotifier, int?>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return ReadingGoalNotifier(repo);
});
