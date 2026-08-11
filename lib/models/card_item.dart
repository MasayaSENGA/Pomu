/// クレジットカード1枚分の情報を表すモデル。
class CardItem {
  /// 券面カラーの選択肢数。`CardPalette.all.length` と一致させること
  /// （ズレていないことは card_item_test.dart で検証している）。
  static const int paletteCount = 8;

  final String id;
  String name; // カード名
  String last4; // カード番号の下4桁
  int closingDay; // 締め日（1〜31）
  String usageMethod; // $付け方法のメモ
  int colorIndex; // 券面カラー（CardPalette のインデックス）
  bool isUsedThisCycle; // 現在の締めサイクルで利用済みか
  DateTime? cycleClosingDate; // 現在追跡しているサイクルの締め日

  /// このカードに割り当てられた通知IDのブロック番号。
  /// 通知IDは「ブロック番号 × スロット数 + 枝番」で決まる。
  /// null は未割り当てで、[CardRepository] が保存時に採番する。
  int? notificationBlock;

  CardItem({
    required this.id,
    required this.name,
    required this.last4,
    required this.closingDay,
    required this.usageMethod,
    this.colorIndex = 0,
    this.isUsedThisCycle = false,
    this.cycleClosingDate,
    this.notificationBlock,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'last4': last4,
        'closingDay': closingDay,
        'usageMethod': usageMethod,
        'colorIndex': colorIndex,
        'isUsedThisCycle': isUsedThisCycle,
        'cycleClosingDate': cycleClosingDate?.toIso8601String(),
        'notificationBlock': notificationBlock,
      };

  /// 保存済みデータから復元する。
  ///
  /// 端末に残ったデータは旧バージョン由来だったり壊れていたりするので、
  /// id 以外は型が違っても既定値に倒して読み進める。
  /// id が無いものは通知の対象を特定できないため [FormatException] を投げ、
  /// 呼び出し側（[CardRepository]）がその1件だけスキップする。
  factory CardItem.fromJson(Map<String, dynamic> json) {
    final id = _asString(json['id']);
    if (id == null || id.isEmpty) {
      throw const FormatException('id を持たないカードデータです');
    }

    final name = _asString(json['name'])?.trim();
    final closingDay = _asInt(json['closingDay']) ?? 1;

    return CardItem(
      id: id,
      name: (name == null || name.isEmpty) ? '名称未設定のカード' : name,
      last4: _asString(json['last4'])?.trim() ?? '',
      // 範囲外の値は closingDateFor が壊れるのでここで丸める。
      closingDay: closingDay.clamp(1, 31),
      usageMethod: _asString(json['usageMethod']) ?? '',
      // 旧バージョンのデータには色が無いので、ID から決定的に割り当てる。
      colorIndex:
          _asInt(json['colorIndex']) ?? (id.hashCode & 0x7fffffff) % paletteCount,
      isUsedThisCycle: _asBool(json['isUsedThisCycle']) ?? false,
      cycleClosingDate: _asDate(json['cycleClosingDate']),
      notificationBlock: _asInt(json['notificationBlock']),
    );
  }

  static String? _asString(Object? value) => value is String ? value : null;

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static bool? _asBool(Object? value) => value is bool ? value : null;

  static DateTime? _asDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
