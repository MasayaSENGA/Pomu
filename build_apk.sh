#!/usr/bin/env bash
# APK をビルドするスクリプト。
#   ./build_apk.sh          → デバッグAPK（そのまま端末にインストール可）
#   ./build_apk.sh release  → リリースAPK（現状は debug 鍵で署名）
set -euo pipefail

cd "$(dirname "$0")"
MODE="${1:-debug}"

# ---- Android SDK の場所を自動検出して local.properties に反映 ----
find_sdk() {
  local candidates=(
    "${ANDROID_SDK_ROOT:-}"
    "${ANDROID_HOME:-}"
    "$HOME/Library/Android/sdk"
    "$HOME/Android/Sdk"
    "/usr/local/share/android-sdk"
    "/opt/homebrew/share/android-commandlinetools"
  )
  for c in "${candidates[@]}"; do
    if [ -n "$c" ] && [ -d "$c/platforms" ]; then
      echo "$c"
      return 0
    fi
  done
  return 1
}

echo "▶ Android SDK を確認しています..."
if SDK_DIR="$(find_sdk)"; then
  echo "  使用する SDK: $SDK_DIR"
  # local.properties の sdk.dir を検出結果で上書き
  if [ -f android/local.properties ]; then
    grep -v '^sdk\.dir=' android/local.properties > android/local.properties.tmp || true
    mv android/local.properties.tmp android/local.properties
  fi
  printf 'sdk.dir=%s\n' "$SDK_DIR" | cat - android/local.properties > android/local.properties.tmp
  mv android/local.properties.tmp android/local.properties
else
  cat <<'MSG'

⚠ Android SDK（platforms/ を含むディレクトリ）が見つかりませんでした。

  Android Studio をインストールしただけでは SDK 本体は入っていません。
  一度 Android Studio を起動し、初回セットアップウィザードを完了してください。
  （More Actions → SDK Manager から "Android SDK Platform" を1つ以上インストール）

  通常のインストール先: ~/Library/Android/sdk

  完了したら、ライセンスに同意してから再実行してください:
    flutter doctor --android-licenses
    ./build_apk.sh

MSG
  exit 1
fi

# ---- ライセンス確認 ----
if [ ! -d "$SDK_DIR/licenses" ]; then
  cat <<'MSG'

⚠ SDK のライセンスに未同意のようです。先に次を実行してください:
    flutter doctor --android-licenses

MSG
  exit 1
fi

echo "▶ 依存を取得しています..."
flutter pub get

# analyze は info レベルの指摘でも終了コードが 0 にならないため、
# エラー（error/warning）が出た時だけ止める。
echo "▶ 解析しています..."
if ! ANALYZE_OUT="$(flutter analyze 2>&1)"; then
  echo "$ANALYZE_OUT"
  if echo "$ANALYZE_OUT" | grep -qE '^\s*(error|warning) •'; then
    echo
    echo "⚠ error / warning があるためビルドを中止しました。"
    exit 1
  fi
  echo
  echo "（info レベルの指摘のみのため続行します）"
else
  echo "$ANALYZE_OUT"
fi

echo "▶ テストを実行しています..."
flutter test

echo "▶ APK をビルドしています: ${MODE}"
flutter build apk "--${MODE}"

echo
echo "✅ 完了しました。出力先:"
ls -lh build/app/outputs/flutter-apk/*.apk
