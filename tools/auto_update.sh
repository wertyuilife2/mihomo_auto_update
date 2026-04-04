#!/usr/bin/env bash
set -euo pipefail

# 定时执行订阅更新脚本。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../config/config.conf"

UPDATE_SCRIPT="${REPO_ROOT}/tools/update_subs.sh"

log() {
  printf '[%s] [mihomo-auto] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

# 执行一次订阅更新；失败时保留当前配置继续运行。
run_update() {
  log "running update script..."

  if bash "$UPDATE_SCRIPT"; then
    log "update success."
  else
    log "update FAILED! keep current config."
    return 1
  fi
}

main() {
  local next_update_ts

  # 启动后先立即更新一次。
  run_update
  next_update_ts=$(( $(date +%s) + UPDATE_INTERVAL ))

  while true; do
    sleep "$CHECK_INTERVAL"

    # 到达更新时间后再执行更新。
    if [ "$(date +%s)" -ge "$next_update_ts" ]; then
      run_update || true
      next_update_ts=$(( $(date +%s) + UPDATE_INTERVAL ))
    fi
  done
}

main
