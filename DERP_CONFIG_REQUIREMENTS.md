# Tailscale DERP服务器配置需求详解

## 官方derper配置需求分析

根据Tailscale官方源码分析，`derper`服务器需要以下配置：

### 1. 必需的配置文件

#### 配置文件路径
- **参数**: `-c <config_path>`  
- **默认值**: 
  - root用户: `/var/lib/derper/derper.key`
  - 非root用户: **必须指定**，否则报错退出

#### 配置文件格式 (JSON)
```json
{
    "PrivateKey": "privkey:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
}
```

**说明**:
- `PrivateKey`: Tailscale节点私钥，格式为`privkey:`前缀 + 64位十六进制字符
- 如果配置文件不存在，derper会自动生成新的私钥并写入文件

### 2. 主要命令行参数

#### 网络监听配置
```bash
-a ":443"                    # 服务器监听地址，默认443端口
-http-port 80                # HTTP端口，设为-1禁用
-stun-port 3478              # STUN服务端口
```

#### TLS证书配置
```bash
-certmode "letsencrypt"      # 证书模式: manual 或 letsencrypt
-certdir "/path/to/certs"    # 证书目录路径
-hostname "your.domain.com"  # 域名（用于Let's Encrypt）
```

#### 服务功能开关
```bash
-derp true                   # 是否启用DERP服务
-stun true                   # 是否启用STUN服务
```

### 3. 完整的启动命令示例

#### 使用Let's Encrypt自动证书
```bash
./derper \
    -c /var/lib/derper/derper.key \
    -hostname derp.wedaren.tech \
    -certmode letsencrypt \
    -a :443 \
    -stun-port 3478 \
    -http-port 80
```

#### 使用手动证书
```bash
./derper \
    -c /var/lib/derper/derper.key \
    -hostname derp.wedaren.tech \
    -certmode manual \
    -certdir /opt/derp/certs \
    -a :443 \
    -stun-port 3478 \
    -http-port -1
```

### 4. 配置文件生成过程

当首次运行时，如果配置文件不存在，derper会：

1. 生成新的Tailscale节点私钥
2. 创建配置目录（如果不存在）
3. 将配置写入JSON文件，权限设为0600
4. 继续启动服务

### 5. 实际配置示例

#### 为我们的服务器创建配置
```bash
# 创建配置目录
sudo mkdir -p /var/lib/derper

# 创建配置文件（让derper自动生成）
sudo /opt/derp/derper \
    -c /var/lib/derper/derper.key \
    -hostname derp.wedaren.tech \
    -certmode manual \
    -certdir /opt/derp/certs \
    -a :443 \
    -stun-port 3478 \
    -http-port -1 \
    -dev  # 首次运行用dev模式生成配置文件
```

### 6. systemd服务配置

```ini
[Unit]
Description=Tailscale DERP Server
After=network.target

[Service]
Type=simple
User=root
ExecStart=/opt/derp/derper \
    -c /var/lib/derper/derper.key \
    -hostname derp.wedaren.tech \
    -certmode manual \
    -certdir /opt/derp/certs \
    -a :443 \
    -stun-port 3478 \
    -http-port -1
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### 7. 关键注意事项

1. **配置文件是必需的** - 不能省略 `-c` 参数
2. **私钥格式固定** - 必须是`privkey:`前缀的Tailscale格式
3. **端口权限** - 绑定443端口需要root权限或cap_net_bind_service
4. **证书路径** - manual模式需要确保证书文件存在且可读
5. **STUN端口** - 默认3478，客户端需要能访问此UDP端口

### 8. 配置验证

生成的配置文件示例：
```json
{
    "PrivateKey": "privkey:a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456"
}
```

**文件权限**: 0600 (仅所有者可读写)
**文件位置**: `/var/lib/derper/derper.key`

这就是为什么之前的部署失败了 - 我们没有提供必需的 `-c` 配置文件参数！
