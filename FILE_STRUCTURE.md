# Tailscale Custom DERP Server 项目文件说明

本项目包含了部署和配置 Tailscale 自定义 DERP 服务器的完整解决方案。

## 🗂️ 文件结构

### 📜 部署脚本
- **`deploy-official-derp-fixed.sh`** - 主要的 DERP 服务器部署脚本（推荐使用）
  - 使用官方 `go install` 方法安装 derper
  - 自动配置 SSL 证书和 systemd 服务
  - 已测试并验证可用

- **`setup-nginx-proxy.sh`** - nginx 反向代理配置脚本
  - 配置 nginx 作为 DERP 服务器的反向代理
  - 处理 SSL 终端和端口分配（nginx: 80/443, DERP: 8443）
  - 支持多域名配置

### 📚 文档
- **`README.md`** - 项目主文档，包含部署说明和使用方法

- **`DERP_CONFIG_REQUIREMENTS.md`** - DERP 服务器配置要求和技术细节
  - 端口配置说明
  - SSL 证书要求
  - 网络配置指南

- **`DEPLOYMENT_SUCCESS_FINAL.md`** - 成功部署的最终配置记录
  - 完整的部署步骤
  - 配置文件内容
  - 验证方法

- **`NGINX_PROXY_SUCCESS.md`** - nginx 反向代理成功配置文档
  - nginx 配置详情
  - SSL 证书配置
  - 端口分配策略

## 🚀 快速开始

1. **部署 DERP 服务器**：
   ```bash
   sudo ./deploy-official-derp-fixed.sh
   ```

2. **配置 nginx 反向代理**（如果需要运行其他网站）：
   ```bash
   sudo ./setup-nginx-proxy.sh
   ```

3. **管理其他域名**：
   nginx域名管理工具已独立为单独项目：`/home/admin/nginx-domain-manager`

## 📋 当前配置状态

- **域名**: derp.wedaren.tech
- **服务器**: 阿里云 Ubuntu 24.04 LTS (47.86.97.218)
- **端口分配**: 
  - nginx: 80 (HTTP), 443 (HTTPS)
  - DERP: 8443 (内部端口，通过 nginx 代理)
  - STUN: 3478 (UDP)
- **SSL 证书**: Let's Encrypt 自动续期

## 🛠️ 维护命令

- 检查服务状态: `sudo systemctl status derper nginx`
- 查看日志: `sudo journalctl -u derper -f`
- 重启服务: `sudo systemctl restart derper nginx`
- 更新证书: `sudo certbot renew`

---
*最后更新: 2025年8月10日*
