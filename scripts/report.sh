#!/usr/bin/env bash
# 배포·QA 기록 요약: 횟수, 걸린 시간(중앙값·평균·최소·최대), 단계별 평균. 회고·이력서 수치의 근거.
#   report.sh            지금 레포 설정의 배포 기록 + QA 기록
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/config.sh"
export DEVFLOW_CONFIG="$(devflow_config)"
DLOG=$(expand "$(cfg .deploy.log "$HOME/.config/devflow/deploys.log")")
QLOG=$(expand "$(cfg .qa.log "$HOME/.config/qaflow/qa.log")")
python3 - "$DLOG" "$QLOG" <<'PY'
import json, sys, statistics as st, os
def load(p):
    if not os.path.exists(p): return []
    return [json.loads(l) for l in open(p) if l.strip()]
def stats(xs):
    if not xs: return "기록 없음"
    return f"{len(xs)}회 · 중앙값 {st.median(xs):.0f}초 · 평균 {st.mean(xs):.0f}초 · 최소 {min(xs)}초 · 최대 {max(xs)}초"
d = [r for r in load(sys.argv[1]) if r.get("kind") == "deploy" and str(r.get("totalSeconds", "")).isdigit()]
print("배포 전체:", stats([int(r["totalSeconds"]) for r in d]))
print("재시작→UP:", stats([int(r["upSeconds"]) for r in d if str(r.get("upSeconds", "")).isdigit()]))
steps = {}
for r in d:
    for kv in (r.get("steps") or "").split():
        k, v = kv.split("="); steps.setdefault(k, []).append(int(v))
if steps: print("단계별 평균:", " · ".join(f"{k} {st.mean(v):.0f}초" for k, v in steps.items()))
fails = [r for r in d if "FAIL" in (r.get("checks") or "")]
print("확인 실패한 배포:", len(fails))
q = load(sys.argv[2])
print("QA 한 번:", stats([r["seconds"] for r in q]), "· 탭 합계", sum(r["taps"] for r in q))
PY
