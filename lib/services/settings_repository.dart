/// アプリの簡易な設定（key-value）を hive に永続化するリポジトリ（W9）。
///
/// 「月間読書目標」のように小さなセッション横断状態を扱うために W9 で導入。
/// 既存の本棚 / レビュー用 box とは別の `settings` box に保存する
/// （ライフサイクル・スキーマが違うので物理的に分離）。
///
/// W6 の表示設定とは別物（あちらはセッション内のみ保持・hive に書かない）。
library;

import 'package:hive_ce/hive.dart';

const _boxName = 'settings';
const _monthlyGoalKey = 'reading_goal_monthly';

class SettingsRepository {
  final Box<dynamic> _box;

  SettingsRepository._(this._box);

  /// テスト用: 任意の [Box] を注入できるコンストラクタ。
  SettingsRepository.test(Box<dynamic> box) : _box = box;

  static SettingsRepository? _instance;

  /// アプリ全体で 1 つだけ使う設定リポジトリ。
  /// 本番では [init] で先に open しておく。
  static SettingsRepository get instance {
    final i = _instance;
    if (i == null) {
      throw StateError(
        'SettingsRepository.init() が呼ばれていません。main() で先に初期化してください。',
      );
    }
    return i;
  }

  /// hive の box を開いてシングルトンインスタンスを作る。main() から呼ぶ。
  static Future<void> init() async {
    final box = await Hive.openBox<dynamic>(_boxName);
    _instance = SettingsRepository._(box);
  }

  /// 月間読書目標（冊数）。未設定なら null。
  int? get monthlyGoal {
    final v = _box.get(_monthlyGoalKey);
    if (v is int) return v;
    return null;
  }

  /// 月間読書目標をセット（null を渡すと削除）。
  Future<void> setMonthlyGoal(int? goal) async {
    if (goal == null) {
      await _box.delete(_monthlyGoalKey);
    } else {
      await _box.put(_monthlyGoalKey, goal);
    }
  }
}
