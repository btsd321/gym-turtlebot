# Docker Linux 容器使用 Windows 代理备忘

## 环境说明

- 宿主机：Windows + LightningX 代理客户端
- 容器：Docker Desktop for Windows 上的 Linux 容器
- 代理软件：LightningX（HTTP 代理端口默认仅监听 127.0.0.1）

---

## 核心思路

LightningX 的 HTTP 代理端口只监听 `127.0.0.1`，容器无法直接访问。
通过 Windows 的 `netsh portproxy` 将宿主机 Docker 网关 IP 上的端口转发到 `127.0.0.1` 代理端口，容器即可访问。

```
容器 → 172.18.0.1:19828 → (Windows portproxy) → 127.0.0.1:19828 → LightningX → 互联网
```

---

## 部署步骤

### 第一步：确认代理端口

在 Windows PowerShell 中查看 LightningX 监听的端口：

```powershell
Get-NetTCPConnection -State Listen | Where-Object {
    (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).Name -like "*lightning*"
} | Select-Object LocalAddress, LocalPort | Format-Table -AutoSize
```

典型输出：
```
LocalAddress  LocalPort
------------  ---------
::                19822   # 内部端口（不是代理）
127.0.0.1         19827   # SOCKS 端口（仅本机）
127.0.0.1         19828   # HTTP 代理端口（仅本机）✅ 用这个
```

### 第二步：确认 Docker 网关 IP

```powershell
# 查看 Docker bridge 网关地址（通常是 172.18.0.1）
Get-NetIPAddress | Where-Object { $_.IPAddress -like "172.*" } | Select-Object IPAddress, InterfaceAlias
```

### 第三步：添加端口转发规则（需要管理员权限）

```powershell
# 将 Docker 网关 IP 上的端口转发到本机代理
netsh interface portproxy add v4tov4 `
  listenaddress=172.18.0.1 `
  listenport=19828 `
  connectaddress=127.0.0.1 `
  connectport=19828

# 验证规则
netsh interface portproxy show all
```

### 第四步：添加防火墙规则（允许容器访问）

```powershell
New-NetFirewallRule -DisplayName "LightningX Proxy for Docker" `
  -Direction Inbound `
  -Action Allow `
  -Protocol TCP `
  -LocalPort 19828 `
  -RemoteAddress 172.16.0.0/12
```

### 第五步：容器内设置代理环境变量

```bash
# 动态获取网关 IP（推荐，应对网关 IP 变化）
GATEWAY=$(ip route | grep default | awk '{print $3}')
export http_proxy=http://${GATEWAY}:19828
export https_proxy=http://${GATEWAY}:19828

# 验证
curl https://ipinfo.io/ip
```

写入 `~/.bashrc` 永久生效：

```bash
cat >> ~/.bashrc << 'EOF'
GATEWAY=$(ip route | grep default | awk '{print $3}')
export http_proxy=http://${GATEWAY}:19828
export https_proxy=http://${GATEWAY}:19828
EOF

source ~/.bashrc
```

---

## apt 代理配置（容器内）

```bash
# 动态写入 apt 代理配置
GATEWAY=$(ip route | grep default | awk '{print $3}')
echo "Acquire::http::Proxy \"http://${GATEWAY}:19828\";" > /etc/apt/apt.conf.d/01proxy
echo "Acquire::https::Proxy \"http://${GATEWAY}:19828\";" >> /etc/apt/apt.conf.d/01proxy
```

---

## 维护命令

```powershell
# 查看所有端口转发规则
netsh interface portproxy show all

# 删除转发规则
netsh interface portproxy delete v4tov4 listenaddress=172.18.0.1 listenport=19828

# 删除防火墙规则
Remove-NetFirewallRule -DisplayName "LightningX Proxy for Docker"
```

---

## 注意事项

1. **LightningX 端口可能每次启动变化**，重启后需重新确认端口号并更新转发规则
2. **Docker 网关 IP** 通常固定为 `172.18.0.1`，但重建 Docker 网络后可能变化
3. `netsh portproxy` 规则在 Windows 重启后会自动保留
4. 如果代理软件支持"允许局域网（Allow LAN）"，可以直接用 `host.docker.internal:端口`，无需端口转发，更简单
