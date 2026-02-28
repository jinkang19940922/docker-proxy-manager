#!/bin/bash

# ==========================================
# Linux Docker 代理管理脚本 (通用版)
# 支持：Ubuntu, Debian, Deepin, CentOS, Rocky, Fedora, Arch, 群晖 DSM 等
# ==========================================

DEFAULT_PROXY="http://192.168.10.222:7890"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检测系统类型
detect_system() {
    # 检测群晖 Synology (特征文件 /etc/synoinfo.conf)
    if [ -f /etc/synoinfo.conf ] || [ -f /etc.defaults/synoinfo.conf ]; then
        SYSTEM_TYPE="synology"
        SYSTEM_NAME="Synology DSM"
    # 检测飞牛 fnOS (基于 Debian，有 fnos 特征)
    elif [ -f /etc/fnos_version ] || grep -q "fnOS" /etc/issue 2>/dev/null; then
        SYSTEM_TYPE="fnos"
        SYSTEM_NAME="fnOS (飞牛 NAS)"
    # 检测威联通 QNAP (基于 Gentoo/Linux，有 qpkg 特征)
    elif [ -d /share/CACHEDEV1_DATA/.qpkg ] || [ -d /share/HDA_DATA/.qpkg ] || command -v container-station &> /dev/null; then
        SYSTEM_TYPE="qnap"
        SYSTEM_NAME="QNAP (威联通 NAS)"
    elif [ -f /etc/debian_version ]; then
        SYSTEM_TYPE="debian"
        SYSTEM_NAME="Debian/Ubuntu/Deepin"
    elif [ -f /etc/redhat-release ]; then
        SYSTEM_TYPE="redhat"
        SYSTEM_NAME="RHEL/CentOS/Rocky/Fedora"
    elif [ -f /etc/arch-release ]; then
        SYSTEM_TYPE="arch"
        SYSTEM_NAME="Arch Linux"
    else
        SYSTEM_TYPE="unknown"
        SYSTEM_NAME="Unknown"
    fi
}

# 检测 Docker 服务管理方式
detect_docker_service() {
    # 检查 Docker 是否安装
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}错误：未检测到 Docker，请先安装 Docker${NC}"
        exit 1
    fi

    # 检测服务管理方式
    if [ "$SYSTEM_TYPE" = "synology" ]; then
        # 群晖 DSM 7.x 使用 systemctl 管理 Docker
        # 检测是 Docker 包还是 Container Manager 包
        if systemctl list-unit-files pkg-ContainerManager-dockerd.service &> /dev/null 2>&1; then
            SERVICE_MANAGER="systemctl"
            SERVICE_NAME="pkg-ContainerManager-dockerd"
        elif systemctl list-unit-files pkg-Docker-dockerd.service &> /dev/null 2>&1; then
            SERVICE_MANAGER="systemctl"
            SERVICE_NAME="pkg-Docker-dockerd"
        elif command -v systemctl &> /dev/null; then
            #  fallback 到标准 docker 服务
            SERVICE_MANAGER="systemctl"
            SERVICE_NAME="docker"
        else
            # 旧版群晖使用 synoservice
            SERVICE_MANAGER="synoservice"
            SERVICE_NAME="pkgctl-Docker"
        fi
    elif [ "$SYSTEM_TYPE" = "fnos" ]; then
        # 飞牛 fnOS 使用 systemctl
        SERVICE_MANAGER="systemctl"
        SERVICE_NAME="docker"
    elif [ "$SYSTEM_TYPE" = "qnap" ]; then
        # 威联通 QNAP 使用 init.d 脚本
        SERVICE_MANAGER="initd"
        SERVICE_NAME="container-station"
    elif command -v systemctl &> /dev/null && systemctl list-unit-files docker.service &> /dev/null 2>&1; then
        SERVICE_MANAGER="systemctl"
        SERVICE_NAME="docker"
    elif command -v service &> /dev/null; then
        SERVICE_MANAGER="service"
        SERVICE_NAME="docker"
    else
        SERVICE_MANAGER="manual"
        SERVICE_NAME="docker"
    fi
}

# 检测配置文件路径
detect_config_path() {
    if [ "$SERVICE_MANAGER" = "systemctl" ]; then
        # systemd 方式 (现代 Linux/飞牛 fnOS/群晖 DSM 7.x)
        if [ "$SYSTEM_TYPE" = "synology" ]; then
            # 群晖 DSM 7.x 特殊处理
            if [ "$SERVICE_NAME" = "pkg-ContainerManager-dockerd" ]; then
                PROXY_CONF="/etc/systemd/system/pkg-ContainerManager-dockerd.service.d/http-proxy.conf"
            elif [ "$SERVICE_NAME" = "pkg-Docker-dockerd" ]; then
                PROXY_CONF="/etc/systemd/system/pkg-Docker-dockerd.service.d/http-proxy.conf"
            else
                PROXY_CONF="/etc/systemd/system/docker.service.d/http-proxy.conf"
            fi
        else
            # 标准 systemd 配置
            PROXY_CONF="/etc/systemd/system/docker.service.d/http-proxy.conf"
        fi
        CONFIG_TYPE="systemd"
    elif [ "$SERVICE_MANAGER" = "synoservice" ]; then
        # 群晖 DSM 旧版使用 /etc/default/docker
        PROXY_CONF="/etc/default/docker"
        CONFIG_TYPE="default_file"
    elif [ "$SERVICE_MANAGER" = "initd" ]; then
        # 威联通 QNAP 使用 docker 环境变量文件
        PROXY_CONF="/etc/default/docker"
        CONFIG_TYPE="default_file"
    elif [ -f /etc/default/docker ]; then
        # Debian/Ubuntu 传统方式
        PROXY_CONF="/etc/default/docker"
        CONFIG_TYPE="default_file"
    elif [ -f /etc/sysconfig/docker ]; then
        # RHEL/CentOS 传统方式
        PROXY_CONF="/etc/sysconfig/docker"
        CONFIG_TYPE="sysconfig_file"
    else
        # 默认使用 systemd
        PROXY_CONF="/etc/systemd/system/docker.service.d/http-proxy.conf"
        CONFIG_TYPE="systemd"
    fi
}

# 检查 root 权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}错误：请使用 root 权限运行此脚本${NC}"
        echo -e "${YELLOW}提示：使用 'sudo -i' 切换或 'sudo bash $0' 运行${NC}"
        exit 1
    fi
}

# 重启 Docker 服务
restart_docker() {
    echo -e "${YELLOW}正在重启 Docker 服务...${NC}"

    case $SERVICE_MANAGER in
        systemctl)
            systemctl daemon-reload
            if [ "$SYSTEM_TYPE" = "synology" ] && [ -n "$SERVICE_NAME" ]; then
                # 群晖使用特定服务名
                systemctl restart "$SERVICE_NAME"
            else
                # 标准 docker 服务
                systemctl restart docker
            fi
            ;;
        synoservice)
            synoservice --restart pkgctl-Docker
            ;;
        initd)
            # 威联通 QNAP 使用 init.d 脚本重启
            /etc/init.d/container-station.sh restart
            ;;
        service)
            service docker restart
            ;;
        manual)
            echo -e "${YELLOW}请手动重启 Docker 服务${NC}"
            return 1
            ;;
    esac

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Docker 服务已重启${NC}"
    else
        echo -e "${RED}✗ Docker 服务重启失败${NC}"
        return 1
    fi
}

# 设置代理
set_proxy() {
    read -p "请输入代理地址 (默认：$DEFAULT_PROXY): " input_proxy
    PROXY_ADDR=${input_proxy:-$DEFAULT_PROXY}

    case $CONFIG_TYPE in
        systemd)
            mkdir -p "$(dirname "$PROXY_CONF")"
            cat > "$PROXY_CONF" <<EOF
[Service]
Environment="HTTP_PROXY=$PROXY_ADDR"
Environment="HTTPS_PROXY=$PROXY_ADDR"
Environment="NO_PROXY=localhost,127.0.0.1,192.168.0.0/16,172.17.0.0/16,10.0.0.0/8"
EOF
            ;;
        default_file)
            # 备份并更新 /etc/default/docker
            if [ -f "$PROXY_CONF" ]; then
                cp "$PROXY_CONF" "${PROXY_CONF}.bak.$(date +%Y%m%d%H%M%S)"
            fi
            cat > "$PROXY_CONF" <<EOF
# Docker 代理配置
export HTTP_PROXY="$PROXY_ADDR"
export HTTPS_PROXY="$PROXY_ADDR"
export NO_PROXY="localhost,127.0.0.1,192.168.0.0/16,172.17.0.0/16,10.0.0.0/8"
EOF
            ;;
        sysconfig_file)
            # 备份并更新 /etc/sysconfig/docker
            if [ -f "$PROXY_CONF" ]; then
                cp "$PROXY_CONF" "${PROXY_CONF}.bak.$(date +%Y%m%d%H%M%S)"
            fi
            cat > "$PROXY_CONF" <<EOF
# Docker 代理配置
export HTTP_PROXY="$PROXY_ADDR"
export HTTPS_PROXY="$PROXY_ADDR"
export NO_PROXY="localhost,127.0.0.1,192.168.0.0/16,172.17.0.0/16,10.0.0.0/8"
EOF
            ;;
    esac

    echo -e "${GREEN}✓ 代理已设定为：$PROXY_ADDR${NC}"
    echo -e "${YELLOW}  配置文件：$PROXY_CONF${NC}"
    restart_docker
}

# 查看状态
show_status() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  系统信息${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo "系统类型：$SYSTEM_NAME"
    echo "服务管理：$SERVICE_MANAGER"
    echo "Docker 版本：$(docker --version 2>/dev/null || echo '未知')"
    echo ""
    
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  当前代理配置${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo "配置文件：$PROXY_CONF"
    
    if [ -f "$PROXY_CONF" ]; then
        echo -e "${GREEN}✓ 配置文件存在${NC}"
        echo "--- 配置内容 ---"
        cat "$PROXY_CONF"
    else
        echo -e "${YELLOW}✗ 配置文件不存在${NC}"
    fi
    echo ""
    
    # 显示当前环境变量中的代理
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  当前环境变量代理${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo "HTTP_PROXY=${HTTP_PROXY:-未设置}"
    echo "HTTPS_PROXY=${HTTPS_PROXY:-未设置}"
    echo "NO_PROXY=${NO_PROXY:-未设置}"
    echo ""
    
    # 测试连接
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  测试代理连接${NC}"
    echo -e "${GREEN}========================================${NC}"
    read -p "是否测试拉取 hello-world 镜像？(y/n): " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        echo "开始测试..."
        if docker pull hello-world 2>&1; then
            echo -e "${GREEN}✓ 测试成功${NC}"
        else
            echo -e "${RED}✗ 测试失败${NC}"
        fi
    fi
}

# 删除代理
remove_proxy() {
    if [ -f "$PROXY_CONF" ]; then
        rm -f "$PROXY_CONF"
        echo -e "${GREEN}✓ 已删除代理配置：$PROXY_CONF${NC}"
        
        # 如果是 systemd 配置，需要 reload
        if [ "$CONFIG_TYPE" = "systemd" ]; then
            restart_docker
        else
            echo -e "${YELLOW}提示：请手动重启 Docker 服务使更改生效${NC}"
        fi
    else
        echo -e "${YELLOW}当前未配置代理文件${NC}"
    fi
}

# 临时拉取镜像
temp_pull() {
    read -p "请输入代理地址 (默认：$DEFAULT_PROXY): " input_proxy
    PROXY_ADDR=${input_proxy:-$DEFAULT_PROXY}
    read -p "请输入要拉取的镜像名： " image_name

    if [ -z "$image_name" ]; then
        echo -e "${RED}错误：镜像名不能为空${NC}"
        return 1
    fi

    echo -e "${YELLOW}正在使用临时代理拉取：$image_name${NC}"
    echo -e "${YELLOW}代理地址：$PROXY_ADDR${NC}"
    
    HTTP_PROXY=$PROXY_ADDR HTTPS_PROXY=$PROXY_ADDR docker pull "$image_name"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ 拉取成功${NC}"
    else
        echo -e "${RED}✗ 拉取失败${NC}"
    fi
}

# 显示菜单
show_menu() {
    clear
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}    Linux Docker 代理管理工具${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "  系统：${YELLOW}$SYSTEM_NAME${NC}"
    echo -e "  服务管理：${YELLOW}$SERVICE_MANAGER${NC}"
    echo -e "  配置类型：${YELLOW}$CONFIG_TYPE${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo "1. 设置/更新 Docker 代理"
    echo "2. 查看当前代理配置"
    echo "3. 删除代理"
    echo "4. 临时代理拉取镜像 (不保存)"
    echo "5. 退出"
    echo -e "${GREEN}========================================${NC}"
    read -p "请输入选项 [1-5]: " choice
}

# 初始化
init() {
    check_root
    detect_system
    detect_docker_service
    detect_config_path
}

# 测试模式 - 仅显示检测结果
test_detect() {
    detect_system
    detect_docker_service
    detect_config_path
    
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  系统检测结果${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo "系统类型：$SYSTEM_NAME"
    echo "服务管理：$SERVICE_MANAGER"
    echo "配置文件：$PROXY_CONF"
    echo "配置类型：$CONFIG_TYPE"
    echo ""
    
    # 检查配置文件是否存在
    if [ -f "$PROXY_CONF" ]; then
        echo -e "${GREEN}✓ 配置文件存在${NC}"
    else
        echo -e "${YELLOW}✗ 配置文件不存在（首次设置时会创建）${NC}"
    fi
    
    # 检查目录是否存在
    if [ "$CONFIG_TYPE" = "systemd" ]; then
        if [ -d "$(dirname "$PROXY_CONF")" ]; then
            echo -e "${GREEN}✓ 配置目录存在${NC}"
        else
            echo -e "${YELLOW}✗ 配置目录不存在（首次设置时会创建）${NC}"
        fi
    fi
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${YELLOW}提示：检测完成，未进行任何修改${NC}"
}

# 显示使用说明
show_usage() {
    echo "用法：$0 [选项]"
    echo ""
    echo "选项:"
    echo "  --test, -t    仅测试系统检测，不进行任何修改"
    echo "  --help, -h    显示此帮助信息"
    echo ""
    echo "无选项时进入交互菜单"
}

# 主程序
main() {
    # 处理命令行参数
    case "${1:-}" in
        --test|-t)
            test_detect
            exit 0
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
    esac

    init

    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}欢迎使用 Linux Docker 代理管理工具${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo "检测到的配置："
    echo "  系统：$SYSTEM_NAME"
    echo "  服务管理：$SERVICE_MANAGER"
    echo "  配置文件：$PROXY_CONF"
    echo "  配置类型：$CONFIG_TYPE"
    echo ""
    read -p "按回车键继续..."

    # 主循环
    while true; do
        show_menu
        case $choice in
            1) set_proxy ;;
            2) show_status ;;
            3) remove_proxy ;;
            4) temp_pull ;;
            5) echo "退出"; exit 0 ;;
            *) echo -e "${RED}无效选项${NC}" ;;
        esac
        echo ""
        read -p "按回车键继续..."
    done
}

main "$@"
