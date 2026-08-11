import 'package:flutter_test/flutter_test.dart';

import 'package:card_usage_tracker/models/card_item.dart';
import 'package:card_usage_tracker/theme/app_theme.dart';

void main() {
  test('paletteCount は CardPalette の選択肢数と一致している', () {
    // ズレると旧データの色フォールバックが偏る。
    expect(CardItem.paletteCount, CardPalette.all.length);
  });

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
      notificationBlock: 4242,
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
    expect(restored.notificationBlock, card.notificationBlock);
  });

  test('id が無いデータは読み込みを拒否する', () {
    // 通知の対象を特定できないため、握りつぶさず呼び出し側にスキップさせる。
    expect(
      () => CardItem.fromJson({'name': 'idなし', 'last4': '1234'}),
      throwsFormatException,
    );
  });

  test('名前が空でも読み込める', () {
    final restored = CardItem.fromJson({'id': 'a', 'name': '  '});
    expect(restored.name, '名称未設定のカード');
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
