# 🎉 官方Tailscale DERP服务器部署成功！

## 部署信息
- **部署时间**: 2025年8月10日 11:16
- **服务状态**: ✅ 运行中 (Active)
- **安装方式**: `go install tailscale.com/cmd/derper@latest`
- **配置方式**: 官方推荐配置

## 服务详情

### 网络配置
- **域名**: derp.wedaren.tech
- **HTTPS端口**: 443 ✅
- **STUN端口**: 3478 (UDP) ✅
- **HTTP端口**: 已禁用 (-1)

### 文件路径
```
/opt/derp/derper                    # DERP服务器二进制文件
/var/lib/derper/derper.key         # 配置文件（含私钥）
/opt/derp/certs/                   # SSL证书目录
├── derp.wedaren.tech.crt          # 证书文件
├── derp.wedaren.tech.key          # 私钥文件
├── fullchain.pem                  # Let's Encrypt证书链
└── privkey.pem                    # Let's Encrypt私钥
```

### 服务配置
```ini
[Service]
ExecStart=/opt/derp/derper \
    -c /var/lib/derper/derper.key \
    -hostname derp.wedaren.tech \
    -certmode manual \
    -certdir /opt/derp/certs \
    -a :443 \
    -stun-port 3478 \
    -http-port -1
```

## 功能测试结果

### ✅ HTTPS服务
```bash
curl https://derp.wedaren.tech/
# 返回: DERP服务器主页
```

### ✅ DERP探针
```bash
curl https://derp.wedaren.tech/derp/probe
# 返回: HTTP/1.1 200 OK
```

### ✅ STUN服务
- 端口3478已绑定并监听
- 支持IPv4和IPv6

## Tailscale客户端配置

在Tailscale管理控制台中添加自定义DERP服务器：

```json
{
  "derpMap": {
    "regions": {
      "900": {
        "regionID": 900,
        "regionCode": "custom-cn",
        "regionName": "Custom China DERP",
        "nodes": [
          {
            "name": "derp.wedaren.tech",
            "regionID": 900,
            "hostName": "derp.wedaren.tech",
            "ipv4": "47.86.97.218",
            "derpPort": 443,
            "stunPort": 3478,
            "stunOnly": false,
            "canPort80": false
          }
        ]
      }
    }
  }
}
```

## 系统服务管理

```bash
# 查看服务状态
sudo systemctl status derper

# 查看日志
sudo journalctl -u derper -f

# 重启服务
sudo systemctl restart derper

# 停止服务
sudo systemctl stop derper
```

## 证书更新

证书位于 `/opt/derp/certs/`，当Let's Encrypt证书更新时，需要同步更新DERP证书文件：

```bash
sudo cp /opt/derp/certs/fullchain.pem /opt/derp/certs/derp.wedaren.tech.crt
sudo cp /opt/derp/certs/privkey.pem /opt/derp/certs/derp.wedaren.tech.key
sudo systemctl restart derper
```

## 关键差异解决

### 与简化版本的区别
- ✅ **完整DERP协议支持** - 不只是HTTP响应
- ✅ **WebSocket升级处理** - 支持DERP客户端连接
- ✅ **STUN服务集成** - NAT穿透支持
- ✅ **官方协议实现** - 100%兼容Tailscale客户端

### 证书文件名问题
- 官方derper需要 `<hostname>.crt` 和 `<hostname>.key`
- 不是标准的 `fullchain.pem` 和 `privkey.pem`
- 已通过复制文件解决

## 验证命令

```bash
# 基础连接测试
curl -I https://derp.wedaren.tech/

# DERP探针测试
curl -v https://derp.wedaren.tech/derp/probe

# 服务状态检查
sudo systemctl is-active derper

# 端口监听验证
sudo ss -tlnp | grep :443
sudo ss -ulnp | grep :3478
```

## 🎯 部署成功要点

1. **使用官方安装方法**: `go install tailscale.com/cmd/derper@latest`
2. **提供必需配置文件**: `-c /var/lib/derper/derper.key`
3. **正确的证书文件名**: `<hostname>.crt` 和 `<hostname>.key`
4. **完整的启动参数**: 所有必需的命令行选项
5. **systemd集成**: 自动启动和重启

现在您有一个完全功能的Tailscale DERP服务器，可以为Tailscale客户端提供中继服务！
