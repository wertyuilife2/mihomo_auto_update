#!/usr/bin/env bash
set -euo pipefail

# 停止 mihomo 主进程和自动更新进程。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/config.conf"

AUTO_UPDATE_SCRIPT="${SCRIPT_DIR}/tools/auto_update.sh"
MIHOMO_PROCESS_PATTERN="mihomo -d ${MIHOMO_CONFIG_DIR}"
AUTO_UPDATE_PROCESS_PATTERN="bash ${AUTO_UPDATE_SCRIPT}"

log() {
  printf '[%s] [mihomo-stop] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

# 先拿到 sudo 凭证，避免中途停止时卡住。
sudo -v

# 如果 mihomo 在运行，就停止它。
if pgrep -f -- "$MIHOMO_PROCESS_PATTERN" > /dev/null; then
  log "stopping mihomo..."
  sudo pkill -f -- "$MIHOMO_PROCESS_PATTERN"
  sleep 2

  if pgrep -f -- "$MIHOMO_PROCESS_PATTERN" > /dev/null; then
    log "failed to stop mihomo."
    exit 1
  fi

  log "mihomo stopped."
else
  log "mihomo is not running."
fi

# 如果自动更新脚本在运行，就停止它。
if pgrep -f -- "$AUTO_UPDATE_PROCESS_PATTERN" > /dev/null; then
  log "stopping auto update script..."
  pkill -f -- "$AUTO_UPDATE_PROCESS_PATTERN"
  sleep 2

  if pgrep -f -- "$AUTO_UPDATE_PROCESS_PATTERN" > /dev/null; then
    log "failed to stop auto update script."
    exit 1
  fi

  log "auto update script stopped."
else
  log "auto update script is not running."
fi
