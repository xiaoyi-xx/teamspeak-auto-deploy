#!/bin/bash

# ================================================
# TeamSpeak 3 一体化自动部署脚本
# 自动完成部署、启动并提示用户记录Token
# 使用方法：sudo bash install-teamspeak.sh
# ================================================

# 配置变量
DEFAULT_TS_VERSION="3.13.7"
TS_VERSION="${1:-$DEFAULT_TS_VERSION}"
TS_USER="teamspeak"
TS_DIR="/home/teamspeak"
TS_INSTALL_DIR="$TS_DIR/teamspeak3-server"
TS_DOWNLOAD_URL="https://files.teamspeak-services.com/releases/server/${TS_VERSION}/teamspeak3-server_linux_amd64-${TS_VERSION}.tar.bz2"
TS_SERVICE_FILE="/etc/systemd/system/teamspeak.service"
CREDENTIALS_FILE="$TS_DIR/teamspeak_credentials.txt"
SERVER_IP=""

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# 高亮显示函数
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_highlight() { echo -e "${PURPLE}[!]$NC $1"; }
print_token() { echo -e "${CYAN}${BOLD}$1${NC}"; }
print_divider() { echo "=============================================="; }

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本必须以root权限运行！"
        print_info "请使用: sudo bash $0"
        exit 1
    fi
}

# 获取服务器IP
get_server_ip() {
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    if [[ -z "$SERVER_IP" ]]; then
        SERVER_IP="您的服务器IP"
    fi
}

# 显示欢迎信息
show_welcome() {
    clear
    print_divider
    echo "       TeamSpeak 3 一体化部署脚本"
    print_divider
    echo ""
    print_info "此脚本将自动完成以下所有步骤："
    echo ""
    echo "  ✓ 1. 更新系统并安装必要工具"
    echo "  ✓ 2. 创建专用用户"
    echo "  ✓ 3. 下载并安装TeamSpeak服务器"
    echo "  ✓ 4. 配置防火墙"
    echo "  ✓ 5. 创建系统服务"
    echo "  ✓ 6. 首次启动服务"
    echo "  ✦ 7. 显示并等待您记录管理员Token"
    echo "  ✓ 8. 启用开机自启"
    echo ""
    print_warning "注意：服务启动后会生成管理员Token"
    print_warning "请务必在提示时立即记录并保存！"
    echo ""
}

# 确认继续
confirm_continue() {
    read -p "是否继续安装？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "安装已取消"
        exit 0
    fi
}

# 更新系统和安装工具
update_system() {
    print_info "正在检测包管理器..."
    
    if command -v yum &> /dev/null; then
        # CentOS/RHEL系统
        print_info "正在更新系统软件包..."
        yum update -y
        
        print_info "正在安装必要工具..."
        yum install -y wget tar bzip2 nano net-tools curl
        
        print_success "系统更新完成"
    elif command -v apt-get &> /dev/null; then
        # Debian/Ubuntu系统
        print_info "正在更新系统软件包..."
        apt-get update -y
        
        print_info "正在安装必要工具..."
        apt-get install -y wget tar bzip2 nano net-tools curl
        
        print_success "系统更新完成"
    else
        print_error "不支持的包管理器！"
        print_info "请手动安装必要工具：wget tar bzip2 nano net-tools curl"
        exit 1
    fi
}

# 创建专用用户
create_user() {
    print_info "正在创建用户 $TS_USER..."
    
    if id "$TS_USER" &>/dev/null; then
        print_warning "用户 $TS_USER 已存在"
        read -p "是否删除现有用户并重新创建？(y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            systemctl stop teamspeak 2>/dev/null
            systemctl disable teamspeak 2>/dev/null
            userdel -r "$TS_USER" 2>/dev/null
            useradd -m -s /bin/bash "$TS_USER"
            print_success "用户 $TS_USER 已重新创建"
        else
            print_info "使用现有用户"
        fi
    else
        useradd -m -s /bin/bash "$TS_USER"
        print_success "用户 $TS_USER 创建完成"
    fi
}

# 下载并安装TeamSpeak
install_teamspeak() {
    print_info "正在下载 TeamSpeak $TS_VERSION..."
    
    # 确保目录存在
    if ! mkdir -p "$TS_DIR"; then
        print_error "无法创建目录: $TS_DIR"
        exit 1
    fi
    chown "$TS_USER":"$TS_USER" "$TS_DIR"
    
    # 切换到用户目录
    if ! cd "$TS_DIR"; then
        print_error "无法切换到目录: $TS_DIR"
        exit 1
    fi
    
    # 下载
    print_info "正在从 TeamSpeak 官方服务器下载..."
    if sudo -u "$TS_USER" wget --timeout=60 --tries=3 "$TS_DOWNLOAD_URL" -O teamspeak.tar.bz2 2>/dev/null; then
        print_success "下载完成"
    else
        print_error "下载失败！"
        print_info "请检查："
        echo "  1. 网络连接"
        echo "  2. 下载地址是否正确: $TS_DOWNLOAD_URL"
        print_info "您也可以手动下载后放在 $TS_DIR 目录下"
        exit 1
    fi
    
    # 检查下载文件大小
    if [[ ! -s teamspeak.tar.bz2 ]]; then
        print_error "下载的文件为空，请检查网络连接或下载地址"
        sudo -u "$TS_USER" rm -f teamspeak.tar.bz2
        exit 1
    fi
    
    # 解压
    print_info "正在解压文件..."
    if ! sudo -u "$TS_USER" tar -xvjf teamspeak.tar.bz2 2>/dev/null; then
        print_error "解压失败！"
        print_info "请检查文件是否完整或损坏"
        sudo -u "$TS_USER" rm -f teamspeak.tar.bz2
        exit 1
    fi
    
    # 检查解压后的目录
    local extracted_dir="teamspeak3-server_linux_amd64"
    if [[ ! -d "$extracted_dir" ]]; then
        # 尝试自动检测解压后的目录名称
        extracted_dir=$(ls -d teamspeak3-server_linux_* 2>/dev/null | head -1)
        if [[ -z "$extracted_dir" ]]; then
            print_error "无法找到解压后的目录"
            sudo -u "$TS_USER" rm -f teamspeak.tar.bz2
            exit 1
        fi
    fi
    
    # 重命名目录
    if ! sudo -u "$TS_USER" mv "$extracted_dir" teamspeak3-server 2>/dev/null; then
        print_error "无法重命名目录"
        sudo -u "$TS_USER" rm -f teamspeak.tar.bz2
        exit 1
    fi
    
    # 接受许可协议
    if ! sudo -u "$TS_USER" touch "$TS_INSTALL_DIR/.ts3server_license_accepted" 2>/dev/null; then
        print_error "无法创建许可协议接受文件"
        exit 1
    fi
    
    # 清理
    if ! sudo -u "$TS_USER" rm -f teamspeak.tar.bz2; then
        print_warning "无法清理临时文件，但不影响安装"
    fi
    
    # 设置权限
    if ! chown -R "$TS_USER":"$TS_USER" "$TS_DIR" 2>/dev/null; then
        print_error "无法设置目录权限"
        exit 1
    fi
    
    print_success "TeamSpeak 安装完成"
}

# 配置防火墙
configure_firewall() {
    print_info "正在配置防火墙..."
    
    local firewall_configured=false
    
    # 检查firewalld
    if command -v firewall-cmd &> /dev/null && systemctl is-active --quiet firewalld; then
        firewall-cmd --permanent --add-port=9987/udp > /dev/null 2>&1
        firewall-cmd --permanent --add-port=10011/tcp > /dev/null 2>&1
        firewall-cmd --permanent --add-port=30033/tcp > /dev/null 2>&1
        firewall-cmd --reload > /dev/null 2>&1
        print_success "firewalld规则已添加"
        firewall_configured=true
    # 检查ufw
    elif command -v ufw &> /dev/null; then
        ufw allow 9987/udp > /dev/null 2>&1
        ufw allow 10011/tcp > /dev/null 2>&1
        ufw allow 30033/tcp > /dev/null 2>&1
        # 如果ufw未启用，提示用户启用
        if ! ufw status | grep -q "active"; then
            print_warning "ufw已安装但未启用，建议运行 'ufw enable' 启用防火墙"
        fi
        print_success "ufw规则已添加"
        firewall_configured=true
    fi
    
    if [ "$firewall_configured" = false ]; then
        print_warning "未检测到支持的防火墙(firewalld或ufw)，跳过防火墙配置"
        print_info "请手动配置防火墙以允许以下端口："
        echo "  - UDP 9987 (语音通信)"
        echo "  - TCP 10011 (服务器查询)"
        echo "  - TCP 30033 (文件传输)"
    else
        # 显示已开放的端口
        echo "已开放端口："
        echo "  ✓ UDP 9987 (语音通信)"
        echo "  ✓ TCP 10011 (服务器查询)"
        echo "  ✓ TCP 30033 (文件传输)"
    fi
    
    # 显示云服务器配置提示
    print_info "云服务器安全组配置提示："
    echo "  请在云服务器控制台安全组中开放以下端口："
    echo "  - UDP 9987 (语音通信)"
    echo "  - TCP 10011 (服务器查询)"
    echo "  - TCP 30033 (文件传输)"
}

# 创建systemd服务
create_service() {
    print_info "正在创建systemd服务..."
    
    # 创建服务文件
    cat > "$TS_SERVICE_FILE" << EOF
[Unit]
Description=TeamSpeak 3 Server
After=network.target

[Service]
User=$TS_USER
Group=$TS_USER
Type=forking
WorkingDirectory=$TS_INSTALL_DIR
ExecStart=$TS_INSTALL_DIR/ts3server_startscript.sh start
ExecStop=$TS_INSTALL_DIR/ts3server_startscript.sh stop
Restart=always
RestartSec=10
PIDFile=$TS_INSTALL_DIR/ts3server.pid

# 环境变量（可选配置）
# Environment=TS3SERVER_LICENSE=accept
# Environment=TS3SERVER_DB_SQLPATH=$TS_INSTALL_DIR/sql/
# Environment=TS3SERVER_DB_SQLCREATEPATH=$TS_INSTALL_DIR/sql/create_sqlite/

[Install]
WantedBy=multi-user.target
EOF
    
    # 重新加载systemd配置
    systemctl daemon-reload
    print_success "systemd服务创建完成"
}

# 启动服务并提取Token
start_service_and_get_token() {
    print_divider
    echo "       准备首次启动TeamSpeak服务"
    print_divider
    echo ""
    print_warning "⚠️  重要提示：服务启动后将生成管理员Token"
    print_warning "Token只能使用一次，是获取管理员权限的唯一凭证"
    echo ""
    print_info "请准备好记录管理员Token！"
    echo ""
    
    # 等待用户确认
    read -p "按 Enter 键开始启动服务..." -n 1 -r
    echo ""
    
    # 启用并启动服务
    print_info "正在启用并启动TeamSpeak服务..."
    systemctl enable teamspeak.service
    systemctl start teamspeak.service
    
    # 等待服务启动
    print_info "等待服务启动..."
    for i in {1..30}; do
        if systemctl is-active --quiet teamspeak.service; then
            print_success "服务启动成功！"
            break
        fi
        echo -n "."
        sleep 1
        
        if [ $i -eq 30 ]; then
            print_error "服务启动超时"
            print_info "尝试查看日志：journalctl -u teamspeak.service -n 20"
            exit 1
        fi
    done
    echo ""
    
    # 等待Token生成
    print_info "正在等待生成管理员Token..."
    sleep 5
    
    # 获取服务日志
    print_info "正在从日志中提取管理员凭证..."
    echo ""
}

# 显示并等待用户记录Token
display_and_save_token() {
    local max_attempts=5
    local attempt=1
    local token_found=false
    
    while [ $attempt -le $max_attempts ] && [ "$token_found" = false ]; do
        print_info "尝试获取Token (第 $attempt 次尝试)..."
        
        local admin_line=""
        local token_line=""
        
        # 尝试从journalctl获取日志
        if command -v journalctl &> /dev/null; then
            local journal_output=$(journalctl -u teamspeak.service -n 50 --no-pager 2>/dev/null)
            # 提取管理员账户和Token
            admin_line=$(echo "$journal_output" | grep -i "loginname=" | tail -1)
            token_line=$(echo "$journal_output" | grep -i "token=" | tail -1)
        fi
        
        # 如果journalctl失败或未找到Token，尝试从日志文件获取
        if [[ -z "$token_line" ]]; then
            local log_file=$(find "$TS_INSTALL_DIR/logs" -name "ts3server_*.log" 2>/dev/null | sort -r | head -1)
            if [[ -n "$log_file" ]]; then
                local log_content=$(tail -n 100 "$log_file" 2>/dev/null)
                admin_line=$(echo "$log_content" | grep -i "loginname=" | tail -1)
                token_line=$(echo "$log_content" | grep -i "token=" | tail -1)
            fi
        fi
        
        if [[ -n "$token_line" ]]; then
            token_found=true
            
            # 清屏并显示凭证
            clear
            print_divider
            echo "      🎉 TeamSpeak 3 部署完成！"
            print_divider
            echo ""
            print_success "✅ 服务正在运行"
            echo ""
            
            # 显示服务器信息
            print_info "🌐 服务器连接信息："
            echo "   服务器地址: $SERVER_IP"
            echo "   语音端口: 9987 (UDP)"
            echo "   查询端口: 10011 (TCP)"
            echo "   文件端口: 30033 (TCP)"
            echo ""
            
            # 高亮显示Token
            print_highlight "🔐 管理员账户信息："
            if [[ -n "$admin_line" ]]; then
                print_token "   $admin_line"
            else
                print_warning "   未找到管理员账户信息"
            fi
            echo ""
            
            print_highlight "🔑 管理员Token (权限密钥)："
            print_token "   $token_line"
            echo ""
            
            print_divider
            print_warning "⚠️  ⚠️  ⚠️   请立即记录上面的Token！  ⚠️  ⚠️  ⚠️"
            print_divider
            echo ""
            print_info "重要提示："
            echo "  1. 此Token只能使用一次，使用后失效"
            echo "  2. 这是获取服务器管理员权限的唯一凭证"
            echo "  3. 客户端连接后使用此Token获取管理员权限"
            echo "  4. 请务必将此Token保存到安全的地方"
            echo ""
            
            # 保存到文件
            save_credentials_to_file "$admin_line" "$token_line"
            
            # 等待用户记录
            wait_for_user_confirmation
            
            break
        else
            print_warning "未找到Token，等待后重试..."
            sleep 3
            attempt=$((attempt + 1))
        fi
    done
    
    if [ "$token_found" = false ]; then
        print_error "无法获取Token，请手动检查日志："
        if command -v journalctl &> /dev/null; then
            echo "   journalctl -u teamspeak.service -f"
        fi
        echo "   或查看日志文件：$TS_INSTALL_DIR/logs/"
        print_info "您也可以稍后从日志中查找Token"
    fi
}

# 保存凭证到文件
save_credentials_to_file() {
    local admin_line="$1"
    local token_line="$2"
    
    cat > "$CREDENTIALS_FILE" << EOF
==============================================
TeamSpeak 3 服务器管理员凭证
生成时间: $(date)
服务器IP: $SERVER_IP
==============================================

🔐 管理员账户:
${admin_line:-未找到}

🔑 管理员Token (权限密钥):
${token_line:-未找到}

==============================================
🌐 连接信息：
==============================================
服务器地址: $SERVER_IP
语音端口: 9987 (UDP)
查询端口: 10011 (TCP)
文件端口: 30033 (TCP)

快速连接链接:
ts3server://$SERVER_IP?port=9987

==============================================
📝 重要提示：
==============================================
1. 此Token只能使用一次，使用后失效
2. 这是获取服务器管理员权限的唯一凭证
3. 客户端连接后使用此Token获取管理员权限
4. 请务必将此Token保存到安全的地方

==============================================
⚙️  管理命令：
==============================================
启动服务: sudo systemctl start teamspeak
停止服务: sudo systemctl stop teamspeak
重启服务: sudo systemctl restart teamspeak
查看状态: sudo systemctl status teamspeak
查看日志: sudo journalctl -u teamspeak -f
禁用服务: sudo systemctl disable teamspeak

==============================================
EOF
    
    chown "$TS_USER":"$TS_USER" "$CREDENTIALS_FILE"
    chmod 600 "$CREDENTIALS_FILE"
    
    print_success "凭证已保存到文件: $CREDENTIALS_FILE"
    print_info "查看凭证: cat $CREDENTIALS_FILE"
    echo ""
}

# 等待用户确认已记录Token
wait_for_user_confirmation() {
    print_divider
    print_info "请确认您已记录管理员Token"
    print_divider
    echo ""
    
    while true; do
        echo "请选择："
        echo "  1. ✅ 我已记录Token，继续"
        echo "  2. 📋 再次显示Token"
        echo "  3. 📄 查看凭证文件"
        echo "  4. ❌ 停止服务并退出（不推荐）"
        read -p "请选择 (1-4): " choice
        
        case $choice in
            1)
                print_success "继续完成安装..."
                return 0
                ;;
            2)
                # 再次显示Token
                clear
                print_divider
                echo "        管理员Token (再次显示)"
                print_divider
                echo ""
                local token_line=$(journalctl -u teamspeak.service -n 50 --no-pager | grep -i "token=" | tail -1)
                local admin_line=$(journalctl -u teamspeak.service -n 50 --no-pager | grep -i "loginname=" | tail -1)
                
                if [[ -n "$admin_line" ]]; then
                    print_highlight "管理员账户："
                    print_token "   $admin_line"
                    echo ""
                fi
                
                if [[ -n "$token_line" ]]; then
                    print_highlight "管理员Token："
                    print_token "   $token_line"
                else
                    print_warning "未找到Token"
                fi
                echo ""
                print_divider
                ;;
            3)
                if [[ -f "$CREDENTIALS_FILE" ]]; then
                    clear
                    print_divider
                    echo "        凭证文件内容"
                    print_divider
                    cat "$CREDENTIALS_FILE"
                    echo ""
                    print_divider
                else
                    print_error "凭证文件不存在"
                fi
                ;;
            4)
                print_warning "正在停止服务..."
                systemctl stop teamspeak.service
                systemctl disable teamspeak.service
                print_info "服务已停止，您可以在准备好后手动启动："
                echo "  sudo systemctl start teamspeak"
                exit 0
                ;;
            *)
                print_error "无效选择，请重新输入"
                ;;
        esac
    done
}

# 创建管理脚本
create_management_script() {
    print_info "正在创建管理脚本..."
    
    # 创建管理脚本
    cat > "$TS_DIR/manage-teamspeak.sh" << EOF
#!/bin/bash
# TeamSpeak 3 服务器管理脚本

# 配置变量
TS_USER="teamspeak"
TS_DIR="/home/teamspeak"
TS_INSTALL_DIR="$TS_DIR/teamspeak3-server"
CREDENTIALS_FILE="$TS_DIR/teamspeak_credentials.txt"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}错误：此脚本需要root权限${NC}"
    echo "请使用: sudo bash $0"
    exit 1
fi

# 显示菜单
show_menu() {
    clear
    echo "=============================================="
    echo -e "${CYAN}${BOLD}      TeamSpeak 3 服务器管理工具${NC}"
    echo "=============================================="
    echo ""
    echo -e "${GREEN}服务状态：${NC}"
    systemctl is-active teamspeak.service >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "  ✅ ${GREEN}服务正在运行${NC}"
    else
        echo -e "  ❌ ${RED}服务未运行${NC}"
    fi
    echo ""
    echo -e "${BLUE}1.${NC} 启动服务"
    echo -e "${BLUE}2.${NC} 停止服务"
    echo -e "${BLUE}3.${NC} 重启服务"
    echo -e "${BLUE}4.${NC} 查看服务状态"
    echo -e "${BLUE}5.${NC} 查看实时日志"
    echo -e "${BLUE}6.${NC} 查看服务器日志"
    echo -e "${BLUE}7.${NC} 查看管理员凭证"
    echo -e "${BLUE}8.${NC} 查看连接信息"
    echo -e "${BLUE}9.${NC} 启用开机自启"
    echo -e "${BLUE}10.${NC} 禁用开机自启"
    echo -e "${BLUE}11.${NC} 查看Token（从日志提取）"
    echo -e "${BLUE}12.${NC} 备份服务器数据"
    echo -e "${BLUE}13.${NC} ${RED}卸载TeamSpeak服务器${NC}"  # 红色警告
    echo -e "${BLUE}0.${NC} 退出"
    echo ""
}

# 显示凭证
show_credentials() {
    echo "=============================================="
    echo -e "${CYAN}管理员凭证${NC}"
    echo "=============================================="
    if [[ -f "$CREDENTIALS_FILE" ]]; then
        cat "$CREDENTIALS_FILE"
    else
        echo -e "${YELLOW}凭证文件不存在，尝试从日志提取...${NC}"
        echo ""
        get_token_from_logs
    fi
}

# 从日志提取Token
get_token_from_logs() {
    echo -e "${BLUE}正在从日志中提取Token...${NC}"
    echo ""
    
    local token_line=""
    local admin_line=""
    
    # 尝试从journalctl获取日志
    if command -v journalctl &> /dev/null; then
        local journal_output=$(journalctl -u teamspeak.service -n 100 --no-pager 2>/dev/null)
        admin_line=$(echo "$journal_output" | grep -i "loginname=" | tail -1)
        token_line=$(echo "$journal_output" | grep -i "token=" | tail -1)
    fi
    
    # 如果journalctl失败或未找到Token，尝试从日志文件获取
    if [[ -z "$token_line" ]]; then
        local log_file=$(find "$TS_INSTALL_DIR/logs" -name "ts3server_*.log" 2>/dev/null | sort -r | head -1)
        if [[ -n "$log_file" ]]; then
            local log_content=$(tail -n 100 "$log_file" 2>/dev/null)
            admin_line=$(echo "$log_content" | grep -i "loginname=" | tail -1)
            token_line=$(echo "$log_content" | grep -i "token=" | tail -1)
        fi
    fi
    
    if [[ -n "$admin_line" ]]; then
        echo -e "${GREEN}管理员账户：${NC}"
        echo "  $admin_line"
        echo ""
    fi
    
    if [[ -n "$token_line" ]]; then
        echo -e "${GREEN}管理员Token：${NC}"
        echo -e "${YELLOW}  $token_line${NC}"
    else
        echo -e "${RED}未找到Token${NC}"
        if command -v journalctl &> /dev/null; then
            echo "请尝试查看完整日志：journalctl -u teamspeak.service | grep -i token"
        fi
        echo "或查看日志文件：$TS_INSTALL_DIR/logs/"
    fi
}

# 查看连接信息
show_connection_info() {
    local server_ip=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    
    echo "=============================================="
    echo -e "${CYAN}连接信息${NC}"
    echo "=============================================="
    echo -e "${GREEN}服务器地址：${NC} $server_ip"
    echo -e "${GREEN}语音端口：${NC} 9987 (UDP)"
    echo -e "${GREEN}查询端口：${NC} 10011 (TCP)"
    echo -e "${GREEN}文件端口：${NC} 30033 (TCP)"
    echo ""
    echo -e "${GREEN}快速连接链接：${NC}"
    echo "ts3server://$server_ip?port=9987"
}

# 备份服务器数据
backup_server() {
    local backup_dir="$TS_DIR/backups"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$backup_dir/teamspeak_backup_$timestamp.tar.gz"
    local max_backups=5
    
    echo "=============================================="
    echo -e "${CYAN}备份服务器数据${NC}"
    echo "=============================================="
    
    # 检查并创建备份目录
    if [[ ! -d "$backup_dir" ]]; then
        echo -e "${BLUE}正在创建备份目录...${NC}"
        mkdir -p "$backup_dir"
        if [[ $? -ne 0 ]]; then
            echo -e "${RED}❌ 无法创建备份目录: $backup_dir${NC}"
            return 1
        fi
    fi
    
    # 设置正确的权限
    chown $TS_USER:$TS_USER "$backup_dir"
    chmod 700 "$backup_dir"  # 仅允许所有者访问
    
    echo -e "${BLUE}正在停止服务...${NC}"
    systemctl stop teamspeak.service
    
    # 检查服务是否真的停止
    sleep 2
    if systemctl is-active --quiet teamspeak.service; then
        echo -e "${RED}❌ 无法停止服务，备份中止${NC}"
        return 1
    fi
    
    echo -e "${BLUE}正在备份数据...${NC}"
    echo -e "${YELLOW}备份文件: $backup_file${NC}"
    
    # 执行备份，显示详细进度
    tar -czvf "$backup_file" -C "$TS_DIR" "$(basename $TS_INSTALL_DIR)"/ 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
        # 验证备份文件
        echo -e "${BLUE}正在验证备份文件...${NC}"
        if gzip -t "$backup_file" 2>/dev/null; then
            echo -e "${GREEN}✅ 备份文件验证成功${NC}"
        else
            echo -e "${YELLOW}⚠️  备份文件验证失败，可能已损坏${NC}"
        fi
        
        echo -e "${BLUE}正在启动服务...${NC}"
        systemctl start teamspeak.service
        
        echo -e "${GREEN}✅ 备份完成！${NC}"
        echo -e "备份文件: $backup_file"
        echo -e "大小: $(du -h "$backup_file" 2>/dev/null | cut -f1)"
        
        # 限制备份文件数量，保留最近的$max_backups个备份
        echo -e "${BLUE}正在清理旧备份文件...${NC}"
        local backup_count=$(ls -1 "$backup_dir"/teamspeak_backup_*.tar.gz 2>/dev/null | wc -l)
        if [[ $backup_count -gt $max_backups ]]; then
            local backups_to_delete=$((backup_count - max_backups))
            ls -1t "$backup_dir"/teamspeak_backup_*.tar.gz 2>/dev/null | tail -n $backups_to_delete | xargs -r rm -f
            echo -e "${GREEN}✅ 已清理 $backups_to_delete 个旧备份文件${NC}"
        else
            echo -e "${GREEN}✅ 当前备份数量 ($backup_count) 未超过限制 ($max_backups)${NC}"
        fi
    else
        echo -e "${RED}❌ 备份失败！${NC}"
        echo -e "${BLUE}正在启动服务...${NC}"
        systemctl start teamspeak.service
    fi
}

# 卸载TeamSpeak服务器
uninstall_teamspeak() {
    echo "=============================================="
    echo -e "${RED}${BOLD}⚠️  卸载TeamSpeak服务器${NC}"
    echo "=============================================="
    echo -e "${RED}警告：此操作将永久删除TeamSpeak服务器及其所有数据！${NC}"
    echo ""
    echo -e "将执行以下操作："
    echo -e "  1. 停止TeamSpeak服务"
    echo -e "  2. 禁用开机自启"
    echo -e "  3. 删除systemd服务文件"
    echo -e "  4. 删除用户 '$TS_USER' 及其主目录"
    echo -e "  5. 删除所有相关数据和配置"
    echo ""
    
    # 询问用户是否要备份数据
    read -p "是否先备份数据？(y/N): " -n 1 -r
    echo
    if [[ \$REPLY =~ ^[Yy]$ ]]; then
        backup_server
        echo ""
    fi
    
    # 二次确认卸载
    read -p "确定要卸载TeamSpeak服务器吗？(y/N): " -n 1 -r
    echo
    if [[ ! \$REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}卸载已取消${NC}"
        return 0
    fi
    
    echo -e "${BLUE}正在停止服务...${NC}"
    systemctl stop teamspeak.service >/dev/null 2>&1
    
    echo -e "${BLUE}正在禁用开机自启...${NC}"
    systemctl disable teamspeak.service >/dev/null 2>&1
    
    echo -e "${BLUE}正在删除systemd服务文件...${NC}"
    rm -f /etc/systemd/system/teamspeak.service >/dev/null 2>&1
    systemctl daemon-reload >/dev/null 2>&1
    
    echo -e "${BLUE}正在删除用户 '$TS_USER' 及其数据...${NC}"
    userdel -r "$TS_USER" >/dev/null 2>&1
    
    echo -e "${BLUE}正在删除管理脚本...${NC}"
    rm -f "$(dirname "$0")/manage-teamspeak.sh" >/dev/null 2>&1
    
    echo -e "${GREEN}✅ TeamSpeak服务器已成功卸载${NC}"
    echo ""
    echo -e "如需重新安装，请运行：${CYAN}sudo bash install-teamspeak.sh${NC}"
    echo ""
    read -p "按 Enter 键继续..." -n 1 -r
    echo
    return 0
}

# 主循环
while true; do
    show_menu
    read -p "请选择操作 (0-12): " choice
    
    case $choice in
        1)
            echo -e "${BLUE}正在启动服务...${NC}"
            systemctl start teamspeak.service
            sleep 2
            systemctl is-active teamspeak.service >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✅ 服务已启动${NC}"
            else
                echo -e "${RED}❌ 服务启动失败${NC}"
            fi
            ;;
        2)
            echo -e "${BLUE}正在停止服务...${NC}"
            systemctl stop teamspeak.service
            sleep 2
            systemctl is-active teamspeak.service >/dev/null 2>&1
            if [ $? -ne 0 ]; then
                echo -e "${GREEN}✅ 服务已停止${NC}"
            else
                echo -e "${RED}❌ 服务停止失败${NC}"
            fi
            ;;
        3)
            echo -e "${BLUE}正在重启服务...${NC}"
            systemctl restart teamspeak.service
            sleep 2
            systemctl is-active teamspeak.service >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✅ 服务已重启${NC}"
            else
                echo -e "${RED}❌ 服务重启失败${NC}"
            fi
            ;;
        4)
            echo "=============================================="
            echo -e "${CYAN}服务状态${NC}"
            echo "=============================================="
            systemctl status teamspeak.service --no-pager -l
            ;;
        5)
            echo "=============================================="
            echo -e "${CYAN}实时日志 (按Ctrl+C退出)${NC}"
            echo "=============================================="
            journalctl -u teamspeak.service -f
            ;;
        6)
            echo "=============================================="
            echo -e "${CYAN}服务器日志${NC}"
            echo "=============================================="
            local log_file=$(find "$TS_INSTALL_DIR/logs" -name "ts3server_*.log" 2>/dev/null | sort -r | head -1)
            if [[ -n "$log_file" ]]; then
                tail -50 "$log_file"
            else
                echo -e "${YELLOW}日志文件不存在${NC}"
            fi
            ;;
        7)
            show_credentials
            ;;
        8)
            show_connection_info
            ;;
        9)
            systemctl enable teamspeak.service
            echo -e "${GREEN}✅ 已启用开机自启${NC}"
            ;;
        10)
            systemctl disable teamspeak.service
            echo -e "${GREEN}✅ 已禁用开机自启${NC}"
            ;;
        11)
            get_token_from_logs
            ;;
        12)
            backup_server
            ;;
        13)
            uninstall_teamspeak
            ;;
        0)
            echo -e "${GREEN}退出管理工具${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选择，请重新输入${NC}"
            ;;
    esac
    
    echo ""
    read -p "按 Enter 键继续..."
done
EOF
    
    chmod +x "$TS_DIR/manage-teamspeak.sh"
    print_success "管理脚本创建完成: $TS_DIR/manage-teamspeak.sh"
}

# 显示最终完成信息
show_final_completion() {
    clear
    print_divider
    echo "      🎉 TeamSpeak 3 部署完成！"
    print_divider
    echo ""
    print_success "✅ 所有步骤已完成！"
    echo ""
    
    print_info "📊 部署摘要："
    echo "  ✓ TeamSpeak 版本: $TS_VERSION"
    echo "  ✓ 安装目录: $TS_INSTALL_DIR"
    echo "  ✓ 运行用户: $TS_USER"
    echo "  ✓ 服务状态: $(systemctl is-active teamspeak.service)"
    echo "  ✓ 开机自启: $(systemctl is-enabled teamspeak.service 2>/dev/null && echo '已启用' || echo '未启用')"
    echo ""
    
    print_info "🌐 连接信息："
    echo "  服务器地址: $SERVER_IP"
    echo "  语音端口: 9987 (UDP)"
    echo "  查询端口: 10011 (TCP)"
    echo "  文件端口: 30033 (TCP)"
    echo ""
    
    print_info "🔑 管理员凭证："
    echo "  已保存到: $CREDENTIALS_FILE"
    echo "  查看命令: cat $CREDENTIALS_FILE"
    echo ""
    
    print_info "⚙️  管理命令："
    echo "  启动/停止/重启: sudo systemctl start|stop|restart teamspeak"
    echo "  查看状态: sudo systemctl status teamspeak"
    echo "  查看日志: sudo journalctl -u teamspeak -f"
    echo "  使用管理工具: sudo bash $TS_DIR/manage-teamspeak.sh"
    echo ""
    
    print_info "📱 客户端连接步骤："
    echo "  1. 下载TeamSpeak客户端: https://www.teamspeak.com/en/downloads/"
    echo "  2. 连接服务器: $SERVER_IP:9987"
    echo "  3. 使用保存的Token获取管理员权限"
    echo ""
    
    print_warning "⚠️  重要提醒："
    echo "  请务必将管理员Token保存到安全的地方！"
    echo "  此Token只能使用一次，是获取管理员权限的唯一凭证。"
    echo ""
    
    print_divider
    print_success "🎊 恭喜！您的TeamSpeak服务器已准备就绪！"
    print_divider
}

# 主函数
main() {
    check_root
    get_server_ip
    show_welcome
    confirm_continue
    
    print_info "开始部署 TeamSpeak 3 服务器..."
    echo ""
    
    update_system
    echo ""
    
    create_user
    echo ""
    
    install_teamspeak
    echo ""
    
    configure_firewall
    echo ""
    
    create_service
    echo ""
    
    start_service_and_get_token
    echo ""
    
    display_and_save_token
    echo ""
    
    create_management_script
    echo ""
    
    show_final_completion
}

# 异常处理
trap 'print_error "脚本被用户中断"; exit 1' INT TERM

# 运行主函数
main "$@"