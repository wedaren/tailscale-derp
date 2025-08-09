# Tailscale Custom DERP Server 部署指南

本项目提供了在Ubuntu服务器上部署Tailscale自定义DERP服务器的完整解决方案。

## 🚀 功能特性

- ✅ **一键部署**: 使用官方derper程序，稳定可靠
- ✅ **自动SSL**: 集成Let's Encrypt证书管理
- ✅ **nginx代理**: 支持80/443端口共享，可运行多个网站
- ✅ **系统服务**: systemd管理，开机自启
- ✅ **安全配置**: 最佳实践的安全设置

## 📋 系统要求

- Ubuntu 18.04+ 或 Debian 10+
- 公网IP和域名
- root权限
- 开放端口：80, 443, 3478 (UDP)

## ⚡ 快速开始

### 1. 部署DERP服务器
```bash
sudo ./deploy-official-derp-fixed.sh
```

### 2. 配置nginx反向代理（可选）
如需在同一服务器运行其他网站：
```bash
sudo ./setup-nginx-proxy.sh
```

### 3. 添加更多域名
nginx域名管理工具已独立为单独项目：
```bash
cd /home/admin/nginx-domain-manager
sudo ./add-subdomain.sh
```

## 🗂️ 项目结构

- `deploy-official-derp-fixed.sh` - DERP服务器部署脚本
- `setup-nginx-proxy.sh` - nginx反向代理配置
- `README.md` - 本文档
- `NGINX_PROXY_SUCCESS.md` - nginx代理配置记录
- `DERP_CONFIG_REQUIREMENTS.md` - 配置要求详情

## � 配置Tailscale客户端

部署完成后，在Tailscale客户端配置：

```bash
# 设置自定义DERP服务器
tailscale set --advertise-connector-on-conflict=false
tailscale configure derp add https://your-domain.com
```

或在管理面板的ACL中添加：
```json
{
  "derpMap": {
    "regions": {
      "900": {
        "regionID": 900,
        "regionCode": "custom",
        "nodes": [
          {
            "name": "custom",
            "regionID": 900,
            "hostname": "your-domain.com",
            "stunOnly": false,
            "derpport": 443
          }
        ]
      }
    }
  }
}
```

## �️ 维护命令

```bash
# 查看服务状态
sudo systemctl status derper

# 查看日志
sudo journalctl -u derper -f

# 重启服务
sudo systemctl restart derper

# 测试DERP连接
curl https://your-domain.com/derp/probe
```

## 🌐 相关项目

- **nginx域名管理工具**: `/home/admin/nginx-domain-manager`
  - 快速添加新域名到nginx
  - 支持静态网站、反向代理、PHP应用
  - 自动SSL证书管理
