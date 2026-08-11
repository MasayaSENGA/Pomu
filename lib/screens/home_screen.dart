import 'package:flutter/material.dart';

import '../models/card_item.dart';
import '../services/card_repository.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/closing_date_utils.dart';
import '../widgets/card_list_tile.dart';
import 'card_edit_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<CardItem> _cards = [];
  bool _loading = true;
  Object? _error;

  /// 通知権限の状態。null は「判定できない（権限の概念が無い環境）」。
  bool? _notificationsAllowed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // アプリがバックグラウンドから戻ってきたタイミングでも
    // 月またぎをチェックして表示を最新化する。
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _bootstrap() async {
    await _requestPermissions();
    await _refresh();
  }

  Future<void> _requestPermissions() async {
    bool? granted;
    try {
      granted = await NotificationService.instance.requestPermissions();
    } catch (_) {
      // 判定できない場合は警告を出さない（誤った警告のほうが害が大きい）。
      granted = null;
    }
    if (!mounted) return;
    setState(() => _notificationsAllowed = granted);
  }

  Future<void> _refresh() async {
    try {
      final cards = await CardRepository.instance.syncAllCycles();
      // 未対応かつ締め日が近いものを上に。済みは下にまとめる。
      cards.sort((a, b) {
        if (a.isUsedThisCycle != b.isUsedThisCycle) {
          return a.isUsedThisCycle ? 1 : -1;
        }
        return _remainingDays(a).compareTo(_remainingDays(b));
      });
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _loading = false;
        _error = null;
      });
      _notifyIfDataWasDropped();
    } catch (error) {
      // 失敗してもローディングのまま固まらせない。
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  void _notifyIfDataWasDropped() {
    final repository = CardRepository.instance;
    if (!repository.dataWasDropped) return;
    repository.acknowledgeDroppedData();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('読み込めない保存データがあったため、一部のカードを復元できませんでした。'),
      ),
    );
  }

  int _remainingDays(CardItem card) {
    final closing = card.cycleClosingDate;
    if (closing == null) return card.closingDay;
    return ClosingDateUtils.daysUntil(DateTime.now(), closing);
  }

  Future<void> _openEditor({CardItem? existing}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CardEditScreen(existing: existing)),
    );
    if (result == true) {
      await _refresh();
    }
  }

  Future<void> _toggleUsed(CardItem card, bool value) async {
    await CardRepository.instance.toggleUsed(card.id, value);
    await _refresh();
  }

  Future<bool> _confirmDelete(CardItem card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
        icon: const Icon(Icons.delete_outline, size: 28),
        title: const Text('カードを削除しますか？'),
        content: Text('「${card.name}」を削除します。この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    await CardRepository.instance.deleteCard(card.id);
    await _refresh();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final doneCount = _cards.where((c) => c.isUsedThisCycle).length;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _AppBar(scheme: scheme),
            if (_notificationsAllowed == false)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: _PermissionBanner(onRetry: _requestPermissions),
                ),
              ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ErrorState(onRetry: _refresh),
              )
            else if (_cards.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(onAdd: () => _openEditor()),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: _SummaryCard(
                    total: _cards.length,
                    done: doneCount,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                sliver: SliverList.separated(
                  itemCount: _cards.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final card = _cards[index];
                    return _StaggeredIn(
                      index: index,
                      key: ValueKey('anim_${card.id}'),
                      child: Dismissible(
                        key: ValueKey(card.id),
                        direction: DismissDirection.endToStart,
                        background: const _DeleteBackground(),
                        // 削除処理とリスト更新は自前で行うため、
                        // Dismissible 側には常に false を返す。
                        confirmDismiss: (_) async {
                          await _confirmDelete(card);
                          return false;
                        },
                        child: CardListTile(
                          card: card,
                          onToggle: (v) => _toggleUsed(card, v),
                          onEdit: () => _openEditor(existing: card),
                          onDelete: () => _confirmDelete(card),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('カードを追加'),
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  const _AppBar({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 132,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                gradient: CardPalette.byIndex(0).gradient,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Pomu',
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                scheme.primaryContainer.withValues(alpha: 0.55),
                scheme.surface.withValues(alpha: 0),
              ],
            ),
          ),
          child: SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 14, 20, 0),
                child: Text(
                  '毎月の \$付けを忘れずに',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 今サイクルの進捗サマリー。
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.total, required this.done});

  final int total;
  final int done;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final remaining = total - done;
    final progress = total == 0 ? 0.0 : done / total;
    final allDone = remaining == 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            height: 54,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: value,
                      strokeWidth: 6,
                      strokeCap: StrokeCap.round,
                      backgroundColor:
                          scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                      color: allDone ? const Color(0xFF10B981) : scheme.primary,
                    ),
                  ),
                  Text(
                    '$done/$total',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allDone ? '今サイクルは全部完了！' : '未対応が $remaining 枚',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  allDone
                      ? '締め日を過ぎたら自動でリセットされます'
                      : 'カードをタップすると \$付け済みにできます',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            allDone ? Icons.celebration_rounded : Icons.pending_actions_rounded,
            color: allDone ? const Color(0xFF10B981) : scheme.primary,
          ),
        ],
      ),
    );
  }
}

/// スワイプ削除時の背景。
class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 28),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Icon(
        Icons.delete_outline_rounded,
        color: Theme.of(context).colorScheme.onErrorContainer,
      ),
    );
  }
}

/// リスト表示時に、少しずつ遅れてフェードインさせる。
class _StaggeredIn extends StatelessWidget {
  const _StaggeredIn({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + (index.clamp(0, 8) * 70)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 18),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// 通知が許可されていないことを知らせるバナー。
/// 許可されないままだとアプリの目的（$付け忘れの通知）が果たせないため、
/// 一覧の先頭に出し続ける。
class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notifications_off_outlined,
              size: 20, color: scheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '通知が許可されていません',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'このままだと \$付け忘れのお知らせが届きません。'
                  '端末の「設定 > 通知 > Pomu」から許可してください。',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onErrorContainer.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => onRetry(),
            style: TextButton.styleFrom(foregroundColor: scheme.onErrorContainer),
            child: const Text('再確認'),
          ),
        ],
      ),
    );
  }
}

/// 読み込みに失敗したときの表示。ここが無いとローディングのまま固まってしまう。
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 44, color: scheme.outline),
            const SizedBox(height: 16),
            Text(
              'カードを読み込めませんでした',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '時間をおいてもう一度お試しください。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => onRetry(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('再読み込み'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 重ねたダミー券面
            SizedBox(
              height: 140,
              width: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _GhostCard(paletteIndex: 2, angle: -0.12, dy: 6),
                  _GhostCard(paletteIndex: 1, angle: 0.08, dy: -4),
                  _GhostCard(paletteIndex: 0, angle: 0, dy: -14),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'まだカードがありません',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'カードを登録すると、締め日の翌日に\n\$付け忘れをお知らせします。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('最初のカードを追加'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GhostCard extends StatelessWidget {
  const _GhostCard({
    required this.paletteIndex,
    required this.angle,
    required this.dy,
  });

  final int paletteIndex;
  final double angle;
  final double dy;

  @override
  Widget build(BuildContext context) {
    final palette = CardPalette.byIndex(paletteIndex);
    return Transform.translate(
      offset: Offset(0, dy),
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: 180,
          height: 108,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: palette.gradient,
            boxShadow: [
              BoxShadow(
                color: palette.start.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
