#!/bin/bash
set -u

cd "$(dirname "$0")" || exit 1
app=".build/Build/Products/Debug-iphonesimulator/myapp.app"
console_pid=""

build_app() {
  xcodebuild -quiet -project myapp.xcodeproj -scheme myapp \
    -configuration Debug -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath .build build
}

stop_console() {
  if [[ -n "$console_pid" ]]; then
    kill "$console_pid" 2>/dev/null || true
    wait "$console_pid" 2>/dev/null || true
    console_pid=""
  fi
}

run_app() {
  build_app || return 1
  local bundle_id
  bundle_id=$(plutil -extract CFBundleIdentifier raw "$app/Info.plist") || return 1
  stop_console
  xcrun simctl install booted "$app" || return 1

  if [[ ! -t 0 ]]; then
    exec xcrun simctl launch --console-pty --terminate-running-process booted "$bundle_id"
  fi

  xcrun simctl launch --console-pty --terminate-running-process booted "$bundle_id" </dev/null &
  console_pid=$!
}

trap stop_console EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

run_app || printf '\nNo se pudo iniciar la app.\n' >&2
[[ -t 0 ]] || exit 1

printf '\nr: recompilar y reiniciar · q: salir\n'
while IFS= read -rsn 1 tecla; do
  case "$tecla" in
    r)
      printf '\nRecompilando…\n'
      run_app || printf '\nError. Pulsa r para volver a intentar.\n' >&2
      ;;
    q) break ;;
  esac
done
