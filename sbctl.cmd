@REM ============================================================================
@REM Sing-Box Network Proxy Controller
@REM ============================================================================
@REM Description: Comprehensive management tool for sing-box proxy service
@REM             Supports installation, configuration, updates, and maintenance
@REM Author:      wzdnzd
@REM Date:        2025-06-05
@REM Version:     1.0
@REM Repository:  https://github.com/wzdnzd/batches
@REM ============================================================================
@echo off & PUSHD %~DP0 & cd /d "%~dp0"
chcp 65001 >nul 2>nul
setlocal enableDelayedExpansion

@REM ============================================================================
@REM CONSTANTS AND CONFIGURATION
@REM ============================================================================
@REM Application constants
set "BATCH_NAME=%~nx0"                    @REM Current script filename
set "CONFIG_FILE=config.json"             @REM Default configuration file
set "SINGBOX_EXE=sing-box.exe"           @REM Sing-box executable name
set "CRONET_DLL=libcronet.dll"            @REM Cronet native library shipped with Windows builds
set "APPLICATION_NAME=SingBox"            @REM Application registry name
set "GITHUB_REPO=wzdnzd/sing-box"       @REM GitHub repository for updates
set "DEFAULT_DASHBOARD_NAME=dashboard"   @REM Default dashboard name
set "DEFAULT_DASHBOARD_URL=https://github.com/Zephyruso/zashboard/archive/refs/heads/gh-pages.zip" @REM Default dashboard download URL
set "DEFAULT_ICON_URL=https://raw.githubusercontent.com/wzdnzd/batches/main/icons/sing-box.ico" @REM Default icon URL
set "MAX_REDOWNLOAD_ATTEMPTS=1"           @REM Max times to re-download binary after abnormal start

@REM Registry paths for system configuration
set "PROXY_REG_PATH=HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
set "AUTOSTART_REG_PATH=HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
set "STARTUP_APPROVED=HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"

@REM System directories
set "TEMP_DIR=%TEMP%"                     @REM Temporary files directory
set "CURL_BINARY=!windir!\System32\curl.exe"  @REM Windows curl, avoid Git Bash PATH
set "TAR_BINARY=!windir!\System32\tar.exe"    @REM Windows tar, avoid Git Bash PATH

@REM Initialize color support for console output
call :setESC

@REM Start main workflow
goto :workflow

@REM ============================================================================
@REM FUNCTION DEFINITIONS
@REM ============================================================================

@REM ============================================================================
@REM MAIN WORKFLOW - Entry point and variable initialization
@REM ============================================================================
:workflow
@REM Terminal type detection for proper display formatting
call :isMicrosoftTerminal ms_terminal

@REM Feature control flags
@REM Enable desktop shortcut creation
if defined SINGBOX_ENABLE_SHORTCUT (
    set "enable_shortcut=!SINGBOX_ENABLE_SHORTCUT!"
) else (
    set "enable_shortcut=1"
)

@REM Enable remote configuration updates
if defined SINGBOX_ENABLE_REMOTE_CONFIG (
    set "enable_remote_config=!SINGBOX_ENABLE_REMOTE_CONFIG!"
) else (
    set "enable_remote_config=0"
)
set "redownload_attempts=0"               @REM Times the binary has been re-downloaded after abnormal start

@REM Console color settings
set "info_color=38;2;22;198;12"
set "warn_color=38;2;249;241;165"
set "error_color=38;2;231;72;86"

@REM Operation control flags - determine which action to perform
set "should_exit=0"                       @REM Exit flag for error conditions
set "init_flag=0"                         @REM Initialize proxy network
set "test_flag=0"                         @REM Test network connectivity
set "repair_flag=0"                       @REM Repair network issues
set "reload_flag=0"                       @REM Reload configuration
set "restart_flag=0"                      @REM Restart proxy program
set "kill_flag=0"                         @REM Stop proxy program
set "update_flag=0"                       @REM Update all components
set "purge_flag=0"                        @REM Clean all settings
set "exclude_updates=0"                   @REM Exclude subscription updates
set "regenerate_scripts=0"                @REM Regenerate update scripts
set "as_daemon=0"                         @REM Run as background daemon
set "show_window=0"                       @REM Show window when running

@REM Configuration and runtime variables
set "configuration=!CONFIG_FILE!"        @REM Active configuration file path

@REM Subscription link URL
if defined SINGBOX_SUBSCRIPTION_LINK (
    set "subscription_link=!SINGBOX_SUBSCRIPTION_LINK!"
) else (
    set "subscription_link="
)
set "is_web_link=0"                       @REM Flag for web-based configuration
if "!subscription_link:~0,8!" == "https://" set "is_web_link=1"
if "!subscription_link:~0,7!" == "http://" set "is_web_link=1"

@REM Remote configuration URL
if defined SINGBOX_REMOTE_URL (
    set "remote_url=!SINGBOX_REMOTE_URL!"
) else (
    set "remote_url="
)

@REM Custom reverse proxy url
if defined SINGBOX_REVERSE_PROXY (
    set "custom_proxy_url=!SINGBOX_REVERSE_PROXY!"
) else (
    set "custom_proxy_url="
)

@REM GitHub repository for updates
if defined SINGBOX_GITHUB_REPO (
    call :validateGithubRepo "!SINGBOX_GITHUB_REPO!"
    if "!should_exit!" == "1" exit /b 1
)
set "dest="                               @REM Destination workspace directory
set "singbox_server="                     @REM Sing-box API server address

@REM Parse and validate command line arguments
call :parseArgs %*
if "!should_exit!" == "1" exit /b 1

@REM Set default workspace directory if not specified
if "!dest!" == "" set "dest=%~dp0"
call :normalizeFilePath dest "!dest!"

@REM Initialize script file paths for automation
set "startup_script=!dest!\startup.vbs"   @REM Auto-startup VBS script
set "update_script=!dest!\update.vbs"     @REM Auto-update VBS script

@REM Execute immediate operations that don't require validation
if "!kill_flag!" == "1" goto :closeProxy
if "!purge_flag!" == "1" goto :purge

@REM Check if any action flag is set
call :hasAction action_required
if "!action_required!" == "0" (
    if "!should_exit!" == "0" goto :usage
    exit /b
)

@REM Validate configuration file before proceeding
call :validateConfiguration config_file
if "!config_file!" == "" exit /b 1

@REM Execute requested operations in priority order
if "!test_flag!" == "1" (
    call :testConnection available 1
    exit /b
)
if "!reload_flag!" == "1" goto :reloadConfig
if "!restart_flag!" == "1" goto :restartProgram
if "!repair_flag!" == "1" goto :resolveIssues
if "!update_flag!" == "1" goto :updateComponents
if "!init_flag!" == "1" goto :initialize

exit /b


@REM ============================================================================
@REM Check if any action flag is set
@REM Parameters: <r> - Return variable name (0=no action, 1=action required)
@REM Returns:    Sets return variable to 1 if any operation flag is active
@REM ============================================================================
:hasAction <result>
set "%~1=0"
if "!restart_flag!" == "1" set "%~1=1"
if "!repair_flag!" == "1" set "%~1=1"
if "!reload_flag!" == "1" set "%~1=1"
if "!test_flag!" == "1" set "%~1=1"
if "!update_flag!" == "1" set "%~1=1"
if "!init_flag!" == "1" set "%~1=1"
goto :eof


@REM ============================================================================
@REM Validate and process configuration file
@REM Parameters: <r> - Return variable name for validated config file path
@REM Returns:    Sets return variable to validated config path or empty on error
@REM Purpose:    Validates config file existence, format, and downloads if URL
@REM ============================================================================
:validateConfiguration <result>
set "%~1="
set "subscription_file=!TEMP_DIR!\singbox_subscription.json"

@REM Convert relative path to absolute path and normalize
call :convertToAbsolutePath config_location "!configuration!"
call :normalizeFilePath config_location "!config_location!"

@REM Validate configuration file path
if "!config_location!" == "" (
    @echo [%ESC%[!error_color!m错误%ESC%[0m] 配置文件路径%ESC%[!error_color!m无效%ESC%[0m
    exit /b 1
)

@REM Ensure path doesn't contain whitespace (causes issues with sing-box)
if "!config_location!" NEQ "!config_location: =!" (
    @echo [%ESC%[!error_color!m错误%ESC%[0m] 无效的配置文件 "%ESC%[!warn_color!m!config_location!%ESC%[0m"， 路径不能包含%ESC%[!warn_color!m空格%ESC%[0m
    exit /b 1
)

@REM Handle web-based configuration (subscription URL)
if "!is_web_link!" == "1" (
    @REM Warn user about overwriting existing config file
    if exist "!config_location!" (
        set "tips=[%ESC%[!warn_color!m警告%ESC%[0m] %ESC%[!warn_color!m已存在%ESC%[0m配置文件 "%ESC%[!warn_color!m!config_location!%ESC%[0m" 会被%ESC%[!error_color!m覆盖%ESC%[0m，是否继续？ (%ESC%[!warn_color!mY%ESC%[0m/%ESC%[!warn_color!mN%ESC%[0m) "
        if "!ms_terminal!" == "1" (
            choice /t 6 /d n /n /m "!tips!"
        ) else (
            set /p "=!tips!" <nul
            choice /t 6 /d n /n
        )
        if !errorlevel! == 2 exit /b 1
    )

    @REM Download subscription configuration from URL
    del /f /q "!subscription_file!" >nul 2>nul

    set "status_code=000"
    for /f %%a in ('!CURL_BINARY! --retry 3 --retry-max-time 30 -m 60 --connect-timeout 30 -L -s -o "!subscription_file!" -w "%%{http_code}" -H "User-Agent: sing-box" "!subscription_link!"') do set "status_code=%%a"

    @REM Process successful download
    if "!status_code!" == "200" (
        set "file_size=0"
        if exist "!subscription_file!" (for %%a in ("!subscription_file!") do set "file_size=%%~za")
        if !file_size! GTR 64 (
            @REM Validate downloaded file contains valid sing-box configuration
            set "content="
            for /f "tokens=*" %%a in ('findstr /i /r /c:"\"external_controller\"[ ]*:[ ]*\".*:[0-9][0-9]*\"" !subscription_file!') do set "content=%%a"
            if "!content!" == "" (
                @echo [%ESC%[!error_color!m错误%ESC%[0m] 订阅 "%ESC%[!warn_color!m!subscription_link!%ESC%[0m" 无效，请检查确认
                exit /b 1
            )

            @REM Create destination directory and move config file
            del /f /q "!config_location!" >nul 2>nul
            call :splitPath file_path file_name "!config_location!"
            call :createDirectories success "!file_path!"
            if "!success!" == "0" (
                @echo [%ESC%[!error_color!m错误%ESC%[0m] 创建文件夹 "%ESC%[!warn_color!m!file_path!%ESC%[0m" %ESC%[!error_color!m失败%ESC%[0m，请确认路径是否合法
                exit /b 1
            )

            move "!subscription_file!" "!config_location!" >nul 2>nul
            @echo [%ESC%[!info_color!m信息%ESC%[0m] 订阅下载%ESC%[!info_color!m成功%ESC%[0m

            @REM Save subscription URL for future updates
            @echo !subscription_link! > "!file_path!\subscriptions.txt"
        ) else (
            @REM Downloaded file is too small, likely empty or error page
            set "status_code=000"
        )
    )

    @REM Handle download failure
    if "!status_code!" NEQ "200" (
        @echo [%ESC%[!error_color!m错误%ESC%[0m] 订阅下载%ESC%[!error_color!m失败%ESC%[0m， 请检查确认此订阅是否有效
        exit /b 1
    )
)

@REM Verify local configuration file exists
if not exist "!config_location!" (
    @echo [%ESC%[!error_color!m错误%ESC%[0m] 配置文件 "%ESC%[!warn_color!m!config_location!%ESC%[0m" %ESC%[!error_color!m不存在%ESC%[0m
    goto :eof
)

@REM Validate configuration file format (must contain outbounds section)
set "content="
for /f "tokens=*" %%a in ('findstr /i /r /c:"\"outbounds\"[ ]*:[ ]*\[" "!config_location!"') do set "content=%%a"
if "!content!" == "" (
    @echo [%ESC%[!error_color!m错误%ESC%[0m] %ESC%[!error_color!m无效%ESC%[0m的配置文件 "%ESC%[!warn_color!m!config_location!%ESC%[0m"
    exit /b 1
)

@REM Return validated configuration file path
set "%~1=!config_location!"
goto :eof


@REM ============================================================================
@REM Initialize network proxy system
@REM Purpose:    First-time setup of sing-box proxy with user confirmation
@REM Parameters: None
@REM Returns:    Calls updateComponents to download and configure everything
@REM ============================================================================
:initialize
set "tips=[%ESC%[!warn_color!m提示%ESC%[0m] 网络代理程序将在目录 "%ESC%[!warn_color!m!dest!%ESC%[0m" 安装并运行，是否继续？(%ESC%[!warn_color!mY%ESC%[0m/%ESC%[!warn_color!mN%ESC%[0m) "
if "!ms_terminal!" == "1" (
    choice /t 5 /d n /n /m "!tips!"
) else (
    set /p "=!tips!" <nul
    choice /t 5 /d n /n
)
if !errorlevel! == 2 exit /b 1

set "exclude_updates=1"
call :updateComponents
goto :eof


@REM ============================================================================
@REM Diagnose and repair network proxy issues
@REM Purpose:    Interactive troubleshooting for proxy connectivity problems
@REM Parameters: None
@REM Returns:    Attempts to fix issues and reports success/failure
@REM ============================================================================
:resolveIssues
@echo [%ESC%[!info_color!m信息%ESC%[0m] 开始检查并尝试修复网络代理，请稍等

@REM Test current proxy status before attempting repairs
call :testConnection available 0
set "lazy_check=0"
if "!available!" == "1" (
    @REM Proxy is working, confirm user wants to continue anyway
    set "tips=[%ESC%[!warn_color!m提示%ESC%[0m] 代理网络运行%ESC%[!info_color!m正常%ESC%[0m，%ESC%[!error_color!m不存在%ESC%[0m问题，是否继续？(%ESC%[!warn_color!mY%ESC%[0m/%ESC%[!warn_color!mN%ESC%[0m) "
    if "!ms_terminal!" == "1" (
        choice /t 5 /d n /n /m "!tips!"
    ) else (
        set /p "=!tips!" <nul
        choice /t 5 /d n /n
    )
    if !errorlevel! == 2 exit /b 1
) else (
    @REM Check if process is running but network is still unavailable
    call :isProcessRunning status
    if "!status!" == "0" (
        call :checkNetworkWrapper continue 1
        if "!continue!" == "0" exit /b
    ) else set "lazy_check=1"
)

@REM Present repair options: Reload, Restart, Update/restore, or Cancel
set "tips=[%ESC%[!warn_color!m提示%ESC%[0m] 按 %ESC%[!warn_color!mO%ESC%[0m %ESC%[!warn_color!m重载%ESC%[0m，按 %ESC%[!warn_color!mR%ESC%[0m %ESC%[!warn_color!m重启%ESC%[0m，按 %ESC%[!warn_color!mU%ESC%[0m %ESC%[!warn_color!m恢复%ESC%[0m至默认，按 %ESC%[!warn_color!mN%ESC%[0m %ESC%[!rncolor!m取消%ESC%[0m (%ESC%[!warn_color!mO%ESC%[0m/%ESC%[!warn_color!mR%ESC%[0m/%ESC%[!warn_color!mU%ESC%[0m/%ESC%[!warn_color!mN%ESC%[0m) "
if "!ms_terminal!" == "1" (
    choice /t 6 /c ORUN /d R /n /m "!tips!"
) else (
    set /p "=!tips!" <nul
    choice /t 6 /c ORUN /d R /n
)

@REM Execute selected repair action
if !errorlevel! == 1 (
    @REM Option R: Reload the proxy configuration
    call :reloadConfig
) else if !errorlevel! == 2 (
    @REM Option R: Restart the proxy program
    call :restartProgram
) else if !errorlevel! == 3 (
    @REM Option U: Update/restore components to default state
    call :killProcessWrapper

    @REM Perform network check if process was running
    if "!lazy_check!" == "1" (
        call :checkNetworkWrapper continue 0
        if "!continue!" == "0" exit /b
    )

    @REM Download and restore all components
    call :updateComponents
) else (
    @REM Option N: Cancel repair operation
    exit /b
)

@REM Verify repair was successful by testing connectivity multiple times
for /l %%i in (1,1,5) do (
    call :testConnection available 0
    if "!available!" == "1" (
        @echo [%ESC%[!info_color!m信息%ESC%[0m] 问题修复%ESC%[!info_color!m成功%ESC%[0m，网络代理可%ESC%[!info_color!m正常%ESC%[0m使用
        exit /b
    ) else (
        @REM Wait before next test attempt
        timeout /t 1 /nobreak >nul 2>nul
    )
)

@REM Report repair failure after all attempts
@echo [%ESC%[!error_color!m错误%ESC%[0m] 问题修复%ESC%[!error_color!m失败%ESC%[0m， 网络代理仍%ESC%[!error_color!m无法%ESC%[0m使用， 请尝试其他方法
goto :eof


@REM ============================================================================
@REM Check basic network connectivity wrapper
@REM Parameters: <r> - Return variable (0=should terminate, 1=continue)
@REM            <enable> - Log level (0=silent, 1=verbose)
@REM Returns:    Network availability status and recommendations
@REM ============================================================================
:checkNetworkWrapper <result> <enable>
set "%~1=1"
call :trim log_level "%~2"
if "!log_level!" == "" set "log_level=1"

@REM Test basic network connectivity without proxy
call :checkNetworkAvailable available 0 "https://www.baidu.com" ""
if "!available!" == "0" (
    @echo [%ESC%[!error_color!m错误%ESC%[0m] 网络%ESC%[!error_color!m不可用%ESC%[0m， 但代理程序%ESC%[!error_color!m并未运行%ESC%[0m，请检查你的%ESC%[!warn_color!m本地网络%ESC%[0m是否正常

    @REM Signal that operation should terminate
    set "%~1=0"
    exit /b
)

@REM Provide user guidance if logging is enabled
if "!log_level!" == "1" (
    @echo [%ESC%[!warn_color!m提示%ESC%[0m] 网络代理%ESC%[!error_color!m没有开启%ESC%[0m， 推荐选择 %ESC%[!warn_color!mRestart%ESC%[0m 开启
)
goto :eof


@REM ============================================================================
@REM Update all components workflow
@REM Purpose:    Downloads and updates sing-box, dashboard, and configurations
@REM Parameters: None
@REM Returns:    Updates all components and starts the proxy service
@REM ============================================================================
:updateComponents
@REM Request administrator privileges if running as daemon
if "!as_daemon!" == "1" (
    cacls "%SystemDrive%\System Volume Information" >nul 2>&1 || (
        if "!show_window!" == "1" (
            powershell.exe -NoLogo -NoProfile -Command "Start-Process '%~snx0' -ArgumentList ' %*' -Verb RunAs"
        ) else (
            powershell.exe -NoLogo -NoProfile -Command "Start-Process '%~snx0' -ArgumentList ' %*' -Verb RunAs -WindowStyle Hidden"
        )
        exit /b
    )
)

@REM Download and prepare all required components
call :prepare changed

@REM Report update status to user
if "!changed!" == "0" (
    @echo [%ESC%[!info_color!m信息%ESC%[0m] 当前已是最新版本，无需更新
) else (
    @REM Allow time for file operations to complete
    timeout /t 1 /nobreak >nul 2>nul
)

@REM Clean up temporary files and directories
call :cleanWorkspace "!TEMP_DIR!"

@REM Start the sing-box proxy service
call :startSingbox

@REM Regenerate auto-update script if requested
if "!regenerate_scripts!" == "1" call :generateUpdateVbs

goto :eof


@REM ============================================================================
@REM Parse and validate command line arguments
@REM Purpose:    Processes all command line options and sets appropriate flags
@REM Parameters: All command line arguments (%*)
@REM Returns:    Sets global flags based on parsed arguments
@REM ============================================================================
:parseArgs
set "result=false"

@REM Configuration file or subscription
if "%1" == "-c" set "result=true"
if "%1" == "--conf" set "result=true"
if "!result!" == "true" (
    call :validateConfArg "%~2"
    if "!should_exit!" == "1" goto :eof
    shift & shift & goto :parseArgs
)

@REM Daemon mode
if "%1" == "-d" set "result=true"
if "%1" == "--daemon" set "result=true"
if "!result!" == "true" (
    set "as_daemon=1"
    set "result=false"
    shift & goto :parseArgs
)

@REM Exclude subscription updates
if "%1" == "-e" set "result=true"
if "%1" == "--exclude" set "result=true"
if "!result!" == "true" (
    set "exclude_updates=1"
    set "result=false"
    shift & goto :parseArgs
)

@REM Fix/repair mode
if "%1" == "-f" set "result=true"
if "%1" == "--fix" set "result=true"
if "!result!" == "true" (
    set "repair_flag=1"
    set "result=false"
    shift & goto :parseArgs
)

@REM Generate update script
if "%1" == "-g" set "result=true"
if "%1" == "--generate" set "result=true"
if "!result!" == "true" (
    set "regenerate_scripts=1"
    set "result=false"
    shift & goto :parseArgs
)

@REM Help
if "%1" == "-h" set "result=true"
if "%1" == "--help" set "result=true"
if "!result!" == "true" call :usage

@REM Initialize
if "%1" == "-i" set "result=true"
if "%1" == "--init" set "result=true"
if "!result!" == "true" (
    set "init_flag=1"
    set "result=false"
    shift & goto :parseArgs
)

@REM Kill/stop
if "%1" == "-k" set "result=true"
if "%1" == "--kill" set "result=true"
if "!result!" == "true" (
    set "kill_flag=1"
    set "result=false"
    shift & goto :parseArgs
)

@REM Reload configuration
if "%1" == "-o" set "result=true"
if "%1" == "--reload" set "result=true"
if "!result!" == "true" (
    set "reload_flag=1"
    set "result=false"
    shift & goto :parseArgs
)

@REM Purge
if "%1" == "-p" set "result=true"
if "%1" == "--purge" set "result=true"
if "!result!" == "true" (
    set "purge_flag=1"
    set "result=false"
    shift & goto :parseArgs
)

@REM Start/Restart
if "%1" == "-r" set "result=true"
if "%1" == "--restart" set "result=true"
if "!result!" == "true" (
    set "restart_flag=1"
    set "result=false"
    shift & goto :parseArgs
)

@REM Show window
if "%1" == "-s" set "result=true"
if "%1" == "--show" set "result=true"
if "!result!" == "true" (
    set "show_window=1"
    set "result=false"
    shift & goto :parseArgs
)

@REM Test connectivity
if "%1" == "-t" set "result=true"
if "%1" == "--test" set "result=true"
if "!result!" == "true" (
    set "test_flag=1"
    set "result=false"
    shift & goto :parseArgs
)

@REM Update
if "%1" == "-u" set "result=true"
if "%1" == "--update" set "result=true"
if "!result!" == "true" (
    set "update_flag=1"
    set "result=false"
    shift & goto :parseArgs
)

@REM Workspace directory
if "%1" == "-w" set "result=true"
if "%1" == "--workspace" set "result=true"
if "!result!" == "true" (
    call :validateWorkspaceArg "%~2"
    if "!should_exit!" == "1" goto :eof
    shift & shift & goto :parseArgs
)

@REM End of arguments
if "%1" == "" goto :eof

@REM Handle special goto syntax or unknown arguments
if "%1" NEQ "" (
    call :trim syntax "%~1"
    if "!syntax!" == "goto" (
        call :handleGotoSyntax "%~2" "%*"
        exit /b
    )

    @echo [%ESC%[!error_color!m错误%ESC%[0m] 未知参数：%ESC%[!error_color!m%1%ESC%[0m
    @echo.
    goto :usage
)

goto :eof


@REM ============================================================================
@REM Validate configuration argument from command line
@REM Parameters: <subscription> - Configuration file path or subscription URL
@REM Purpose:    Validates and processes --conf parameter input
@REM Process:    Checks format, determines if URL or file, validates accordingly
@REM ============================================================================
:validateConfArg <subscription>
call :trim subscription "%~1"
if "!subscription!" == "" goto :invalidConfArg
if "!subscription:~0,2!" == "--" goto :invalidConfArg
if "!subscription:~0,1!" == "-" goto :invalidConfArg

@REM Check if it's a URL; CLI --conf always overrides env-derived is_web_link
set "is_web_link=0"
if "!subscription:~0,8!" == "https://" set "is_web_link=1"
if "!subscription:~0,7!" == "http://" set "is_web_link=1"

if "!is_web_link!" == "1" (
    call :validateUrl "!subscription!"
) else (
    call :validateConfigFile "!subscription!"
)
goto :eof


@REM ============================================================================
@REM Handle invalid configuration argument error
@REM Purpose:    Displays error message and shows usage when --conf is invalid
@REM ============================================================================
:invalidConfArg
@echo [%ESC%[!error_color!m错误%ESC%[0m] 参数 "%ESC%[!warn_color!m--conf%ESC%[0m" 需要有效的配置文件或订阅链接
@echo.
goto :usage


@REM ============================================================================
@REM Validate workspace directory argument from command line
@REM Parameters: <param> - Workspace directory path
@REM Purpose:    Validates and processes --workspace parameter input
@REM Process:    Checks path validity, creates if needed, sets dest variable
@REM ============================================================================
:validateWorkspaceArg <param>
call :trim param "%~1"
if "!param!" == "" goto :invalidWorkspaceArg
if "!param:~0,2!" == "--" goto :invalidWorkspaceArg
if "!param:~0,1!" == "-" goto :invalidWorkspaceArg

call :convertToAbsolutePath directory "!param!"
if not exist "!directory!" (
    call :createDirectories success "!directory!"
    if "!success!" == "1" (
        rd "!directory!" /s /q >nul 2>nul
    ) else (
        set "should_exit=1"
    )
)

if "!should_exit!" == "1" (
    @echo [%ESC%[!error_color!m错误%ESC%[0m] 工作目录路径 "%ESC%[!warn_color!m!directory!%ESC%[0m" 无效
    @echo.
    goto :eof
)

set "dest=!directory!"
goto :eof


@REM ============================================================================
@REM Handle invalid workspace argument error
@REM Purpose:    Displays error message and shows usage when --workspace is invalid
@REM ============================================================================
:invalidWorkspaceArg
@echo [%ESC%[!error_color!m错误%ESC%[0m] 参数 "%ESC%[!warn_color!m--workspace%ESC%[0m" 需要有效的路径
@echo.
goto :usage


@REM ============================================================================
@REM Handle goto syntax for function calls
@REM Parameters: <func_name> - Function name to call
@REM            <all_params> - All parameters to pass to function
@REM Purpose:    Processes goto syntax for calling functions with parameters
@REM ============================================================================
:handleGotoSyntax <func_name> <all_params>
call :trim func_name "%~1"
if "!func_name!" == "" (
    @echo [%ESC%[!error_color!m错误%ESC%[0m] goto 语法需要提供函数名
    goto :usage
)

for /f "tokens=1-2,* delims= " %%a in ("%~2") do set "params=%%c"
if "!params!" == "" (
    call !func_name!
) else (
    call !func_name! !params!
)
exit /b


@REM ============================================================================
@REM Validate subscription URL format and content
@REM Parameters: <url> - URL string to validate
@REM Purpose:    Ensures URL is properly formatted and contains no invalid characters
@REM Validation: Checks for quotes, whitespace, and proper HTTP/HTTPS format
@REM ============================================================================
:validateUrl <url>
set "invalid_url=0"
call :trim url "%~1"

@REM Check for quotes and whitespace
if "!url!" neq "!url: =!" set "invalid_url=1"
set "temp_check=!TEMP_DIR!\url_check.txt"
echo !url! > "!temp_check!" 2>nul
if exist "!temp_check!" (
    findstr /i /r /c:"\"^" "!temp_check!" >nul && set "invalid_url=1"
    del /f /q "!temp_check!" >nul 2>nul
)

@REM Validate URL pattern
echo "!url!" > "!temp_check!" 2>nul
if exist "!temp_check!" (
    findstr /i /r /c:^"\"http.*://.*[a-zA-Z0-9][a-zA-Z0-9]*\"^" "!temp_check!" >nul 2>nul || set "invalid_url=1"
    del /f /q "!temp_check!" >nul 2>nul
)

if "!invalid_url!" == "1" (
    @echo [%ESC%[!error_color!m错误%ESC%[0m] 无效的订阅链接 "%ESC%[!warn_color!m!url!%ESC%[0m"
    @echo.
    set "should_exit=1"
    goto :eof
)

set "subscription_link=!url!"
goto :eof


@REM ============================================================================
@REM Validate configuration file format and extension
@REM Parameters: <filename> - Configuration file path to validate
@REM Purpose:    Ensures config file has proper .json extension
@REM Validation: Checks file extension and sets configuration variable
@REM ============================================================================
:validateConfigFile <filename>
call :trim filename "%~1"
if "!filename:~-5!" NEQ ".json" (
    @echo [%ESC%[!error_color!m错误%ESC%[0m] 配置文件 "%ESC%[!warn_color!m!filename!%ESC%[0m" 格式无效，仅支持 .json 格式
    @echo.
    set "should_exit=1"
    goto :eof
)
set "configuration=!filename!"
goto :eof


@REM ============================================================================
@REM Validate GitHub repository slug from environment
@REM Parameters: <repo> - Repository slug to validate (username/repo)
@REM Purpose:    Accepts only GitHub owner/name before overriding GITHUB_REPO
@REM ============================================================================
:validateGithubRepo <repo>
call :trim repo "%~1"
if "!repo!" == "" (
    call :invalidGithubRepo ""
    goto :eof
)
if "!repo!" NEQ "!repo: =!" (
    call :invalidGithubRepo "!repo!"
    goto :eof
)

echo(!repo!| findstr /r /x /c:"[A-Za-z0-9][A-Za-z0-9_-]*/[A-Za-z0-9._-][A-Za-z0-9._-]*" >nul
if errorlevel 1 (
    call :invalidGithubRepo "!repo!"
    goto :eof
)

set "GITHUB_REPO=!repo!"
goto :eof

:invalidGithubRepo <repo>
call :trim repo "%~1"
@echo [%ESC%[!error_color!m错误%ESC%[0m] 环境变量 "%ESC%[!warn_color!mSINGBOX_GITHUB_REPO%ESC%[0m" 无效："%ESC%[!warn_color!m!repo!%ESC%[0m"，格式必须为 %ESC%[!warn_color!musername/repo%ESC%[0m
set "should_exit=1"
goto :eof


@REM ============================================================================
@REM Display comprehensive usage information and help text
@REM Purpose:    Shows all available command line options and usage examples
@REM Format:     Uses array-based approach for flexible help text management
@REM ============================================================================
:usage
set "usage_lines[0]=使用方法：!BATCH_NAME! [功能选项] [其他参数]"
set "usage_lines[1]=BLANK"
set "usage_lines[2]=功能选项："
set "usage_lines[3]=  -f, --fix             检查并修复代理网络"
set "usage_lines[4]=  -h, --help            显示帮助信息"
set "usage_lines[5]=  -i, --init            初始化代理网络"
set "usage_lines[6]=  -k, --kill            停止代理程序"
set "usage_lines[7]=  -o, --reload          重新加载配置文件"
set "usage_lines[8]=  -p, --purge           清理所有设置"
set "usage_lines[9]=  -r, --restart         重启代理程序"
set "usage_lines[10]=  -t, --test            测试网络连接"
set "usage_lines[11]=  -u, --update          更新所有组件"
set "usage_lines[12]=BLANK"
set "usage_lines[13]=其他参数："
set "usage_lines[14]=  -c, --conf            指定配置文件或订阅链接"
set "usage_lines[15]=  -d, --daemon          后台运行"
set "usage_lines[16]=  -e, --exclude         跳过订阅更新"
set "usage_lines[17]=  -g, --generate        重新生成更新脚本"
set "usage_lines[18]=  -s, --show            显示窗口"
set "usage_lines[19]=  -w, --workspace       指定工作目录"
set "usage_lines[20]=BLANK"

for /l %%i in (0,1,20) do (
    call set "line=%%usage_lines[%%i]%%"
    if "!line!" == "BLANK" (
        @echo.
    ) else (
        @echo !line!
    )
)

set "should_exit=1"
goto :eof


@REM ============================================================================
@REM Extract provider URLs and local save paths from JSON configuration
@REM Parameters: <urls> - Return variable for comma-separated provider URLs
@REM            <cache_files> - Return variable for comma-separated local save paths
@REM Purpose:    Parses sing-box config to find subscription providers for updates
@REM Compatible: Uses "path" as default; other sing-box implementations use "cache_file"
@REM Method:     PowerShell ConvertFrom-Json on the top-level providers array
@REM ============================================================================
:extractProviders <urls> <cache_files>
set "%~1="
set "%~2="

if not exist "!config_file!" goto :eof

set "urls="
set "cache_files="
set "temp_result=!TEMP_DIR!\providers_extract.txt"
del /f /q "!temp_result!" >nul 2>nul

@REM Prefer "path" (this fork); fall back to "cache_file" (other implementations)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "@((Get-Content '!config_file!' -Encoding UTF8 | ConvertFrom-Json).providers) | Where-Object { $_.url -and ($_.path -or $_.cache_file) } | ForEach-Object { $_.url + '|' + $(if ($_.path) { $_.path } else { $_.cache_file }) }" > "!temp_result!" 2>nul

if exist "!temp_result!" (
    for /f "usebackq tokens=1,2 delims=|" %%a in ("!temp_result!") do (
        call :addProvider "%%a" "%%b"
    )
    del /f /q "!temp_result!" >nul 2>nul
)

if "!urls:~0,1!" == "," set "urls=!urls:~1!"
if "!cache_files:~0,1!" == "," set "cache_files=!cache_files:~1!"

set "%~1=!urls!"
set "%~2=!cache_files!"
goto :eof


@REM ============================================================================
@REM Extract remote rule sets from configuration file
@REM Parameters: <urls> - Return variable for comma-separated URLs
@REM            <cache_files> - Return variable for comma-separated save paths
@REM Purpose:    Filters route.rule_set entries with type=remote, url, and path
@REM Method:     PowerShell ConvertFrom-Json on route.rule_set
@REM ============================================================================
:extractRuleSets <urls> <cache_files>
set "%~1="
set "%~2="

if not exist "!config_file!" goto :eof

set "urls="
set "cache_files="
set "temp_result=!TEMP_DIR!\rulesets_extract.txt"
del /f /q "!temp_result!" >nul 2>nul

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$c = Get-Content '!config_file!' -Encoding UTF8 | ConvertFrom-Json; if ($c.route) { @($c.route.rule_set) | Where-Object { $_.type -eq 'remote' -and $_.url -and $_.path } | ForEach-Object { $_.url + '|' + $_.path } }" > "!temp_result!" 2>nul

if exist "!temp_result!" (
    for /f "usebackq tokens=1,2 delims=|" %%a in ("!temp_result!") do (
        call :addProvider "%%a" "%%b"
    )
    del /f /q "!temp_result!" >nul 2>nul
)

if "!urls:~0,1!" == "," set "urls=!urls:~1!"
if "!cache_files:~0,1!" == "," set "cache_files=!cache_files:~1!"

set "%~1=!urls!"
set "%~2=!cache_files!"
goto :eof


@REM ============================================================================
@REM Add provider to URL and local save path lists if valid
@REM Parameters: <url> - Provider subscription URL
@REM            <cache_file> - Local save path (path or cache_file)
@REM Purpose:    Validates and adds provider info to global comma-separated lists
@REM ============================================================================
:addProvider <url> <cache_file>
call :trim url "%~1"
call :trim cache_file "%~2"
if "!url!" NEQ "" if "!cache_file!" NEQ "" (
    set "is_valid=0"
    @REM Validate URL format (must be HTTP/HTTPS)
    if "!url:~0,8!" == "https://" set "is_valid=1"
    if "!url:~0,7!" == "http://" set "is_valid=1"
    if "!is_valid!" == "1" (
        @REM Add to comma-separated lists
        set "urls=!urls!,!url!"
        set "cache_files=!cache_files!,!cache_file!"
    )
)
goto :eof


@REM ============================================================================
@REM Update subscription providers from remote sources
@REM Purpose:    Downloads and updates HTTP-based subscription configurations
@REM Process:    Extracts providers, validates URLs, downloads updates
@REM ============================================================================
:updateSubscriptions
@echo [%ESC%[!info_color!m信息%ESC%[0m] 检查并更新订阅，仅刷新 %ESC%[!warn_color!mremote%ESC%[0m 类型的订阅

@REM Extract providers information
call :extractProviders urls cache_files

if "!urls!" == "" (
    @echo [%ESC%[!warn_color!m警告%ESC%[0m] 未发现订阅配置，跳过更新，文件："!config_file!"
    goto :eof
)

@REM Process each provider
call :processProviders "!urls!" "!cache_files!"
goto :eof


@REM ============================================================================
@REM Update remote rule sets from route.rule_set
@REM Purpose:    Downloads remote rule sets that have both url and path
@REM Process:    Filters type=remote entries, then reuses provider download
@REM ============================================================================
:updateRuleSets
@echo [%ESC%[!info_color!m信息%ESC%[0m] 检查并更新远程规则集，仅刷新 %ESC%[!warn_color!mtype%ESC%[0m 为 %ESC%[!warn_color!mremote%ESC%[0m 且同时配置了 %ESC%[!warn_color!murl%ESC%[0m 与 %ESC%[!warn_color!mpath%ESC%[0m 的规则

call :extractRuleSets urls cache_files

if "!urls!" == "" (
    @echo [%ESC%[!warn_color!m警告%ESC%[0m] 未发现可更新的远程规则集，跳过更新，文件："!config_file!"
    goto :eof
)

set "ruleset_count=0"
for %%a in (!urls!) do set /a ruleset_count+=1
@echo [%ESC%[!info_color!m信息%ESC%[0m] 发现 %ESC%[!warn_color!m!ruleset_count!%ESC%[0m 个远程规则集，开始更新

call :processProviders "!urls!" "!cache_files!"
goto :eof


@REM ============================================================================
@REM Process multiple provider subscriptions for updates
@REM Parameters: <urls> - Comma-separated list of provider URLs
@REM            <cache_files> - Comma-separated list of cache file paths
@REM Purpose:    Iterates through provider lists and updates each one
@REM ============================================================================
:processProviders <urls> <cache_files>
call :trim urls "%~1"
call :trim cache_files "%~2"

if "!urls!" == "" goto :eof
if "!cache_files!" == "" goto :eof

set "url_array=!urls!"
set "cache_array=!cache_files!"


@REM ============================================================================
@REM Main loop for processing provider subscriptions
@REM Purpose:    Iterates through URL and cache file arrays in parallel
@REM Process:    Extracts pairs, validates, and calls processProvider for each
@REM ============================================================================
:processProviderLoop
if "!url_array!" == "" goto :eof

@REM Extract current URL and cache file
for /f "tokens=1* delims=," %%a in ("!url_array!") do (
    set "current_url=%%a"
    set "url_array=%%b"
)
for /f "tokens=1* delims=," %%a in ("!cache_array!") do (
    set "current_cache=%%a"
    set "cache_array=%%b"
)

call :trim current_url "!current_url!"
call :trim current_cache "!current_cache!"

if "!current_url!" == "" goto :processProviderLoop
if "!current_cache!" == "" goto :processProviderLoop

@REM Process single provider
call :processProvider "!current_url!" "!current_cache!"
goto :processProviderLoop


@REM ============================================================================
@REM Process a single provider subscription update
@REM Parameters: <url> - Provider subscription URL
@REM            <cache_file> - Local cache file path for this provider
@REM Purpose:    Downloads and validates a single subscription update
@REM ============================================================================
:processProvider <url> <cache_file>
call :convertToAbsolutePath target_file "%~2"
if "!target_file!" == "" (
    @echo [%ESC%[!error_color!m错误%ESC%[0m] 保存路径无效："%~2"
    goto :eof
)

call :splitPath file_path file_name "!target_file!"
call :createDirectories success "!file_path!"
call :applyGithubProxy process_url "%~1"

@REM Download subscription or rule set. Geosite .srs for a handful of domains can be ~40 bytes, so keep the floor at 16.
del /f /q "!TEMP_DIR!\!file_name!" >nul 2>nul
call :downloadWithRetry "!process_url!" "!TEMP_DIR!\!file_name!" 16

@REM Validate and move file
set "file_size=0"
if exist "!TEMP_DIR!\!file_name!" (
    for %%a in ("!TEMP_DIR!\!file_name!") do set "file_size=%%~za"
)

if !file_size! GEQ 16 (
    del /f /q "!target_file!" >nul 2>nul
    move "!TEMP_DIR!\!file_name!" "!file_path!" >nul 2>nul
) else (
    @echo [%ESC%[!error_color!m错误%ESC%[0m] 下载失败，文件：!file_name!，链接：!process_url!
    del /f /q "!TEMP_DIR!\!file_name!" >nul 2>nul
)
goto :eof


@REM ============================================================================
@REM Split file path into directory and filename components
@REM Parameters: <directory> - Return variable for directory path
@REM            <filename> - Return variable for filename
@REM            <file_path> - Full file path to split
@REM Purpose:    Utility function to separate path components
@REM ============================================================================
:splitPath <directory> <filename> <file_path>
set "%~1=%~dp3"                          @REM Extract directory path
set "%~2=%~nx3"                          @REM Extract filename with extension

@REM Remove trailing backslash from directory path
if "!%~1:~-1!" == "\" set "%~1=!%~1:~0,-1!"
goto :eof


@REM ============================================================================
@REM Convert relative path to absolute path
@REM Parameters: <r> - Return variable for absolute path
@REM            <filename> - Relative or absolute file path
@REM Purpose:    Resolves relative paths to absolute paths using base directory
@REM ============================================================================
:convertToAbsolutePath <result> <filename>
call :trim file_path %~2
set "%~1="

if "!file_path!" == "" goto :eof

@REM Check if path is already absolute (contains drive letter)
@echo "!file_path!" | findstr ":" >nul 2>nul && (
    set "%~1=!file_path!"
    goto :eof
) || (
    @REM Use dest directory or script directory as base
    if "!dest!" NEQ "" (set "basedir=!dest!") else (set "basedir=%~dp0")
    if "!basedir:~-1!" == "\" set "basedir=!basedir:~0,-1!"

    @REM Handle current directory reference
    if "!file_path!" == "." (
        set "%~1=!basedir!"
        goto :eof
    )

    @REM Convert forward slashes to backslashes
    set "file_path=!file_path:/=\!"
    @REM Handle different relative path formats
    if "!file_path:~0,3!" == ".\\" (
        set "%~1=!basedir!\!file_path:~3!"
    ) else if "!file_path:~0,2!" == ".\" (
        set "%~1=!basedir!\!file_path:~2!"
    ) else (
        set "%~1=!basedir!\!file_path!"
    )
)
goto :eof


@REM ============================================================================
@REM Test network connectivity through proxy
@REM Parameters: <r> - Return variable (0=failed, 1=success)
@REM            <allowed> - Output level (0=silent, 1=verbose)
@REM Purpose:    Tests if proxy network is working properly
@REM ============================================================================
:testConnection <result> <allowed>
@REM Check if sing-box process is running
set "%~1=0"
call :trim output "%~2"
if "!output!" == "" set "output=1"

call :isProcessRunning status
if "!status!" == "0" (
    if "!output!" == "1" (
        @echo [%ESC%[!warn_color!m提示%ESC%[0m] 网络%ESC%[!error_color!m不可用%ESC%[0m，代理程序%ESC%[!error_color!m已退出%ESC%[0m
    )

    goto :eof
)

@REM Generate proxy server address for testing
call :generateProxyAddress server

@REM Test network connectivity through proxy
call :checkNetworkAvailable status "!output!" "https://www.google.com" "!server!"
set "%~1=!status!"
goto :eof


@REM ============================================================================
@REM Check network availability with optional proxy
@REM Parameters: <r> - Return variable (0=failed, 1=success)
@REM            <allowed> - Output level (0=silent, 1=verbose)
@REM            <url> - URL to test connectivity against
@REM            <proxyserver> - Proxy server address (optional)
@REM Purpose:    Tests network connectivity with or without proxy
@REM ============================================================================
:checkNetworkAvailable <result> <allowed> <url> <proxyserver>
set "%~1=0"
call :trim output "%~2"
call :trim url "%~3"
call :trim proxy_server "%~4"

@REM Set default values for optional parameters
if "!output!" == "" set "output=1"
if "!url!" == "" set "url=https://www.google.com"

@REM Test network connectivity with curl
set "status_code=000"
if "!proxy_server!" == "" (
    @REM Direct connection test
    for /f %%a in ('!CURL_BINARY! --retry 3 --retry-max-time 10 -m 5 --connect-timeout 5 -L -s -o nul -w "%%{http_code}" "!url!"') do set "status_code=%%a"
) else (
    @REM Proxy connection test
    for /f %%a in ('!CURL_BINARY! -x !proxy_server! --retry 3 --retry-max-time 10 -m 5 --connect-timeout 5 -L -s -o nul -w "%%{http_code}" "!url!"') do set "status_code=%%a"
)

@REM Process test results and provide user feedback
if "!status_code!" == "200" (
    set "%~1=1"
    if "!output!" == "1" (
        @echo [%ESC%[!info_color!m信息%ESC%[0m] 代理网络不存在问题，能够%ESC%[!info_color!m正常%ESC%[0m使用
    )
) else (
    set "%~1=0"
    if "!output!" == "1" (
        @REM Configure post-processing for failed connections
        call :postProcess

        @echo [%ESC%[!warn_color!m提示%ESC%[0m] 代理网络%ESC%[!error_color!m不可用%ESC%[0m，可%ESC%[!warn_color!m再次测试%ESC%[0m或使用命令 "%ESC%[!warn_color!m!BATCH_NAME! -r%ESC%[0m" %ESC%[!warn_color!m重启%ESC%[0m 或者 "%ESC%[!warn_color!m!BATCH_NAME! -f%ESC%[0m" %ESC%[!warn_color!m修复%ESC%[0m
    )
)
goto :eof


@REM ============================================================================
@REM Generate proxy server address for network testing
@REM Parameters: <r> - Return variable for proxy address (format: host:port)
@REM Purpose:    Determines proxy address from system settings or config file
@REM Fallback:   Prompts user to configure system proxy if not set
@REM ============================================================================
:generateProxyAddress <result>
set "%~1="

call :getSystemProxy server
if "!server!" NEQ "" (
    set "%~1=!server!"
    goto :eof
)

@REM Extract proxy settings from configuration file if system proxy not set
if exist "!config_file!" (
    @REM Skip if TUN mode is enabled (no system proxy needed)
    call :isTunEnabled enabled
    if "!enabled!" == "1" goto :eof
    @REM Extract proxy port from configuration
    call :extractProxyPort port
    if "!port!" == "" goto :eof

    @REM Prompt user to configure system proxy
    set "tips=[%ESC%[!warn_color!m提示%ESC%[0m] 系统代理%ESC%[!error_color!m未配置%ESC%[0m，是否设置？(%ESC%[!warn_color!mY%ESC%[0m/%ESC%[!warn_color!mN%ESC%[0m) "
    if "!ms_terminal!" == "1" (
        choice /t 5 /d y /n /m "!tips!"
    ) else (
        set /p "=!tips!" <nul
        choice /t 5 /d y /n
    )
    if !errorlevel! == 2 goto :eof

    @REM Configure system proxy with extracted port
    call :enableSystemProxy "127.0.0.1:!port!"
    set "%~1=127.0.0.1:!port!"
    goto :eof
)
goto :eof


@REM ============================================================================
@REM Create directory if it doesn't exist
@REM Parameters: <r> - Return variable (0=failed, 1=success)
@REM            <directory> - Directory path to create
@REM Purpose:    Ensures directory exists for file operations
@REM ============================================================================
:createDirectories <result> <directory>
set "%~1=0"
call :trim directory "%~2"
if "!directory!" == "" (
    @echo [%ESC%[!warn_color!m警告%ESC%[0m] 路径为空，创建目录失败
    goto :eof
)

if not exist "!directory!" (
    mkdir "!directory!"
    if "!errorlevel!" == "0" set "%~1=1"
) else (set "%~1=1")
goto :eof


@REM ============================================================================
@REM Check if TUN mode is enabled in sing-box configuration
@REM Parameters: <enabled> - Return variable (0=disabled, 1=enabled)
@REM Purpose:    Determines if TUN interface is configured for transparent proxy
@REM Method:     Searches for "type":"tun" in JSON configuration
@REM ============================================================================
:isTunEnabled <enabled>
set "%~1=0"

@REM Check if TUN inbound exists in JSON
for /f "tokens=*" %%a in ('findstr /i /r /c:"\"type\"[ ]*:[ ]*\"tun\"" "!config_file!"') do (
    set "%~1=1"
    goto :eof
)
goto :eof


@REM ============================================================================
@REM Download and extract sing-box binary files
@REM Parameters: <success> - Return variable for success (0=failed, 1=success)
@REM            <download_url> - Download URL for sing-box executable
@REM Purpose:    Downloads sing-box executable from GitHub releases
@REM Process:    Downloads ZIP, extracts, renames, validates
@REM ============================================================================
:downloadSingbox <success> <download_url>
set "%~1=0"
call :trim download_url "%~2"

@REM Download sing-box executable if URL is available
if "!download_url!" NEQ "" (
    @REM Validate download URL format
    if /i "!download_url:~0,8!" NEQ "https://" (
        @echo [%ESC%[!error_color!m错误%ESC%[0m] !SINGBOX_EXE! 下载地址解析失败："!download_url!"
    ) else (
        @echo [%ESC%[!info_color!m信息%ESC%[0m] 开始下载 %ESC%[!warn_color!m!SINGBOX_EXE!%ESC%[0m 至 %ESC%[!warn_color!m!dest!%ESC%[0m

        @REM Download ZIP archive with retry mechanism
        call :downloadWithRetry "!download_url!" "!TEMP_DIR!\sing-box.zip" 2048
        if exist "!TEMP_DIR!\sing-box.zip" (
            call :isZipArchive zip_valid "!TEMP_DIR!\sing-box.zip" 2048
            if "!zip_valid!" == "0" (
                @echo [%ESC%[!error_color!m错误%ESC%[0m] !SINGBOX_EXE! 下载内容%ESC%[!error_color!m无效%ESC%[0m，可能是代理返回了错误页面，下载链接："!download_url!"
                if "!last_download_url!" NEQ "" if /i "!last_download_url!" NEQ "!download_url!" (
                    @echo [%ESC%[!error_color!m错误%ESC%[0m] 实际下载链接："!last_download_url!"
                )
                del /f /q "!TEMP_DIR!\sing-box.zip" >nul 2>nul
            ) else (
                set "extract_dir=!TEMP_DIR!\singbox"
                if exist "!extract_dir!" rd /s /q "!extract_dir!" >nul 2>nul

                @REM Locate sing-box.exe inside the archive instead of walking %TEMP%
                set "real_path="
                for /f "delims=" %%a in ('!TAR_BINARY! -tf "!TEMP_DIR!\sing-box.zip" 2^>nul ^| findstr /i /e /c:"!SINGBOX_EXE!"') do set "real_path=%%a"

                call :extractArchive zip_extracted "!TEMP_DIR!\sing-box.zip" "!extract_dir!"
                del /f /q "!TEMP_DIR!\sing-box.zip" >nul 2>nul

                if "!zip_extracted!" == "1" if "!real_path!" NEQ "" if exist "!extract_dir!\!real_path!" (
                    for %%a in ("!extract_dir!\!real_path!") do (
                        move /y "%%~fa" "!TEMP_DIR!\!SINGBOX_EXE!" >nul 2>nul
                        if exist "%%~dpa!CRONET_DLL!" move /y "%%~dpa!CRONET_DLL!" "!TEMP_DIR!\" >nul 2>nul
                    )
                )

                if exist "!extract_dir!" rd /s /q "!extract_dir!" >nul 2>nul
            )
        ) else (
            @echo [%ESC%[!error_color!m错误%ESC%[0m] !SINGBOX_EXE! 下载失败，下载链接："!download_url!"
            if "!last_download_url!" NEQ "" if /i "!last_download_url!" NEQ "!download_url!" (
                @echo [%ESC%[!error_color!m错误%ESC%[0m] 实际下载链接："!last_download_url!"
            )
        )

        @REM Validate extracted executable
        if exist "!TEMP_DIR!\!SINGBOX_EXE!" (
            set "%~1=1"
        ) else (
            @echo [%ESC%[!error_color!m错误%ESC%[0m] "!TEMP_DIR!\!SINGBOX_EXE!" 不存在，下载链接："!download_url!"
        )
    )
)

goto :eof


@REM ============================================================================
@REM Download file with automatic retry mechanism
@REM Parameters: <url> - Source URL to download from
@REM            <filename> - Local file path to save downloaded content
@REM            [minBytes] - Reject files smaller than this size (default 16)
@REM Purpose:    Robust file download with retry logic for network failures
@REM ============================================================================
:downloadWithRetry <url> <filename> [minBytes]
set max_retries=3
set "last_download_url="
set "fail_reason="
set "downloaded_size=0"
call :trim download_url "%~1"
call :trim saved_path "%~2"
call :trim min_bytes "%~3"
call :removeQuotes download_url "!download_url!"
@REM 16 bytes rejects empty/truncated payloads while still accepting small geosite .srs files (~40 bytes)
if "!min_bytes!" == "" set "min_bytes=16"

if "!download_url!" == "" goto :eof
if "!saved_path!" == "" goto :eof

if exist "!saved_path!" del /f /q "!saved_path!" >nul 2>nul
set /a "count=0"

:retry
if !count! GEQ !max_retries! (
    @echo [%ESC%[!error_color!m错误%ESC%[0m] 文件 %ESC%[!warn_color!m!saved_path!%ESC%[0m 下载失败，已达最大重试次数，请尝试再次执行此命令
    if "!fail_reason!" == "size" (
        @echo [%ESC%[!error_color!m错误%ESC%[0m] 下载内容过小：%ESC%[!warn_color!m!downloaded_size!%ESC%[0m 字节，要求至少 %ESC%[!warn_color!m!min_bytes!%ESC%[0m 字节
    )
    if "!last_download_url!" NEQ "" (
        @echo [%ESC%[!error_color!m错误%ESC%[0m] 最后一次下载链接：%ESC%[!warn_color!m!last_download_url!%ESC%[0m
    )
    if exist "!saved_path!" del /f /q "!saved_path!" >nul 2>nul
    goto :eof
)

@REM Always re-download from scratch; partial resumes can keep corrupt proxy responses
if exist "!saved_path!" del /f /q "!saved_path!" >nul 2>nul
set "fail_reason="
set "downloaded_size=0"

call :applyGithubProxy real_download_url "!download_url!"
set "last_download_url=!real_download_url!"
!CURL_BINARY! --retry 5 --retry-max-time 120 --connect-timeout 20 -f -s -L -o "!saved_path!" "!real_download_url!"
set "fail_flag=!errorlevel!"
if not exist "!saved_path!" set "fail_flag=1"

@REM Reject empty or truncated files (common for proxy/HTML error pages)
if "!fail_flag!" == "0" (
    for %%a in ("!saved_path!") do set "downloaded_size=%%~za"
    if !downloaded_size! LSS !min_bytes! (
        set "fail_flag=1"
        set "fail_reason=size"
        del /f /q "!saved_path!" >nul 2>nul
    )
)

if "!fail_flag!" NEQ "0" (
    set /a "count+=1"

    if "!fail_reason!" == "size" (
        @echo [%ESC%[!warn_color!m提示%ESC%[0m] 下载内容过小（%ESC%[!warn_color!m!downloaded_size!%ESC%[0m 字节，要求至少 %ESC%[!warn_color!m!min_bytes!%ESC%[0m 字节），正在进行第 %ESC%[!warn_color!m!count!%ESC%[0m 次重试，下载链接：!real_download_url!
    ) else (
        @echo [%ESC%[!warn_color!m提示%ESC%[0m] 文件下载失败，正在进行第 %ESC%[!warn_color!m!count!%ESC%[0m 次重试，下载链接：!real_download_url!
    )
    goto :retry
)
goto :eof


@REM ============================================================================
@REM Validate whether a file is a readable zip/tar archive
@REM Parameters: <result> - Return variable (0=invalid, 1=valid)
@REM            <filePath> - Archive path to validate
@REM            [minBytes] - Minimum accepted size (default 1024)
@REM ============================================================================
:isZipArchive <result> <filePath> [minBytes]
set "%~1=0"
call :trim archive_path "%~2"
call :trim archive_min_bytes "%~3"
if "!archive_min_bytes!" == "" set "archive_min_bytes=1024"
if "!archive_path!" == "" goto :eof
if not exist "!archive_path!" goto :eof

set "archive_size=0"
for %%a in ("!archive_path!") do set "archive_size=%%~za"
if !archive_size! LSS !archive_min_bytes! goto :eof

@REM Windows tar (libarchive) can list zip content; failure usually means HTML/corrupt payload
!TAR_BINARY! -tf "!archive_path!" >nul 2>nul
if "!errorlevel!" NEQ "0" goto :eof

set "%~1=1"
goto :eof


@REM ============================================================================
@REM Extract a zip/tar archive into the target directory
@REM Parameters: <result> - Return variable (0=failed, 1=success)
@REM            <archivePath> - Archive file to extract
@REM            <destDir> - Destination directory
@REM ============================================================================
:extractArchive <result> <archivePath> <destDir>
set "%~1=0"
call :trim archive_file "%~2"
call :trim extract_dir "%~3"
if "!archive_file!" == "" goto :eof
if "!extract_dir!" == "" goto :eof
if not exist "!archive_file!" goto :eof

call :createDirectories extract_ready "!extract_dir!"
if "!extract_ready!" == "0" goto :eof

@REM Use -xf so zip archives are not forced through gzip
!TAR_BINARY! -xf "!archive_file!" -C "!extract_dir!" >nul 2>nul
if "!errorlevel!" NEQ "0" goto :eof

set "%~1=1"
goto :eof


@REM ============================================================================
@REM Detect file changes and trigger updates
@REM Parameters: <r> - Return variable (0=no changes, 1=changes detected)
@REM            <filenames> - Space-separated list of files to check
@REM Purpose:    Compares downloaded files with existing ones using MD5 hashes
@REM ============================================================================
:detect <result> <filenames>
set "%~1=0"
set "file_names=%~2"

for %%a in (!file_names!) do (
    set "file_name=%%a"

    @REM Verify downloaded file exists in temporary directory
    if not exist "!TEMP_DIR!\!file_name!" (
        @echo [%ESC%[!error_color!m错误%ESC%[0m] %ESC%[!warn_color!m!file_name!%ESC%[0m 下载成功，但在 "!TEMP_DIR!" 文件夹下未找到，请确认是否已被删除
        goto :eof
    )

    @REM Force upgrade if in repair mode
    if "!repair!" == "1" (
        del /f /q "!dest!\!file_name!" >nul 2>nul
    )

    @REM Install new file if destination doesn't exist
    if not exist "!dest!\!file_name!" (
        set "%~1=1"
        call :upgrade "!file_names!"
        exit /b
    )

    @REM Compare files using MD5 hash and upgrade if different
    call :compareFileMd5 diff "!TEMP_DIR!\!file_name!" "!dest!\!file_name!"
    if "!diff!" == "1" (
        set "%~1=1"
        @echo [%ESC%[!info_color!m信息%ESC%[0m] 发现新版本，文件名：%ESC%[!warn_color!m!file_name!%ESC%[0m
        call :upgrade "!file_names!"
        exit /b
    )
)
goto :eof


@REM ============================================================================
@REM Compare two files using MD5 hash
@REM Parameters: <changed> - Return variable (0=same, 1=different)
@REM            <source> - Source file path
@REM            <target> - Target file path for comparison
@REM Purpose:    Determines if files are different to decide on updates
@REM ============================================================================
:compareFileMd5 <changed> <source> <target>
set "%~1=0"

call :trim source "%~2"
call :trim target "%~3"

@REM Validate file existence before comparison
if not exist "!source!" if not exist "!target!" goto :eof
if not exist "!source!" goto :eof
if not exist "!target!" (
    set "%~1=1"
    goto :eof
)

@REM Calculate MD5 hash for source file
set "original_hash=" & for /F "skip=1 delims=" %%h in ('2^> nul CertUtil -hashfile "!source!" MD5') do if not defined original_hash set "original_hash=%%h"
@REM Calculate MD5 hash for target file
set "received_hash=" & for /F "skip=1 delims=" %%h in ('2^> nul CertUtil -hashfile "!target!" MD5') do if not defined received_hash set "received_hash=%%h"

@REM Compare hashes and set result flag
if "!original_hash!" NEQ "!received_hash!" (set "%~1=1")
goto :eof


@REM ============================================================================
@REM Upgrade sing-box executable and related files
@REM Parameters: <file_names> - Space-separated list of files to upgrade
@REM Purpose:    Safely replaces existing files with new versions
@REM Process:    Stops service, validates files, replaces files
@REM ============================================================================
:upgrade <file_names>
call :trim file_names "%~1"
if "!file_names!" == "" goto :eof

@REM Verify all required files exist in temporary directory
set "existing_files="
for %%a in (!file_names!) do (
    if exist "!TEMP_DIR!\%%a" (
        if "!existing_files!" == "" (
            set "existing_files=%%a"
        ) else (
            set "existing_files=!existing_files!;%%a"
        )
    )
)

@REM Abort upgrade if any required files are missing
if "!existing_files!" == "" goto :terminate

@REM Stop sing-box service before file replacement
call :killProcessWrapper

@REM Replace each file with new version
for %%a in (!file_names!) do (
    set "file_name=%%a"

    @REM Remove existing file to avoid conflicts
    if exist "!dest!\!file_name!" (
        del /f /q "!dest!\!file_name!" >nul 2>nul
    )

    @REM Move new file from temporary to destination directory
    move "!TEMP_DIR!\!file_name!" "!dest!" >nul 2>nul
)
goto :eof


@REM ============================================================================
@REM Start sing-box proxy service
@REM Purpose:    Starts sing-box if not running, or restarts if already running
@REM Returns:    Calls appropriate startup or restart function
@REM ============================================================================
:startSingbox
call :isProcessRunning status

if "!status!" == "0" (
    @REM Start sing-box service if not currently running
    call :executeWrapper 0
) else (
    @REM Reload configuration if already running
    @echo [%ESC%[!info_color!m信息%ESC%[0m] 订阅和代理规则更新完毕，即将重新加载
    goto :reloadConfig
)
goto :eof


@REM ============================================================================
@REM Execute operation with administrator privileges
@REM Parameters: <args> - Operation/function to execute with elevated rights
@REM            <show> - Window visibility (0=hidden, 1=visible)
@REM Purpose:    Handles UAC elevation for operations requiring admin rights
@REM ============================================================================
:privilege <args> <show>
set "show=0"
set "operation=%~1"
if "!operation!" == "" (
    @echo [%ESC%[!error_color!m错误%ESC%[0m] 非法操作，必须指定函数名
    exit /b 1
)

@REM Parse window visibility parameter (0=hidden, 1=visible)
call :trim param "%~2"
set "display=" & for /f "delims=0123456789" %%i in ("!param!") do set "display=%%i"
if defined display (set "show=0") else (set "show=!param!")
if "!show!" NEQ "0" set "show=1"

@REM Check if already running as administrator, if not request elevation
cacls "%SystemDrive%\System Volume Information" >nul 2>&1 && (
    if "!show!" == "0" (
        !operation!
        exit /b
    ) else (
        powershell.exe -NoLogo -NoProfile -Command "Start-Process '%~snx0' -ArgumentList '%~1' -Verb RunAs"
        exit /b
    )
) || (
    if "!show!" == "0" (
        powershell.exe -NoLogo -NoProfile -Command "Start-Process '%~snx0' -ArgumentList '%~1' -Verb RunAs -WindowStyle Hidden"
    ) else (
        powershell.exe -NoLogo -NoProfile -Command "Start-Process '%~snx0' -ArgumentList '%~1' -Verb RunAs"
    )
    exit /b
)
goto :eof


@REM ============================================================================
@REM Execute sing-box with specified configuration
@REM Parameters: <config> - Configuration file path
@REM            <dest> - Working directory path
@REM Purpose:    Launches sing-box process with proper configuration and directory
@REM ============================================================================
:execute <config> <dest>
call :trim file "%~1"
call :trim dest "%~2"

@REM Handle special case where parameters come from privilege escalation
if "!file:~0,13!" == "goto :execute" (
    for /f "tokens=1-5 delims= " %%a in ("!file!") do (
        set "file=%%c"
        set "dest=%%d"
    )
)

@REM Validate configuration file path
if "!file!" == "" (
    @echo [%ESC%[!info_color!m信息%ESC%[0m] 配件文件路径无效，无法启动代理程序
    goto :eof
)

@REM Validate working directory path
if "!dest!" == "" (
    @echo [%ESC%[!info_color!m信息%ESC%[0m] 工作目录路径无效，无法启动代理程序
    goto :eof
)

@REM Ensure sing-box executable name is defined
if "!SINGBOX_EXE!" == "" set "SINGBOX_EXE=sing-box.exe"

@REM Enable silent administrator mode to avoid UAC prompts
call :enableSilentAdmin success

@REM Launch sing-box with configuration file and working directory
call :splitPath file_path file_name "!file!"
"!dest!\!SINGBOX_EXE!" run --config "!file_name!" --directory "!file_path!"

goto :eof


@REM ============================================================================
@REM Prepare and validate all required components
@REM Parameters: <changed> - Return variable (0=no changes, 1=changes detected)
@REM Purpose:    Downloads, updates, and validates all sing-box components
@REM Process:    Config update, server extraction, subscriptions, rule sets, downloads
@REM ============================================================================
:prepare <changed>
set "%~1=0"

@REM Update configuration files if needed
call :updateConfiguration

@REM Extract API server endpoint from configuration
call :extractServer singbox_server

@REM Determine dashboard directory name from configuration
call :extractDashboardInfo dashboard_name dashboard_url dashboard_path

@REM Update subscription providers unless excluded
if "!exclude_updates!" == "0" call :updateSubscriptions

@REM Update remote rule sets that persist to a local path
call :updateRuleSets

@REM Determine download URL for sing-box
call :checkAndGetSingboxDownloadUrl singbox_url

@REM Clean temporary workspace before downloads
call :cleanWorkspace "!TEMP_DIR!"

@REM Download and update dashboard files
call :updateDashboard "!dashboard_name!" "!dashboard_url!" "!dashboard_path!"

@REM Download sing-box executable and related files
call :downloadSingbox success "!singbox_url!"

@REM Check if any files changed using MD5 comparison
set "changed=0"
set "singbox_files=!SINGBOX_EXE!"
if exist "!TEMP_DIR!\!CRONET_DLL!" set "singbox_files=!singbox_files! !CRONET_DLL!"
if "!success!" == "1" call :detect changed "!singbox_files!"

@REM Return change status to caller
if "!changed!" == "1" set "%~1=!changed!"

goto :eof


@REM ============================================================================
@REM Configure autostart and auto-update features
@REM Purpose:    Sets up automatic startup, update checking, and desktop shortcuts
@REM Process:    Enables silent admin, displays hints, configures autostart/update
@REM ============================================================================
:postProcess
@REM Enable silent administrator mode to reduce UAC prompts
call :privilege "goto :enableSilentAdmin" 0

@REM Display configuration hints and proxy setup guidance
call :displayHints

@REM Add current script to user's environment path
call :addScriptToPath

@REM Configure automatic startup when user logs in
call :enableAutostart

@REM Configure automatic update checking
call :enableAutoUpdate

@REM Create desktop shortcut for easy access
call :createDesktopShortcut
goto :eof


@REM ============================================================================
@REM Extract sing-box API server endpoint from configuration
@REM Parameters: <r> - Return variable for server URL (format: http://host:port)
@REM Purpose:    Parses external_controller setting for dashboard access
@REM Method:     Uses regex to find external_controller in JSON config
@REM ============================================================================
:extractServer <result>
set "%~1="
@REM sing-box uses experimental.clash_api.external_controller setting
for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"\"external_controller\"[ ]*:" "!config_file!"') do (
    set "line=%%b"
    call :trim line "!line!"
    @REM Remove trailing comma and quotes from JSON value
    if "!line:~-1!" == "," set "line=!line:~0,-1!"
    @REM Remove quotes using string replacement
    set "line=!line:"=!"
    set "server_host=!line!"
)

@REM Add localhost if only port is specified (starts with colon)
if "!server_host!" NEQ "" if "!server_host:~0,1!" == ":" set "server_host=127.0.0.1!server_host!"

@REM Return complete HTTP URL for API access
set "%~1=http://!server_host!"
goto :eof


@REM ============================================================================
@REM Print captured check output using the same error style
@REM Parameters: <file> - Check output file
@REM Purpose:    Prints each non-empty line so users can see configuration errors
@REM ============================================================================
:printErrorOutput <file>
call :trim error_file "%~1"
if "!error_file!" == "" goto :eof
if not exist "!error_file!" goto :eof

set "line_count=0"
for /f "usebackq delims=" %%a in ("!error_file!") do (
    set /a line_count+=1
    @echo [%ESC%[!error_color!m错误%ESC%[0m] %%a
)
goto :eof


@REM ============================================================================
@REM Validate configuration with sing-box check before starting
@REM Parameters: <result> - Return variable (0=failed, 1=passed)
@REM Purpose:    Runs "sing-box check -c -D" and prints all errors on failure
@REM ============================================================================
:checkConfiguration <result>
set "%~1=0"

call :splitPath config_dir config_name "!config_file!"
if "!config_dir!" == "" set "config_dir=!dest!"
if "!config_dir!" == "" (
    @echo [%ESC%[!error_color!m错误%ESC%[0m] 配置文件工作目录%ESC%[!error_color!m无效%ESC%[0m，无法校验
    goto :eof
)

set "test_output=!TEMP_DIR!\singbox-check-output.txt"
del /f /q "!test_output!" >nul 2>nul

"!dest!\!SINGBOX_EXE!" check -c "!config_file!" -D "!config_dir!" --disable-color > "!test_output!" 2>&1
set "check_error=!errorlevel!"

if "!check_error!" NEQ "0" (
    @echo [%ESC%[!error_color!m错误%ESC%[0m] 网络代理启动%ESC%[!error_color!m失败%ESC%[0m，配置文件 "%ESC%[!warn_color!m!config_file!%ESC%[0m" 校验未通过
    set "has_check_output=0"
    if exist "!test_output!" (
        for %%a in ("!test_output!") do if %%~za GTR 0 set "has_check_output=1"
    )
    if "!has_check_output!" == "1" (
        call :printErrorOutput "!test_output!"
    ) else (
        @echo [%ESC%[!error_color!m错误%ESC%[0m] 未捕获到详细校验信息，请检查 %ESC%[!warn_color!m!SINGBOX_EXE!%ESC%[0m 或配置文件 "%ESC%[!warn_color!m!config_file!%ESC%[0m"
    )
    del /f /q "!test_output!" >nul 2>nul
    goto :eof
)

del /f /q "!test_output!" >nul 2>nul
set "%~1=1"
goto :eof


@REM ============================================================================
@REM Handle abnormal process after start
@REM Parameters: <action> - Return variable (redownload or empty)
@REM Purpose:    Re-downloads binary only under the attempt cap
@REM ============================================================================
:handleAbnormalStart <action>
set "%~1="

if "!MAX_REDOWNLOAD_ATTEMPTS!" == "" set "MAX_REDOWNLOAD_ATTEMPTS=2"
if "!redownload_attempts!" == "" set "redownload_attempts=0"

@echo [%ESC%[!error_color!m错误%ESC%[0m] 代理进程%ESC%[!error_color!m异常%ESC%[0m

if !redownload_attempts! GEQ !MAX_REDOWNLOAD_ATTEMPTS! (
    @echo [%ESC%[!error_color!m错误%ESC%[0m] 代理进程多次异常，已达到最大重新下载次数 %ESC%[!warn_color!m!MAX_REDOWNLOAD_ATTEMPTS!%ESC%[0m，请检查配置文件 "%ESC%[!warn_color!m!config_file!%ESC%[0m" 或手动更换 %ESC%[!warn_color!m!SINGBOX_EXE!%ESC%[0m
    taskkill /im "!SINGBOX_EXE!" /f >nul 2>nul
    goto :eof
)

set /a next_attempt=redownload_attempts+1
set "tips=[%ESC%[!warn_color!m警告%ESC%[0m] 代理进程%ESC%[!error_color!m异常%ESC%[0m，将第 %ESC%[!warn_color!m!next_attempt!%ESC%[0m/%ESC%[!warn_color!m!MAX_REDOWNLOAD_ATTEMPTS!%ESC%[0m 次重新下载 %ESC%[!warn_color!m!SINGBOX_EXE!%ESC%[0m，是否继续？(%ESC%[!warn_color!mY%ESC%[0m/%ESC%[!warn_color!mN%ESC%[0m) "
if "!ms_terminal!" == "1" (
    choice /t 5 /d y /n /m "!tips!"
) else (
    set /p "=!tips!" <nul
    choice /t 5 /d y /n
)
if !errorlevel! == 1 (
    set /a redownload_attempts+=1
    @echo [%ESC%[!info_color!m信息%ESC%[0m] 正在删除并重新下载 %ESC%[!warn_color!m!SINGBOX_EXE!%ESC%[0m（第 %ESC%[!warn_color!m!redownload_attempts!%ESC%[0m/%ESC%[!warn_color!m!MAX_REDOWNLOAD_ATTEMPTS!%ESC%[0m 次）
    del /f /q "!dest!\!SINGBOX_EXE!" >nul 2>nul
    set "%~1=redownload"
) else (
    @echo [%ESC%[!error_color!m错误%ESC%[0m] 代理程序启动%ESC%[!error_color!m失败%ESC%[0m，请检查代理程序 %ESC%[!warn_color!m!dest!\!SINGBOX_EXE!%ESC%[0m 是否完好
    taskkill /im "!SINGBOX_EXE!" /f >nul 2>nul
)
goto :eof


@REM ============================================================================
@REM Execute sing-box with privilege escalation wrapper
@REM Parameters: <should_check> - Whether to check/prepare components (0/1)
@REM Purpose:    Validates environment and starts sing-box with proper privileges
@REM Process:    Preparation, validation, configuration check, startup
@REM ============================================================================
:executeWrapper <should_check>
call :trim should_check "%~1"
if "!should_check!" == "" set "should_check=0"
if not exist "!dest!\!SINGBOX_EXE!" set "should_check=1"

if "!should_check!" == "1" (
    call :prepare changed
) else (
    call :extractServer singbox_server
    call :extractDashboardInfo dashboard_name _ _
)

@REM Verify config
if not exist "!dest!\!SINGBOX_EXE!" (
    @echo [%ESC%[!error_color!m错误%ESC%[0m] 网络代理启动%ESC%[!error_color!m失败%ESC%[0m，"%ESC%[!warn_color!m!dest!\!SINGBOX_EXE!%ESC%[0m" 缺失
    goto :eof
)

if not exist "!config_file!" (
    @echo [%ESC%[!error_color!m错误%ESC%[0m] 网络代理启动%ESC%[!error_color!m失败%ESC%[0m，配置文件 "%ESC%[!warn_color!m!config_file!%ESC%[0m" 不存在
    goto :eof
)

call :checkConfiguration check_ok
if "!check_ok!" NEQ "1" goto :eof

@REM Run sing-box with config
call :privilege "goto :execute !config_file! !dest!" !show_window!

for /l %%i in (1,1,6) do (
    @REM Check running status
    call :isProcessRunning status

    if "!status!" == "1" (
        @REM Wait briefly so FATAL exits can finish and memory can settle
        timeout /t 2 /nobreak >nul 2>nul
        call :isProcessRunning status
        if "!status!" == "0" goto :executeStartFailed

        @REM Abnormal detect
        call :abnormal state

        if "!state!" == "1" (
            call :handleAbnormalStart action
            if "!action!" == "redownload" goto :restartProgram
            goto :eof
        ) else (
            if "!dashboard_name!" == "" (
                @echo [%ESC%[!info_color!m信息%ESC%[0m] 代理程序启动%ESC%[!info_color!m成功%ESC%[0m
            ) else (
                set "message=[%ESC%[!info_color!m信息%ESC%[0m] 代理程序启动%ESC%[!info_color!m成功%ESC%[0m，可在浏览器中访问 %ESC%[!warn_color!m!singbox_server!/ui%ESC%[0m 查看详细信息"

                call :parseJsonValue secret "secret"
                if "!secret:~0,1!" == """" if "!secret:~-1!" == """" set "secret=!secret:~1,-1!"

                if "!secret!" NEQ "" if !secret! NEQ "" set "message=!message!，密码：%ESC%[!warn_color!m!secret!%ESC%[0m"

                @echo !message!
            )
            call :postProcess
            exit /b
        )
    ) else (
        @REM Waiting
        timeout /t 1 /nobreak >nul 2>nul
    )
)

:executeStartFailed
@echo [%ESC%[!error_color!m错误%ESC%[0m] 代理程序启动%ESC%[!error_color!m失败%ESC%[0m，请检查配置文件 "%ESC%[!warn_color!m!config_file!%ESC%[0m" 是否正确
goto :eof


@REM ============================================================================
@REM Extract proxy port from sing-box configuration
@REM Parameters: <r> - Return variable for proxy port number
@REM Purpose:    Finds listen_port in inbounds array for system proxy setup
@REM Default:    Returns 7890 if no port found in configuration
@REM ============================================================================
:extractProxyPort <result>
set "%~1=7890"
@REM Sing-box uses inbounds array, try to find mixed or http inbound
for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"\"listen_port\"[ ]*:" "!config_file!"') do (
    set "line=%%b"
    call :trim line "!line!"
    @REM Remove trailing comma
    if "!line:~-1!" == "," set "line=!line:~0,-1!"
    set "port=!line!"
    if "!port!" NEQ "" (
        set "%~1=!port!"
        goto :eof
    )
)

@REM Fallback to default port
set "%~1=7890"
goto :eof


@REM ============================================================================
@REM Display configuration hints and proxy setup guidance
@REM Purpose:    Provides user guidance for proxy configuration and TUN mode
@REM Process:    Checks TUN mode, configures system proxy, displays instructions
@REM ============================================================================
:displayHints
call :isTunEnabled enabled
call :getSystemProxy server
if "!enabled!" == "1" (
    if "!server!" NEQ "" (
        @echo [%ESC%[!warn_color!m提示%ESC%[0m] 程序正以 %ESC%[!warn_color!mtun%ESC%[0m 模式运行，系统代理设置已被禁用
        call :disableSystemProxy
    )
    goto :eof
)

call :extractProxyPort proxy_port
if "!proxy_port!" == "" set "proxy_port=7890"

@REM Set proxy
set "proxy_server=127.0.0.1:!proxy_port!"
if "!proxy_server!" NEQ "!server!" (
    set "tips=[%ESC%[!warn_color!m提示%ESC%[0m] 系统代理%ESC%[!error_color!m未配置%ESC%[0m，是否设置？(%ESC%[!warn_color!mY%ESC%[0m/%ESC%[!warn_color!mN%ESC%[0m) "
    if "!ms_terminal!" == "1" (
        choice /t 5 /d y /n /m "!tips!"
    ) else (
        set /p "=!tips!" <nul
        choice /t 5 /d y /n
    )
    if !errorlevel! == 1 call :enableSystemProxy "!proxy_server!"
)

@REM Hint
@echo [%ESC%[!warn_color!m提示%ESC%[0m] 如果无法正常使用网络代理，请到 "%ESC%[!warn_color!m设置 -^> 网络和 Internet -^> 代理%ESC%[0m" 确认是否已设置为 "%ESC%[!warn_color!m!proxy_server!%ESC%[0m"
goto :eof


@REM ============================================================================
@REM Add current script to user's environment path
@REM Purpose:    Adds the current script directory to user PATH environment variable
@REM Process:    Queries current PATH, checks if already exists, prompts user for confirmation, then adds to registry
@REM ============================================================================
:addScriptToPath
set "script_dir=%~dp0"
set "script_dir=!script_dir:~0,-1!"

@REM Query current path values
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "current_path=%%b"

@REM Check if already added
echo !current_path! | findstr /i /c:"!script_dir!" >nul
if !errorlevel! == 0 goto :eof

set "tips=[%ESC%[!warn_color!m提示%ESC%[0m] 是否将脚本路径 %ESC%[!warn_color!m!script_dir!%ESC%[0m 加入到用户 PATH 路径？(%ESC%[!warn_color!mY%ESC%[0m/%ESC%[!warn_color!mN%ESC%[0m) "

if "!msterminal!" == "1" (
    choice /t 5 /d y /n /m "!tips!"
) else (
    set /p "=!tips!" <nul
    choice /t 5 /d y /n
)

if !errorlevel! == 1 (
    @REM Rewrite Path Environment
    set "new_path=!current_path!;!script_dir!"
    reg add "HKCU\Environment" /v Path /t REG_EXPAND_SZ /d "!new_path!" /f >nul 2>nul

    @echo [%ESC%[!info_color!m信息%ESC%[0m] 添加 %ESC%[!warn_color!m!script_dir!%ESC%[0m 到用户 PATH 路径%ESC%[!info_color!m成功%ESC%[0m
) 

goto :eof


@REM ============================================================================
@REM Restart sing-box proxy program
@REM Purpose:    Safely stops and restarts the proxy service
@REM Process:    Checks status, kills process, verifies termination, restarts
@REM ============================================================================
:restartProgram
@REM Check if sing-box process is currently running
call :isProcessRunning status
if "!status!" == "1" (
    @REM Attempt to terminate the running process
    call :killProcessWrapper

    @REM Verify process was successfully terminated
    call :isProcessRunning status

    if "!status!" == "1" (
        @echo [%ESC%[!error_color!m错误%ESC%[0m] 无法关闭进程，代理程序重启%ESC%[!error_color!m失败%ESC%[0m，请到%ESC%[!error_color!m任务管理中心%ESC%[0m手动退出 %ESC%[!warn_color!m!SINGBOX_EXE!%ESC%[0m
        goto :eof
    )
)

@REM Start the proxy service
call :executeWrapper 0
exit /b


@REM ============================================================================
@REM Kill sing-box process with administrator privileges
@REM Purpose:    Safely terminates sing-box process and disables system proxy
@REM Process:    Checks status, elevates privileges, kills process, verifies
@REM ============================================================================
:killProcessWrapper
call :isProcessRunning status
if "!status!" == "0" goto :eof

@REM Execute kill operation with elevated privileges
call :privilege "goto :killProcess" 0

@REM Monitor process termination with retry mechanism
for /l %%i in (1,1,6) do (
    call :isProcessRunning status
    if "!status!" == "0" (
        @echo [%ESC%[!info_color!m信息%ESC%[0m] 代理程序关闭%ESC%[!info_color!m成功%ESC%[0m，可使用 "%ESC%[!warn_color!m!BATCH_NAME! -r%ESC%[0m" 命令重启

        @REM Disable system proxy settings when stopping service
        call :disableSystemProxy
        exit /b
    ) else (
        @REM Wait before next status check
        timeout /t 1 /nobreak >nul 2>nul
    )
)

@REM Report failure if process couldn't be terminated
@echo [%ESC%[!error_color!m错误%ESC%[0m] 代理程序关闭%ESC%[!error_color!m失败%ESC%[0m，请到%ESC%[!error_color!m任务管理中心%ESC%[0m手动退出 %ESC%[!warn_color!m!SINGBOX_EXE!%ESC%[0m
goto :eof


@REM ============================================================================
@REM Force terminate sing-box process
@REM Purpose:    Uses taskkill to forcefully stop sing-box process
@REM Process:    Finds process, kills it, enables silent admin, verifies termination
@REM ============================================================================
:killProcess
tasklist | findstr /i "!SINGBOX_EXE!" >nul 2>nul && taskkill /im "!SINGBOX_EXE!" /f >nul 2>nul
set "exit_code=!errorlevel!"

@REM Enable silent admin mode to prevent UAC prompts
call :enableSilentAdmin success

@REM Verify process termination with retry mechanism
for /l %%i in (1,1,6) do (
    @REM Check if process is still running
    call :isProcessRunning status
    if "!status!" == "0" (
        @echo [%ESC%[!info_color!m信息%ESC%[0m] 网络代理已关闭
        goto :eof
    ) else (
        @REM Wait for process to fully terminate
        timeout /t 1 /nobreak >nul 2>nul
    )
)

@echo [%ESC%[!error_color!m错误%ESC%[0m] 网络代理关闭失败，请到%ESC%[!error_color!m任务管理中心%ESC%[0m手动结束 %ESC%[!warn_color!m!SINGBOX_EXE!%ESC%[0m 进程
goto :eof


@REM ============================================================================
@REM Check if sing-box process is currently running
@REM Parameters: <r> - Return variable (0=not running, 1=running)
@REM Purpose:    Detects sing-box process status using tasklist command
@REM ============================================================================
:isProcessRunning <result>
tasklist | findstr /i "!SINGBOX_EXE!" >nul 2>nul && set "%~1=1" || set "%~1=0"
goto :eof


@REM ============================================================================
@REM Check if sing-box process is behaving abnormally
@REM Parameters: <r> - Return variable (0=normal, 1=abnormal)
@REM Purpose:    Detects abnormal memory usage that may indicate process issues
@REM Threshold:  Memory usage above 5120KB is considered abnormal
@REM ============================================================================
:abnormal <result>
set "%~1=1"

@REM Get memory usage from tasklist output
set "memory_usage="

for /f "tokens=5 delims= " %%a in ('tasklist /nh ^|findstr /i !SINGBOX_EXE!') do set "memory_usage=%%a"
if "!memory_usage!" NEQ "" (
    @REM Remove comma separators from memory value
    set "memory_usage=!memory_usage:,=!"

    @REM Consider process normal if memory usage is reasonable (>5MB)
    if !memory_usage! GTR 5120 (set "%~1=0")
)

goto :eof


@REM ============================================================================
@REM Remove leading and trailing whitespace from string
@REM Parameters: <r> - Return variable for trimmed string
@REM            <raw_text> - Input string to trim
@REM Purpose:    Utility function for cleaning up string values
@REM ============================================================================
:trim <result> <rawtext>
set "raw_text=%~2"
set "%~1="
if "!raw_text!" == "" goto :eof

@REM Remove leading whitespace using for loop
for /f "tokens=* delims= " %%a in ("!raw_text!") do set "raw_text=%%a"

@REM Remove trailing whitespace (limited to 10 iterations for performance)
for /l %%a in (1,1,10) do if "!raw_text:~-1!"==" " set "raw_text=!raw_text:~0,-1!"

set "%~1=!raw_text!"
goto :eof


@REM ============================================================================
@REM Apply GitHub proxy to URLs for faster downloads
@REM Parameters: <r> - Return variable for proxied URL
@REM            <raw_url> - Original GitHub URL to proxy
@REM Purpose:    Improves download speed by using GitHub proxy service
@REM ============================================================================
:applyGithubProxy <result> <rawurl>
set "%~1="

call :trim raw_url "%~2"
if "!raw_url!" == "" goto :eof

call :trim proxy_url "!custom_proxy_url!"
if "!proxy_url!" == "" (
    @REM GitHub proxy service for faster downloads in China. Apply the selected GitHub proxy list: https://github.com/XIU2/UserScript/blob/master/GithubEnhanced-High-Speed-Download.user.js
    set "proxy_urls[0]=https://ghfast.top"
    set "proxy_urls[1]=https://git.udrone.vip"
    set "proxy_urls[2]=https://gh.noki.icu"
    set "proxy_urls[3]=https://ghproxy.monkeyray.net"
    set "proxy_urls[4]=https://ghproxy.net"

    @REM Pick a random index in [0, 4]
    set /a "num=!random! %% 5"
    for %%N in (!num!) do set "ghProxy=!proxy_urls[%%N]!"
) else (
    set "ghProxy=!proxy_url!"
)

@REM Apply proxy prefix to various GitHub URL patterns
if "!raw_url:~0,18!" == "https://github.com" set "raw_url=!ghProxy!/!raw_url!"
if "!raw_url:~0,33!" == "https://raw.githubusercontent.com" set "raw_url=!ghProxy!/!raw_url!"
if "!raw_url:~0,34!" == "https://gist.githubusercontent.com" set "raw_url=!ghProxy!/!raw_url!"

set "%~1=!raw_url!"
goto :eof


@REM ============================================================================
@REM Remove leading and trailing quotes from string
@REM Parameters: <r> - Return variable for unquoted string
@REM            <str> - Input string that may have quotes
@REM Purpose:    Utility function for cleaning quoted JSON values
@REM ============================================================================
:removeQuotes <result> <str>
set "%~1="
call :trim str "%~2"
if "!str!" == "" goto :eof

if !str:~0^,1!!str:~-1! equ "" set "str=!str:~1,-1!"
if "!str:~0,1!!str:~0,1!" == "''" set "str=!str:~1!"
if "!str:~-1!!str:~-1!" == "''" set "str=!str:~0,-1!"
set "%~1=!str!"
goto :eof


@REM ============================================================================
@REM Parse JSON value by key from configuration file
@REM Parameters: <r> - Return variable for parsed value
@REM            <key> - JSON key to search for
@REM Purpose:    Extracts specific values from sing-box JSON configuration
@REM Method:     Uses regex to find key-value pairs and cleans the result
@REM ============================================================================
:parseJsonValue <r> <key>
set "%~1="
call :trim key "%~2"
if "!key!" == "" goto :eof

@REM Search for JSON key in configuration file
set "text="
for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"\"!key!\"[ ]*:" "!config_file!"') do set "text=%%b"

if "!text!" == "" goto :eof

@REM Clean up JSON value formatting
call :trim text "!text!"
@REM Remove trailing comma if present
if "!text:~-1!" == "," set "text=!text:~0,-1!"
@REM Remove surrounding quotes
call :removeQuotes text "!text!"

set "%~1=!text!"
goto :eof


@REM ============================================================================
@REM Update configuration from remote subscription if enabled
@REM Purpose:    Downloads and validates remote configuration updates
@REM Process:    Checks subscription file, downloads config, validates, backs up
@REM ============================================================================
:updateConfiguration
set "download_path=!TEMP_DIR!\singbox_config.json"
del /f /q "!download_path!" >nul 2>nul

@REM Extract remote configuration URL from subscription file
set "subscription_file=!dest!\subscriptions.txt"
set "subscription="

if exist "!subscription_file!" (
    @REM Find HTTP/HTTPS URLs in subscription file
    for /f "tokens=*" %%a in ('findstr /i /r /c:"^http.*://" "!subscription_file!"') do set "subscription=%%a"
    if "!subscription!" NEQ "" (
        call :trim subscription "!subscription!"
        @REM Skip commented lines (starting with #)
        if "!subscription:~0,1!" NEQ "#" set "remote_url=!subscription!"
    )
)

@REM Download remote configuration if enabled and URL available
if "!enable_remote_config!" == "1" if "!remote_url!" NEQ "" (
    @REM Download configuration file with retry and resume support
    !CURL_BINARY! --retry 5 --retry-max-time 90 -m 120 --connect-timeout 15 -H "User-Agent: sing-box" -s -L -C - "!remote_url!" > "!download_path!"
    if not exist "!download_path!" (
        @echo [%ESC%[!warn_color!m警告%ESC%[0m] 配置文件下载失败，如有需要，请重试或点击 %ESC%[!warn_color!m!remote_url!%ESC%[0m 手动下载并替换
        goto :eof
    )

    @REM Validate downloaded configuration if sing-box executable exists
    if exist "!dest!\!SINGBOX_EXE!" (
        @REM Check file size to ensure it's not empty or error page
        for %%a in ("!download_path!") do set "file_size=%%~za"
        if !file_size! LSS 32 (
            del /f /q "!download_path!" >nul 2>nul
            @echo [%ESC%[!warn_color!m警告%ESC%[0m] 配置文件下载失败，如有需要，请重试或点击 %ESC%[!warn_color!m!remote_url!%ESC%[0m 手动下载并替换
            exit /b 1
        )

        @REM Validate configuration syntax using sing-box check command
        "!dest!\!SINGBOX_EXE!" check --config "!download_path!" >nul 2>nul

        @REM Handle configuration validation failure
        if !errorlevel! NEQ 0 (
            @echo [%ESC%[!error_color!m错误%ESC%[0m] 配置文件 %ESC%[!warn_color!m!remote_url!%ESC%[0m 存在错误，无法更新
            del /f /q "!download_path!" >nul 2>nul
            exit /b 1
        )
    )

    @REM Compare downloaded config with existing using MD5 hash
    call :compareFileMd5 diff "!download_path!" "!config_file!"
    if "!diff!" == "0" (
        @REM Files are identical, no update needed
        del /f /q "!download_path!" >nul 2>nul
        goto :eof
    )

    @REM Backup existing configuration before replacing
    set "backup_file=config.json.bak"
    @echo [%ESC%[!info_color!m信息%ESC%[0m] 发现较新配置，原有文件将备份为 %ESC%[!warn_color!m!dest!\!backup_file!%ESC%[0m

    @REM Remove old backup and create new one
    del /f /q "!dest!\!backup_file!" >nul 2>nul
    ren "!config_file!" !backup_file!

    @REM Replace configuration with downloaded version
    move "!download_path!" "!config_file!" >nul 2>nul
)
goto :eof


@REM ============================================================================
@REM Extract dashboard directory path from configuration
@REM Parameters: <r> - Return variable for dashboard directory path
@REM Purpose:    Finds external_ui setting for dashboard location
@REM Default:    Uses "dashboard" if no path specified in configuration
@REM ============================================================================
:extractDashboardInfo <name> <url> <raw_folder_name>
set "%~1="
set "%~2="
set "%~3="

if not exist "!config_file!" goto :eof

@REM Extract dashboard download url from configuration
call :parseJsonValue url "external_ui_download_url"
if "!url!" == "" (
    @REM Fallback: search for external_ui_download_url in experimental.clash_api section
    for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"\"external_ui_download_url\"[ ]*:" "!config_file!"') do (
        set "line=%%b"
        call :trim line "!line!"
        
        @REM Clean JSON value formatting
        if "!line:~-1!" == "," set "line=!line:~0,-1!"
        call :removeQuotes line "!line!"

        @REM Validate URL format
        set "is_valid=0"
        if /i "!line:~0,8!" == "https://" set "is_valid=1"
        if /i "!line:~0,7!" == "http://" set "is_valid=1"

        if "!is_valid!" == "1" set "url=!line!"
    )
)

@REM Extract dashboard folder name from configuration
call :parseJsonValue name "external_ui"
if "!name!" == "" (
    @REM Fallback: search for external_ui in experimental.clash_api section
    for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"\"external_ui\"[ ]*:" "!config_file!"') do (
        set "line=%%b"
        call :trim line "!line!"

        @REM Clean JSON value formatting
        if "!line:~-1!" == "," set "line=!line:~0,-1!"
        call :removeQuotes line "!line!"
        set "name=!line!"
    )
)

if "!url!" NEQ "" if "!name!" == "" set "name=!DEFAULT_DASHBOARD_NAME!"
if "!url!" == "" if "!name!" NEQ "" set "url=!DEFAULT_DASHBOARD_URL!"

set "raw_folder_name="

if "!url!" NEQ "" (
    @REM If url contains zashboard, set raw_folder_name to zashboard-gh-pages
    echo "!url!" | findstr /i /r /c:"zashboard" >nul && set "raw_folder_name=zashboard-gh-pages"
    @REM If url contains metacubexd, set raw_folder_name to metacubexd-gh-pages
    echo "!url!" | findstr /i /r /c:"metacubexd" >nul && set "raw_folder_name=metacubexd-gh-pages"
    @REM If url contains yacd, set raw_folder_name to yacd-gh-pages
    echo "!url!" | findstr /i /r /c:"yacd" >nul && set "raw_folder_name=yacd-gh-pages"
)

if "!raw_folder_name!" == "" (
    @echo [%ESC%[!warn_color!m警告%ESC%[0m] 无法识别控制面板类型，仅支持 ZashBoard、MetaCubeXD 和 Yacd
    goto :eof
)

@REM Apply GitHub proxy to dashboard download URL
call :applyGithubProxy url "!url!"

set "%~1=!name!"
set "%~2=!url!"
set "%~3=!raw_folder_name!"
goto :eof


@REM ============================================================================
@REM Verify file contains required content
@REM Parameters: <r> - Return variable (0=failed, 1=success)
@REM            <file> - File path to check
@REM            <check> - Content pattern to search for
@REM Purpose:    Validates file contains expected configuration elements
@REM ============================================================================
:verify <result> <file> <check>
set "%~1=0"
call :trim candidate "%~2"
if not exist "!candidate!" goto :eof

call :trim check "%~3"

if "!check!" == "" (
    set "%~1=1"
    goto :eof
)

set "text="
for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"!check!:[ ]*" "!candidate!"') do set "text=%%a"

@REM Not required
call :trim text "!text!"

if "!text!" == "!check!" set "%~1=1"
goto :eof


@REM ============================================================================
@REM Update dashboard to latest version
@REM Purpose:    Downloads and installs latest dashboard files
@REM Process:    Downloads ZIP, validates, extracts, renames, replaces existing dashboard
@REM ============================================================================
:updateDashboard <name> <url> <raw_folder_name>
call :trim name "%~1"
call :trim url "%~2"
call :trim raw_folder_name "%~3"
call :removeQuotes url "!url!"

if "!url!" == "" (
    @echo [%ESC%[!info_color!m信息%ESC%[0m] 控制面板%ESC%[!warn_color!m未启用%ESC%[0m，跳过更新
    goto :eof
)

if "!name!" == "" (
    @echo [%ESC%[!error_color!m错误%ESC%[0m] 无法获取控制面板保存路径
    goto :eof
)

@REM Resolve dashboard path relative to dest when config uses a relative external_ui
call :convertToAbsolutePath dashboard_dest "!name!"
if "!dashboard_dest!" == "" (
    @echo [%ESC%[!error_color!m错误%ESC%[0m] 无法获取控制面板保存路径
    goto :eof
)
call :normalizeFilePath dashboard_dest "!dashboard_dest!"

call :createDirectories success "!dashboard_dest!"

@echo [%ESC%[!info_color!m信息%ESC%[0m] 开始下载并更新控制面板

@REM Prefer a larger minimum size so tiny proxy/HTML error pages are rejected early
call :downloadWithRetry "!url!" "!TEMP_DIR!\dashboard.zip" 2048

if not exist "!TEMP_DIR!\dashboard.zip" (
    @echo [%ESC%[!warn_color!m警告%ESC%[0m] 控制面板下载失败，原始链接："!url!"
    if "!last_download_url!" NEQ "" if /i "!last_download_url!" NEQ "!url!" (
        @echo [%ESC%[!warn_color!m警告%ESC%[0m] 实际下载链接："!last_download_url!"
    )
    goto :eof
)

@REM Validate the payload is a real archive, not an HTML/error page saved as .zip
call :isZipArchive valid "!TEMP_DIR!\dashboard.zip" 2048
if "!valid!" == "0" (
    @echo [%ESC%[!warn_color!m警告%ESC%[0m] 控制面板下载内容%ESC%[!error_color!m无效%ESC%[0m，可能是代理返回了错误页面，原始链接："!url!"
    if "!last_download_url!" NEQ "" if /i "!last_download_url!" NEQ "!url!" (
        @echo [%ESC%[!warn_color!m警告%ESC%[0m] 实际下载链接："!last_download_url!"
    )
    del /f /q "!TEMP_DIR!\dashboard.zip" >nul 2>nul
    goto :eof
)

@REM Resolve base path and directory name before extraction
call :splitPath base_path folder_name "!dashboard_dest!"
if "!base_path!" == "" (
    @echo [%ESC%[!error_color!m错误%ESC%[0m] 无法获取控制面板保存路径
    del /f /q "!TEMP_DIR!\dashboard.zip" >nul 2>nul
    goto :eof
)

if "!folder_name!" == "" (
    @echo [%ESC%[!error_color!m错误%ESC%[0m] 无法获取控制面板文件夹名
    del /f /q "!TEMP_DIR!\dashboard.zip" >nul 2>nul
    goto :eof
)

@REM Clear stale extract directories from previous attempts
if exist "!TEMP_DIR!\!raw_folder_name!" rd /s /q "!TEMP_DIR!\!raw_folder_name!" >nul 2>nul
if /i "!folder_name!" NEQ "!raw_folder_name!" if exist "!TEMP_DIR!\!folder_name!" rd /s /q "!TEMP_DIR!\!folder_name!" >nul 2>nul

@REM Extract the archive (zip-compatible, quoted destination path)
call :extractArchive dashboard_extracted "!TEMP_DIR!\dashboard.zip" "!TEMP_DIR!"
del /f /q "!TEMP_DIR!\dashboard.zip" >nul 2>nul
if "!dashboard_extracted!" == "0" (
    @echo [%ESC%[!warn_color!m警告%ESC%[0m] 控制面板压缩包%ESC%[!error_color!m解压失败%ESC%[0m，原始链接："!url!"
    if "!last_download_url!" NEQ "" if /i "!last_download_url!" NEQ "!url!" (
        @echo [%ESC%[!warn_color!m警告%ESC%[0m] 实际下载链接："!last_download_url!"
    )
    goto :eof
)

if not exist "!TEMP_DIR!\!raw_folder_name!" (
    @echo [%ESC%[!warn_color!m警告%ESC%[0m] 控制面板解压后未找到目录 "%ESC%[!warn_color!m!raw_folder_name!%ESC%[0m"
    goto :eof
)

@REM Rename the extracted directory to the configured dashboard folder name
if /i "!raw_folder_name!" NEQ "!folder_name!" (
    ren "!TEMP_DIR!\!raw_folder_name!" "!folder_name!" >nul 2>nul
    if not exist "!TEMP_DIR!\!folder_name!" (
        @echo [%ESC%[!warn_color!m警告%ESC%[0m] 控制面板目录重命名%ESC%[!error_color!m失败%ESC%[0m："!raw_folder_name!" -^> "!folder_name!"
        if exist "!TEMP_DIR!\!raw_folder_name!" rd /s /q "!TEMP_DIR!\!raw_folder_name!" >nul 2>nul
        goto :eof
    )
)

@REM Ensure extracted content is non-empty before replacing the installed dashboard
dir /a /s /b "!TEMP_DIR!\!folder_name!" >nul 2>nul
if errorlevel 1 (
    @echo [%ESC%[!warn_color!m警告%ESC%[0m] 控制面板解压结果%ESC%[!error_color!m为空%ESC%[0m，原始链接："!url!"
    if exist "!TEMP_DIR!\!folder_name!" rd /s /q "!TEMP_DIR!\!folder_name!" >nul 2>nul
    goto :eof
)

call :replaceDirectory "!TEMP_DIR!\!folder_name!" "!dashboard_dest!"
if exist "!dashboard_dest!\index.html" (
    @echo [%ESC%[!info_color!m信息%ESC%[0m] 控制面板已更新至最新版本
) else (
    @echo [%ESC%[!warn_color!m警告%ESC%[0m] 控制面板更新%ESC%[!error_color!m失败%ESC%[0m，目标目录缺少 index.html："!dashboard_dest!"
)
goto :eof


@REM ============================================================================
@REM Replace directory with new content
@REM Parameters: <src> - Source directory to copy from
@REM            <dest> - Destination directory to replace
@REM Purpose:    Safely replaces directory contents with new files
@REM ============================================================================
:replaceDirectory <source_dir> <target_dir>
set "source_dir=%~1"
set "target_dir=%~2"

if "!source_dir!" == "" (
    @echo [%ESC%[!warn_color!m警告%ESC%[0m] 移动失败，源文件夹路径为空
    goto :eof
)

if "!target_dir!" == "" (
    @echo [%ESC%[!warn_color!m警告%ESC%[0m] 移动失败，目标路径为空
    goto :eof
)

if not exist "!source_dir!" (
    @echo [%ESC%[!error_color!m错误%ESC%[0m] 文件夹移动失败，源文件夹不存在："!source_dir!"
    goto :eof
)

@REM Remove existing target directory if it exists
if exist "!target_dir!" rd "!target_dir!" /s /q >nul 2>nul

@REM Copy source directory to destination with all subdirectories
xcopy "!source_dir!" "!target_dir!" /h /e /y /q /i >nul 2>nul

@REM Clean up source directory after successful copy
rd "!source_dir!" /s /q >nul 2>nul
goto :eof


@REM ============================================================================
@REM Clean temporary workspace files and directories
@REM Parameters: [directory] - Optional directory path (defaults to TEMP_DIR)
@REM Purpose:    Removes temporary files created during download and extraction
@REM ============================================================================
:cleanWorkspace
set "directory=%~1"
if "!directory!" == "" set "directory=!TEMP_DIR!"

if exist "!directory!\sing-box.zip" del /f /q "!directory!\sing-box.zip" >nul
if exist "!directory!\!SINGBOX_EXE!" del /f /q "!directory!\!SINGBOX_EXE!" >nul
if exist "!directory!\!CRONET_DLL!" del /f /q "!directory!\!CRONET_DLL!" >nul
if exist "!directory!\singbox" rd /s /q "!directory!\singbox" >nul 2>nul

if "!SINGBOX_EXE!" NEQ "" (
    if exist "!directory!\!SINGBOX_EXE!" del /f /q "!directory!\!SINGBOX_EXE!" >nul
)

@REM Delete directory
if "!dashboard_path!" NEQ "" (
    if exist "!directory!\!dashboard_path!" rd "!directory!\!dashboard_path!" /s /q >nul
)

if "!dashboard_name!" == "" goto :eof
if exist "!directory!\!dashboard_name!.zip" del /f /q "!directory!\!dashboard_name!.zip" >nul
if exist "!directory!\!dashboard_name!" rd "!directory!\!dashboard_name!" /s /q >nul 2>nul
goto :eof


@REM ============================================================================
@REM Normalize file path by replacing path separators
@REM Parameters: <r> - Return variable for normalized path
@REM            <directory> - Input directory path to normalize
@REM Purpose:    Converts mixed path separators to Windows standard backslashes
@REM ============================================================================
:normalizeFilePath <result> <directory>
set "%~1="
call :trim directory "%~2"

if "!directory!" == "" goto :eof

@REM Replace double backslashes with single backslashes
set "directory=!directory:\\=\!"

@REM Replace forward slashes with backslashes for Windows compatibility
set "directory=!directory:/=\!"

@REM Remove trailing backslash if present
if "!directory:~-1!" == "\" set "directory=!directory:~0,-1!"
set "%~1=!directory!"
goto :eof


@REM ============================================================================
@REM Terminate script with error cleanup
@REM Purpose:    Handles script termination when critical components are missing
@REM Process:    Reports error, cleans workspace, exits with error code
@REM ============================================================================
:terminate
@echo [%ESC%[!error_color!m错误%ESC%[0m] 更新失败，代理程序、域名及 IP 地址数据库或控制面板缺失
call :cleanWorkspace "!TEMP_DIR!"
exit /b 1
goto :eof


@REM ============================================================================
@REM Close proxy service with user confirmation
@REM Purpose:    Safely shuts down proxy service with user confirmation
@REM Process:    Checks status, prompts user, calls kill wrapper
@REM ============================================================================
:closeProxy
call :isProcessRunning status
if "!status!" == "0" (
    @echo [%ESC%[!info_color!m信息%ESC%[0m] 网络代理程序%ESC%[!warn_color!m未运行%ESC%[0m，无须关闭
    goto :eof
)

set "tips=[%ESC%[!warn_color!m警告%ESC%[0m] 此操作将会关闭代理网络，是否继续？(%ESC%[!warn_color!mY%ESC%[0m/%ESC%[!warn_color!mN%ESC%[0m) "
if "!ms_terminal!" == "1" (
    choice /t 6 /d y /n /m "!tips!"
) else (
    set /p "=!tips!" <nul
    choice /t 6 /d y /n
)
if !errorlevel! == 2 exit /b 1
goto :killProcessWrapper


@REM ============================================================================
@REM Initialize ANSI escape sequences for colored console output
@REM Purpose:    Sets up ESC variable for colored text display in console
@REM Method:     Uses prompt command to capture escape character
@REM ============================================================================
:setESC
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do (
  set ESC=%%b
  exit /b 0
)
exit /b 0


@REM ============================================================================
@REM Enable Windows system proxy settings
@REM Parameters: <server> - Proxy server address (format: host:port)
@REM Purpose:    Configures Windows to use sing-box as system proxy
@REM Registry:   Modifies Internet Settings registry keys
@REM ============================================================================
:enableSystemProxy <server>
call :trim server "%~1"
if "!server!" == "" goto :eof

reg add "!PROXY_REG_PATH!" /v ProxyEnable /t REG_DWORD /d 1 /f >nul 2>nul
reg add "!PROXY_REG_PATH!" /v ProxyServer /t REG_SZ /d "!server!" /f >nul 2>nul
reg add "!PROXY_REG_PATH!" /v ProxyOverride /t REG_SZ /d "<local>" /f >nul 2>nul
goto :eof


@REM ============================================================================
@REM Disable Windows system proxy settings
@REM Purpose:    Removes proxy configuration from Windows Internet Settings
@REM Registry:   Clears proxy-related registry keys to restore direct connection
@REM ============================================================================
:disableSystemProxy
reg add "!PROXY_REG_PATH!" /v ProxyServer /t REG_SZ /d "" /f >nul 2>nul
reg add "!PROXY_REG_PATH!" /v ProxyEnable /t REG_DWORD /d 0 /f >nul 2>nul
reg add "!PROXY_REG_PATH!" /v ProxyOverride /t REG_SZ /d "" /f >nul 2>nul
goto :eof


@REM ============================================================================
@REM Query current system proxy status from registry
@REM Parameters: <r> - Return variable for proxy server address
@REM Purpose:    Retrieves current proxy settings from Windows registry
@REM Registry:   Reads ProxyServer value from Internet Settings
@REM ============================================================================
:getSystemProxy <result>
set "%~1="

@REM Enabled
call :queryRegistry enable "!PROXY_REG_PATH!" "ProxyEnable" "REG_DWORD"
if "!enable!" NEQ "0x1" goto :eof

@REM Proxy server
call :queryRegistry server "!PROXY_REG_PATH!" "ProxyServer" "REG_SZ"
if "!server!" NEQ "" set "%~1=!server!"
goto :eof


@REM ============================================================================
@REM Enable automatic startup when user logs in
@REM Purpose:    Configures sing-box to start automatically on system boot
@REM Process:    Creates VBS script and registers it in Windows startup registry
@REM ============================================================================
:enableAutostart
call :queryRegistry exe_name "!AUTOSTART_REG_PATH!" "!APPLICATION_NAME!" "REG_SZ"
if "!startup_script!" NEQ "!exe_name!" (
    set "tips=[%ESC%[!warn_color!m提示%ESC%[0m] 是否允许网络代理程序开机自启？(%ESC%[!warn_color!mY%ESC%[0m/%ESC%[!warn_color!mN%ESC%[0m) "
    if "!ms_terminal!" == "1" (
        choice /t 5 /d y /n /m "!tips!"
    ) else (
        set /p "=!tips!" <nul
        choice /t 5 /d y /n
    )
    if !errorlevel! == 2 exit /b 1

    call :enableSilentAdmin success
    if "!success!" == "0" (
        @echo [%ESC%[!error_color!m错误%ESC%[0m] 权限受限，%ESC%[!error_color!m无法设置%ESC%[0m开机自启
        goto :eof
    )

    call :generateStartupVbs "!startup_script!" "-r"
    call :registerExecutable success "!startup_script!"
    if "!success!" == "1" (
        @echo [%ESC%[!info_color!m信息%ESC%[0m] 网络代理程序开机自启设置%ESC%[!info_color!m完成%ESC%[0m
    ) else (
        @echo [%ESC%[!error_color!m错误%ESC%[0m] 网络代理程序开机自启设置%ESC%[!error_color!m失败%ESC%[0m
    )
)

goto :eof


@REM ============================================================================
@REM Disable automatic startup on system boot
@REM Parameters: <r> - Return variable (0=failed, 1=success)
@REM Purpose:    Removes sing-box from Windows startup registry entries
@REM ============================================================================
:disableAutostart <result>
set "%~1=0"
call :queryRegistry exe_name "!AUTOSTART_REG_PATH!" "!APPLICATION_NAME!" "REG_SZ"

if "!exe_name!" == "" (
    set "%~1=1"
) else (
    set "should_delete=1"
    if "!startup_script!" NEQ "!exe_name!" (
        set "tips=[%ESC%[!warn_color!m警告%ESC%[0m] 发现相同名字但执行路径不同的配置，是否继续？(%ESC%[!warn_color!mY%ESC%[0m/%ESC%[!warn_color!mN%ESC%[0m) "
        if "!ms_terminal!" == "1" (
            choice /t 5 /d n /n /m "!tips!"
        ) else (
            set /p "=!tips!" <nul
            choice /t 5 /d n /n
        )
        if !errorlevel! == 2 set "should_delete=0"
    )
    if "!should_delete!" == "1" (
        reg delete "!AUTOSTART_REG_PATH!" /v "!APPLICATION_NAME!" /f >nul 2>nul
        if "!errorlevel!" == "0" set "%~1=1"

        @REM Disable
        reg delete "!STARTUP_APPROVED!" /v "!APPLICATION_NAME!" /f >nul 2>nul
    )
)
goto :eof


@REM ============================================================================
@REM Enable automatic update checking via scheduled tasks
@REM Parameters: <refresh> - Force refresh flag (0=check existing, 1=recreate)
@REM Purpose:    Sets up Windows scheduled task for automatic updates
@REM ============================================================================
:enableAutoUpdate <refresh>
call :trim refresh "%~1"
if "!refresh!" == "" set "refresh=0"
set "task_name=SingBoxUpdater"

call :getTaskStatus ready "!task_name!"
if "!refresh!" == "1" set "ready=0"

if "!ready!" == "0" (
    set "tips=[%ESC%[!warn_color!m提示%ESC%[0m] 是否设置自动检查更新代理应用及规则？(%ESC%[!warn_color!mY%ESC%[0m/%ESC%[!warn_color!mN%ESC%[0m) "
    if "!ms_terminal!" == "1" (
        choice /t 5 /d n /n /m "!tips!"
    ) else (
        set /p "=!tips!" <nul
        choice /t 5 /d y /n
    )
    if !errorlevel! == 2 exit /b 1

    @REM Generate VBS for update
    call :generateUpdateVbs

    @REM Delete old task
    call :deleteTask success "!task_name!"

    @REM Create new task
    call :createTask success "!update_script!" "!task_name!"
    if "!success!" == "1" (
        @echo [%ESC%[!info_color!m信息%ESC%[0m] 自动检查更新设置%ESC%[!info_color!m成功%ESC%[0m
    ) else (
        @echo [%ESC%[!error_color!m错误%ESC%[0m] 自动检查更新设置%ESC%[!error_color!m失败%ESC%[0m
    )
)
goto :eof


@REM ============================================================================
@REM Generate VBScript file for automatic updates
@REM Purpose:    Creates VBS script that calls this batch file with update flag
@REM Output:     Creates update.vbs in destination directory
@REM ============================================================================
:generateUpdateVbs
set "operation=-u"

@REM Generate and write to file
call :generateStartupVbs "!update_script!" "!operation!"

goto :eof


@REM ============================================================================
@REM Create Windows scheduled task for automatic operations
@REM Parameters: <r> - Return variable (0=failed, 1=success)
@REM            <path> - Executable path for the task
@REM            <taskname> - Name of the scheduled task
@REM Purpose:    Creates daily recurring task with user-specified time
@REM ============================================================================
:createTask <result> <path> <taskname>
set "%~1=0"
call :trim exe_name "%~2"
if "!exe_name!" == "" goto :eof

call :trim task_name "%~3"
if "!task_name!" == "" goto :eof

@REM Input start time
call :getScheduleTime start_time

@REM Create
schtasks /create /tn "!task_name!" /tr "!exe_name!" /sc daily /mo 1 /ri 480 /st !start_time! /du 0012:00 /f >nul 2>nul
if "!errorlevel!" == "0" set "%~1=1"
goto :eof


@REM ============================================================================
@REM Prompt user for scheduled task start time
@REM Parameters: <time> - Return variable for time in HH:MM format
@REM Purpose:    Gets user input for when scheduled task should run daily
@REM Default:    Uses 09:15 if user doesn't specify custom time
@REM ============================================================================
:getScheduleTime <time>
set "%~1="
set "user_time="
set "default_time=09:15"

@REM Choose
set "tips=[%ESC%[!warn_color!m提示%ESC%[0m] 正在设置更新时间，默认为 %ESC%[!warn_color!m09:15%ESC%[0m，是否需要修改？(%ESC%[!warn_color!mY%ESC%[0m/%ESC%[!warn_color!mN%ESC%[0m) "
if "!ms_terminal!" == "1" (
    choice /c yn /n /d n /t 5 /m "!tips!"
) else (
    set /p "=!tips!" <nul
    choice /c yn /n /d n /t 5
)

if !errorlevel! == 2 (
    set "%~1=!default_time!"
    goto :eof
)

@REM Prompt user input time
call :promptUserInput input_time "!default_time!" 0
set "%~1=!input_time!"
goto :eof


@REM ============================================================================
@REM Prompt user for input with validation and retry
@REM Parameters: <r> - Return variable for validated input
@REM            <default> - Default value if user provides no input
@REM            <retry> - Retry flag (1=show error message)
@REM Purpose:    Gets user input with validation and retry on invalid input
@REM ============================================================================
:promptUserInput <result> <default> <retry>
set "%~1="

set "tips=[%ESC%[!warn_color!m提示%ESC%[0m] 请输入一个格式为 %ESC%[!warn_color!mHH:MM%ESC%[0m 的 %ESC%[!warn_color!m24小时制%ESC%[0m 时间："

call :trim retry_flag "%~3"
if "!retry_flag!" == "1" (
    set "tips=[%ESC%[!error_color!m错误%ESC%[0m] 输入的时间%ESC%[!error_color!m无效%ESC%[0m或%ESC%[!error_color!m格式不正确%ESC%[0m，请重新输入："
    set "retry_flag=0"
)

set /p "user_input=!tips!"
if not defined user_input (set "user_input=%~2")

@REM Validate user input
call :validateTimeInput "%~1" "%~2" "!user_input!"
goto :eof


@REM ============================================================================
@REM Validate user input time format and values
@REM Parameters: <r> - Return variable for validated time
@REM            <default> - Default time to use on validation failure
@REM            <input> - User input time string to validate
@REM Purpose:    Validates HH:MM format and reasonable time values (0-23:0-59)
@REM ============================================================================
:validateTimeInput <result> <default> <input>
set "%~1="

@REM Trim user input
call :trim user_time "%~3"

set "valid_flag=0"
for /f "tokens=1-2 delims=:" %%a in ("!user_time!") do (
    set "hours=%%a" 2>nul
    set "minutes=%%b" 2>nul

    call :isNumber hour_flag !hours!
    call :isNumber minute_flag !minutes!

    if !hour_flag! == 1 if !minute_flag! == 1 if !hours! lss 24 if !minutes! lss 60 if !hours! geq 0 if !minutes! geq 0 (
        set "valid_flag=1"
    )
)

if "!valid_flag!" == "0" (call :promptUserInput "%~1" "%~2" 1) else (set "%~1=!user_time!")
goto :eof


@REM ============================================================================
@REM Check if variable contains a valid two-digit number
@REM Parameters: <r> - Return variable (0=invalid, 1=valid)
@REM            <variable> - String to validate as number
@REM Purpose:    Validates input is a two-digit number (00-99)
@REM ============================================================================
:isNumber <result> <variable>
set "%~1=0"
call :trim variable "%~2"

@echo !variable! | findstr /r /c:"^[0-9][0-9][ ]*$" >nul 2>nul && (set "%~1=1")

goto :eof


@REM ============================================================================
@REM Query Windows scheduled task status
@REM Parameters: <status> - Return variable (0=not ready, 1=ready)
@REM            <taskname> - Name of scheduled task to check
@REM Purpose:    Checks if scheduled task exists and is in Ready state
@REM ============================================================================
:getTaskStatus <status> <taskname>
set "%~1=0"
call :trim task_name "%~2"
if "!task_name!" == "" goto :eof

@REM Query
schtasks /query /tn "!task_name!" >nul 2>nul
if "!errorlevel!" NEQ "0" goto :eof

@REM Compare script path is same as current path
set "command_path="
for /f "tokens=3 delims=<>" %%a in ('schtasks /query /tn "!task_name!" /xml ^| findstr "<Command>"') do set "command_path=%%a"
call :trim command_path "!command_path!"

if "!command_path!" NEQ "!update_script!" goto :eof

set "status="
for /f "usebackq skip=3 tokens=4" %%a in (`schtasks /query /tn "!task_name!"`) do set "status=%%a"
call :trim status "!status!"

if "!status!" == "Ready" set "%~1=1"

goto :eof


@REM ============================================================================
@REM Delete Windows scheduled task
@REM Parameters: <r> - Return variable (0=failed, 1=success)
@REM            <taskname> - Name of scheduled task to delete
@REM Purpose:    Removes scheduled task with elevated privileges if needed
@REM ============================================================================
:deleteTask <result> <taskname>
set "%~1=0"
call :trim task_name "%~2"
if "!task_name!" == "" goto :eof

schtasks /query /tn "!task_name!" >nul 2>nul
@REM Not found
if "!errorlevel!" NEQ "0" (
    set "%~1=1"
    goto :eof
)

@REM Remove
call :privilege "goto :cancelScheduledTask !task_name!" 0

@REM Get delete status
for /l %%i in (1,1,5) do (
    schtasks /query /tn "!task_name!" >nul 2>nul
    if "!errorlevel!" == "0" (
        @REM Wait
        timeout /t 1 /nobreak >nul 2>nul
    ) else (
        set "%~1=1"
        exit /b
    )
)
goto :eof


@REM ============================================================================
@REM Remove scheduled task with administrator privileges
@REM Parameters: <taskname> - Name of scheduled task to remove
@REM Purpose:    Forcefully deletes scheduled task and enables silent admin mode
@REM ============================================================================
:cancelScheduledTask <taskname>
@REM Delete
schtasks /delete /tn "%~1" /f  >nul 2>nul

@REM Get administrator privileges
call :enableSilentAdmin result
goto :eof


@REM ============================================================================
@REM Register executable in Windows startup registry
@REM Parameters: <r> - Return variable (0=failed, 1=success)
@REM            <path> - Path to executable file to register
@REM Purpose:    Adds application to Windows startup registry for auto-start
@REM ============================================================================
:registerExecutable <result> <path>
set "%~1=0"
call :trim exe_name "%~2"
if "!exe_name!" == "" goto :eof
if not exist "!exe_name!" goto :eof

@REM Delete
reg delete "!AUTOSTART_REG_PATH!" /v "!APPLICATION_NAME!" /f >nul 2>nul

@REM Register
reg add "!AUTOSTART_REG_PATH!" /v "!APPLICATION_NAME!" /t "REG_SZ" /d "!exe_name!" >nul 2>nul
if "!errorlevel!" NEQ "0" goto :eof

@REM Approved
reg delete "!STARTUP_APPROVED!" /v "!APPLICATION_NAME!" /f >nul 2>nul

@REM Register
reg add "!STARTUP_APPROVED!" /v "!APPLICATION_NAME!" /t "REG_BINARY" /d "02 00 00 00 00 00 00 00 00 00 00 00" >nul 2>nul

if "!errorlevel!" == "0" set "%~1=1"
goto :eof


@REM ============================================================================
@REM Generate VBScript file for startup operations
@REM Parameters: <path> - Output path for VBS file
@REM            <operation> - Command line operation to execute
@REM Purpose:    Creates VBS script that runs batch file with specified operation
@REM ============================================================================
:generateStartupVbs <path> <operation>
call :trim start_script "%~1"
if "!start_script!" == "" goto :eof

call :trim operation "%~2"
if "!operation!" == "" goto :eof

@echo set ws = WScript.CreateObject^("WScript.Shell"^) > "!start_script!"

@echo ws.Run "%~dp0!BATCH_NAME! !operation! -w !dest! -c !config_file!", 0 >> "!start_script!"
@echo set ws = Nothing >> "!start_script!"
goto :eof


@REM ============================================================================
@REM Determine if Windows OS is Home edition
@REM Parameters: <r> - Return variable (0=Professional, 1=Home edition)
@REM Purpose:    Checks Windows edition to determine available features
@REM Method:     Uses WMIC to check OperatingSystemSKU and caption
@REM ============================================================================
:isHomeEdition <result>
set "%~1=1"

set "content=" 
for /f %%a in ('wmic os get OperatingSystemSKU ^| findstr /r /i /c:"^[1-9][0-9]*"') do set "content=%%a"
call :trim content "!content!"

@REM SKU codes 2/3/5/26 represent various Home editions
if "!content!" NEQ "2" if "!content!" NEQ "3" if "!content!" NEQ "5" if "!content!" NEQ "26" (
    @REM Check OS caption for Professional edition indicators
    for /f "delims=" %%a in ('wmic os get caption ^| findstr /i /c:"pro" /c:"professional"') do set "content=%%a"
    call :trim content "!content!"
    if "!content!" NEQ "" set "%~1=0"
)
goto :eof


@REM ============================================================================
@REM Enable run as administrator capability on Home editions
@REM Parameters: <r> - Return variable (0=failed, 1=success)
@REM Purpose:    Installs Group Policy packages needed for admin privileges
@REM Method:     Uses DISM to install Windows Group Policy components
@REM ============================================================================
:enableRunAs <result>
set "%~1=1"

call :isHomeEdition edition
if "!edition!" == "0" goto :eof

set "packages_file=!TEMP_DIR!\group_policy_packages.txt"

@REM Locate all Group Policy packages needed for admin functionality
dir /b "C:\Windows\servicing\Packages\Microsoft-Windows-GroupPolicy-ClientExtensions-Package~3*.mum" > "!packages_file!"
dir /b "C:\Windows\servicing\Packages\Microsoft-Windows-GroupPolicy-ClientTools-Package~3*.mum" >> "!packages_file!"

@REM Install Group Policy packages using DISM
for /f %%i in ('findstr /i . "!packages_file!" 2^>nul') do dism /online /norestart /add-package:"C:\Windows\servicing\Packages\%%i" >nul 2>nul
if "!errorlevel!" NEQ "0" set "%~1=0"

del /f /q "!packages_file!" >nul 2>nul
goto :eof


@REM ============================================================================
@REM Enable silent administrator mode (no UAC prompts)
@REM Parameters: <r> - Return variable (0=failed, 1=success)
@REM Purpose:    Disables UAC prompts for administrator operations
@REM Registry:   Sets ConsentPromptBehaviorAdmin to 0 in Group Policy
@REM ============================================================================
:enableSilentAdmin <result>
set "%~1=0"

@REM Registry path and key for UAC consent prompt behavior
set "group_policy=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
set "gpr_key=ConsentPromptBehaviorAdmin"

call :queryRegistry code "!group_policy!" "!gpr_key!" "REG_DWORD"
if "!code!" == "0x0" (
    set "%~1=1"
    exit /b  
)

call :enableRunAs enable
if "!enable!" == "0" goto :eof

@REM Modify registry to disable UAC consent prompts for administrators
reg delete "!group_policy!" /v ConsentPromptBehaviorAdmin /f >nul 2>nul
reg add "!group_policy!" /v ConsentPromptBehaviorAdmin /t REG_DWORD /d 0 /f >nul 2>nul
if "!errorlevel!" == "0" set "%~1=1"
goto :eof


@REM ============================================================================
@REM Purge all sing-box configurations and settings
@REM Purpose:    Complete cleanup of proxy settings, autostart, and scheduled tasks
@REM Process:    Disables proxy, removes autostart, deletes tasks, stops service
@REM ============================================================================
:purge
set "tips=[%ESC%[!warn_color!m警告%ESC%[0m] 即将关闭系统代理并禁用开机自启，是否继续？(%ESC%[!warn_color!mY%ESC%[0m/%ESC%[!warn_color!mN%ESC%[0m) "
if "!ms_terminal!" == "1" (
    choice /t 6 /d n /n /m "!tips!"
) else (
    set /p "=!tips!" <nul
    choice /t 6 /d n /n
)
if !errorlevel! == 2 exit /b 1

@REM Disable Windows system proxy settings
call :disableSystemProxy

@REM Remove automatic startup configuration
call :disableAutostart success
if "!success!" == "0" (
    @echo [%ESC%[!error_color!m错误%ESC%[0m] 开机自启%ESC%[!error_color!m禁用失败%ESC%[0m，可在%ESC%[!warn_color!m任务管理中心%ESC%[0m手动设置
)

@REM Delete automatic update scheduled task
call :deleteTask success "SingBoxUpdater"
if "!success!" == "0" (
    @echo [%ESC%[!error_color!m错误%ESC%[0m] 自动检查跟新取消%ESC%[!error_color!m失败%ESC%[0m，可在%ESC%[!warn_color!m任务计划程序%ESC%[0m中手动删除
)

@REM Stop running sing-box process
call :killProcessWrapper

@REM Remove desktop shortcut and icon
call :deleteDesktopShortcut

@echo [%ESC%[!info_color!m信息%ESC%[0m] 清理%ESC%[!info_color!m完毕%ESC%[0m, bye~
goto :eof


@REM ============================================================================
@REM Query value from Windows registry
@REM Parameters: <r> - Return variable for registry value
@REM            <path> - Registry path to query
@REM            <key> - Registry key name
@REM            <type> - Registry value type (default: REG_SZ)
@REM Purpose:    Retrieves specific values from Windows registry
@REM ============================================================================
:queryRegistry <result> <path> <key> <type>
set "%~1="
set "value="

@REM Path
call :trim registry_path "%~2"
if "!registry_path!" == "" goto :eof

@REM Key
call :trim registry_key "%~3"
if "!registry_key!" == "" goto :eof

@REM Type
call :trim registry_type "%~4"
if "!registry_type!" == "" set "registry_type=REG_SZ"

@REM Query
reg query "!registry_path!" /V "!registry_key!" >nul 2>nul
if "!errorlevel!" NEQ "0" goto :eof

for /f "tokens=3" %%a in ('reg query "!registry_path!" /V "!registry_key!" ^| findstr /r /i "!registry_type!"') do set "value=%%a"
call :trim value "!value!"
set "%~1=!value!"
goto :eof


@REM ============================================================================
@REM Download icon file for desktop shortcuts
@REM Parameters: <r> - Return variable (0=failed, 1=success)
@REM            <iconname> - Filename for downloaded icon
@REM Purpose:    Downloads sing-box icon from GitHub repository
@REM ============================================================================
:downloadIcon <result> <iconname>
set "%~1=0"

call :trim icon_name "%~2"
if "!icon_name!" == "" goto :eof

call :applyGithubProxy icon_url "!DEFAULT_ICON_URL!"
set "status_code=000"
for /f %%a in ('!CURL_BINARY! --retry 3 --retry-max-time 60 -m 60 --connect-timeout 30 -L -s -o "!dest!\!icon_name!" -w "%%{http_code}" "!icon_url!"') do set "status_code=%%a"

if "!status_code!" == "200" set "%~1=1"
goto :eof


@REM ============================================================================
@REM Create desktop shortcut using VBScript
@REM Parameters: <r> - Return variable (0=failed, 1=success)
@REM            <linkdest> - Destination path for shortcut file
@REM            <target> - VBScript path passed as arguments to wscript.exe
@REM            <iconname> - Icon file name (optional)
@REM Purpose:    Creates Windows shortcut with custom icon and working directory
@REM             Target is wscript.exe so the shortcut can be pinned to the taskbar
@REM ============================================================================
:createShortcut <result> <linkdest> <target> <iconname>
set "%~1=0"
call :trim link_dest "%~2"
call :trim target "%~3"
call :trim icon_name "%~4"


if "!link_dest!" == "" goto :eof
if "!target!" == "" goto :eof
if "!icon_name!" == "" set "icon_name=sing-box.ico"
if exist "!link_dest!" del /f /q "!link_dest!" >nul

set "vbs_path=!TEMP_DIR!\createshortcut.vbs"
((
    @echo set ows = WScript.CreateObject^("WScript.Shell"^)
    @echo slinkfile = ows.ExpandEnvironmentStrings^("!link_dest!"^)
    @echo set olink = ows.CreateShortcut^(slinkfile^)
    @echo olink.TargetPath = ows.ExpandEnvironmentStrings^("%%SystemRoot%%\System32\wscript.exe"^)
    @echo olink.Arguments = "//B " ^& Chr^(34^) ^& ows.ExpandEnvironmentStrings^("!target!"^) ^& Chr^(34^)
    @echo olink.IconLocation = ows.ExpandEnvironmentStrings^("!dest!\!icon_name!"^)
    @echo olink.WorkingDirectory = ows.ExpandEnvironmentStrings^("!dest!"^)
    @echo olink.Save
) 1>!vbs_path!

cscript //nologo "!vbs_path!"
if "!errorlevel!" == "0" set "%~1=1"

del /f /q "!vbs_path!"
) >nul
goto :eof


@REM ============================================================================
@REM Create desktop shortcut for sing-box with user confirmation
@REM Purpose:    Interactive creation of desktop shortcut with icon download
@REM Process:    Prompts user, downloads icon, creates shortcut via VBScript
@REM ============================================================================
:createDesktopShortcut
if "!enable_shortcut!" == "0" goto :eof

set "icon_name=sing-box.ico"
set "link_dest=!HOMEDRIVE!!HOMEPATH!\Desktop\SingBox.lnk"
set "shortcut_matched=0"
set "action=添加"

@REM Parse the existing shortcut target and arguments
if exist "!link_dest!" (
    set "action=更新"

    for /f "usebackq delims=" %%a in (`powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$shortcut=(New-Object -ComObject WScript.Shell).CreateShortcut($env:link_dest); $shortcutCommand=($shortcut.TargetPath + ' ' + $shortcut.Arguments).Trim(); $expectedShortcutCommand=((Join-Path $env:SystemRoot 'System32\wscript.exe') + ' //B ' + [char]34 + $env:startup_script + [char]34).Trim(); if ($shortcutCommand -ieq $expectedShortcutCommand) { '1' } else { '0' }"`) do set "shortcut_matched=%%a"
)

if "!shortcut_matched!" == "1" goto :eof

set "tips=[%ESC%[!warn_color!m提示%ESC%[0m] 是否!action!桌面快捷方式？(%ESC%[!warn_color!mY%ESC%[0m/%ESC%[!warn_color!mN%ESC%[0m) "
if "!ms_terminal!" == "1" (
    choice /t 5 /d y /n /m "!tips!"
) else (
    set /p "=!tips!" <nul
    choice /t 5 /d y /n
)
if !errorlevel! == 2 goto :eof

if not exist "!dest!\!icon_name!" (
    call :downloadIcon finished "!icon_name!"
    if "!finished!" == "0" (
        @echo [%ESC%[!error_color!m错误%ESC%[0m] 应用图标文件下载%ESC%[!error_color!m失败%ESC%[0m，无法创建桌面快捷方式
        goto :eof
    )
)

call :createShortcut finished "!link_dest!" "!startup_script!" "!icon_name!"
if "!finished!" == "0" (
    @echo [%ESC%[!error_color!m错误%ESC%[0m] 桌面快捷方式!action!%ESC%[!error_color!m失败%ESC%[0m，如有需要，请自行创建
) else (
    @echo [%ESC%[!info_color!m信息%ESC%[0m] 桌面快捷方式!action!%ESC%[!info_color!m成功%ESC%[0m
)
goto :eof


@REM ============================================================================
@REM Remove desktop shortcut for sing-box
@REM Purpose:    Deletes sing-box shortcut and icon files from desktop
@REM Files:      Removes both .lnk shortcut and .ico icon files
@REM ============================================================================
:deleteDesktopShortcut
set "link_path=!HOMEDRIVE!!HOMEPATH!\Desktop\SingBox.lnk"
del /f /q "!link_path!" >nul 2>nul
goto :eof


@REM ============================================================================
@REM Check version and get download URL in single API call to optimize requests
@REM Parameters: <download_url> - Return variable for download URL if update needed
@REM Purpose:    Combines version check and URL extraction to reduce API calls
@REM Method:     Single GitHub API request, compares versions, extracts URL if needed
@REM ============================================================================
:checkAndGetSingboxDownloadUrl <download_url>
set "%~1="
set "local_version="
set "remote_version="

@REM If sing-box doesn't exist, need to download
if not exist "!dest!\!SINGBOX_EXE!" (
    @echo [%ESC%[!info_color!m信息%ESC%[0m] 未找到本地 !SINGBOX_EXE!，准备下载
    call :getSingboxUrl download_url
    set "%~1=!download_url!"
    goto :eof
)

@REM Get current local sing-box version from executable
call :getLocalSingboxVersion local_version
if "!local_version!" == "" (
    @echo [%ESC%[!warn_color!m警告%ESC%[0m] 无法获取本地 !SINGBOX_EXE! 版本信息
    call :getSingboxUrl download_url
    set "%~1=!download_url!"
    goto :eof
)

@REM Get remote version and download URL from GitHub API in single request
set "api_url=https://api.github.com/repos/!GITHUB_REPO!/releases"
call :applyGithubProxy api_url "!api_url!"

@REM Download GitHub releases API response to temporary file
set "temp_file=!TEMP_DIR!\singbox_release.json"
del /f /q "!temp_file!" >nul 2>nul

@REM Fetch release information from GitHub API with retry mechanism
!CURL_BINARY! --retry 3 --retry-max-time 30 -m 60 --connect-timeout 30 -s -L "!api_url!" > "!temp_file!"
if not exist "!temp_file!" (
    @echo [%ESC%[!warn_color!m警告%ESC%[0m] 无法获取远程 !SINGBOX_EXE! 版本信息，本地版本：!local_version!
    goto :eof
)

@REM Validate downloaded file has meaningful content (not empty or error page)
for %%a in ("!temp_file!") do set "file_size=%%~za"
if !file_size! LSS 10 (
    del /f /q "!temp_file!" >nul 2>nul
    @echo [%ESC%[!warn_color!m警告%ESC%[0m] 无法获取远程 !SINGBOX_EXE! 版本信息，本地版本：!local_version!
    goto :eof
)

@REM Extract remote version (commit ID) from filename pattern
set "remote_version="
for /f "tokens=*" %%a in ('findstr /i /r /c:"name.*sing-box-[a-f0-9][a-f0-9]*-windows-amd64\.zip" "!temp_file!"') do (
    set "line=%%a"
    call :extractCommitId commit_id "!line!"
    if "!commit_id!" NEQ "" (
        set "remote_version=!commit_id!"
        goto :compareSingboxVersion
    )
)

@REM ============================================================================
@REM Compare local and remote versions using commit IDs
@REM Parameters: <download_url> - Return variable for download URL if update needed
@REM Purpose:    Compares local and remote versions to determine update necessity
@REM Method:     Compares commit IDs from local executable and GitHub releases
@REM ============================================================================
:compareSingboxVersion
if "!remote_version!" == "" (
    del /f /q "!temp_file!" >nul 2>nul
    @echo [%ESC%[!warn_color!m警告%ESC%[0m] 无法获取远程 !SINGBOX_EXE! 版本信息，本地版本：!local_version!
    goto :eof
)

@REM Compare local and remote versions using commit IDs
if "!local_version!" NEQ "!remote_version!" (
    @echo [%ESC%[!info_color!m信息%ESC%[0m] 发现新版本 !SINGBOX_EXE!，本地版本：%ESC%[!warn_color!m!local_version!%ESC%[0m，远程版本：%ESC%[!warn_color!m!remote_version!%ESC%[0m

    @REM Extract download URL from the same API response
    for /f "tokens=*" %%a in ('findstr /i /r /c:"browser_download_url.*sing-box-[a-f0-9][a-f0-9]*-windows-amd64\.zip" "!temp_file!"') do (
        set "line=%%a"
        call :extractDownloadUrl download_url "!line!"
        if "!download_url!" NEQ "" (
            call :applyGithubProxy download_url "!download_url!"

            set "%~1=!download_url!"
            del /f /q "!temp_file!" >nul 2>nul
            goto :eof
        )
    )
) else (
    @echo [%ESC%[!info_color!m信息%ESC%[0m] !SINGBOX_EXE! 当前已是最新版本，本地版本：%ESC%[!warn_color!m!local_version!%ESC%[0m，远程版本：%ESC%[!warn_color!m!remote_version!%ESC%[0m
)

del /f /q "!temp_file!" >nul 2>nul
goto :eof


@REM ============================================================================
@REM Get local sing-box version from executable
@REM Parameters: <version> - Return variable for version (commit ID)
@REM Purpose:    Extracts version information from local sing-box executable
@REM Method:     Runs 'sing-box version' and extracts first 8 chars of Revision
@REM ============================================================================
:getLocalSingboxVersion <version>
set "%~1="
if not exist "!dest!\!SINGBOX_EXE!" goto :eof

set "temp_file=!TEMP_DIR!\singbox_version.txt"
"!dest!\!SINGBOX_EXE!" version > "!temp_file!" 2>nul

@REM Extract revision from version output and take first 8 characters
for /f "tokens=2" %%a in ('findstr /i "Revision" "!temp_file!" 2^>nul') do (
    set "revision=%%a"
    set "%~1=!revision:~0,8!"

    del /f /q "!temp_file!" >nul 2>nul
    goto :eof
)

del /f /q "!temp_file!" >nul 2>nul
goto :eof


@REM ============================================================================
@REM Extract commit ID from JSON line containing filename
@REM Parameters: <r> - Return variable for extracted commit ID
@REM            <json_line> - JSON line containing filename with commit ID
@REM Purpose:    Parses filename pattern sing-box-XXXXXXXX-windows-amd64.zip
@REM Method:     Extracts 8-character hex commit ID from filename
@REM ============================================================================
:extractCommitId <r> <json_line>
set "%~1="
call :trim json_line "%~2"
if "!json_line!" == "" goto :eof

@REM Extract filename from JSON line
set "line=!json_line!"
@REM Find the name field with sing-box pattern
echo !line! | findstr /r /c:"sing-box-[a-f0-9][a-f0-9]*-windows-amd64\.zip" >nul || goto :eof

@REM Extract the filename value from name field
for /f "tokens=1* delims=:" %%a in ("!line!") do (
    echo %%a | findstr /i "name" >nul && (
        set "name_part=%%b"
        call :trim name_part "!name_part!"
        @REM Remove quotes and comma using string replacement
        set "name_part=!name_part:"=!"
        if "!name_part:~-1!" == "," set "name_part=!name_part:~0,-1!"

        @REM Extract commit ID from filename: sing-box-XXXXXXXX-windows-amd64.zip
        for /f "tokens=1,2,3,4 delims=-" %%c in ("!name_part!") do (
            set "commit_id=%%e"
            @REM Ensure it's exactly 8 characters and contains only hex characters
            if "!commit_id:~7,1!" NEQ "" if "!commit_id:~8,1!" == "" (
                echo !commit_id!>"%TEMP_DIR%\commit_check.txt"
                findstr /r /c:"^[a-f0-9][a-f0-9]*$" "%TEMP_DIR%\commit_check.txt" >nul && (
                    set "%~1=!commit_id!"
                    del "%TEMP_DIR%\commit_check.txt" >nul 2>nul
                    goto :eof
                )
                del "%TEMP_DIR%\commit_check.txt" >nul 2>nul
            )
        )
    )
)
goto :eof


@REM ============================================================================
@REM Get sing-box download URL from GitHub releases
@REM Parameters: <url> - Return variable for download URL
@REM Purpose:    Fetches download URL for latest sing-box Windows release
@REM Method:     Parses GitHub API response for browser_download_url field
@REM ============================================================================
:getSingboxUrl <url>
set "%~1="

set "api_url=https://api.github.com/repos/!GITHUB_REPO!/releases"
call :applyGithubProxy api_url "!api_url!"

@REM Get release info
set "temp_file=!TEMP_DIR!\singbox_release.json"
del /f /q "!temp_file!" >nul 2>nul

!CURL_BINARY! --retry 3 --retry-max-time 30 -m 60 --connect-timeout 30 -s -L "!api_url!" > "!temp_file!"
if not exist "!temp_file!" goto :eof

@REM Check if file has content
for %%a in ("!temp_file!") do set "file_size=%%~za"
if !file_size! LSS 10 (
    del /f /q "!temp_file!" >nul 2>nul
    goto :eof
)

@REM Search for browser_download_url field containing sing-box Windows release
for /f "tokens=*" %%a in ('findstr /i /r /c:"browser_download_url.*sing-box-[a-f0-9][a-f0-9]*-windows-amd64\.zip" "!temp_file!"') do (
    set "line=%%a"
    call :extractDownloadUrl download_url "!line!"
    if "!download_url!" NEQ "" (
        call :applyGithubProxy download_url "!download_url!"
        set "%~1=!download_url!"

        del /f /q "!temp_file!" >nul 2>nul
        goto :eof
    )
)

del /f /q "!temp_file!" >nul 2>nul
goto :eof


@REM ============================================================================
@REM Extract download URL from GitHub API JSON response line
@REM Parameters: <r> - Return variable for extracted download URL
@REM            <json_line> - JSON line containing browser_download_url field
@REM Purpose:    Parses GitHub release API response to find sing-box download URL
@REM Pattern:    Looks for sing-box-[commit]-windows-amd64.zip pattern
@REM ============================================================================
:extractDownloadUrl <r> <json_line>
set "%~1="
call :trim json_line "%~2"
if "!json_line!" == "" goto :eof

@REM Extract browser_download_url using string manipulation
set "search_str=browser_download_url"
set "line=!json_line!"

@REM Find browser_download_url field
for /f "tokens=1* delims=:" %%a in ("!line!") do (
    echo %%a | findstr /i "!search_str!" >nul && (
        set "url_part=%%b"
        @REM Extract URL from the value part
        for /f "tokens=1* delims=," %%c in ("!url_part!") do (
            set "url=%%c"
            call :trim url "!url!"
            @REM Remove quotes using string replacement
            set "url=!url:"=!"
            @REM Validate URL contains sing-box pattern
            echo !url! | findstr /r /c:"sing-box-[a-f0-9][a-f0-9]*-windows-amd64\.zip" >nul && (
                set "%~1=!url!"
                goto :eof
            )
        )
    )
)
goto :eof


@REM ============================================================================
@REM Reload sing-box configuration without restarting
@REM Purpose:    Hot-reloads configuration using sing-box API
@REM Parameters: None
@REM Returns:    Success/failure status with user feedback
@REM ============================================================================
:reloadConfig
if not exist "!config_file!" goto :eof

@REM Parse API server path
if "!singbox_server!" == "" call :extractServer singbox_server

if "!singbox_server!" == "" (
    @echo [%ESC%[!error_color!m错误%ESC%[0m] %ESC%[!error_color!m不支持%ESC%[0m重载，可使用 "%ESC%[!warn_color!m!BATCH_NAME! -r%ESC%[0m" 重启或者在文件 "%ESC%[!warn_color!m!config_file!%ESC%[0m" 配置 "%ESC%[!warn_color!mexternal_controller%ESC%[0m" 属性以启用该功能
    goto :eof
)

set "singbox_api=!singbox_server!/configs?reload=true"

@REM Extract secret for API authentication
call :parseJsonValue secret "secret"

@REM Check if sing-box process is running
call :isProcessRunning status

if "!status!" == "1" (
    @REM Convert backslashes to forward slashes for JSON
    set "file_path=!config_file:\=/!"

    @REM Call API for reload
    set "status_code=000"
    set "output=!TEMP_DIR!\singbox_reload_output.txt"
    if exist "!output!" del /f /q "!output!" >nul 2>nul

    if "!secret!" NEQ "" (
        for /f %%a in ('!CURL_BINARY! --retry 3 -L -s -o "!output!" -w "%%{http_code}" -H "Content-Type: application/json" -H "Authorization: Bearer !secret!" -X PUT -d "{""path"":""!file_path!""}" "!singbox_api!"') do set "status_code=%%a"
    ) else (
        for /f %%a in ('!CURL_BINARY! --retry 3 -L -s -o "!output!" -w "%%{http_code}" -H "Content-Type: application/json" -X PUT -d "{""path"":""!file_path!""}" "!singbox_api!"') do set "status_code=%%a"
    )

    if "!status_code!" == "204" (
        @echo [%ESC%[!info_color!m信息%ESC%[0m] 网络代理程序重载%ESC%[!info_color!m成功%ESC%[0m，祝你使用愉快
        call :postProcess
    ) else if "!status_code!" == "401" (
        @echo [%ESC%[!info_color!m信息%ESC%[0m] %ESC%[!warn_color!msecret%ESC%[0m 已被修改，请使用 "%ESC%[!warn_color!m!BATCH_NAME! -r%ESC%[0m" 重启
    ) else (
        set "content="

        if exist "!output!" (
            @REM Read error output
            for /f "delims=" %%a in (!output!) do set "content=%%a"
        )

        @echo [%ESC%[!error_color!m错误%ESC%[0m] 网络代理程序重载%ESC%[!error_color!m失败%ESC%[0m，请检查配置文件 "%ESC%[!warn_color!m!config_file!%ESC%[0m" 是否有效
        if "!content!" NEQ "" (
            @echo [%ESC%[!error_color!m错误%ESC%[0m] 错误信息："!content!"
        )

        @echo.
    )

    @REM Clean up output file
    del /f /q "!output!" >nul 2>nul
) else (
    @echo [%ESC%[!error_color!m错误%ESC%[0m] 网络代理程序%ESC%[!error_color!m未启动%ESC%[0m，可使用命令 "%ESC%[!warn_color!m!BATCH_NAME! -r%ESC%[0m" 启动
)
goto :eof

@REM ============================================================================
@REM Detect whether the script runs in Windows Terminal
@REM Purpose:    Detect whether the script runs in Windows Terminal
@REM Parameters: <result>
@REM ============================================================================
:isMicrosoftTerminal <result>
set "%~1=0"

@REM Windows Terminal sets WT_SESSION for hosted command-line processes.
@REM Classic conhost.exe sessions do not define it, so this avoids spawning PowerShell.
if defined WT_SESSION set "%~1=1"
goto :eof

@REM ============================================================================
@REM END OF SCRIPT
@REM ============================================================================
endlocal
