#!/bin/bash
clear

echo "===================================================="
echo " Cloudflare Tunnel + Xray VLESS-WS 一键安装脚本"
echo " 支持：任意 Linux（含 WebHostMost 免费主机）"
echo " 作者：lihuabing-hk（自动生成仓库版）"
echo "===================================================="

# 检查 root
if [ $(id -u) != "0" ]; then
  echo "请使用 root 运行：sudo su"
  exit 1
fi

# 输入域名
read -p "请输入子域名（如：vless.example.com）：" DOMAIN

# 自动生成 UUID
UUID=$(cat /proc/sys/kernel/random/uuid)
echo "生成 UUID: $UUID"

# 安装依赖
apt update -y
apt install -y curl wget sudo unzip

# 安装 cloudflared
echo ">>>> 安装 cloudflared..."
wget -O /usr/local/bin/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x /usr/local/bin/cloudflared

# 登录 Cloudflare（需要你扫码）
echo ">>>> 正在登录 Cloudflare，请复制链接到浏览器打开"
cloudflared tunnel login

# 创建 tunnel
echo ">>>> 创建 Tunnel：xray-tunnel"
cloudflared tunnel create xray-tunnel

# 创建 DNS 解析
echo ">>>> 创建 DNS 解析记录..."
cloudflared tunnel route dns xray-tunnel $DOMAIN

# 写入 cloudflared 配置
mkdir -p /etc/cloudflared

cat >/etc/cloudflared/config.yml <<EOF
tunnel: xray-tunnel
credentials-file: /root/.cloudflared/xray-tunnel.json

ingress:
  - hostname: $DOMAIN
    service: http://localhost:3000
  - service: http_status:404
EOF

# 安装 Xray-core
echo ">>>> 安装 Xray..."
bash <(curl -Ls https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)

# 写入 Xray 配置
cat >/usr/local/etc/xray/config.json <<EOF
{
  "inbounds": [
    {
      "protocol": "vless",
      "port": 3000,
      "settings": {
        "clients": [
          {
            "id": "$UUID"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF

# 启动 Xray
systemctl enable xray
systemctl restart xray

# 启动 cloudflared
echo ">>>> 启动 Cloudflare Tunnel..."
cloudflared service install
systemctl enable cloudflared
systemctl restart cloudflared

clear
echo "===================================================="
echo "   Cloudflare Tunnel + Xray 安装完成（超稳定）"
echo "===================================================="
echo ""
echo "VLESS 节点信息："
echo "-------------------------------------"
echo "地址：$DOMAIN"
echo "UUID：$UUID"
echo "传输：ws"
echo "路径：/"
echo "TLS：开启（Cloudflare 自动提供）"
echo "端口：443"
echo "-------------------------------------"
echo ""
echo "你现在可以把节点导入 v2rayN / v2rayNG / Shadowrocket 了！"
