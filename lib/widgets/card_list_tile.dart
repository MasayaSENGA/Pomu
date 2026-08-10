import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../models/card_item.dart';
import '../theme/app_theme.dart';
import '../utils/closing_date_utils.dart';

/// カード券面を模したリッチなタイル。
/// タップで $付け済み / 未 をトグルし、右上のメニューから編集・削除ができる。
class CardListTile extends StatelessWidget {
  const CardListTile({
    super.key,
    required this.card,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final CardItem card;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = CardPalette.byIndex(card.colorIndex);
    final status = _CardStatus.of(card);
    final done = card.isUsedThisCycle;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardRadius,
        gradient: palette.gradient,
        boxShadow: [
          BoxShadow(
            color: palette.start.withValues(alpha: done ? 0.12 : 0.34),
            blurRadius: done ? 10 : 22,
            offset: Offset(0, done ? 4 : 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppRadius.cardRadius,
        child: Stack(
          children: [
            const Positioned(right: -30, top: -50, child: _Blob(150, 0.10)),
            const Positioned(left: -40, bottom: -70, child: _Blob(170, 0.07)),
            // 済みの券面はうっすら暗くして「片付いた感」を出す
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 280),
                  opacity: done ? 1 : 0,
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.28),
                  ),
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onToggle(!done),
                onLongPress: onEdit,
                splashColor: Colors.white.withValues(alpha: 0.12),
                highlightColor: Colors.white.withValues(alpha: 0.06),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 8, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(context, status, palette),
                      const SizedBox(height: 18),
                      _numberRow(),
                      const SizedBox(height: 16),
                      _footer(context),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, _CardStatus status, CardPalette palette) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CheckBadge(checked: card.isUsedThisCycle, checkColor: palette.end),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                card.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 6),
              _StatusChip(status: status),
            ],
          ),
        ),
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_horiz_rounded,
            color: Colors.white.withValues(alpha: 0.85),
          ),
          tooltip: 'メニュー',
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'edit',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.edit_outlined),
                title: Text('編集'),
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_outline),
                title: Text('削除'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _numberRow() {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Row(
        children: [
          // ICチップ風の装飾
          Container(
            width: 34,
            height: 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: const LinearGradient(
                colors: [Color(0xFFF7E7A6), Color(0xFFCBA94E)],
              ),
            ),
            child: Center(
              child: Container(
                width: 20,
                height: 12,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            '•••• •••• •••• ${card.last4}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.6,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context) {
    final closing = card.cycleClosingDate;
    final closingLabel = closing != null
        ? '${closing.month}/${closing.day}'
        : '毎月${card.closingDay}日';

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '締め日',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 10,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  closingLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (card.usageMethod.isNotEmpty)
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sticky_note_2_outlined,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      card.usageMethod,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 券面のチェックマーク。チェック時に円が塗りつぶされる。
class _CheckBadge extends StatelessWidget {
  const _CheckBadge({required this.checked, required this.checkColor});

  final bool checked;
  final Color checkColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutBack,
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: checked ? Colors.white : Colors.white.withValues(alpha: 0.12),
        border: Border.all(
          color: Colors.white.withValues(alpha: checked ? 1 : 0.55),
          width: 1.6,
        ),
      ),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutBack,
        scale: checked ? 1 : 0,
        child: Icon(Icons.check_rounded, size: 19, color: checkColor),
      ),
    );
  }
}

/// 券面の背景に置く半透明の円。
class _Blob extends StatelessWidget {
  const _Blob(this.size, this.opacity);

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

/// 状態表示（済み / 残り日数 / 超過）。
class _CardStatus {
  const _CardStatus(this.label, this.icon, {this.urgent = false});

  final String label;
  final IconData icon;
  final bool urgent;

  static _CardStatus of(CardItem card) {
    if (card.isUsedThisCycle) {
      return const _CardStatus('今月分は \$付け済み', Icons.verified_rounded);
    }
    final closing = card.cycleClosingDate;
    if (closing == null) {
      return _CardStatus('毎月${card.closingDay}日締め', Icons.event_outlined);
    }
    final days = ClosingDateUtils.daysUntil(DateTime.now(), closing);
    if (days > 0) {
      return _CardStatus(
        '締め日まで あと$days日',
        Icons.schedule_rounded,
        urgent: days <= 3,
      );
    }
    if (days == 0) {
      return const _CardStatus('今日が締め日', Icons.priority_high_rounded,
          urgent: true);
    }
    return const _CardStatus('締め日を過ぎています', Icons.warning_amber_rounded,
        urgent: true);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final _CardStatus status;

  @override
  Widget build(BuildContext context) {
    final bg = status.urgent
        ? const Color(0xFFFFE08A)
        : Colors.white.withValues(alpha: 0.18);
    final fg = status.urgent ? const Color(0xFF6B4B00) : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              color: fg,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
