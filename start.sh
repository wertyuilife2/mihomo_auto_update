#!/usr/bin/env bash
set -euo pipefail

# 启动 mihomo 主进程和自动更新进程。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/config.conf"

MIHOMO_UI_DIR="${MIHOMO_CONFIG_DIR}/ui"
LOG_DIR="${SCRIPT_DIR}/logs"
MIHOMO_LOG="${LOG_DIR}/mihomo.log"
AUTO_UPDATE_SCRIPT="${SCRIPT_DIR}/tools/auto_update.sh"
AUTO_UPDATE_LOG="${LOG_DIR}/auto_update.log"
MIHOMO_PROCESS_PATTERN="mihomo -d ${MIHOMO_CONFIG_DIR}"
AUTO_UPDATE_PROCESS_PATTERN="bash ${AUTO_UPDATE_SCRIPT}"

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
  log "starting mihomo..."

  # 用命令行参数固定 config dir、controller 和 ui 目录。
  sudo nohup "$MIHOMO_BIN" \
    -d "$MIHOMO_CONFIG_DIR" \
    -ext-ctl "$MIHOMO_EXT_CTL" \
    -ext-ui "$MIHOMO_UI_DIR" \
    > /dev/null 2>> "$MIHOMO_LOG" &
  sleep 1

  if pgrep -f -- "$MIHOMO_PROCESS_PATTERN" > /dev/null; then
    log "mihomo is successfully running."
  else
    log "failed to start mihomo."
    exit 1
  fi
fi

# 自动更新脚本单独运行，和 mihomo 主进程互不依赖。
if pgrep -f -- "$AUTO_UPDATE_PROCESS_PATTERN" > /dev/null; then
  log "auto update script already running, skipped"
else
  log "starting auto update script..."
  nohup bash "$AUTO_UPDATE_SCRIPT" >> "$AUTO_UPDATE_LOG" 2>&1 &
  sleep 1

  if pgrep -f -- "$AUTO_UPDATE_PROCESS_PATTERN" > /dev/null; then
    log "auto update script is successfully running."
  else
    log "failed to start auto update script."
    exit 1
  fi
fi
