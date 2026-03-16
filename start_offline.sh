#!/usr/bin/env bash
set -euo pipefail

# 如果服务器没网，使用TUN mode+SSH反向代理
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/config.conf"

LOG_DIR="${SCRIPT_DIR}/logs"
MIHOMO_PROCESS_PATTERN="mihomo -d ${MIHOMO_CONFIG_DIR}"
MIHOMO_UI_DIR="${MIHOMO_CONFIG_DIR}/ui"
LOG_DIR="${SCRIPT_DIR}/logs"
MIHOMO_LOG="${LOG_DIR}/mihomo.log"
OFFLINE_CONFIG_PATH="${SCRIPT_DIR}/config_offline.yaml"

log() {
  printf '[%s] [mihomo-start] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

# 先拿到 sudo 凭证，避免中途启动时卡住。
sudo -v
mkdir -p "$LOG_DIR"


# 如果 mihomo 已经在跑，就不重复启动。
if pgrep -f -- "$MIHOMO_PROCESS_PATTERN" > /dev/null; then
  log "mihomo is already running, skipped"
else
  log "mihomo is not running, starting mihomo..."

  sudo nohup "$MIHOMO_BIN" \
    -d "$MIHOMO_CONFIG_DIR" \
    -ext-ctl "$MIHOMO_EXT_CTL" \
    -ext-ui "$MIHOMO_UI_DIR" \
    -f "$OFFLINE_CONFIG_PATH" \
    >> "$MIHOMO_LOG" 2>&1 &
  sleep 2

  if pgrep -f -- "$MIHOMO_PROCESS_PATTERN" > /dev/null; then
    log "mihomo is successfully running."
  else
    log "failed to start mihomo."
    exit 1
  fi
fi