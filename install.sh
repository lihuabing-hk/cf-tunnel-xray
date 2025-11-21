#!/bin/bash

UUID="12396266-3a1f-43f7-8efb-e2478d4950e7"

echo "=== 安装 Xray ==="
bash <(curl -Ls https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)

mkdir -p /usr/local/etc/xray

cat >/usr/local/etc/xray/vless-ws.json <<EOF
{
  "inbounds": [
    {
      "tag": "vless-ws",
      "port": 3000,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "flow": ""
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/ws"
        }
      }
    }
  ]
}
EOF

cat >/usr/local/etc/xray/vmess-ws.json <<EOF
{
  "inbounds": [
    {
      "tag": "vmess-ws",
      "port": 3001,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$UUID"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vmess"
        }
      }
    }
  ]
}
EOF

cat >/usr/local/etc/xray/vless-h2.json <<EOF
{
  "inbounds": [
    {
      "tag": "vless-h2",
      "port": 3002,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "h2",
        "httpSettings": {
          "path": "/h2"
        }
      }
    }
  ]
}
EOF

echo "=== 安装 cloudflared ==="
wget -O /usr/local/bin/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x /usr/local/bin/cloudflared

mkdir -p /etc/cloudflared

echo "=== 登录 Cloudflare Tunnel ==="
cloudflared tunnel login

echo "=== 创建 tunnel ==="
cloudflared tunnel create xray-tunnel

cat >/etc/cloudflared/config.yml <<EOF
tunnel: xray-tunnel
credentials-file: /root/.cloudflared/xray-tunnel.json

ingress:
  - hostname: ws.hb0724.netlib.re
    service: http://localhost:3000

  - hostname: vmess.hb0724.netlib.re
    service: http://localhost:3001

  - hostname: h2.hb0724.netlib.re
    service: http://localhost:3002

  - service: http_status:404
EOF

cloudflared service install

systemctl enable cloudflared
systemctl start cloudflared

echo "=== 安装完成 ==="
