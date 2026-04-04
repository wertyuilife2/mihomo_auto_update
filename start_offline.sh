#!/usr/bin/env bash
set -euo pipefail

# 服务器没网的情况下，要TUN mode连局域网的代理，用这个脚本。

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/config.conf"
# shellcheck disable=SC1091
source "${REPO_ROOT}/tools/logrotate.sh"

MIHOMO_PROCESS_PATTERN="mihomo -d ${MIHOMO_CONFIG_DIR}"
MIHOMO_UI_DIR="${MIHOMO_CONFIG_DIR}/ui"
OFFLINE_CONFIG_PATH="${REPO_ROOT}/config_offline.yaml"

log() {
  printf '[%s] [mihomo-start] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

# 先拿到 sudo 凭证，避免中途启动时卡住。
sudo -v
mkdir -p "$LOG_DIR"
register_logrotate "$MIHOMO_LOG" "$AUTO_UPDATE_LOG"
log "logrotate registered at ${LOGROTATE_CONF_PATH}"

# 如果 mihomo 已经在跑，就不重复启动。
if pgrep -f -- "$MIHOMO_PROCESS_PATTERN" > /dev/null; then
  log "mihomo is already running, skipped"
else
  log "mihomo is not running, starting mihomo..."

  sudo setsid "$MIHOMO_BIN" \
    -d "$MIHOMO_CONFIG_DIR" \
    -ext-ctl "$MIHOMO_EXT_CTL" \
    -ext-ui "$MIHOMO_UI_DIR" \
    -f "$OFFLINE_CONFIG_PATH" \
    >> "$MIHOMO_LOG" 2>&1 < /dev/null &
  sleep 2

  if pgrep -f -- "$MIHOMO_PROCESS_PATTERN" > /dev/null; then
    log "mihomo is successfully running."
  else
    log "failed to start mihomo."
    exit 1
  fi
fi
