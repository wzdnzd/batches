## 注意事项

本仓库中的脚本主要是 Windows `cmd`/`bat` 脚本。若直接从 GitHub 下载单个 `.cmd` 文件后出现闪退、乱码、`is not recognized as an internal or external command`、`The syntax of the command is incorrect` 等问题，请优先检查文件换行格式是否为 `CRLF`。

将脚本改为 `CRLF` 的常用方法：

1. **VS Code**
   - 打开脚本文件，例如 `blash.cmd`。
   - 点击右下角状态栏中的 `LF`。
   - 在弹出的菜单中选择 `CRLF`。
   - 保存文件后重新运行脚本。

2. **Windows 记事本**
   - 右键脚本文件，选择 `打开方式` -> `记事本`。
   - 不修改内容，直接选择 `文件` -> `另存为`。
   - 将文件名保持为原来的 `.cmd` 文件名，例如 `blash.cmd`。
   - `保存类型` 选择 `所有文件 (*.*)`，避免保存成 `.txt`。
   - 点击 `保存` 并覆盖原文件后重新运行脚本。

3. **Notepad++**
   - 打开脚本文件。
   - 菜单选择 `编辑` -> `文档格式转换` -> `转换为 Windows (CR LF) 格式`。
   - 保存文件后重新运行脚本。

4. **PowerShell**
   - 在脚本所在目录执行：

     ```powershell
     $path = ".\blash.cmd"
     $content = Get-Content -LiteralPath $path -Raw
     $content = $content -replace "`r?`n", "`r`n"
     Set-Content -LiteralPath $path -Value $content -NoNewline -Encoding UTF8
     ```

5. **Git**
   - 如果是通过 `git clone` 获取仓库，可执行：

     ```bash
     git config core.autocrlf true
     git checkout -- .
     ```

## 工具列表

### 1. [blash.cmd](https://github.com/wzdnzd/batches/blob/main/blash.cmd)

> 基于 [Clash](https://github.com/zhongfly/Clash-premium-backup/releases) 或 [Mihomo](https://github.com/MetaCubeX/mihomo) 的网络代理命令行管理工具

使用方法：blash.cmd [功能选项] [其他参数]，支持 `-` 和 `--` 两种模式



功能选项

| 短参数 | 长参数       | 功能                                                             |
| ------ | ------------ | ---------------------------------------------------------------- |
| `-f`   | `--fix`      | 检查并尝试修复代理网络                                           |
| `-h`   | `--help`     | 打印帮助信息                                                     |
| `-i`   | `--init`     | 利用 `--conf` 提供的配置文件或订阅地址创建代理网络               |
| `-k`   | `--kill`     | 退出网络代理程序                                                 |
| `-o`   | `--overload` | 重新加载配置文件                                                 |
| `-p`   | `--purge`    | 关闭系统代理并禁止程序开机自启，取消自动更新                     |
| `-r`   | `--restart`  | 重启网络代理程序                                                 |
| `-t`   | `--test`     | 测试代理网络是否可用                                             |
| `-u`   | `--update`   | 更新所有组件，包括 clash.exe、订阅、代理规则以及 IP 地址数据库等 |

其他参数

| 短参数 | 长参数         | 功能                                                                                                        |
| ------ | -------------- | ----------------------------------------------------------------------------------------------------------- |
| `-a`   | `--alpha`      | 是否允许使用预览版，默认为稳定版，搭配 `-i` 或者 `-u` 使用                                                  |
| `-b`   | `--brief`      | 精简模式运行，没有明确配置 dashboard 情况下，无法使用可视化页面                                             |
| `-c`   | `--conf`       | 配置文件，支持本地配置文件和订阅链接，默认为当前目录下的 `config.yaml`                                      |
| `-d`   | `--daemon`     | 后台静默执行，禁止打印日志                                                                                  |
| `-e`   | `--exclude`    | 更新时跳过代理集中配置的订阅                                                                                |
| `-g`   | `--generate`   | 重新生成自动检查更新的脚本，搭配 `-u` 使用                                                                  |
| `-m`   | `--meta`       | 如果配置兼容，使用 [mihomo](https://github.com/MetaCubeX/mihomo) 代替 clash.premium，搭配 `-i` 或 `-u` 使用 |
| `-n`   | `--native`     | 强制使用 clash.premium，搭配 `-i` 或 `-u` 使用                                                              |
| `-q`   | `--quick`      | 仅更新新订阅和代理规则，搭配 `-u` 使用                                                                      |
| `-s`   | `--show`       | 新窗口中执行，默认为当前窗口                                                                                |
| `-v`   | `--verne`      | 强制使用 [vernesong/mihomo](https://github.com/vernesong/mihomo) 内核，搭配 `-i` 或 `-u` 使用               |
| `-w`   | `--workspace`  | 代理程序运行路径，默认为当前脚本所在目录                                                                    |
| `-x`   | `--metacubexd` | 使用 [metacubexd](https://github.com/MetaCubeX/metacubexd) 控制面板，搭配 `-i` 或 `-u` 使用                 |
| `-y`   | `--yacd`       | 使用 [yacd](https://github.com/MetaCubeX/Yacd-meta) 控制面板，搭配 `-i` 或 `-u` 使用                        |
| `-z`   | `--zashboard`  | 使用 [zashboard](https://github.com/Zephyruso/zashboard) 控制面板，搭配 `-i` 或 `-u` 使用                   |



### 2. [copilot-agent.cmd](https://github.com/wzdnzd/batches/blob/main/copilot-agent.cmd)

> 基于 [override](https://github.com/linux-do/override) 和 [cocopilot](https://cocopilot.org/dash) 实现的 [Github Copilot](https://github.com/features/copilot) Agent 命令行管理工具

使用方法：copilot-agent.cmd [功能选项] [其他参数]，支持 `-` 和 `--` 两种模式



功能选项

| 短参数 | 长参数      | 功能                                                                                                            |
| ------ | ----------- | --------------------------------------------------------------------------------------------------------------- |
| `-e`   | `--env`     | 设置环境变量，配合 `-a`、`-b` 以及 `-l` 使用                                                                    |
| `-g`   | `--github`  | 打印 [override 项目](https://github.com/linux-do/override) 及 [cocopilot 平台](https://cocopilot.org/dash) 地址 |
| `-h`   | `--help`    | 打印帮助信息                                                                                                    |
| `-p`   | `--purge`   | 禁止服务开机自启、自动更新及环境变量设置等                                                                      |
| `-q`   | `--quit`    | 退出服务                                                                                                        |
| `-r`   | `--restart` | 重启服务                                                                                                        |
| `-s`   | `--start`   | 启动服务                                                                                                        |
| `-u`   | `--update`  | 检查并更新 `override.exe` 可执行程序                                                                            |

其他参数

| 短参数 | 长参数          | 功能                                                  |
| ------ | --------------- | ----------------------------------------------------- |
| `-a`   | `--all`         | 为所有用户设置环境变量，默认只对当前用户有效          |
| `-b`   | `--base`        | 接口地址，默认为 `https://cocopilot.org`              |
| `-d`   | `--display`     | 前台运行，默认启动守护进程静默执行                    |
| `-f`   | `--filename`    | 可执行程序文件名，默认为 `override.exe`               |
| `-i`   | `--interactive` | 新窗口中执行，不隐藏窗口                              |
| `-l`   | `--link`        | API 接口子路径，默认为空                              |
| `-w`   | `--workspace`   | `override.exe` 所在文件夹路径，默认为当前脚本所在目录 |

### 3. [sbctl.cmd](https://github.com/wzdnzd/batches/blob/main/sbctl.cmd)

> 基于 [sing-box](https://github.com/wzdnzd/sing-box)（支持节点订阅、重载配置、重启服务以及 `Load-Balance` 等策略） 的网络代理命令行管理工具

使用方法：sbctl.cmd [功能选项] [其他参数]，支持 `-` 和 `--` 两种模式

功能选项

| 短参数 | 长参数      | 功能               |
| ------ | ----------- | ------------------ |
| `-f`   | `--fix`     | 检查并修复代理网络 |
| `-h`   | `--help`    | 显示帮助信息       |
| `-i`   | `--init`    | 初始化代理网络     |
| `-k`   | `--kill`    | 停止代理程序       |
| `-o`   | `--reload`  | 重新加载配置文件   |
| `-p`   | `--purge`   | 清理所有设置       |
| `-r`   | `--restart` | 重启代理程序       |
| `-t`   | `--test`    | 测试网络连接       |
| `-u`   | `--update`  | 更新所有组件       |

其他参数

| 短参数 | 长参数        | 功能                   |
| ------ | ------------- | ---------------------- |
| `-c`   | `--conf`      | 指定配置文件或订阅链接 |
| `-d`   | `--daemon`    | 后台运行               |
| `-e`   | `--exclude`   | 跳过订阅更新           |
| `-g`   | `--generate`  | 重新生成更新脚本       |
| `-s`   | `--show`      | 显示窗口               |
| `-w`   | `--workspace` | 指定工作目录           |

### 4. [weasel-manager.cmd](https://github.com/wzdnzd/batches/blob/main/weasel-manager.cmd)

> [小狼毫 Weasel](https://github.com/rime/weasel) 输入法安装、更新、卸载和 Rime 配置同步命令行管理工具

使用方法：

```bat
weasel-manager.cmd install --dir <install-dir> --stable
weasel-manager.cmd install --dir <install-dir> --beta
weasel-manager.cmd install --dir <install-dir> --version <version>
weasel-manager.cmd install --dir <install-dir> --installer <installer.exe>
weasel-manager.cmd update
weasel-manager.cmd update --stable
weasel-manager.cmd update --beta
weasel-manager.cmd update --version <version>
weasel-manager.cmd uninstall
weasel-manager.cmd sync
weasel-manager.cmd sync --data-dir <rime-user-dir>
weasel-manager.cmd sync --dir <install-dir> --data-dir <rime-user-dir>
```

功能命令

| 命令        | 功能                                                     |
| ----------- | -------------------------------------------------------- |
| `install`   | 安装小狼毫，可从稳定版、测试版、指定版本或本地安装包安装 |
| `update`    | 更新小狼毫，可使用稳定版、测试版或指定版本               |
| `uninstall` | 卸载小狼毫                                               |
| `sync`      | 同步或更新 Rime 用户配置仓库                             |

参数

| 参数                   | 功能                                          |
| ---------------------- | --------------------------------------------- |
| `--dir PATH`           | 小狼毫程序安装目录                            |
| `--installer PATH`     | 本地安装包路径                                |
| `--version VALUE`      | 安装或更新到指定版本                          |
| `--channel VALUE`      | 指定通道，取值为 `stable` 或 `beta`           |
| `--7z PATH`            | 指定 `7z.exe` 路径                            |
| `--data-dir PATH`      | Rime 用户数据目录或配置仓库根目录             |
| `--rime-dir PATH`      | `--data-dir` 的别名                           |
| `--force`              | 允许使用非空且不像小狼毫目录的目标目录        |
| `--nostart`            | 安装或更新后不启动服务                        |
| `--yes`                | 卸载时不再询问确认                            |
| `--purge`              | 卸载时同时删除保留的用户数据目录              |
| `--admin-window VALUE` | 设置提权窗口显示方式，取值为 `show` 或 `hide` |

