#!/bin/sh
REMOTE_ADDRESS="${REMOTE_ADDRESS:-}"
REMOTE_PORT="${REMOTE_PORT:-}"
ID="${ID:-}"
PUBLIC_KEY="${PUBLIC_KEY:-}"
SHORT_ID="${SHORT_ID:-00}"
FLOW="${FLOW:-xtls-rprx-vision}"
FINGER_PRINT="${FINGER_PRINT:-chrome}"
SERVER_NAME="${SERVER_NAME:-t.me}"

/bin/busybox cat > /etc/sing-box/config.json << EOF
{
  "log": {
    "disabled": true,
    "level": "debug"
  },
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "interface_name": "tun0",
      "address": [
        "172.16.255.1/24"
      ],
      "mtu": 1500,
      "auto_route": true,
      "strict_route": true,
      "route_exclude_address": [
        "192.168.0.0/16",
        "172.16.0.0/12"
      ],
      "stack": "system",
      "sniff": false,
      "domain_strategy": "ipv4_only"
    },
    {
      "type": "mixed",
      "tag": "mixed-in",
      "listen": "0.0.0.0",
      "listen_port": 1080,
      "users": [],
      "sniff": false,
      "domain_strategy": "ipv4_only"
    }
  ],
  "outbounds": [
    {
      "type": "vless",
      "tag": "vless-out",
      "server": "${REMOTE_ADDRESS}",
      "server_port": ${REMOTE_PORT},
      "uuid": "${ID}",
      "flow": "${FLOW}",
      "network": "tcp",
      "tls": {
        "enabled": true,
        "server_name": "${SERVER_NAME}",
        "insecure": false,
        "utls": {
          "enabled": true,
          "fingerprint": "${FINGER_PRINT}"
        },
        "reality": {
          "enabled": true,
          "public_key": "${PUBLIC_KEY}",
          "short_id": "${SHORT_ID}"
        }
      }
    }
  ],
  "route": {
    "auto_detect_interface": true
  }
}
EOF

/usr/local/bin/sing-box run -c /etc/sing-box/config.json || exit 1

