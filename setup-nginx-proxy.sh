#!/bin/bash

# 配置nginx作为DERP服务器的反向代理
# DERP服务器改用8443端口，nginx处理80和443端口

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== 配置nginx反向代理DERP服务器 ===${NC}"

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}此脚本需要 root 权限运行${NC}"
   exit 1
fi

DOMAIN="derp.wedaren.tech"
DERP_PORT="8443"
CERT_DIR="/opt/derp/certs"

echo -e "${YELLOW}配置说明:${NC}"
echo "- nginx监听: 80 (HTTP) 和 443 (HTTPS)"
echo "- DERP服务器监听: $DERP_PORT (内部端口)"
echo "- DERP专用域名: $DOMAIN"
echo "- nginx转发: $DOMAIN -> localhost:$DERP_PORT"
echo "- 保留默认配置，支持其他域名"
echo ""

# 1. 安装nginx
echo -e "${YELLOW}安装nginx...${NC}"
apt update
apt install -y nginx

# 2. 停止DERP服务器
echo -e "${YELLOW}停止DERP服务器...${NC}"
systemctl stop derper

# 3. 修改DERP服务器配置，改用8443端口
echo -e "${YELLOW}修改DERP服务器端口配置...${NC}"
cat > /etc/systemd/system/derper.service << EOF
[Unit]
Description=Tailscale DERP Server (Official)
After=network.target
Documentation=https://tailscale.com/kb/1232/derp-servers

[Service]
Type=simple
User=root
ExecStart=/opt/derp/derper \\
    -c /var/lib/derper/derper.key \\
    -hostname $DOMAIN \\
    -certmode manual \\
    -certdir $CERT_DIR \\
    -a :$DERP_PORT \\
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
ReadWritePaths=/var/lib/derper $CERT_DIR /var/log

[Install]
WantedBy=multi-user.target
EOF

# 4. 创建nginx配置
echo -e "${YELLOW}创建nginx配置...${NC}"

# 保留默认配置，创建基于域名的虚拟主机
echo "保留默认nginx配置，创建域名专用配置"

# 创建DERP专用配置
cat > /etc/nginx/sites-available/derp << EOF
# DERP服务器nginx反向代理配置

# HTTP到HTTPS重定向
server {
    listen 80;
    server_name $DOMAIN;
    
    # 重定向所有HTTP请求到HTTPS
    return 301 https://\$server_name\$request_uri;
}

# HTTPS反向代理到DERP服务器
server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    # SSL证书配置
    ssl_certificate $CERT_DIR/fullchain.pem;
    ssl_certificate_key $CERT_DIR/privkey.pem;
    
    # SSL安全配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-CHACHA20-POLY1305;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # DERP专用头部设置
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    
    # WebSocket支持（DERP协议需要）
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    
    # 超时设置
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
    
    # 反向代理到DERP服务器
    location / {
        proxy_pass https://127.0.0.1:$DERP_PORT;
        
        # 禁用缓存（对于实时通信重要）
        proxy_buffering off;
        proxy_cache off;
    }
    
    # 健康检查端点
    location /nginx-health {
        access_log off;
        return 200 "nginx proxy ok\\n";
        add_header Content-Type text/plain;
    }
}
EOF

# 启用配置
ln -sf /etc/nginx/sites-available/derp /etc/nginx/sites-enabled/

# 5. 测试nginx配置
echo -e "${YELLOW}测试nginx配置...${NC}"
nginx -t

if [ $? -ne 0 ]; then
    echo -e "${RED}nginx配置测试失败${NC}"
    exit 1
fi

# 6. 启动服务
echo -e "${YELLOW}启动服务...${NC}"

# 重新加载systemd配置
systemctl daemon-reload

# 启动DERP服务器（新端口）
systemctl start derper

# 启动并启用nginx
systemctl enable nginx
systemctl start nginx

# 等待服务启动
sleep 5

# 7. 验证配置
echo -e "${YELLOW}验证服务配置...${NC}"

echo "检查端口监听:"
echo "- DERP服务器端口 $DERP_PORT:"
ss -tlnp | grep ":$DERP_PORT" || echo "  未监听"

echo "- nginx端口 443:"
ss -tlnp | grep ":443" || echo "  未监听"

echo "- nginx端口 80:"
ss -tlnp | grep ":80" || echo "  未监听"

echo ""
echo -e "${YELLOW}测试连接...${NC}"

# 测试nginx代理
if curl -s -m 10 "https://$DOMAIN/" | grep -q -i "derp"; then
    echo -e "${GREEN}✅ nginx -> DERP代理正常${NC}"
else
    echo -e "${RED}❌ nginx代理测试失败${NC}"
fi

# 测试DERP探针
if curl -s -m 10 "https://$DOMAIN/derp/probe" && echo; then
    echo -e "${GREEN}✅ DERP探针通过nginx正常${NC}"
else
    echo -e "${RED}❌ DERP探针测试失败${NC}"
fi

# 测试nginx健康检查
if curl -s -m 5 "https://$DOMAIN/nginx-health"; then
    echo -e "${GREEN}✅ nginx健康检查正常${NC}"
else
    echo -e "${RED}❌ nginx健康检查失败${NC}"
fi

echo ""
echo -e "${GREEN}=== nginx反向代理配置完成！ ===${NC}"
echo -e "${GREEN}配置信息:${NC}"
echo "  - nginx监听: 80 (HTTP重定向), 443 (HTTPS)"
echo "  - DERP服务器: 内部端口 $DERP_PORT"
echo "  - 代理域名: $DOMAIN"
echo "  - STUN端口: 3478 (直接暴露)"
echo ""
echo -e "${YELLOW}服务管理:${NC}"
echo "  - 重启nginx: sudo systemctl restart nginx"
echo "  - 重启DERP: sudo systemctl restart derper"
echo "  - 查看nginx日志: sudo journalctl -u nginx -f"
echo "  - 查看DERP日志: sudo journalctl -u derper -f"
echo ""
echo -e "${YELLOW}现在您可以:${NC}"
echo "  1. DERP服务器专用域名: $DOMAIN"
echo "  2. 添加其他二级域名网站到nginx"
echo "  3. 80和443端口由nginx统一管理"
echo ""
echo -e "${YELLOW}添加其他网站示例:${NC}"
echo "创建新的nginx配置文件："
echo "  sudo nano /etc/nginx/sites-available/example.com"
echo "然后启用："
echo "  sudo ln -s /etc/nginx/sites-available/example.com /etc/nginx/sites-enabled/"
echo "  sudo nginx -t && sudo systemctl reload nginx"
echo ""
echo -e "${YELLOW}示例配置模板:${NC}"
cat << 'TEMPLATE'
# /etc/nginx/sites-available/example.com
server {
    listen 80;
    server_name example.wedaren.tech;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name example.wedaren.tech;
    
    # SSL证书（需要为新域名申请证书）
    ssl_certificate /path/to/example.wedaren.tech/fullchain.pem;
    ssl_certificate_key /path/to/example.wedaren.tech/privkey.pem;
    
    # 网站根目录或反向代理配置
    root /var/www/example;
    index index.html;
}
TEMPLATE
