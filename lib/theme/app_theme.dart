import 'package:flutter/material.dart';

/// アプリ全体で使う配色・角丸・装飾のデザイントークン。
class AppTheme {
  AppTheme._();

  static const Color seed = Color(0xFF5B5BD6);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xFFF6F5FB)
          : const Color(0xFF121218),
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}

/// 角丸のサイズ。
class AppRadius {
  AppRadius._();

  static const double card = 22;
  static const double tile = 18;
  static const double chip = 999;

  static BorderRadius get cardRadius => BorderRadius.circular(card);
  static BorderRadius get tileRadius => BorderRadius.circular(tile);
}

/// カード券面のグラデーション配色。
class CardPalette {
  const CardPalette(this.name, this.start, this.end);

  final String name;
  final Color start;
  final Color end;

  LinearGradient get gradient => LinearGradient(
        colors: [start, end],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// 券面の上に置くテキストの色（常に白系で読みやすい配色にしてある）。
  Color get onSurface => Colors.white;

  static const List<CardPalette> all = [
    CardPalette('インディゴ', Color(0xFF4F46E5), Color(0xFF7C3AED)),
    CardPalette('サンセット', Color(0xFFF97316), Color(0xFFEC4899)),
    CardPalette('オーシャン', Color(0xFF0EA5E9), Color(0xFF2563EB)),
    CardPalette('フォレスト', Color(0xFF10B981), Color(0xFF047857)),
    CardPalette('ミッドナイト', Color(0xFF334155), Color(0xFF0F172A)),
    CardPalette('ローズ', Color(0xFFE11D48), Color(0xFF9F1239)),
    CardPalette('ゴールド', Color(0xFFF59E0B), Color(0xFFB45309)),
    CardPalette('プラム', Color(0xFF8B5CF6), Color(0xFFD946EF)),
  ];

  static CardPalette byIndex(int index) => all[index % all.length];
}

/// 共通のフォーム入力装飾。ThemeData 側には持たせず、
/// 各フィールドで組み合わせて使う（SDK 差分の影響を受けにくくするため）。
InputDecoration appInputDecoration(
  BuildContext context, {
  required String label,
  String? hint,
  String? helper,
  Widget? prefixIcon,
  String? counterText,
}) {
  final scheme = Theme.of(context).colorScheme;
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
        borderRadius: AppRadius.tileRadius,
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    counterText: counterText,
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: border(Colors.transparent, 0),
    enabledBorder: border(scheme.outlineVariant.withValues(alpha: 0.6), 1),
    focusedBorder: border(scheme.primary, 2),
    errorBorder: border(scheme.error, 1),
    focusedErrorBorder: border(scheme.error, 2),
  );
}
