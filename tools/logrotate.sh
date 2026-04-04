#!/usr/bin/env bash

LOGROTATE_CONF_PATH="/etc/logrotate.d/mihomo_auto_update"
LOGROTATE_MAX_SIZE="300K"
LOGROTATE_ROTATE_COUNT="3"

# 这个脚本负责注册 logrotate 来定期轮转 mihomo 的日志，避免日志占满磁盘。
register_logrotate() {
  local mihomo_log="$1"
  local auto_update_log="$2"

  sudo mkdir -p "$(dirname -- "$LOGROTATE_CONF_PATH")"
  sudo tee "$LOGROTATE_CONF_PATH" > /dev/null <<EOF
"${mihomo_log}" "${auto_update_log}" {
    size ${LOGROTATE_MAX_SIZE}
    rotate ${LOGROTATE_ROTATE_COUNT}
    compress
    missingok
    notifempty
    copytruncate
}
EOF
}

unregister_logrotate() {
  sudo rm -f "$LOGROTATE_CONF_PATH"
}
