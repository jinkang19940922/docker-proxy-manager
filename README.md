# Docker Proxy Manager

🐳 **Linux Docker 代理管理工具** - 一键配置 Docker 镜像加速代理

一个通用的 Shell 脚本，用于在各类 Linux 发行版上轻松配置和管理 Docker HTTP/HTTPS 代理。

> **最新版本**: v2.0.0 - 新增群晖 DSM 7.x、飞牛 fnOS、威联通 QNAP 支持

---

## ✨ 功能特点

- 🎯 **自动检测系统** - 支持 Ubuntu、Debian、Deepin、CentOS、Rocky、Fedora、Arch、群晖 DSM、飞牛 fnOS、威联通 QNAP
- 🔧 **智能适配配置** - 自动识别 systemd、service、init.d 等服务管理方式
- 🎨 **彩色输出** - 清晰的状态提示和操作反馈
- 💾 **配置备份** - 修改配置前自动备份原有文件
- 🚀 **临时拉取** - 支持使用临时代理拉取镜像（不保存配置）
- 📊 **状态查看** - 显示系统信息、Docker 版本、当前代理配置
- 🧪 **测试模式** - 新增 `--test` 参数，仅检测系统不修改配置

---

## 🚀 快速开始

### 下载脚本

```bash
# 方式 1: 直接下载
wget https://raw.githubusercontent.com/your-username/docker-proxy-manager/main/docker-proxy-manager.sh

# 方式 2: 或手动复制脚本内容
```

### 赋予执行权限

```bash
chmod +x docker-proxy-manager.sh
```

### 运行脚本

```bash
# 方式 1: 使用 sudo 直接运行
sudo bash docker-proxy-manager.sh

# 方式 2: 先切换 root 再运行
sudo -i
./docker-proxy-manager.sh

# 方式 3: 仅测试系统检测（不修改任何配置）
sudo bash docker-proxy-manager.sh --test

# 方式 4: 查看帮助信息
bash docker-proxy-manager.sh --help
```

---

## 📋 功能菜单

```
========================================
    Linux Docker 代理管理工具
========================================
  系统：Debian/Ubuntu/Deepin
  服务管理：systemctl
  配置类型：systemd
========================================
1. 设置/更新 Docker 代理
2. 查看当前代理配置
3. 删除代理
4. 临时代理拉取镜像 (不保存)
5. 退出
========================================
```

### 选项说明

| 选项 | 功能 | 说明 |
|------|------|------|
| 1 | 设置/更新代理 | 配置 Docker 服务代理，自动重启服务 |
| 2 | 查看状态 | 显示系统信息、配置文件、环境变量 |
| 3 | 删除代理 | 移除代理配置文件 |
| 4 | 临时拉取 | 使用临时代理拉取指定镜像 |
| 5 | 退出 | 退出脚本 |

---

## 💡 使用示例

### 场景 1: 配置永久代理

```bash
# 运行脚本，选择选项 1
# 输入代理地址，如：http://192.168.10.222:7890
# 脚本自动配置并重启 Docker
```

### 场景 2: 临时拉取国外镜像

```bash
# 运行脚本，选择选项 4
# 输入代理地址和镜像名
# 例如：nginx:latest
# 仅本次拉取使用代理，不影响原有配置
```

### 场景 3: 查看当前配置

```bash
# 运行脚本，选择选项 2
# 显示：
#   - 系统类型和服务管理方式
#   - 配置文件路径和内容
#   - 当前环境变量代理设置
#   - 可选测试拉取 hello-world
```

---

## 🔍 系统兼容性

### 支持的发行版

| 系统类型 | 发行版 | 服务管理 | 配置路径 |
|---------|--------|---------|---------|
| Debian 系 | Ubuntu, Debian, Deepin | systemctl | `/etc/systemd/system/docker.service.d/` |
| RHEL 系 | CentOS, Rocky, Fedora | systemctl | `/etc/systemd/system/docker.service.d/` |
| Arch 系 | Arch Linux, Manjaro | systemctl | `/etc/systemd/system/docker.service.d/` |
| 群晖 | DSM 7.0-7.1 | systemctl | `/etc/systemd/system/pkg-Docker-dockerd.service.d/` |
| 群晖 | DSM 7.2+ (Container Manager) | systemctl | `/etc/systemd/system/pkg-ContainerManager-dockerd.service.d/` |
| 飞牛 | fnOS | systemctl | `/etc/systemd/system/docker.service.d/` |
| 威联通 | QNAP TS/TBS 系列 | init.d | `/etc/default/docker` |
| 传统系统 | 旧版 Debian/CentOS | service | `/etc/default/docker` 或 `/etc/sysconfig/docker` |

### 前置要求

- ✅ 已安装 Docker
- ✅ root 权限（使用 `sudo`）
- ✅ Bash Shell

---

## 📁 配置文件说明

### systemd 方式（现代 Linux）

配置文件：`/etc/systemd/system/docker.service.d/http-proxy.conf`

```ini
[Service]
Environment="HTTP_PROXY=http://192.168.10.222:7890"
Environment="HTTPS_PROXY=http://192.168.10.222:7890"
Environment="NO_PROXY=localhost,127.0.0.1,192.168.0.0/16,172.17.0.0/16,10.0.0.0/8"
```

### Debian/Ubuntu 传统方式

配置文件：`/etc/default/docker`

```bash
export HTTP_PROXY="http://192.168.10.222:7890"
export HTTPS_PROXY="http://192.168.10.222:7890"
export NO_PROXY="localhost,127.0.0.1,192.168.0.0/16,172.17.0.0/16,10.0.0.0/8"
```

### RHEL/CentOS 传统方式

配置文件：`/etc/sysconfig/docker`

```bash
export HTTP_PROXY="http://192.168.10.222:7890"
export HTTPS_PROXY="http://192.168.10.222:7890"
export NO_PROXY="localhost,127.0.0.1,192.168.0.0/16,172.17.0.0/16,10.0.0.0/8"
```

---

## ⚠️ 注意事项

1. **代理地址**：默认代理地址为 `http://192.168.10.222:7890`，可根据实际情况修改
2. **NO_PROXY**：已预设本地地址和 Docker 网段，避免影响本地服务
3. **配置备份**：修改配置前会自动备份，格式为 `*.bak.YYYYMMDDHHMMSS`
4. **服务重启**：配置更改后会自动重启 Docker 服务

---

## 🛠️ 故障排除

### Docker 服务重启失败

```bash
# 手动重启
sudo systemctl restart docker

# 或（群晖）
sudo synoservice --restart pkgctl-Docker
```

### 查看 Docker 状态

```bash
sudo systemctl status docker
```

### 查看日志

```bash
sudo journalctl -u docker -f
```

---

## 📝 许可证

MIT License

---

## 📋 更新日志

### v2.0.0 (2026-02-28) 🎉

**新增支持 NAS 系统**
- ✅ **群晖 Synology DSM 7.x** - 支持 Docker 包和 Container Manager 包
  - DSM 7.0-7.1: `/etc/systemd/system/pkg-Docker-dockerd.service.d/`
  - DSM 7.2+: `/etc/systemd/system/pkg-ContainerManager-dockerd.service.d/`
- ✅ **飞牛 fnOS** - 基于 Debian 的国产 NAS 系统
- ✅ **威联通 QNAP** - 支持 Container Station Docker 管理

**新增功能**
- 🧪 **测试模式** - 添加 `--test` 参数，仅检测系统配置，不进行任何修改
- ℹ️ **帮助信息** - 添加 `--help` 参数显示使用说明
- 🎯 **智能检测** - 优化系统识别逻辑，优先检测 NAS 系统

**改进优化**
- 🔧 群晖 DSM 7.x 使用正确的服务名 (`pkg-Docker-dockerd` / `pkg-ContainerManager-dockerd`)
- 🔧 威联通 QNAP 使用 init.d 方式管理服务
- 📝 更新文档说明各系统配置路径

**Bug 修复**
- 🐛 修复群晖 DSM 系统识别错误（改用 `/etc/synoinfo.conf` 特征文件）
- 🐛 修复群晖 Docker 服务重启命令

---

### v1.0.0 (初始版本)

- 支持 Debian/Ubuntu/CentOS/Arch 等主流 Linux 发行版
- 基础 Docker 代理配置功能

---

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

---

## 📧 联系方式

如有问题或建议，请提交 Issue。
