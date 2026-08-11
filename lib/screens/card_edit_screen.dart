import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/card_item.dart';
import '../services/card_repository.dart';
import '../theme/app_theme.dart';

class CardEditScreen extends StatefulWidget {
  const CardEditScreen({super.key, this.existing});

  final CardItem? existing;

  @override
  State<CardEditScreen> createState() => _CardEditScreenState();
}

class _CardEditScreenState extends State<CardEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _last4Controller;
  late final TextEditingController _usageMethodController;
  late int _closingDay;
  late int _colorIndex;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _last4Controller = TextEditingController(text: existing?.last4 ?? '');
    _usageMethodController =
        TextEditingController(text: existing?.usageMethod ?? '');
    _closingDay = existing?.closingDay ?? 15;
    _colorIndex = existing?.colorIndex ?? 0;

    // 入力に合わせてプレビューを更新する
    _nameController.addListener(_onPreviewChanged);
    _last4Controller.addListener(_onPreviewChanged);
  }

  void _onPreviewChanged() => setState(() {});

  @override
  void dispose() {
    _nameController.removeListener(_onPreviewChanged);
    _last4Controller.removeListener(_onPreviewChanged);
    _nameController.dispose();
    _last4Controller.dispose();
    _usageMethodController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final id =
        widget.existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    final card = CardItem(
      id: id,
      name: _nameController.text.trim(),
      last4: _last4Controller.text.trim(),
      closingDay: _closingDay,
      usageMethod: _usageMethodController.text.trim(),
      colorIndex: _colorIndex,
      isUsedThisCycle: widget.existing?.isUsedThisCycle ?? false,
      cycleClosingDate: widget.existing?.cycleClosingDate,
    );

    await CardRepository.instance.upsertCard(card);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'カードを編集' : 'カードを追加'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            _CardPreview(
              name: _nameController.text.trim().isEmpty
                  ? 'カード名'
                  : _nameController.text.trim(),
              last4: _last4Controller.text.trim(),
              closingDay: _closingDay,
              palette: CardPalette.byIndex(_colorIndex),
            ),
            const SizedBox(height: 28),
            const _SectionLabel('基本情報'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: appInputDecoration(
                context,
                label: 'カード名',
                hint: '例：楽天カード',
                prefixIcon: const Icon(Icons.credit_card_rounded),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'カード名を入力してください' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _last4Controller,
              keyboardType: TextInputType.number,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: appInputDecoration(
                context,
                label: 'カード番号（下4桁）',
                hint: '1234',
                counterText: '',
                prefixIcon: const Icon(Icons.pin_rounded),
              ),
              validator: (v) {
                final value = v?.trim() ?? '';
                if (!RegExp(r'^\d{4}$').hasMatch(value)) {
                  return '数字4桁で入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: 28),
            const _SectionLabel('締め日'),
            const SizedBox(height: 12),
            _ClosingDayPicker(
              value: _closingDay,
              onChanged: (d) => setState(() => _closingDay = d),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '31日など、その月に存在しない日は月末として扱います',
                    style:
                        TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const _SectionLabel('券面カラー'),
            const SizedBox(height: 12),
            _ColorPicker(
              selected: _colorIndex,
              onChanged: (i) => setState(() => _colorIndex = i),
            ),
            const SizedBox(height: 28),
            const _SectionLabel('メモ'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _usageMethodController,
              maxLines: 3,
              decoration: appInputDecoration(
                context,
                label: '\$付け方法',
                hint: '例：Suicaオートチャージに設定',
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_saving ? '保存中...' : '保存する'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.tileRadius,
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// 入力内容がそのまま反映される券面プレビュー。
class _CardPreview extends StatelessWidget {
  const _CardPreview({
    required this.name,
    required this.last4,
    required this.closingDay,
    required this.palette,
  });

  final String name;
  final String last4;
  final int closingDay;
  final CardPalette palette;

  @override
  Widget build(BuildContext context) {
    final digits = last4.padRight(4, '•');
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      height: 176,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardRadius,
        gradient: palette.gradient,
        boxShadow: [
          BoxShadow(
            color: palette.start.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Container(
            width: 40,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              gradient: const LinearGradient(
                colors: [Color(0xFFF7E7A6), Color(0xFFCBA94E)],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '•••• •••• •••• $digits',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.94),
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.8,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '締め日  毎月$closingDay日',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// 1〜31 を横スクロールで選ぶピッカー。
class _ClosingDayPicker extends StatelessWidget {
  const _ClosingDayPicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 31,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = index + 1;
          final selected = day == value;
          return GestureDetector(
            onTap: () => onChanged(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? scheme.primary
                    : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? scheme.primary
                      : scheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 券面カラーの選択。
class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: CardPalette.all.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final palette = CardPalette.byIndex(index);
          final isSelected = index == selected;
          return GestureDetector(
            onTap: () => onChanged(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              decoration: BoxDecoration(
                gradient: palette.gradient,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette.start.withValues(alpha: 0.35),
                    blurRadius: isSelected ? 14 : 6,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 22)
                  : null,
            ),
          );
        },
      ),
    );
  }
}
