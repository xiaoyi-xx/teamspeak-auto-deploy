# TeamSpeak 3 一体化自动部署脚本

这是一个用于快速部署 TeamSpeak 3 服务器的自动化脚本，支持 CentOS/RHEL 系统。脚本会自动完成从系统更新到服务启动的所有步骤，并帮助用户记录管理员 Token。

## 功能特性

- ✅ 自动更新系统并安装必要工具
- ✅ 创建专用用户运行 TeamSpeak
- ✅ 下载并安装 TeamSpeak 服务器
- ✅ 配置防火墙规则
- ✅ 创建 systemd 服务
- ✅ 首次启动服务并提取管理员 Token
- ✅ 保存凭证到文件
- ✅ 创建管理脚本，方便后续管理
- ✅ 详细的彩色输出和用户交互
- ✅ 支持开机自启

## 系统要求

- 操作系统：CentOS/RHEL 7+ 或其他使用 yum 包管理器的 Linux 发行版
- 架构：x86_64 (amd64)
- 权限：需要 root 权限
- 网络：能够访问互联网以上传和下载文件

## 使用方法

### 1. 下载脚本

```bash
git clone https://github.com/xiaoyi-xx/teamspeak-auto-deploy.git
cd teamspeak-auto-deploy
chmod +x install-teamspeak.sh
```

### 2. 运行脚本

```bash
sudo bash install-teamspeak.sh
```

### 3. 按照提示操作

脚本会引导您完成整个部署过程，包括：
- 确认继续安装
- 等待服务启动
- 记录管理员 Token
- 确认已保存 Token

### 4. 连接到服务器

部署完成后，您可以使用 TeamSpeak 客户端连接到您的服务器：
- 服务器地址：您的服务器 IP
- 端口：9987 (UDP)
- 使用脚本提供的管理员 Token 获取管理员权限

## 管理脚本

脚本会创建一个管理脚本，方便您后续管理 TeamSpeak 服务器：

```bash
sudo bash /home/teamspeak/manage-teamspeak.sh
```

管理脚本功能包括：
- 启动/停止/重启服务
- 查看服务状态
- 查看实时日志
- 查看服务器日志
- 查看管理员凭证
- 查看连接信息
- 启用/禁用开机自启
- 从日志提取 Token
- 备份服务器数据

## 手动管理命令

如果您不使用管理脚本，也可以使用以下命令手动管理服务：

```bash
# 启动服务
sudo systemctl start teamspeak

# 停止服务
sudo systemctl stop teamspeak

# 重启服务
sudo systemctl restart teamspeak

# 查看状态
sudo systemctl status teamspeak

# 查看日志
sudo journalctl -u teamspeak -f

# 启用开机自启
sudo systemctl enable teamspeak

# 禁用开机自启
sudo systemctl disable teamspeak
```

## 配置文件

- TeamSpeak 安装目录：`/home/teamspeak/teamspeak3-server`
- 管理员凭证文件：`/home/teamspeak/teamspeak_credentials.txt`
- Systemd 服务文件：`/etc/systemd/system/teamspeak.service`
- 管理脚本：`/home/teamspeak/manage-teamspeak.sh`

## 端口说明

TeamSpeak 服务器需要开放以下端口：

| 端口 | 协议 | 用途 |
|------|------|------|
| 9987 | UDP | 语音通信 |
| 10011 | TCP | 服务器查询 |
| 30033 | TCP | 文件传输 |

## 更新日志

### v1.0.0
- 初始版本
- 支持 TeamSpeak 3.13.7
- 完整的自动化部署流程
- 创建管理脚本

## 注意事项

1. 请务必保存好管理员 Token，它是获取管理员权限的唯一凭证，且只能使用一次
2. 脚本会自动配置防火墙规则，但如果您使用云服务器，还需要在安全组中开放相应端口
3. 脚本目前只支持 CentOS/RHEL 系统，其他系统可能需要修改包管理器命令
4. 建议定期备份服务器数据，您可以使用管理脚本中的备份功能

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！

## 联系方式

如果您有任何问题或建议，请通过 GitHub Issues 联系我。
