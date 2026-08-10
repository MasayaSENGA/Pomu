import 'package:flutter_test/flutter_test.dart';

import 'package:card_usage_tracker/models/card_item.dart';

void main() {
  test('toJson / fromJson で往復できる', () {
    final card = CardItem(
      id: 'abc',
      name: '楽天カード',
      last4: '1234',
      closingDay: 15,
      usageMethod: 'Suicaオートチャージ',
      colorIndex: 3,
      isUsedThisCycle: true,
      cycleClosingDate: DateTime(2026, 8, 15),
    );

    final restored = CardItem.fromJson(card.toJson());

    expect(restored.id, card.id);
    expect(restored.name, card.name);
    expect(restored.last4, card.last4);
    expect(restored.closingDay, card.closingDay);
    expect(restored.usageMethod, card.usageMethod);
    expect(restored.colorIndex, card.colorIndex);
    expect(restored.isUsedThisCycle, card.isUsedThisCycle);
    expect(restored.cycleClosingDate, card.cycleClosingDate);
  });

  test('colorIndex が無い旧データでも読み込める', () {
    final restored = CardItem.fromJson({
      'id': 'legacy-1',
      'name': '旧カード',
      'last4': '9999',
      'closingDay': 25,
    });

    expect(restored.name, '旧カード');
    expect(restored.usageMethod, '');
    expect(restored.isUsedThisCycle, isFalse);
    expect(restored.cycleClosingDate, isNull);
    expect(restored.colorIndex, inInclusiveRange(0, 7));
  });
}
