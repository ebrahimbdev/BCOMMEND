#!/usr/bin/env bash
set -euo pipefail

root="$(realpath "$(dirname "$0")/..")"
tools="${ANDROID_HOME:?ANDROID_HOME is required}/build-tools/36.0.0"
for abi in armeabi-v7a arm64-v8a x86_64; do
  apk="$root/apps/mobile/build/app/outputs/flutter-apk/app-$abi-debug.apk"
  test -f "$apk"
  test "$(apkanalyzer manifest min-sdk "$apk")" = 30
  test "$(apkanalyzer manifest target-sdk "$apk")" = 36
  test "$(apkanalyzer manifest application-id "$apk")" = dev.bcommend.bcommend_mobile.preview
  test "$(apkanalyzer manifest debuggable "$apk")" = true
  "$tools/apksigner" verify "$apk"
  "$tools/zipalign" -c -P 16 4 "$apk"
  sha256sum "$apk"
done
