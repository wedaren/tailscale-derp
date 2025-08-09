#!/bin/bash

# 使用正确配置部署官方Tailscale DERP服务器
# 解决配置文件需求问题

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== 使用正确配置部署官方DERP服务器 ===${NC}"

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}此脚本需要 root 权限运行${NC}"
   exit 1
fi

DOMAIN="derp.wedaren.tech"
CONFIG_DIR="/var/lib/derper"
CONFIG_FILE="$CONFIG_DIR/derper.key"
DERP_DIR="/opt/derp"
CERT_DIR="/opt/derp/certs"

echo -e "${YELLOW}=== 配置需求分析 ===${NC}"
echo "✓ 配置文件路径: $CONFIG_FILE"
echo "✓ 证书目录: $CERT_DIR"
echo "✓ 域名: $DOMAIN"
echo ""

# 停止当前服务
echo -e "${YELLOW}停止当前服务...${NC}"
systemctl stop derper 2>/dev/null || true

# 创建配置目录
echo -e "${YELLOW}创建配置目录...${NC}"
mkdir -p "$CONFIG_DIR"
mkdir -p "$DERP_DIR"

# 使用官方go install安装derper
if [ ! -f "$DERP_DIR/derper" ]; then
    echo -e "${YELLOW}使用go install安装官方derper...${NC}"
    
    # 设置GOPATH和GOBIN
    export GOPATH=/tmp/go
    export GOBIN="$DERP_DIR"
    mkdir -p "$GOPATH"
    
    # 使用官方推荐的方式安装
    /usr/local/go/bin/go install tailscale.com/cmd/derper@latest
    
    # 确保文件存在并设置权限
    if [ -f "$DERP_DIR/derper" ]; then
        chmod +x "$DERP_DIR/derper"
        echo -e "${GREEN}✓ derper安装完成${NC}"
    else
        echo -e "${RED}❌ derper安装失败${NC}"
        exit 1
    fi
fi

# 检查证书文件
echo -e "${YELLOW}检查证书文件...${NC}"
if [ ! -f "$CERT_DIR/fullchain.pem" ] || [ ! -f "$CERT_DIR/privkey.pem" ]; then
    echo -e "${RED}错误: 证书文件不存在${NC}"
    echo "请确保以下文件存在:"
    echo "  - $CERT_DIR/fullchain.pem"
    echo "  - $CERT_DIR/privkey.pem"
    exit 1
fi
echo -e "${GREEN}✓ 证书文件存在${NC}"

# 首次运行生成配置文件（如果不存在）
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}生成配置文件...${NC}"
    
    # 临时以dev模式运行来生成配置文件
    timeout 5 "$DERP_DIR/derper" \
        -c "$CONFIG_FILE" \
        -dev \
        -hostname "$DOMAIN" 2>/dev/null || true
    
    # 如果dev模式没成功，手动创建配置
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}手动创建配置文件...${NC}"
        # 生成一个随机私钥（模拟Tailscale格式）
        PRIVATE_KEY="privkey:$(openssl rand -hex 32)"
        cat > "$CONFIG_FILE" << EOF
{
    "PrivateKey": "$PRIVATE_KEY"
}
EOF
        chmod 600 "$CONFIG_FILE"
    fi
    
    echo -e "${GREEN}✓ 配置文件已生成${NC}"
    echo "配置文件内容:"
    cat "$CONFIG_FILE" | head -5
else
    echo -e "${GREEN}✓ 配置文件已存在${NC}"
fi

# 创建systemd服务文件
echo -e "${YELLOW}创建systemd服务...${NC}"
cat > /etc/systemd/system/derper.service << EOF
[Unit]
Description=Tailscale DERP Server (Official)
After=network.target
Documentation=https://tailscale.com/kb/1232/derp-servers

[Service]
Type=simple
User=root
ExecStart=$DERP_DIR/derper \\
    -c $CONFIG_FILE \\
    -hostname $DOMAIN \\
    -certmode manual \\
    -certdir $CERT_DIR \\
    -a :443 \\
    -stun-port 3478 \\
    -http-port -1
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

# 安全设置
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=$CONFIG_DIR $CERT_DIR /var/log

[Install]
WantedBy=multi-user.target
EOF

# 重新加载systemd并启动服务
echo -e "${YELLOW}启动DERP服务...${NC}"
systemctl daemon-reload
systemctl enable derper
systemctl start derper

# 等待服务启动
sleep 5

# 检查服务状态
echo -e "${YELLOW}检查服务状态...${NC}"
if systemctl is-active --quiet derper; then
    echo -e "${GREEN}✅ DERP服务启动成功！${NC}"
    
    # 显示服务状态
    systemctl status derper --no-pager -l
    
    echo -e "${YELLOW}测试服务功能...${NC}"
    
    # 测试DERP探针
    if curl -s -m 10 "https://$DOMAIN/derp/probe" | grep -q '"derp"'; then
        echo -e "${GREEN}✅ DERP探针响应正常${NC}"
    else
        echo -e "${YELLOW}⚠️ DERP探针测试失败${NC}"
    fi
    
    # 测试根路径
    if curl -s -m 10 "https://$DOMAIN/" | grep -q -i "derp"; then
        echo -e "${GREEN}✅ 根路径响应正常${NC}"
    else
        echo -e "${YELLOW}⚠️ 根路径测试失败${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}=== 官方DERP服务器部署成功！ ===${NC}"
    echo -e "${GREEN}配置信息:${NC}"
    echo "  - 配置文件: $CONFIG_FILE"
    echo "  - HTTPS端口: 443"
    echo "  - STUN端口: 3478 (UDP)"
    echo "  - 证书模式: manual"
    echo "  - 域名: $DOMAIN"
    echo ""
    echo -e "${YELLOW}Tailscale配置:${NC}"
    echo "在Tailscale管理控制台中添加DERP服务器:"
    echo "  - 地址: $DOMAIN:443"
    echo "  - STUN端口: 3478"
    echo "  - 区域ID: 900 (或其他唯一ID)"
    echo ""
    echo -e "${YELLOW}验证部署:${NC}"
    echo "1. curl https://$DOMAIN/derp/probe"
    echo "2. 检查服务日志: journalctl -u derper -f"
    
else
    echo -e "${RED}❌ 服务启动失败${NC}"
    echo -e "${YELLOW}错误日志:${NC}"
    journalctl -u derper -n 20 --no-pager
    exit 1
fi
