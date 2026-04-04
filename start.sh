#!/usr/bin/env bash
set -euo pipefail

# 启动 mihomo 主进程和自动更新进程。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/config.conf"
# shellcheck disable=SC1091
source "${REPO_ROOT}/tools/logrotate.sh"

AUTO_UPDATE_SCRIPT="${REPO_ROOT}/tools/auto_update.sh"
AUTO_UPDATE_PROCESS_PATTERN="bash ${AUTO_UPDATE_SCRIPT}"

log() {
  printf '[%s] [mihomo-start] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

# 先拿到 sudo 凭证，避免中途启动时卡住。
sudo -v
mkdir -p "$LOG_DIR"
register_logrotate "$MIHOMO_LOG" "$AUTO_UPDATE_LOG"
log "logrotate registered at ${LOGROTATE_CONF_PATH}"

# 自动更新脚本单独运行，和 mihomo 主进程互不依赖。
if pgrep -f -- "$AUTO_UPDATE_PROCESS_PATTERN" > /dev/null; then
  log "auto update script already running, skipped"
else
  log "starting auto update script..."
  setsid bash "$AUTO_UPDATE_SCRIPT" >> "$AUTO_UPDATE_LOG" 2>&1 &
  sleep 2

  if pgrep -f -- "$AUTO_UPDATE_PROCESS_PATTERN" > /dev/null; then
    log "auto update script is successfully running."
  else
    log "failed to start auto update script."
    exit 1
  fi
fi
