#!/bin/bash

# 配置singbox的配置文件路径
CONFIG_PATH="/etc/sing-box/config.json"

# 生成UUID和Reality Short ID
UUID=$(uuidgen)                        # 生成随机 UUID
SERVER_PORT=$((RANDOM % 55536 + 10000)) # 自动生成一个大于 10000 且小于 65536 的端口号
SHORT_ID=$(openssl rand -hex 4)         # 生成 Reality 的 Short ID (4字符HEX格式)

# 生成 Reality 公私钥对
KEY_PAIR=$(sing-box generate reality-keypair) # 生成 Reality 公私钥对
PRIVATE_KEY=$(echo "$KEY_PAIR" | grep "PrivateKey" | awk '{print $2}')
PUBLIC_KEY=$(echo "$KEY_PAIR" | grep "PublicKey" | awk '{print $2}')

# 创建 VLESS Reality 配置文件并写入到 singbox 配置路径
cat <<EOF > "$CONFIG_PATH"
{
  "log": {
    "level": "info"
  },
  "inbounds": [
    {
      "type": "vless",
      "sniff": true,
      "sniff_override_destination": true,
      "listen": "::",
      "listen_port": $SERVER_PORT,
      "users": [
        {
          "uuid": "$UUID"，
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
  ],
  "outbounds": [
    {
      "type": "direct"
    }
  ]
}
EOF

# 输出配置信息
echo "配置文件 $CONFIG_PATH 已生成"
echo "UUID: $UUID"
echo "端口: $SERVER_PORT"
echo "Reality Short ID: $SHORT_ID"
echo "Reality 公钥: $PUBLIC_KEY"
