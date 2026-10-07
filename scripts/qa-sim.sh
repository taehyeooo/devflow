#!/usr/bin/env bash
# iOS 시뮬레이터 QA를 한 줄씩: 준비/원복, 탭+캡처, 테스트 데이터 개수 기록·비교, 외부 API 사용량 확인.
#   qa-sim.sh start            임시 QA 토큰 패치 + 로컬 서버를 보는 Metro(별도 포트) + 앱 재실행
#   qa-sim.sh stop             패치 원복(남은 패치 0건 확인) + Metro 종료 + 글자 크기 원복
#   qa-sim.sh tap X Y [이름]   좌표를 누르고 2초 뒤 캡처(이름이 있으면 그 이름으로 저장)
#   qa-sim.sh shot 이름        지금 화면 캡처
#   qa-sim.sh text 크기        글자 크기 바꾸기(large, accessibility-extra-extra-extra-large 등)
#   qa-sim.sh snapshot save|check   테스트 계정 데이터 개수를 QA 전에 저장 / QA 후 같은지 비교
#   qa-sim.sh quota            외부 API(예: Gemini) 오늘 사용량
#   qa-sim.sh front            QA 시뮬레이터 창을 맨 앞으로(창이 여러 개일 때)
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/config.sh"
conf=$(devflow_config)
# 처음 찾은 설정을 고정한다 — 앱 폴더로 cd한 뒤에 다시 찾으면 다른 레포의 설정을 보게 된다(첫 실사용에서 발견).
export DEVFLOW_CONFIG="$conf"
[ -f "$conf" ] && jq -e '.qa' "$conf" >/dev/null || { echo "QA 설정이 없습니다: $conf 의 \"qa\"" >&2; exit 1; }
q() { cfg ".qa.$1" "${2:-}"; }
APP=$(expand "$(q appDir)"); UDID=$(q simUdid); APP_ID=$(q appId); PORT=$(q metroPort 8082)
SHOTS=$(expand "$(q screenshotDir "$HOME/.config/devflow/shots")"); mkdir -p "$SHOTS"
STATE="$HOME/.config/devflow/state"; mkdir -p "$STATE"
PATCH_FILE=$(q tokenPatch.file); PATCH_MARK=$(q tokenPatch.marker QA_TOKEN)
log() { echo "$(date '+%F %T')	qa-$1	${2:-}" >> "$HOME/.config/devflow/usage.log"; }

shot() { local f="$SHOTS/$(date +%H%M%S)-${1:-shot}.png"; xcrun simctl io "$UDID" screenshot "$f" >/dev/null 2>&1; echo "$f"; }

case "${1:-}" in
start)
  cd "$APP"
  if [ -n "$PATCH_FILE" ] && ! grep -q "$PATCH_MARK" "$PATCH_FILE"; then
    cp "$PATCH_FILE" "$STATE/patch.orig"
    python3 - "$PATCH_FILE" "$(q tokenPatch.find)" "$(q tokenPatch.replace)" <<'PY'
import sys
p, find, rep = sys.argv[1:4]
s = open(p).read()
assert s.count(find) == 1, "패치할 위치를 찾지 못했습니다"
open(p, "w").write(s.replace(find, rep))
PY
  fi
  lsof -ti tcp:"$PORT" | xargs kill 2>/dev/null || true
  env_args=()
  while IFS=$'\t' read -r k v; do
    [ -z "$k" ] && continue
    case "$v" in @file:*) v=$(cat "$(expand "${v#@file:}")") ;; esac
    env_args+=("$k=$v")
  done < <(jq -r '.qa.env // {} | to_entries[] | [.key, .value] | @tsv' "$conf")
  (env "${env_args[@]}" nohup npx expo start --port "$PORT" > "$STATE/metro.log" 2>&1 &)
  until curl -s "localhost:$PORT/status" 2>/dev/null | grep -q running; do sleep 2; done
  xcrun simctl spawn "$UDID" defaults write "$APP_ID" RCT_jsLocation "localhost:$PORT"
  xcrun simctl terminate "$UDID" "$APP_ID" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$APP_ID" >/dev/null
  open -a Simulator; sleep 20
  date +%s > "$STATE/qa-start"
  log start; echo "QA 준비 완료 (Metro $PORT) — 화면: $(shot start)"
  ;;
stop)
  cd "$APP"
  [ -f "$STATE/patch.orig" ] && cp "$STATE/patch.orig" "$PATCH_FILE" && rm "$STATE/patch.orig"
  xcrun simctl spawn "$UDID" defaults delete "$APP_ID" RCT_jsLocation 2>/dev/null || true
  xcrun simctl ui "$UDID" content_size large
  xcrun simctl terminate "$UDID" "$APP_ID" 2>/dev/null || true
  lsof -ti tcp:"$PORT" | xargs kill 2>/dev/null || true
  left=$( [ -n "$PATCH_FILE" ] && grep -c "$PATCH_MARK" "$PATCH_FILE" || true ); left=${left:-0}
  # QA 한 번에 걸린 시간과 탭 수를 남긴다(start → stop) — 회고에서 "QA에 얼마나 드는지"의 근거
  if [ -f "$STATE/qa-start" ]; then
    began=$(cat "$STATE/qa-start"); secs=$(( $(date +%s) - began ))
    since=$(date -r "$began" '+%F %T')
    taps=$(awk -F'\t' -v s="$since" '$1 >= s && $2 == "qa-tap"' "$HOME/.config/devflow/usage.log" | wc -l | tr -d ' ')
    QALOG=$(expand "$(q log "$HOME/.config/devflow/qa.log")")
    jq -nc --arg at "$(date '+%F %T')" --argjson secs "$secs" --argjson taps "$taps" --arg left "$left" \
      '{at:$at, kind:"qa", seconds:$secs, taps:$taps, patchLeft:$left}' >> "$QALOG"
    rm -f "$STATE/qa-start"; log session "seconds=$secs taps=$taps"
    echo "QA 한 번: ${secs}초, 탭 ${taps}번"
  fi
  log stop "patch-left=$left"; echo "QA 원복 완료 — 남은 패치 ${left}건"
  ;;
tap)
  node "$DIR/tap.mjs" "$APP" "$UDID" "$APP_ID" "$2" "$3"; sleep 2; log tap "$2,$3"; shot "${4:-tap}" ;;
shot) shot "${2:-shot}" ;;
text) xcrun simctl ui "$UDID" content_size "$2"; sleep 3; shot "text-$2" ;;
front)
  osascript -e 'tell application "Simulator" to activate' \
    -e "tell application \"System Events\" to tell process \"Simulator\" to perform action \"AXRaise\" of (first window whose name starts with \"$(q simName)\")" >/dev/null
  echo "앞으로: $(q simName)" ;;
snapshot)
  cmd=$(q snapshotCmd); [ -n "$cmd" ] || { echo "snapshotCmd 설정이 없습니다" >&2; exit 1; }
  now=$(bash -c "$cmd")
  if [ "$2" = save ]; then echo "$now" > "$STATE/snapshot"; log snapshot-save "$now"; echo "저장: $now"
  else before=$(cat "$STATE/snapshot" 2>/dev/null || echo "?")
    if [ "$now" = "$before" ]; then log snapshot-ok "$now"; echo "같음: $now"; else log snapshot-diff "$before -> $now"; echo "다름: QA 전 $before / 지금 $now"; exit 1; fi
  fi ;;
quota)
  cmd=$(q quotaCmd); [ -n "$cmd" ] || { echo "quotaCmd 설정이 없습니다" >&2; exit 1; }
  out=$(bash -c "$cmd"); log quota "$out"; echo "오늘 사용량: $out" ;;
*) sed -n '2,12p' "$0"; exit 1 ;;
esac
