# Docker Linux 容器使用 Windows 代理备忘

## 环境说明

- 宿主机：Windows + LightningX 代理客户端
- 容器：Docker Desktop for Windows 上的 Linux 容器（WSL2 后端）
- 代理软件：LightningX（HTTP 代理端口默认仅监听 `127.0.0.1`）

---

## 核心思路

LightningX 的 HTTP 代理端口只监听 `127.0.0.1`，容器无法直接访问。
通过 Windows 的 `netsh portproxy` 将 Docker bridge 网关 IP 上的端口转发到 `127.0.0.1` 代理端口，容器即可访问。

```
容器 → 172.18.0.1:19828 → (Windows portproxy) → 127.0.0.1:19828 → LightningX → 互联网
```

---

## 常见误区（不起作用的方案）

### ❌ 容器内使用 `127.0.0.1`

Docker Desktop 使用 WSL2 后端，即使容器设置了 `--network=host`，容器内的 `127.0.0.1` 也是 WSL2 VM 的 loopback，**不是** Windows 宿主机的 loopback，因此连不到 Windows 上的 LightningX。

### ❌ 使用 `host.docker.internal`

`host.docker.internal` 在使用 `--network=host` 的容器中不可靠，DNS 解析可能不生效。

### ❌ `.wslconfig` 设置 `networkingMode=mirrored`

镜像网络模式只对用户手动创建的 WSL2 发行版（如 Ubuntu）生效，对 Docker Desktop 内部的 `docker-desktop` distro **无效**。容器内 `127.0.0.1` 仍然是 WSL2 VM loopback。

---

## 部署步骤

### 第一步：确认代理端口

在 Windows PowerShell 中查看 LightningX 监听的端口：

```powershell
Get-NetTCPConnection -State Listen | ForEach-Object {
    $proc = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
    [PSCustomObject]@{ LocalAddress = $_.LocalAddress; LocalPort = $_.LocalPort; Process = $proc.Name }
} | Where-Object { $_.Process -like "*lightning*" } | Format-Table -AutoSize
```

典型输出：
```
LocalAddress  LocalPort
------------  ---------
::                19822   # 内部端口（不是代理）
172.18.0.1        59283   # Docker 网关上的随机端口（忽略）
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

# 验证规则（应看到 172.18.0.1:19828 的条目）
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

### 第五步：devcontainer.json 配置代理

`containerEnv` 中使用固定网关 IP（VS Code Server 及其扩展继承此环境变量，不走 shell profile）：

```jsonc
"containerEnv": {
    "HTTP_PROXY":  "http://172.18.0.1:19828",
    "HTTPS_PROXY": "http://172.18.0.1:19828",
    "http_proxy":  "http://172.18.0.1:19828",
    "https_proxy": "http://172.18.0.1:19828",
    "NO_PROXY": "localhost,127.0.0.0/8,::1",
    "no_proxy": "localhost,127.0.0.0/8,::1"
}
```

`postStartCommand` 中动态写入 `/etc/profile.d/99-proxy.sh`，供终端 shell 会话使用（同样指向网关 IP，但通过 `ip route` 动态获取以应对网关变化）。

### 第六步：验证

容器内终端执行：

```bash
# 验证端口转发是否生效
curl -x http://172.18.0.1:19828 https://ipinfo.io/ip

# 验证 VS Code 扩展环境变量
echo $HTTP_PROXY
```

---

## apt 代理配置（容器内）

```bash
# 动态写入 apt 代理配置
GATEWAY=$(ip route | grep default | awk '{print $3}')
echo "Acquire::http::Proxy \"http://${GATEWAY}:19828\";" | sudo tee /etc/apt/apt.conf.d/01proxy
echo "Acquire::https::Proxy \"http://${GATEWAY}:19828\";" | sudo tee -a /etc/apt/apt.conf.d/01proxy
```

---

## 维护命令

```powershell
# 查看所有端口转发规则
netsh interface portproxy show all

# 删除转发规则（端口号变化时重新添加）
netsh interface portproxy delete v4tov4 listenaddress=172.18.0.1 listenport=19828

# 删除防火墙规则
Remove-NetFirewallRule -DisplayName "LightningX Proxy for Docker"
```

---

## 注意事项

1. **LightningX 端口可能每次启动变化**，重启后需重新确认端口号（`Get-NetTCPConnection`），如有变化需更新 portproxy 规则和 `devcontainer.json` 中的 `containerEnv` 并 Rebuild Container
2. **Docker 网关 IP** 通常固定为 `172.18.0.1`，重建 Docker 网络后可能变化
3. `netsh portproxy` 规则在 Windows 重启后**自动保留**，无需重新添加
4. LightningX 在 `172.18.0.1` 上的随机端口（如 `59283`）是其内部监听，无法用于代理
