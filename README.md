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
| `-b`   | `--brief`      | 精简模式运行，没有明确配置dashboard情况下，无法使用可视化页面                                               |
| `-c`   | `--conf`       | 配置文件，支持本地配置文件和订阅链接，默认为当前目录下的 `config.yaml`                                      |
| `-d`   | `--daemon`     | 后台静默执行，禁止打印日志                                                                                  |
| `-e`   | `--exclude`    | 更新时跳过代理集中配置的订阅                                                                                |
| `-g`   | `--generate`   | 重新生成自动检查更新的脚本，搭配 `-u` 使用                                                                  |
| `-m`   | `--meta`       | 如果配置兼容，使用 [mihomo](https://github.com/MetaCubeX/mihomo) 代替 clash.premium，搭配 `-i` 或 `-u` 使用 |
| `-n`   | `--native`     | 强制使用 clash.premium，搭配 `-i` 或 `-u` 使用                                                              |
| `-q`   | `--quick`      | 仅更新新订阅和代理规则，搭配 `-u` 使用                                                                      |
| `-s`   | `--show`       | 新窗口中执行，默认为当前窗口                                                                                |
| `-w`   | `--workspace`  | 代理程序运行路径，默认为当前脚本所在目录                                                                    |
| `-x`   | `--metacubexd` | 使用 [metacubexd](https://github.com/MetaCubeX/metacubexd) 控制面板，搭配 `-i` 或 `-u` 使用                 |
| `-y`   | `--yacd`       | 使用 [yacd](https://github.com/MetaCubeX/Yacd-meta) 控制面板，搭配 `-i` 或 `-u` 使用                        |



### 2. [copilot-agent.cmd](https://github.com/wzdnzd/batches/blob/main/copilot-agent.cmd)

> 基于 [override](https://github.com/linux-do/override) 实现的 [Github Copilot](https://github.com/features/copilot) Agent 命令行管理工具

使用方法：copilot-agent.cmd [功能选项] [其他参数]，支持 `-` 和 `--` 两种模式



功能选项

| 短参数 | 长参数      | 功能                                       |
| ------ | ----------- | ------------------------------------------ |
| `-a`   | `--address` | 打印 `override` 项目对应的 Github 地址     |
| `-h`   | `--help`    | 打印帮助信息                               |
| `-p`   | `--purge`   | 禁止服务开机自启、自动更新及环境变量设置等 |
| `-q`   | `--quit`    | 退出服务                                   |
| `-r`   | `--restart` | 重启服务                                   |
| `-s`   | `--start`   | 启动服务                                   |
| `-u`   | `--update`  | 检查并更新 `override.exe` 可执行程序       |

其他参数

| 短参数 | 长参数          | 功能                                    |
| ------ | --------------- | --------------------------------------- |
| `-d`   | `--display`     | 前台运行，默认启动守护进程静默执行      |
| `-f`   | `--filename`    | 可执行程序文件名，默认为 `override.exe` |
| `-i`   | `--interactive` | 新窗口中执行窗口，不隐藏窗口            |
| `-w`   | `--workspace`   | 服务工作路径，默认为当前脚本所在目录    |
