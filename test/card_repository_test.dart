import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:card_usage_tracker/models/card_item.dart';
import 'package:card_usage_tracker/services/alert_schedule.dart';
import 'package:card_usage_tracker/services/card_repository.dart';

/// 通知プラグインはテスト環境で呼べないので、呼び出しだけ記録する差し替え。
class _FakeScheduler implements AlertScheduler {
  final List<String> synced = [];
  final List<String> cancelled = [];
  final List<String> legacyCancelled = [];

  @override
  Future<void> syncAlerts(CardItem card) async => synced.add(card.id);

  @override
  Future<void> cancelAlerts(CardItem card) async => cancelled.add(card.id);

  @override
  Future<void> cancelLegacyAlert(String cardId) async =>
      legacyCancelled.add(cardId);
}

const _storageKey = 'card_usage_tracker.cards';
const _corruptedKey = 'card_usage_tracker.cards.corrupted';

CardItem _newCard(String id, {int closingDay = 15}) => CardItem(
      id: id,
      name: 'カード$id',
      last4: '1234',
      closingDay: closingDay,
      usageMethod: '',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeScheduler scheduler;
  late CardRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    scheduler = _FakeScheduler();
    repository = CardRepository(scheduler);
  });

  group('保存と読み込み', () {
    test('追加したカードにサイクルと通知IDブロックが設定される', () async {
      final cards = await repository.upsertCard(_newCard('a'));

      expect(cards, hasLength(1));
      expect(cards.single.cycleClosingDate, isNotNull);
      expect(cards.single.isUsedThisCycle, isFalse);
      expect(cards.single.notificationBlock, isNotNull);
      expect(scheduler.synced, ['a']);
    });

    test('通知IDのブロックはカードごとに重複しない', () async {
      await repository.upsertCard(_newCard('a'));
      await repository.upsertCard(_newCard('b'));
      await repository.upsertCard(_newCard('c'));

      final blocks =
          (await repository.loadCards()).map((c) => c.notificationBlock);
      expect(blocks.toSet(), hasLength(3));
    });

    test('名前だけ変更しても進捗と通知IDブロックは引き継がれる', () async {
      await repository.upsertCard(_newCard('a'));
      await repository.toggleUsed('a', true);
      final before = (await repository.loadCards()).single;

      final edited = _newCard('a')..name = '改名後';
      await repository.upsertCard(edited);

      final after = (await repository.loadCards()).single;
      expect(after.name, '改名後');
      expect(after.isUsedThisCycle, isTrue);
      expect(after.notificationBlock, before.notificationBlock);
      expect(after.cycleClosingDate, before.cycleClosingDate);
    });

    test('締め日を変えるとサイクルが作り直される', () async {
      await repository.upsertCard(_newCard('a', closingDay: 15));
      await repository.toggleUsed('a', true);

      await repository.upsertCard(_newCard('a', closingDay: 20));

      final after = (await repository.loadCards()).single;
      expect(after.closingDay, 20);
      expect(after.isUsedThisCycle, isFalse);
      expect(after.cycleClosingDate!.day, 20);
    });
  });

  group('同時更新', () {
    test('2枚を同時にトグルしても、どちらの変更も失われない', () async {
      await repository.upsertCard(_newCard('a'));
      await repository.upsertCard(_newCard('b'));

      // await せずに続けて呼ぶ＝画面を素早く2回タップした状況。
      // 直列化していないと、後勝ちで片方のチェックが消える（回帰防止）。
      await Future.wait([
        repository.toggleUsed('a', true),
        repository.toggleUsed('b', true),
      ]);

      final cards = await repository.loadCards();
      expect(cards.where((c) => c.isUsedThisCycle), hasLength(2));
    });

    test('削除と同時にトグルが来ても例外にならない', () async {
      await repository.upsertCard(_newCard('a'));

      await Future.wait([
        repository.deleteCard('a'),
        repository.toggleUsed('a', true),
      ]);

      expect(await repository.loadCards(), isEmpty);
    });

    test('存在しないIDの削除は何もしない', () async {
      await repository.deleteCard('missing');
      expect(scheduler.cancelled, isEmpty);
    });
  });

  group('壊れたデータからの復帰', () {
    test('JSONとして壊れていても例外を投げず、退避したうえで空を返す', () async {
      SharedPreferences.setMockInitialValues({_storageKey: 'これはJSONではない'});
      final repository = CardRepository(_FakeScheduler());

      final cards = await repository.loadCards();

      expect(cards, isEmpty);
      expect(repository.dataWasDropped, isTrue);

      final prefs = await SharedPreferences.getInstance();
      // 壊れた本体は消し、中身は調査用に退避しておく。
      expect(prefs.getString(_storageKey), isNull);
      expect(prefs.getString(_corruptedKey), 'これはJSONではない');
    });

    test('1件だけ壊れていても、残りのカードは読み込める', () async {
      SharedPreferences.setMockInitialValues({
        _storageKey: jsonEncode([
          {'name': 'idが無い壊れたカード'},
          {'id': 'ok', 'name': '正常なカード', 'last4': '1111', 'closingDay': 10},
        ]),
      });
      final repository = CardRepository(_FakeScheduler());

      final cards = await repository.loadCards();

      expect(cards.map((c) => c.id), ['ok']);
      expect(repository.dataWasDropped, isTrue);
      repository.acknowledgeDroppedData();
      expect(repository.dataWasDropped, isFalse);
    });

    test('型が違う値は既定値に倒して読み進める', () async {
      SharedPreferences.setMockInitialValues({
        _storageKey: jsonEncode([
          {
            'id': 'a',
            'name': '変な値のカード',
            'last4': 1234, // String ではなく数値
            'closingDay': '99', // 文字列かつ範囲外
            'isUsedThisCycle': 'yes', // bool ではない
            'cycleClosingDate': 'not-a-date',
          },
        ]),
      });

      final card = (await CardRepository(_FakeScheduler()).loadCards()).single;

      expect(card.last4, '');
      expect(card.closingDay, 31); // 1〜31 に丸める
      expect(card.isUsedThisCycle, isFalse);
      expect(card.cycleClosingDate, isNull);
    });
  });

  group('旧データの移行', () {
    test('通知IDブロックが無いカードは採番し、旧方式の予約を取り消す', () async {
      SharedPreferences.setMockInitialValues({
        _storageKey: jsonEncode([
          {
            'id': 'legacy',
            'name': '旧カード',
            'last4': '9999',
            'closingDay': 10,
          },
        ]),
      });
      final scheduler = _FakeScheduler();
      final repository = CardRepository(scheduler);

      final cards = await repository.syncAllCycles();

      expect(cards.single.notificationBlock, isNotNull);
      // 取り残すと新IDの予約と二重に通知されてしまう。
      expect(scheduler.legacyCancelled, ['legacy']);
      expect(scheduler.synced, ['legacy']);
      // 採番結果は保存されている（実行ごとに変わらない）。
      expect((await repository.loadCards()).single.notificationBlock,
          cards.single.notificationBlock);
    });

    test('サイクル同期は同じ日に何度呼んでも予約を作り直さない', () async {
      await repository.upsertCard(_newCard('a'));
      scheduler.synced.clear();

      await repository.syncAllCycles();
      await repository.syncAllCycles();

      // 1日1回で十分（毎回の復帰で通知APIを叩かない）。
      expect(scheduler.synced, ['a']);
    });
  });
}
