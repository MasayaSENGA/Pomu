/// クレジットカード1枚分の情報を表すモデル。
class CardItem {
  final String id;
  String name; // カード名
  String last4; // カード番号の下4桁
  int closingDay; // 締め日（1〜31）
  String usageMethod; // $付け方法のメモ
  int colorIndex; // 券面カラー（CardPalette のインデックス）
  bool isUsedThisCycle; // 現在の締めサイクルで利用済みか
  DateTime? cycleClosingDate; // 現在追跡しているサイクルの締め日

  CardItem({
    required this.id,
    required this.name,
    required this.last4,
    required this.closingDay,
    required this.usageMethod,
    this.colorIndex = 0,
    this.isUsedThisCycle = false,
    this.cycleClosingDate,
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
      };

  factory CardItem.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    return CardItem(
      id: id,
      name: json['name'] as String,
      last4: json['last4'] as String,
      closingDay: json['closingDay'] as int,
      usageMethod: json['usageMethod'] as String? ?? '',
      // 旧バージョンのデータには色が無いので、ID から決定的に割り当てる。
      colorIndex: json['colorIndex'] as int? ?? (id.hashCode & 0x7fffffff) % 8,
      isUsedThisCycle: json['isUsedThisCycle'] as bool? ?? false,
      cycleClosingDate: json['cycleClosingDate'] != null
          ? DateTime.parse(json['cycleClosingDate'] as String)
          : null,
    );
  }
}
