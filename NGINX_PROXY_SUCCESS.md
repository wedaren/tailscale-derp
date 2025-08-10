# ✅ nginx反向代理配置完成 

## 🎯 当前配置状态

✅ **nginx运行状态**: 正常监听80和443端口  
✅ **DERP服务器**: 内部8443端口，通过nginx代理  
✅ **SSL证书策略**: 只为有有效证书的域名提供HTTPS  
✅ **默认配置**: 只提供HTTP，不使用自签名证书  

## 📋 端口分配

| 服务 | 端口 | 用途 | 访问方式 |
|------|------|------|----------|
| nginx | 80 | HTTP服务 | 公网访问 |
| nginx | 443 | HTTPS服务 | 公网访问（仅有证书的域名） |
| DERP | 8443 | DERP服务 | nginx内部代理 |
| STUN | 3478 | UDP STUN | 直接公网访问 |

## 🌐 域名配置

### DERP专用域名 (derp.wedaren.tech)
- ✅ **HTTP**: 自动重定向到HTTPS
- ✅ **HTTPS**: 通过nginx代理到内部8443端口  
- ✅ **证书**: Let's Encrypt有效证书
- ✅ **功能**: 完整DERP协议支持

### 默认域名/IP访问
- ✅ **HTTP**: 显示nginx状态页面
- ❌ **HTTPS**: 不提供（避免自签名证书）

## 🔧 服务管理

```bash
# nginx服务管理
sudo systemctl status nginx
sudo systemctl restart nginx
sudo nginx -t

# DERP服务管理  
sudo systemctl status derper
sudo systemctl restart derper
sudo journalctl -u derper -f

# 查看端口监听
sudo ss -tlnp | grep ":80\|:443\|:8443"
```

## 🧪 功能测试

```bash
# 测试DERP服务（通过nginx）
curl https://derp.wedaren.tech/
curl https://derp.wedaren.tech/derp/probe

# 测试nginx默认站点
curl http://47.86.97.218/nginx-status

# 测试nginx健康检查
curl https://derp.wedaren.tech/nginx-health
```

## 🌟 添加新的二级域名

使用提供的脚本添加新网站：

```bash
sudo chmod +x add-subdomain.sh
sudo ./add-subdomain.sh
```

支持的网站类型：
1. **静态网站** - HTML/CSS/JS
2. **反向代理** - 转发到其他端口  
3. **PHP网站** - 带PHP-FPM支持

## 🔒 SSL证书管理

### 为新域名申请证书
```bash
# 自动申请并配置nginx
sudo certbot --nginx -d your-new-domain.com

# 手动申请
sudo certbot certonly --webroot -w /var/www/html -d your-domain.com
```

### 证书续期
```bash
# 手动续期
sudo certbot renew

# 自动续期（已配置）
sudo crontab -l | grep certbot
```

## ✨ 配置优势

1. ✅ **安全**: 不使用自签名证书，避免安全警告
2. ✅ **灵活**: 支持多个二级域名，每个可独立配置  
3. ✅ **维护性**: 清晰的配置结构，易于管理
4. ✅ **扩展性**: 可轻松添加新的网站和服务
5. ✅ **专业**: 符合生产环境最佳实践

## 🎉 现在您可以

1. **DERP服务正常运行**: https://derp.wedaren.tech
2. **添加其他网站**: 使用 `add-subdomain.sh` 脚本
3. **为新域名申请证书**: 使用 `certbot --nginx`
4. **访问nginx状态**: http://您的IP/nginx-status

nginx反向代理配置完成，端口80和443现在由nginx统一管理！🚀
