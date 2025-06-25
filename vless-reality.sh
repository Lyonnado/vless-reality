#!/bin/bash

# —— 安装 jq ——  
if ! command -v jq >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update && apt-get install -y jq
  elif command -v yum >/dev/null 2>&1; then
    yum install -y jq
  fi
fi

# 配置 sing-box 的配置文件路径
CONFIG_PATH="/etc/sing-box/config.json"

# 生成 Reality 公私钥对
KEY_PAIR=$(sing-box generate reality-keypair)
PRIVATE_KEY=$(echo "$KEY_PAIR" | awk '/PrivateKey/ {print $2}')
PUBLIC_KEY=$(echo "$KEY_PAIR" | awk '/PublicKey/  {print $2}')

# 随机端口生成函数（10001–65535）
gen_port() {
  echo $((RANDOM % 55535 + 10001))
}

# 生成 UUID、Short ID 与初始端口
UUID=$(uuidgen)
SHORT_ID=$(openssl rand -hex 4)
SERVER_PORT=$(gen_port)

# 如果已有配置且 jq 可用，避免端口冲突
if [ -f "$CONFIG_PATH" ] && command -v jq >/dev/null 2>&1; then
  existing_ports=($(jq -r '.inbounds[].listen_port' "$CONFIG_PATH"))
  if [ ${#existing_ports[@]} -gt 0 ]; then
    while printf '%s\n' "${existing_ports[@]}" | grep -qx "$SERVER_PORT"; do
      SERVER_PORT=$(gen_port)
    done
  fi
fi

# 新节点的 JSON 片段
read -r -d '' INBOUND_JSON <<EOF
{
  "type": "vless",
  "sniff": true,
  "sniff_override_destination": true,
  "listen": "::",
  "listen_port": $SERVER_PORT,
  "users": [
    {
      "uuid": "$UUID",
      "flow": "xtls-rprx-vision"
    }
  ],
  "tls": {
    "enabled": true,
    "server_name": "www.apple.com",
    "reality": {
      "enabled": true,
      "handshake": {
        "server": "www.apple.com",
        "server_port": 443
      },
      "private_key": "$PRIVATE_KEY",
      "short_id": [
        "$SHORT_ID"
      ]
    }
  }
}
EOF

# 创建或追加配置
if [ ! -f "$CONFIG_PATH" ]; then
  mkdir -p "$(dirname "$CONFIG_PATH")"
  cat > "$CONFIG_PATH" <<EOF
{
  "log": {
    "level": "info"
  },
  "inbounds": [
    $INBOUND_JSON
  ],
  "outbounds": [
    {
      "type": "direct"
    }
  ]
}
EOF
else
  TMP_FILE=$(mktemp)
  jq --argjson node "$INBOUND_JSON" '.inbounds += [$node]' "$CONFIG_PATH" > "$TMP_FILE"
  mv "$TMP_FILE" "$CONFIG_PATH"
fi


# 输出配置信息
echo "配置文件 $CONFIG_PATH 已生成"
echo "UUID: $UUID"
echo "端口: $SERVER_PORT"
echo "Reality Short ID: $SHORT_ID"
echo "Reality 公钥: $PUBLIC_KEY"
echo "{"
echo "  \"type\": \"vless\","
echo "  \"tag\": \"$SERVER_NAME\","
echo "  \"server\": \"$SERVER_IP\","
echo "  \"server_port\": $SERVER_PORT,"
echo "  \"uuid\": \"$UUID\","
echo "  \"packet_encoding\": \"xudp\","
echo "  \"flow\": \"xtls-rprx-vision\","
echo "  \"tls\": {"
echo "    \"enabled\": true,"
echo "    \"server_name\": \"www.apple.com\","
echo "    \"utls\": {"
echo "      \"enabled\": true,"
echo "      \"fingerprint\": \"chrome\""
echo "    },"
echo "    \"reality\": {"
echo "      \"enabled\": true,"
echo "      \"public_key\": \"$PUBLIC_KEY\","
echo "      \"short_id\": \"$SHORT_ID\""
echo "    }"
echo "  }"
echo "},"
