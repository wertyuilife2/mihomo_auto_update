#!/usr/bin/env bash
set -euo pipefail

# 下载新订阅，校验配置，然后通过 mihomo API 热更新。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
# shellcheck disable=SC1091
source "${REPO_ROOT}/config.conf"

MIHOMO_API="http://${MIHOMO_EXT_CTL}"
NEW_CONFIG_PATH="${MIHOMO_CONFIG_DIR}/config.yaml.new"
LIVE_CONFIG_PATH="${MIHOMO_CONFIG_DIR}/config.yaml"
MERGED_CONFIG_PATH="${MIHOMO_CONFIG_DIR}/config.yaml.merged"
OVERRIDE_CONFIG_PATH="${REPO_ROOT}/config_override.yaml"
MERGE_TOOL_PATH="${SCRIPT_DIR}/merge_yaml.py"
MIHOMO_PROCESS_PATTERN="mihomo -d ${MIHOMO_CONFIG_DIR}"
MIHOMO_UI_DIR="${MIHOMO_CONFIG_DIR}/ui"
LOG_DIR="${REPO_ROOT}/logs"
MIHOMO_LOG="${LOG_DIR}/mihomo.log"

log() {
  printf '[%s] [mihomo-update] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

cleanup() {
  rm -f "$MERGED_CONFIG_PATH"
}

validate_and_apply_override_config() {
  if [ ! -f "$OVERRIDE_CONFIG_PATH" ]; then
    return 0
  fi

  log "merging config_override.yaml..."
  python "$MERGE_TOOL_PATH" \
    "$NEW_CONFIG_PATH" \
    "$OVERRIDE_CONFIG_PATH" \
    "$MERGED_CONFIG_PATH"
  mv "$MERGED_CONFIG_PATH" "$NEW_CONFIG_PATH"
}

try_start_mihomo() {
  # 如果 mihomo 已经在跑，就不重复启动。
  if pgrep -f -- "$MIHOMO_PROCESS_PATTERN" > /dev/null; then
    log "mihomo is already running, skipped"
  else
    log "mihomo is not running, starting mihomo..."

    # 用命令行参数固定 config dir、controller 和 ui 目录。
    sudo nohup "$MIHOMO_BIN" \
      -d "$MIHOMO_CONFIG_DIR" \
      -ext-ctl "$MIHOMO_EXT_CTL" \
      -ext-ui "$MIHOMO_UI_DIR" \
      -f "$NEW_CONFIG_PATH" \
      >> "$MIHOMO_LOG" 2>&1 &
    sleep 2

    if pgrep -f -- "$MIHOMO_PROCESS_PATTERN" > /dev/null; then
      log "mihomo is successfully running."
    else
      log "failed to start mihomo."
      exit 1
    fi
  fi
}


trap cleanup EXIT

log "download config..."
# 下载到临时文件，避免失败时污染当前 config.yaml。
curl --proxy "" -fsSL \
  -H "User-Agent: Clash.Meta" \
  "$SUB_URL" \
  -o "$NEW_CONFIG_PATH"

validate_and_apply_override_config

log "test config..."
# 先做语法和配置校验，确认新配置可用。
"$MIHOMO_BIN" -t -d "$MIHOMO_CONFIG_DIR" -f "$NEW_CONFIG_PATH"

log "start mihomo if not running..."
try_start_mihomo

log "reload mihomo..."
# 统一带上 Authorization 头，空 secret 也可以正常工作。
curl --proxy "" -fsS \
  -X PUT \
  -H "Authorization: Bearer ${MIHOMO_SECRET}" \
  -H "Content-Type: application/json" \
  "${MIHOMO_API}/configs?force=true" \
  -d "{\"path\":\"${NEW_CONFIG_PATH}\"}"

log "replace live config..."
# 热更新成功后，再把临时文件覆盖成正式配置。
mv "$NEW_CONFIG_PATH" "$LIVE_CONFIG_PATH"

log "done"
