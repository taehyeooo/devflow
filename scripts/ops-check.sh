#!/usr/bin/env bash
# 운영 상태 한눈에: 설정한 확인 항목(서버 명령은 ssh로, 그 밖은 이 컴퓨터에서)을 돌려 값과 기준을 표로 보여 준다.
#   ops-check.sh              한 번
#   ops-check.sh --watch 10   10분 동안 1분마다(배포 직후 지켜보기) — 기준을 벗어난 항목이 생기면 바로 표시
# 설정 "ops": { host, sshKey, checks: [{ name, cmd, remote: true|false, ok: "값이 맞으면 참인 정규식" }] }
# 운영 DB는 읽기 쿼리만 둔다.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/config.sh"
export DEVFLOW_CONFIG="$(devflow_config)"
[ -f "$DEVFLOW_CONFIG" ] && jq -e '.ops' "$DEVFLOW_CONFIG" >/dev/null || { echo "운영 확인 설정이 없습니다: $DEVFLOW_CONFIG 의 \"ops\"" >&2; exit 1; }
HOST=$(cfg .ops.host); KEY=$(expand "$(cfg .ops.sshKey)")
once() {
  local bad=0 out=()
  while IFS= read -r c; do
    name=$(jq -r .name <<< "$c"); cmd=$(jq -r .cmd <<< "$c"); ok=$(jq -r '.ok // "."' <<< "$c")
    if [ "$(jq -r '.remote // false' <<< "$c")" = true ]; then v=$(ssh -i "$KEY" -o BatchMode=yes -o ConnectTimeout=10 "$HOST" "$cmd" </dev/null 2>&1 | tail -1)
    else v=$(bash -c "$cmd" </dev/null 2>&1 | tail -1); fi
    v=$(printf '%s' "$v" | tr -d '\r' | cut -c1-80)
    if printf '%s' "$v" | grep -Eq "$ok"; then out+=("  ✓ $name: $v"); else out+=("  ✗ $name: $v  (기준 /$ok/)"); bad=$((bad+1)); fi
  done < <(jq -c '.ops.checks[]' "$DEVFLOW_CONFIG")
  printf '[%s] 운영 확인 — 이상 %s건\n' "$(date +%T)" "$bad"; printf '%s\n' "${out[@]}"
  log ops-check "bad=$bad"; return $bad
}
if [ "${1:-}" = "--watch" ]; then
  mins=${2:-10}; worst=0
  for i in $(seq 1 "$mins"); do once; r=$?; [ $r -gt $worst ] && worst=$r; [ "$i" -lt "$mins" ] && sleep 60; done
  echo "지켜보기 ${mins}분 끝 — 가장 많았던 이상 ${worst}건"; exit $worst
fi
once
