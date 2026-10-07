#!/usr/bin/env bash
# 프로젝트 설정 찾기: 서버 주소·키 경로 같은 값은 공개 레포에 올리지 않게 레포 밖에 둔다.
#   DEVFLOW_CONFIG가 있으면 그 파일, 없으면 ~/.config/devflow/<origin 레포 이름>.json
# worktree에서도 같은 설정을 쓰도록 폴더 이름이 아니라 origin 주소에서 레포 이름을 뽑는다.
devflow_config() {
  if [ -n "${DEVFLOW_CONFIG:-}" ]; then echo "$DEVFLOW_CONFIG"; return; fi
  local url name
  url=$(git remote get-url origin 2>/dev/null || true)
  name=$(basename "${url%.git}")
  [ -z "$name" ] && name=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
  echo "$HOME/.config/devflow/$name.json"
}
# cfg <jq 경로> [기본값]
cfg() {
  local f; f=$(devflow_config)
  [ -f "$f" ] || { [ -n "${2:-}" ] && echo "$2"; return; }
  local v; v=$(jq -r "$1 // empty" "$f")
  if [ -z "$v" ]; then echo "${2:-}"; else echo "$v"; fi
}
expand() { eval echo "$1"; }  # ~ 와 $HOME 펼치기
