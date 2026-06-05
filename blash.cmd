@REM ============================================================================
@REM Clash / Mihomo Network Proxy Controller
@REM ============================================================================
@REM Description: Comprehensive management tool for Clash Premium and Mihomo proxy
@REM              service on Windows. Supports installation, configuration,
@REM              updates, dashboard management, startup tasks, and maintenance.
@REM Author:      wzdnzd
@REM Date:        2022-08-24
@REM Repository:  https://github.com/wzdnzd/batches
@REM ============================================================================

@echo off & PUSHD %~DP0 & cd /d "%~dp0"

@REM Use UTF-8 so Chinese messages and symbols render correctly
chcp 65001 >nul 2>nul

@REM Reference: https://blog.csdn.net/sanqima/article/details/37818115
setlocal enableDelayedExpansion

@REM Initialize ANSI color support for console output
call :setEsc

@REM Start main workflow
goto :mainWorkflow


@REM ============================================================================
@REM FUNCTION DEFINITIONS
@REM ============================================================================

@REM ============================================================================
@REM Run the main command workflow
@REM Purpose:    Run the main command workflow
@REM ============================================================================
:mainWorkflow
@REM Batch file name
set "batchName=%~nx0"

@REM Microsoft Terminal renders differently from CMD and PowerShell
@REM Call :isMicrosoftTerminal msTerminal
set "msTerminal=1"

@REM Enable desktop shortcut creation
set "enableShortcut=1"

@REM Enable remote configuration download
set "enableRemoteConfig=1"
set "remoteConfigUrl="

@REM Validate configuration files before starting
set "verifyConfig=0"

@REM Check and update wintun.dll
set "checkWintun=0"

@REM Console color settings
set "infoColor=92"
set "warnColor=93"

if "!msTerminal!" == "1" (
    set "infoColor=95"
    set "warnColor=97"
)

@REM Optional heart output
set "customize=0"
set "drawHeart=0"

@REM Exit flag
set "shouldExit=0"

@REM Initialization flag
set "initFlag=0"

@REM Configuration file name
set "configuration=config.yaml"

@REM Common core executable names
set "clashExecutableName=clash.exe"
set "mihomoExecutableName=mihomo.exe"
set "proxyExecutableName=!clashExecutableName!"

@REM Core display names
set "clashPremiumName=Clash Premium"
set "metaCubeXMihomoName=MetaCubeX Mihomo"
set "smartMihomoName=Smart Mihomo"

@REM Subscription link
set "subscriptionLink="
set "isWebLink=0"

@REM Check status
set "testFlag=0"

@REM Repair flag
set "repairFlag=0"

@REM Reload-only flag
set "reloadOnly=0"

@REM Restart proxy executable flag
set "restartFlag=0"

@REM Close proxy flag
set "killFlag=0"

@REM Update flag
set "updateFlag=0"

@REM Purge flag
set "purgeFlag=0"

@REM Update only subscriptions and rulesets
set "quickFlag=0"

@REM Skip subscription updates
set "excludeUpdates=0"

@REM Use MetaCubeX Mihomo
set "useClashMeta=0"

@REM Use Clash Premium
set "useClashPremium=0"

@REM Use Smart Mihomo smart group core
set "useVerneMihomo=0"

@REM Core edition explicitly selected by arguments
set "coreForced=0"

@REM Installed proxy core differs from the required edition
set "proxyEditionChanged=0"

@REM LightGBM model
set "lgbmUrl="
set "lgbmFile=Model.bin"

@REM Allow alpha versions
set "alpha=0"

@REM Brief mode
set "brief=0"

@REM Regenerate the auto-update script
set "regenerate=0"

@REM Yacd dashboard, see https://github.com/MetaCubeX/Yacd-meta or https://github.com/haishanh/yacd
set "yacd=0"

@REM MetaCubeXD dashboard, see https://github.com/MetaCubeX/metacubexd
set "metaCubeXDashboard=0"

@REM Zashboard, see https://github.com/Zephyruso/zashboard
set "zashboard=0"

@REM Dashboard explicitly specified by arguments
set "dashboardForced=0"

@REM Run in the background
set "asDaemon=0"

@REM Show elevated command window
set "showWindow=0"

@REM Workspace setting
set "dest="

@REM Network proxy registry configuration path
set "proxyRegPath=HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings"

@REM Autostart registry configuration path
set "autostartRegPath=HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
set "startupApprovedRegPath=HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"

@REM Parse arguments
call :parseArgs %*

@REM Handle invalid arguments
if "!shouldExit!" == "1" exit /b 1

@REM Resolve regular file paths
if "!dest!" == "" set "dest=%~dp0"
call :normalizePath dest "!dest!"
call :resolveProxyExecutableName

@REM Startup VBS script path
set "startupVbs=!dest!\startup.vbs"

@REM Auto-update VBS script path
set "updateVbs=!dest!\update.vbs"

@REM Print the heart output
if "!drawHeart!"== "1" goto :printHeart

@REM Close the network proxy
if "!killFlag!" == "1" goto :closeProxy

@REM Remove proxy settings
if "!purgeFlag!" == "1" goto :purge

@REM Prevent configuration validation when no action was requested
if "!reloadOnly!" == "0" if "!restartFlag!" == "0" if "!repairFlag!" == "0" if "!testFlag!" == "0" if "!updateFlag!" == "0" if "!initFlag!" == "0" (
    if "!shouldExit!" == "0" goto :usage
    exit /b
)

@REM Configuration file path
call :validateConfiguration configFile
if "!configFile!" == "" exit /b 1

@REM Connectivity test
if "!testFlag!" == "1" (
    call :testConnection available 1
    exit /b
)

@REM Reload configuration
if "!reloadOnly!" == "1" goto :reloadConfig

@REM Update flag
if "!restartFlag!" == "1" goto :restartProgram

@REM Diagnose issues
if "!repairFlag!" == "1" goto :resolveIssues

@REM Update flag
if "!updateFlag!" == "1" goto :updateComponents

@REM Initialization flag
if "!initFlag!" == "1" goto :initialize

@REM Handle unknown commands
@REM If "!shouldExit!" == "0" goto :usage

exit /b

@REM ============================================================================
@REM Validate and resolve the Clash configuration file
@REM Purpose:    Validate and resolve the Clash configuration file
@REM Parameters: <result>
@REM ============================================================================
:validateConfiguration <result>
set "%~1="
set "subscriptionFile=!temp!\clashsub.yaml"

@REM Resolve an absolute path
call :convertToAbsolutePath configLocation "!configuration!"
call :normalizePath configLocation "!configLocation!"

if "!configLocation!" == "" (
    @echo [%ESC%[91m错误%ESC%[0m] 配置文件路径%ESC%[91m无效%ESC%[0m
    exit /b 1
)

@REM Reject paths containing whitespace
if "!configLocation!" NEQ "!configLocation: =!" (
    @echo [%ESC%[91m错误%ESC%[0m] 无效的配置文件 "%ESC%[!warnColor!m!configLocation!%ESC%[0m"， 路径不能包含%ESC%[!warnColor!m空格%ESC%[0m
    exit /b 1
)

if "!isWebLink!" == "1" (
    if exist "!configLocation!" (
        set "tips=[%ESC%[!warnColor!m警告%ESC%[0m] %ESC%[!warnColor!m已存在%ESC%[0m配置文件 "%ESC%[!warnColor!m!configLocation!%ESC%[0m" 会被%ESC%[91m覆盖%ESC%[0m，是否继续？ (%ESC%[!warnColor!mY%ESC%[0m/%ESC%[!warnColor!mN%ESC%[0m) "
        if "!msTerminal!" == "1" (
            choice /t 6 /d n /n /m "!tips!"
        ) else (
            set /p "=!tips!" <nul
            choice /t 6 /d n /n
        )
        if !errorlevel! == 2 exit /b 1
    )

    @REM Try to download the subscription
    del /f /q "!subscriptionFile!" >nul 2>nul

    set "statusCode=000"
    for /f %%a in ('curl --retry 3 --retry-max-time 30 -m 60 --connect-timeout 30 -L -s -o "!subscriptionFile!" -w "%%{http_code}" -H "User-Agent: Clash" "!subscriptionLink!"') do set "statusCode=%%a"

    @REM Download succeeded
    if "!statusCode!" == "200" (
        set "fileSize=0"
        if exist "!subscriptionFile!" (for %%a in ("!subscriptionFile!") do set "fileSize=%%~za")
        if !fileSize! GTR 64 (
            @REM Validate the file
            set "content="
            for /f "tokens=*" %%a in ('findstr /i /r /c:"^external-controller:[ ][ ]*.*:[0-9][0-9]*.*" !subscriptionFile!') do set "content=%%a"
            if "!content!" == "" (
                @echo [%ESC%[91m错误%ESC%[0m] 订阅 "%ESC%[!warnColor!m!subscriptionLink!%ESC%[0m" 无效，请检查确认
                exit /b 1
            )

            del /f /q "!configLocation!" >nul 2>nul
            call :splitPath filePath fileName "!configLocation!"
            call :createDirectories success "!filePath!"
            if "!success!" == "0" (
                @echo [%ESC%[91m错误%ESC%[0m] 创建文件夹 "%ESC%[!warnColor!m!filePath!%ESC%[0m" %ESC%[91m失败%ESC%[0m，请确认路径是否合法
                exit /b 1
            )

            move "!subscriptionFile!" "!configLocation!" >nul 2>nul
            @echo [%ESC%[!infoColor!m信息%ESC%[0m] 订阅下载%ESC%[!infoColor!m成功%ESC%[0m

            @REM Save the subscription link
            @echo !subscriptionLink! > "!filePath!\subscriptions.txt"
        ) else (
            @REM Downloaded content is empty
            set "statusCode=000"
        )
    )

    if "!statusCode!" NEQ "200" (
        @echo [%ESC%[91m错误%ESC%[0m] 订阅下载%ESC%[91m失败%ESC%[0m， 请检查确认此订阅是否有效
        exit /b 1
    )
)

if not exist "!configLocation!" (
    @echo [%ESC%[91m错误%ESC%[0m] 配置文件 "%ESC%[!warnColor!m!configLocation!%ESC%[0m" %ESC%[91m不存在%ESC%[0m
    goto :eof
)

@REM Validate the file
set "content="
for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"^proxy-groups:[ ]*" "!configLocation!"') do set "content=%%a"
call :trim content "!content!"
if "!content!" NEQ "proxy-groups" (
    @echo [%ESC%[91m错误%ESC%[0m] %ESC%[91m无效%ESC%[0m的配置文件 "%ESC%[!warnColor!m!configLocation!%ESC%[0m"
    exit /b 1
)

set "%~1=!configLocation!"
goto :eof

@REM ============================================================================
@REM Initialize the network proxy workspace
@REM Purpose:    Initialize the network proxy workspace
@REM ============================================================================
:initialize
set "tips=[%ESC%[!warnColor!m提示%ESC%[0m] 网络代理程序将在目录 "%ESC%[!warnColor!m!dest!%ESC%[0m" 安装并运行，是否继续？(%ESC%[!warnColor!mY%ESC%[0m/%ESC%[!warnColor!mN%ESC%[0m) "
if "!msTerminal!" == "1" (
    choice /t 5 /d n /n /m "!tips!"
) else (
    set /p "=!tips!" <nul
    choice /t 5 /d n /n
)
if !errorlevel! == 2 exit /b 1

set "quickFlag=0"
set "excludeUpdates=1"
call :updateComponents
goto :eof

@REM ============================================================================
@REM Diagnose and repair proxy connectivity issues
@REM Purpose:    Diagnose and repair proxy connectivity issues
@REM ============================================================================
:resolveIssues
@REM Force the stable version during repair
set "alpha=0"

@echo [%ESC%[!infoColor!m信息%ESC%[0m] 开始检查并尝试修复网络代理，请稍等

@REM Check current status
call :testConnection available 0
set "lazyCheck=0"
if "!available!" == "1" (
    set "tips=[%ESC%[!warnColor!m提示%ESC%[0m] 代理网络运行%ESC%[!infoColor!m正常%ESC%[0m，%ESC%[91m不存在%ESC%[0m问题，是否继续？(%ESC%[!warnColor!mY%ESC%[0m/%ESC%[!warnColor!mN%ESC%[0m) "
    if "!msTerminal!" == "1" (
        choice /t 5 /d n /n /m "!tips!"
    ) else (
        set /p "=!tips!" <nul
        choice /t 5 /d n /n
    )
    if !errorlevel! == 2 exit /b 1
) else (
    @REM Detect whether the proxy is running
    call :isProcessRunning status
    if "!status!" == "0" (
        call :checkNetworkWrapper continue 1
        if "!continue!" == "0" exit /b
    ) else set "lazyCheck=1"
)

@REM O: Reload | R: Restart | U: Restore | N: Cancel
set "tips=[%ESC%[!warnColor!m提示%ESC%[0m] 按 %ESC%[!warnColor!mO%ESC%[0m %ESC%[!warnColor!m重载%ESC%[0m，按 %ESC%[!warnColor!mR%ESC%[0m %ESC%[!warnColor!m重启%ESC%[0m，按 %ESC%[!warnColor!mU%ESC%[0m %ESC%[!warnColor!m恢复%ESC%[0m至默认，按 %ESC%[!warnColor!mN%ESC%[0m %ESC%[!warnColor!m取消%ESC%[0m (%ESC%[!warnColor!mO%ESC%[0m/%ESC%[!warnColor!mR%ESC%[0m/%ESC%[!warnColor!mU%ESC%[0m/%ESC%[!warnColor!mN%ESC%[0m) "
if "!msTerminal!" == "1" (
    choice /t 6 /c ORUN /d R /n /m "!tips!"
) else (
    set /p "=!tips!" <nul
    choice /t 6 /c ORUN /d R /n
)

if !errorlevel! == 1 (
    call :reloadConfig
) else if !errorlevel! == 2 (
    call :restartProgram
) else if !errorlevel! == 3 (
    @REM Stop the Clash process
    call :killProcessWrapper

    @REM Defer the final network check
    if "!lazyCheck!" == "1" (
        call :checkNetworkWrapper continue 0
        if "!continue!" == "0" exit /b
    )

    @REM Restore required components
    call :updateComponents
) else (
    :: cancel
    exit /b
)

for /l %%i in (1,1,5) do (
    @REM Recheck connectivity
    call :testConnection available 0
    if "!available!" == "1" (
        @echo [%ESC%[!infoColor!m信息%ESC%[0m] 问题修复%ESC%[!infoColor!m成功%ESC%[0m，网络代理可%ESC%[!infoColor!m正常%ESC%[0m使用
        exit /b
    ) else (
        @REM Wait before continuing
        timeout /t 1 /nobreak >nul 2>nul
    )
)

@echo [%ESC%[91m错误%ESC%[0m] 问题修复%ESC%[91m失败%ESC%[0m， 网络代理仍%ESC%[91m无法%ESC%[0m使用， 请尝试其他方法
goto :eof

@REM ============================================================================
@REM Check network connectivity and report user-facing errors
@REM Purpose:    Check network connectivity and report user-facing errors
@REM Parameters: <result>, <enable>
@REM Returns:    Sets <result> with the computed value or status
@REM ============================================================================
:checkNetworkWrapper <result> <enable>
set "%~1=1"
call :trim logLevel "%~2"
if "!logLevel!" == "" set "logLevel=1"

call :checkNetworkAvailable available 0 "https://www.baidu.com" ""
if "!available!" == "0" (
    @echo [%ESC%[91m错误%ESC%[0m] 网络%ESC%[91m不可用%ESC%[0m， 但代理程序%ESC%[91m并未运行%ESC%[0m，请检查你的%ESC%[!warnColor!m本地网络%ESC%[0m是否正常

    @REM Terminate on failure when requested
    set "%~1=0"
    exit /b
)

if "!logLevel!" == "1" (
    @echo [%ESC%[!warnColor!m提示%ESC%[0m] 网络代理%ESC%[91m没有开启%ESC%[0m， 推荐选择 %ESC%[!warnColor!mRestart%ESC%[0m 开启
)
goto :eof

@REM ============================================================================
@REM Update proxy components and related resources
@REM Purpose:    Update proxy components and related resources
@REM ============================================================================
:updateComponents
set "downloadedAlready=0"

if "!quickFlag!" == "1" (
    call :quickUpdate modified
    if "!modified!" == "0" (exit /b 0) else (set "downloadedAlready=1")
)

@REM Run as administrator when needed
if "!asDaemon!" == "1" (
    cacls "%SystemDrive%\System Volume Information" >nul 2>&1 || (
        if "!showWindow!" == "1" (
            powershell -Command "Start-Process '%~snx0' -ArgumentList ' %*' -Verb RunAs"
        ) else (
            powershell -Command "Start-Process '%~snx0' -ArgumentList ' %*' -Verb RunAs -WindowStyle Hidden"
        )
        exit /b
    )
)

@REM Prepare all required components
call :prepareComponents changed 1 !downloadedAlready!

@REM No new version was found
if "!changed!" == "0" (
    @echo [%ESC%[!infoColor!m信息%ESC%[0m] 当前已是最新版本，无需更新
) else (
    @REM Wait before continuing for overwrite files
    timeout /t 1 /nobreak >nul 2>nul
)

@REM Clean temporary files after update
call :cleanWorkspace "!temp!"

@REM Start the proxy program
call :startClash

@REM Regenerate auto update script
if "!regenerate!" == "1" call :generateUpdateVbs

goto :eof

@REM ============================================================================
@REM Parse command-line arguments
@REM Purpose:    Parse command-line arguments
@REM ============================================================================
:parseArgs
set result=false

if "%1" == "-a" set result=true
if "%1" == "--alpha" set result=true
if "!result!" == "true" (
    set "alpha=1"
    set result=false
    shift & goto :parseArgs
)

if "%1" == "-b" set result=true
if "%1" == "--brief" set result=true
if "!result!" == "true" (
    set "brief=1"
    set result=false
    shift & goto :parseArgs
)

if "%1" == "-c" set result=true
if "%1" == "--conf" set result=true
if "!result!" == "true" (
    @REM Validate the file argument
    call :trim subscription "%~2"

    if "!subscription!" == "" set result=false
    if "!subscription:~0,2!" == "--" set result=false
    if "!subscription:~0,1!" == "-" set result=false

    if "!result!" == "false" (
        @echo [%ESC%[91m错误%ESC%[0m] 如果指定参数 "%ESC%[!warnColor!m--conf%ESC%[0m" 或者 "%ESC%[!warnColor!m-c%ESC%[0m" 则必须提供有效的%ESC%[!warnColor!m配置文件%ESC%[0m或%ESC%[!warnColor!m订阅%ESC%[0m
        @echo.
        goto :usage
    )

    if "!subscription:~0,8!" == "https://" set "isWebLink=1"
    if "!subscription:~0,7!" == "http://" set "isWebLink=1"
    if "!isWebLink!" == "1" (
        set "invalid=0"

        @REM Include '"' see https://stackoverflow.com/questions/46238709/how-to-detect-if-input-is-quote
        @REM @echo !subscription! | findstr /i /r /c:"\"^" >nul && (set "invalid=1")

        @REM Remove double quotes
        set "subscription=!subscription:"=!"

        @REM Reject whitespace
        if "!subscription!" neq "!subscription: =!" set "invalid=1"
        @REM Match a URL
        echo "!subscription!" | findstr /i /r /c:^"\"http.*://.*[a-zA-Z0-9][a-zA-Z0-9]*\"^" >nul 2>nul || (set "invalid=1")

        if "!invalid!" == "1" (
            set "shouldExit=1"

            @echo [%ESC%[91m错误%ESC%[0m] 无效的订阅链接 "%ESC%[!warnColor!m!subscription!%ESC%[0m"
            @echo.
            goto :eof
        )
        set "subscriptionLink=!subscription!"
    ) else (
        set "invalid=1"
        if "!subscription:~-5!" == ".yaml" (set "invalid=0") else (
            if "!subscription:~-4!" == ".yml" (set "invalid=0")
        )
        if "!invalid!" == "0" (
            set "configuration=!subscription!"
        ) else (
            set "shouldExit=1"

            @echo [%ESC%[91m错误%ESC%[0m] 无效的配置文件 "%ESC%[!warnColor!m!subscription!%ESC%[0m"，仅支持 "%ESC%[!warnColor!m.yaml%ESC%[0m" 和 "%ESC%[!warnColor!m.yml%ESC%[0m" 格式
            @echo.
            goto :eof
        )
    )
    shift & shift & goto :parseArgs
)

if "%1" == "-d" set result=true
if "%1" == "--daemon" set result=true
if "!result!" == "true" (
    set "asDaemon=1"
    set result=false
    shift & goto :parseArgs
)

if "%1" == "-e" set result=true
if "%1" == "--exclude" set result=true
if "!result!" == "true" (
    set "excludeUpdates=1"
    set result=false
    shift & goto :parseArgs
)

if "%1" == "-f" set result=true
if "%1" == "--fix" set result=true
if "!result!" == "true" (
    set "repairFlag=1"
    set result=false
    shift & goto :parseArgs
)

if "%1" == "-g" set result=true
if "%1" == "--generate" set result=true
if "!result!" == "true" (
    set "regenerate=1"
    set result=false
    shift & goto :parseArgs
)

if "%1" == "-h" set result=true
if "%1" == "--help" set result=true
if "!result!" == "true" (
    call :usage
)

if "%1" == "-i" set result=true
if "%1" == "--init" set result=true
if "!result!" == "true" (
    set "initFlag=1"
    set result=false
    shift & goto :parseArgs
)

if "%1" == "-k" set result=true
if "%1" == "--kill" set result=true
if "!result!" == "true" (
    set "killFlag=1"
    set result=false
    shift & goto :parseArgs
)

if "%1" == "-l" set result=true
if "%1" == "--love" set result=true
if "!result!" == "true" (
    if "!customize!" == "1" (
        set "drawHeart=1"
        set result=false
        shift & goto :parseArgs
    ) else (
        @echo [%ESC%[91m错误%ESC%[0m] 未知参数：%ESC%[91m%1%ESC%[0m
        @echo.
        goto :usage
    )
)

if "%1" == "-m" set result=true
if "%1" == "--meta" set result=true
if "!result!" == "true" (
    set "useClashMeta=1"
    set "useClashPremium=0"
    set "useVerneMihomo=0"
    set "coreForced=1"
    set result=false
    shift & goto :parseArgs
)

if "%1" == "-n" set result=true
if "%1" == "--native" set result=true
if "!result!" == "true" (
    set "useClashPremium=1"
    set "useClashMeta=0"
    set "useVerneMihomo=0"
    set "coreForced=1"
    set result=false
    shift & goto :parseArgs
)

if "%1" == "-o" set result=true
if "%1" == "--overload" set result=true
if "!result!" == "true" (
    set "reloadOnly=1"
    set result=false
    shift & goto :parseArgs
)

if "%1" == "-p" set result=true
if "%1" == "--purge" set result=true
if "!result!" == "true" (
    set "purgeFlag=1"
    set result=false
    shift & goto :parseArgs
)

if "%1" == "-q" set result=true
if "%1" == "--quick" set result=true
if "!result!" == "true" (
    set "quickFlag=1"
    set result=false
    shift & goto :parseArgs
)

if "%1" == "-r" set result=true
if "%1" == "--restart" set result=true
if "!result!" == "true" (
    set "restartFlag=1"
    set result=false
    shift & goto :parseArgs
)

if "%1" == "-s" set result=true
if "%1" == "--show" set result=true
if "!result!" == "true" (
    set "showWindow=1"
    set result=false
    shift & goto :parseArgs
)

if "%1" == "-t" set result=true
if "%1" == "--test" set result=true
if "!result!" == "true" (
    set "testFlag=1"
    set result=false
    shift & goto :parseArgs
)

if "%1" == "-u" set result=true
if "%1" == "--update" set result=true
if "!result!" == "true" (
    set "updateFlag=1"
    set result=false
    shift & goto :parseArgs
)

if "%1" == "-v" set result=true
if "%1" == "--verne" set result=true
if "!result!" == "true" (
    set "useVerneMihomo=1"
    @REM Smart Mihomo still uses the mihomo download and geodata branch
    set "useClashMeta=1"
    set "useClashPremium=0"
    set "coreForced=1"
    set result=false
    shift & goto :parseArgs
)

if "%1" == "-w" set result=true
if "%1" == "--workspace" set result=true
if "!result!" == "true" (
    @REM Validate the file argument
    call :trim param "%~2"
    if "!param!" == "" set result=false
    if "!param:~0,2!" == "--" set result=false
    if "!param:~0,1!" == "-" set result=false

    if "!result!" == "false" (
        @echo [%ESC%[91m错误%ESC%[0m] 无效的参数，如果指定 "%ESC%[!warnColor!m--workspace%ESC%[0m"，"%ESC%[!warnColor!m!param!%ESC%[0m"，则需提供有效的路径
        @echo.
        goto :usage
    )

    call :convertToAbsolutePath directory "!param!"
    if not exist "!directory!" (
        call :createDirectories success "!directory!"
        if "!success!" == "1" (rd "!directory!" /s /q >nul 2>nul) else (set "shouldExit=1")
    )

    if "!shouldExit!" == "1" (
        @echo [%ESC%[91m错误%ESC%[0m] 参数 "%ESC%[!warnColor!m--workspace%ESC%[0m" 指定的文件夹路径 "%ESC%[!warnColor!m!directory!%ESC%[0m" %ESC%[91m无效%ESC%[0m
        @echo.
        goto :eof
    )

    set "dest=!directory!"
    set result=false
    shift & shift & goto :parseArgs
)

if "%1" == "-x" set result=true
if "%1" == "--metacubexd" set result=true
if "!result!" == "true" (
    set "metaCubeXDashboard=1"
    set "dashboardForced=1"
    set "yacd=0"
    set "zashboard=0"
    set result=false
    shift & goto :parseArgs
)

if "%1" == "-y" set result=true
if "%1" == "--yacd" set result=true
if "!result!" == "true" (
    set "metaCubeXDashboard=0"
    set "yacd=1"
    set "dashboardForced=1"
    set "zashboard=0"
    set result=false
    shift & goto :parseArgs
)

if "%1" == "-z" set result=true
if "%1" == "--zashboard" set result=true
if "!result!" == "true" (
    set "metaCubeXDashboard=0"
    set "yacd=0"
    set "zashboard=1"
    set "dashboardForced=1"
    set result=false
    shift & goto :parseArgs
)

@REM Keep this branch separate because merging it changes batch argument parsing behavior
if "%1" == "" goto :eof

if "%1" NEQ "" (
    call :trim syntax "%~1"
    if "!syntax!" == "goto" (
        call :trim funcName "%~2"
        if "!funcName!" == "" (
            @echo [%ESC%[91m错误%ESC%[0m] 无效的语法，调用 "%ESC%[!warnColor!mgoto%ESC%[0m" 时必须提供函数名
            goto :usage
        )

        for /f "tokens=1-2,* delims= " %%a in ("%*") do set "params=%%c"
        if "!params!" == "" (
            call !funcName!
            exit /b
        ) else (
            call !funcName! !params!
            exit /b
        )
    )

    @echo [%ESC%[91m错误%ESC%[0m] 未知参数：%ESC%[91m%1%ESC%[0m
    @echo.
    goto :usage
)

goto :eof

@REM ============================================================================
@REM Print command usage
@REM Purpose:    Print command usage
@REM ============================================================================
:usage
set "usageLine=使用方法：!batchName! [%ESC%[!warnColor!m功能选项%ESC%[0m] [%ESC%[!warnColor!m其他参数%ESC%[0m]，支持 %ESC%[!warnColor!m-%ESC%[0m 和 %ESC%[!warnColor!m--%ESC%[0m 两种模式"
@echo(!usageLine!
@echo.
set "usageLine=功能选项："
@echo(!usageLine!
set "usageLine=-f, --fix             检查并尝试修复代理网络"
@echo(!usageLine!
set "usageLine=-h, --help            打印帮助信息"
@echo(!usageLine!
set "usageLine=-i, --init            利用 %ESC%[!warnColor!m--conf%ESC%[0m 提供的配置文件创建代理网络"
@echo(!usageLine!
set "usageLine=-k, --kill            退出网络代理程序"
@echo(!usageLine!
if "!customize!" == "1" (
    set "usageLine=-l, --love            当然是大声告诉我宝我爱她啦🤪🤪🤪"
    @echo(!usageLine!
)
set "usageLine=-o, --overload        重新加载配置文件"
@echo(!usageLine!
set "usageLine=-p, --purge           关闭系统代理并禁止程序开机自启，取消自动更新"
@echo(!usageLine!
set "usageLine=-r, --restart         重启网络代理程序"
@echo(!usageLine!
set "usageLine=-t, --test            测试代理网络是否可用"
@echo(!usageLine!
set "usageLine=-u, --update          更有所有组件，包括代理程序、订阅、代理规则以及 IP 地址数据库等"
@echo(!usageLine!
@echo.
set "usageLine=其他参数："
@echo(!usageLine!
set "usageLine=-a, --alpha           是否允许使用预览版，默认为稳定版，搭配 %ESC%[!warnColor!m-i%ESC%[0m 或者 %ESC%[!warnColor!m-u%ESC%[0m 使用"
@echo(!usageLine!
set "usageLine=-b, --brief           精简模式运行，没有明确配置dashboard情况下，无法使用可视化页面"
@echo(!usageLine!
set "usageLine=-c, --conf            配置文件，支持本地配置文件和订阅链接，默认为当前目录下的 %ESC%[!warnColor!mconfig.yaml%ESC%[0m"
@echo(!usageLine!
set "usageLine=-d, --daemon          后台静默执行，禁止打印日志"
@echo(!usageLine!
set "usageLine=-e, --exclude         更新时跳过代理集中配置的订阅"
@echo(!usageLine!
set "usageLine=-g, --generate        重新生成自动检查更新的脚本，搭配 %ESC%[!warnColor!m-u%ESC%[0m 使用"
@echo(!usageLine!
set "usageLine=-m, --meta            使用 %ESC%[!warnColor!m!metaCubeXMihomoName!%ESC%[0m 代理内核，搭配 %ESC%[!warnColor!m-i%ESC%[0m 或 %ESC%[!warnColor!m-u%ESC%[0m 使用"
@echo(!usageLine!
set "usageLine=-n, --native          使用 %ESC%[!warnColor!m!clashPremiumName!%ESC%[0m 代理内核，搭配 %ESC%[!warnColor!m-i%ESC%[0m 或 %ESC%[!warnColor!m-u%ESC%[0m 使用"
@echo(!usageLine!
set "usageLine=-q, --quick           仅更新新订阅和代理规则，搭配 %ESC%[!warnColor!m-u%ESC%[0m 使用"
@echo(!usageLine!
set "usageLine=-s, --show            新窗口中执行，默认为当前窗口"
@echo(!usageLine!
set "usageLine=-v, --verne           使用 使用 %ESC%[!warnColor!m!smartMihomoName!%ESC%[0m 代理内核，搭配 %ESC%[!warnColor!m-i%ESC%[0m 或 %ESC%[!warnColor!m-u%ESC%[0m 使用"
@echo(!usageLine!
set "usageLine=-w, --workspace       代理程序运行路径，默认为当前脚本所在目录"
@echo(!usageLine!
set "usageLine=-x, --metacubexd      使用 %ESC%[!warnColor!mmetacubexd%ESC%[0m 控制面板，搭配 %ESC%[!warnColor!m-i%ESC%[0m 或 %ESC%[!warnColor!m-u%ESC%[0m 使用"
@echo(!usageLine!
set "usageLine=-y, --yacd            使用 %ESC%[!warnColor!myacd%ESC%[0m 控制面板，搭配 %ESC%[!warnColor!m-i%ESC%[0m 或 %ESC%[!warnColor!m-u%ESC%[0m 使用"
@echo(!usageLine!
set "usageLine=-z, --zashboard       使用 %ESC%[!warnColor!mzashboard%ESC%[0m 控制面板，搭配 %ESC%[!warnColor!m-i%ESC%[0m 或 %ESC%[!warnColor!m-u%ESC%[0m 使用"
@echo(!usageLine!
@echo.
set "usageLine="

set "shouldExit=1"
goto :eof

@REM ============================================================================
@REM Print the optional heart message
@REM Purpose:    Print the optional heart message
@REM ============================================================================
:printHeart
set "whitespace="

@echo.
@echo !whitespace!        *********           *********
@echo !whitespace!    *****************   *****************
@echo !whitespace!  *****************************************
@echo !whitespace! *******************************************
@echo !whitespace!*********************************************
@echo !whitespace!**********************************************
@echo !whitespace!**********************************************
@echo !whitespace!**********************************************
if "!msTerminal!" == "1" (
    @echo !whitespace!***********  %ESC%[91m我的宝，我爱你 ♥♥♥%ESC%[0m  *************
) else (
    @echo !whitespace!*********** %ESC%[91m我的宝，我爱你 ♥♥♥%ESC%[0m ***************
)

@echo !whitespace!**********                        ***********
@echo !whitespace! ******** %ESC%[91m因为有你，生活可爱了许多%ESC%[0m *********
@echo !whitespace!  *****************************************
@echo !whitespace!   ***************************************
@echo !whitespace!    *************************************
@echo !whitespace!     ***********************************
@echo !whitespace!      *********************************
@echo !whitespace!        *****************************
@echo !whitespace!          *************************
@echo !whitespace!            *********************
@echo !whitespace!               ***************
@echo !whitespace!                  *********
@echo !whitespace!                     ***
@echo !whitespace!                      *
@echo.
exit /b
goto :eof

@REM ============================================================================
@REM Select the required proxy core edition
@REM Purpose:    Select the required proxy core edition
@REM Parameters: <geosite>, <subscriptionFiles>
@REM Returns:    Sets <geosite> with the computed value or status
@REM ============================================================================
:detectRequiredEdition <geosite> <subscriptionFiles>
set "%~1=0"
set "content="
set "needGeoSite=0"

@REM Yacd dashboard
if "!metaCubeXDashboard!" == "0" if "!zashboard!" == "0" if "!dashboard!" NEQ "" if exist "!dashboard!\yacd.ico" set "yacd=1"

@REM MetaCubeXD dashboard
if "!yacd!" == "0" if "!zashboard!" == "0" if "!dashboard!" NEQ "" if exist "!dashboard!\maskable-icon-512x512.png" set "metaCubeXDashboard=1"

@REM Zashboard dashboard
if "!yacd!" == "0" if "!metaCubeXDashboard!" == "0" if "!dashboard!" NEQ "" if exist "!dashboard!\pwa-maskable-512x512.png" set "zashboard=1"

@REM Force use Clash Premium
if "!useClashPremium!" == "1" (
    set "useVerneMihomo=0"
    set "lgbmUrl="
    set "useClashMeta=0"
    call :resolveProxyExecutableName
    goto :eof
)

if "!coreForced!" == "0" (
    set "useVerneMihomo=0"
    if "!cfgHasSmartGroup!" == "1" (
        set "useVerneMihomo=1"
        set "useClashMeta=1"
        set "useClashPremium=0"
    )

    if "!useVerneMihomo!" == "0" (
        call :detectInstalledProxyEdition localEdition localEditionFound
        if "!localEditionFound!" == "1" (
            if "!localEdition!" == "2" (
                set "useVerneMihomo=1"
                set "useClashMeta=1"
                set "useClashPremium=0"
            ) else if "!localEdition!" == "1" (
                set "useClashMeta=1"
                set "useClashPremium=0"
            )
        )
    )
)

set "lgbmUrl="
if "!useVerneMihomo!" == "1" (
    set "useClashMeta=1"
    set "useClashPremium=0"

    if /i "!cfgUseLightGbm:~0,4!" == "true" (
        set "lgbmUrl=!cfgLgbmUrl!"
        if "!lgbmUrl!" == "" set "lgbmUrl=https://github.com/vernesong/mihomo/releases/download/LightGBM-Model/Model.bin"
    )
)

set "notFound=1"
if "!cfgHasGeoSiteRule!" == "1" (
    set "notFound=0"
    set "needGeoSite=1"
)
if "!cfgHasMetaRule!" == "1" set "notFound=0"

@REM Rulesets include GEOSITE, must be MetaCubeX Mihomo
if "!notFound!" == "0" (set "useClashMeta=1")
if "!useClashMeta!" == "1" (
    set "%~1=!needGeoSite!"
    set "useClashPremium=0"
    call :resolveProxyExecutableName
    goto :eof
)

@REM Rules include IP-ASN/SRC-IP-ASN, must be MetaCubeX Mihomo
if "!cfgHasAsnRule!" == "1" (
    set "useClashMeta=1"
    set "useClashPremium=0"
    set "%~1=!needGeoSite!"
    call :resolveProxyExecutableName
    goto :eof
)

@REM MetaCubeX Mihomo does not support SCRIPT rule
if "!cfgHasScriptRule!" == "1" (
    set "useClashMeta=0"
    set "useClashPremium=1"
    call :resolveProxyExecutableName
    goto :eof
)

@REM Include sniffer, must be MetaCubeX Mihomo
if "!cfgHasSniffer!" == "1" (
    set "useClashMeta=1"
    set "useClashPremium=0"
    call :resolveProxyExecutableName
    goto :eof
)

@REM Proxy-groups include exclude-filter, must be MetaCubeX Mihomo
if "!cfgHasExcludeFilter!" == "1" (
    set "useClashMeta=1"
    set "useClashPremium=0"
    call :resolveProxyExecutableName
    goto :eof
)

@REM Include vless or hysteria, must be MetaCubeX Mihomo
if "!cfgHasMetaProxy!" == "1" (
    set "useClashMeta=1"
    set "useClashPremium=0"
    call :resolveProxyExecutableName
    goto :eof
)

@REM Old edition
if exist "!dest!\!mihomoExecutableName!" ("!dest!\!mihomoExecutableName!" -v | findstr /i "Meta" >nul 2>nul && (
        set "useClashMeta=1"
        set "useClashPremium=0"
    )
)
call :resolveProxyExecutableName
goto :eof

@REM ============================================================================
@REM Load frequently used configuration facts
@REM Purpose:    Load frequently used configuration facts
@REM Parameters: <subscriptionFiles>
@REM ============================================================================
:loadConfigSummary <subscriptionFiles>
set "cfgHasSmartGroup=0"
set "cfgHasSmartPreferAsn=0"
set "cfgHasAsnRule=0"
set "cfgHasGeoSiteRule=0"
set "cfgHasMetaRule=0"
set "cfgHasScriptRule=0"
set "cfgHasSniffer=0"
set "cfgHasExcludeFilter=0"
set "cfgHasMetaProxy=0"
set "cfgUseLightGbm="
set "cfgLgbmUrl="
set "cfgGeoSiteUrl="
set "cfgGeoDataMode=false"
set "cfgCountryUrl="
set "cfgGeoIpUrl="
set "cfgGeoAsnUrl="
set "cfgExternalUiUrl="
set "cfgSummaryFile=!temp!\clash-config-summary.txt"
del /f /q "!cfgSummaryFile!" >nul 2>nul

powershell -NoProfile -ExecutionPolicy Bypass -Command "& {$config='!configFile!'; $out='!cfgSummaryFile!'; $subs='%~1'; $vars=[ordered]@{cfgHasSmartGroup='0';cfgHasSmartPreferAsn='0';cfgHasAsnRule='0';cfgHasGeoSiteRule='0';cfgHasMetaRule='0';cfgHasScriptRule='0';cfgHasSniffer='0';cfgHasExcludeFilter='0';cfgHasMetaProxy='0';cfgUseLightGbm='';cfgLgbmUrl='';cfgGeoSiteUrl='';cfgGeoDataMode='false';cfgCountryUrl='';cfgGeoIpUrl='';cfgGeoAsnUrl='';cfgExternalUiUrl=''}; function CleanValue([string]$value) {if ($null -eq $value) {return ''}; return $value.Trim().Trim([char]34).Trim([char]39)}; function Read-Lines([string]$path) {if ($path -and (Test-Path -LiteralPath $path)) {Get-Content -LiteralPath $path}}; $files=@($config); if ($subs) {$files += $subs -split ','}; foreach ($raw in Read-Lines $config) {$line=[string]$raw; $text=$line.Trim(); if ((-not $text) -or $text.StartsWith('#')) {continue}; $lower=$text.ToLowerInvariant(); $isRule=$lower.StartsWith('- '); if ($lower -eq 'type: smart') {$vars.cfgHasSmartGroup='1'}; if ($lower -eq 'prefer-asn: true') {$vars.cfgHasSmartPreferAsn='1'}; if ($lower.StartsWith('- ip-asn,') -or $lower.StartsWith('- src-ip-asn,')) {$vars.cfgHasAsnRule='1'}; if ($isRule -and ($lower -like '*geosite,*')) {$vars.cfgHasGeoSiteRule='1'}; if ($isRule -and ($lower -like '*sub-rule,*' -or $lower -like '*and,*' -or $lower -like '*or,*' -or $lower -like '*not,*' -or $lower -like '*in-type,*')) {$vars.cfgHasMetaRule='1'}; if ($isRule -and ($lower -like '*script,*')) {$vars.cfgHasScriptRule='1'}; if ($lower -eq 'sniffer:') {$vars.cfgHasSniffer='1'}; if ($lower.StartsWith('exclude-filter:')) {$vars.cfgHasExcludeFilter='1'}; if ($lower.StartsWith('uselightgbm:')) {$vars.cfgUseLightGbm=CleanValue (($text -split ':',2)[1])}; if ($lower.StartsWith('lgbm-url:')) {$value=CleanValue (($text -split ':',2)[1]); if ($value -match '^https?://') {$vars.cfgLgbmUrl=$value}}; if ($lower.StartsWith('geosite:')) {$vars.cfgGeoSiteUrl=CleanValue (($text -split ':',2)[1])}; if ($lower.StartsWith('geodata-mode:')) {$vars.cfgGeoDataMode=CleanValue (($text -split ':',2)[1])}; if ($lower.StartsWith('mmdb:')) {$vars.cfgCountryUrl=CleanValue (($text -split ':',2)[1])}; if ($lower.StartsWith('geoip:')) {$value=CleanValue (($text -split ':',2)[1]); if ($value -match '^https?://') {$vars.cfgGeoIpUrl=$value}}; if ($lower.StartsWith('external-ui-url:')) {$value=CleanValue (($text -split ':',2)[1]); if ($value -match '^https?://') {$vars.cfgExternalUiUrl=$value}}}; $insideGeox=$false; foreach ($raw in Read-Lines $config) {$line=[string]$raw; $text=$line.Trim(); if ((-not $text) -or $text.StartsWith('#')) {continue}; if ($text -ieq 'geox-url:') {$insideGeox=$true; continue}; if ($insideGeox) {if ((-not $line.StartsWith(' ')) -and (-not $line.StartsWith('-'))) {$insideGeox=$false; continue}; $parts=$text -split ':',2; if ($parts.Count -eq 2 -and $parts[0].Trim() -ieq 'asn') {$vars.cfgGeoAsnUrl=CleanValue $parts[1]}}}; foreach ($file in $files) {foreach ($raw in Read-Lines $file) {$text=([string]$raw).Trim(); if ((-not $text) -or $text.StartsWith('#')) {continue}; $lower=$text.ToLowerInvariant(); if ($lower -match '^(type:\s+(vless|hysteria)|client-fingerprint:|flow:\s+xtls-)') {$vars.cfgHasMetaProxy='1'}}}; $lines=$vars.GetEnumerator() | ForEach-Object {($_.Key + '=' + $_.Value)}; [System.IO.File]::WriteAllLines($out, [string[]]$lines, (New-Object System.Text.UTF8Encoding $false))}"

if exist "!cfgSummaryFile!" (
    for /f "usebackq tokens=1* delims==" %%a in ("!cfgSummaryFile!") do set "%%a=%%b"
    del /f /q "!cfgSummaryFile!" >nul 2>nul
)
goto :eof

@REM ============================================================================
@REM Resolve the selected proxy executable name
@REM Purpose:    Resolve the selected proxy executable name
@REM ============================================================================
:resolveProxyExecutableName
set "proxyExecutableName=!clashExecutableName!"
if "!useClashMeta!" == "1" set "proxyExecutableName=!mihomoExecutableName!"
if "!useVerneMihomo!" == "1" set "proxyExecutableName=!mihomoExecutableName!"
goto :eof

@REM ============================================================================
@REM Detect the proxy core edition from executable version output
@REM Purpose:    Classify a proxy executable by running its -v argument
@REM Parameters: <edition>, <found>, <executable>
@REM Returns:    <edition>: 0=Clash Premium/unknown, 1=MetaCubeX Mihomo, 2=Smart Mihomo
@REM             <found>:   0=not found, 1=executable exists
@REM ============================================================================
:detectProxyEditionFromExecutable <edition> <found> <executable>
set "%~1=0"
set "%~2=0"
set "proxyVersionLine="
call :trim proxyExecutablePath "%~3"

if "!proxyExecutablePath!" == "" goto :eof
if not exist "!proxyExecutablePath!" goto :eof

set "%~2=1"
for /f "usebackq delims=" %%a in (`""!proxyExecutablePath!" -v 2^>nul"`) do if "!proxyVersionLine!" == "" set "proxyVersionLine=%%a"
if "!proxyVersionLine!" == "" goto :eof

echo !proxyVersionLine! | findstr /l /i /c:"-smart-" >nul 2>nul && (
    set "%~1=2"
    goto :eof
)

echo !proxyVersionLine! | findstr /l /i /c:"Mihomo Meta" >nul 2>nul && set "%~1=1"
goto :eof

@REM ============================================================================
@REM Detect the installed proxy core edition
@REM Purpose:    Prefer the selected executable, then managed fallback names
@REM Parameters: <edition>, <found>
@REM Returns:    <edition>: 0=Clash Premium/unknown, 1=MetaCubeX Mihomo, 2=Smart Mihomo
@REM             <found>:   0=not found, 1=executable exists
@REM ============================================================================
:detectInstalledProxyEdition <edition> <found>
set "%~1=0"
set "%~2=0"

call :detectProxyEditionFromExecutable detectedEdition detectedFound "!dest!\!proxyExecutableName!"
if "!detectedFound!" == "1" (
    set "%~1=!detectedEdition!"
    set "%~2=1"
    goto :eof
)

if /i "!proxyExecutableName!" NEQ "!mihomoExecutableName!" (
    call :detectProxyEditionFromExecutable detectedEdition detectedFound "!dest!\!mihomoExecutableName!"
    if "!detectedFound!" == "1" (
        set "%~1=!detectedEdition!"
        set "%~2=1"
        goto :eof
    )
)

if /i "!proxyExecutableName!" NEQ "!clashExecutableName!" (
    call :detectProxyEditionFromExecutable detectedEdition detectedFound "!dest!\!clashExecutableName!"
    if "!detectedFound!" == "1" (
        set "%~1=!detectedEdition!"
        set "%~2=1"
    )
)
goto :eof

@REM ============================================================================
@REM Resolve the display name for a core edition
@REM Purpose:    Resolve the display name for a core edition
@REM Parameters: <result>, <edition>
@REM Returns:    Sets <result> with the computed value or status
@REM ============================================================================
:resolveCoreDisplayName <result> <edition>
set "%~1=!clashPremiumName!"
if "%~2" == "1" set "%~1=!metaCubeXMihomoName!"
if "%~2" == "2" set "%~1=!smartMihomoName!"
goto :eof

@REM ============================================================================
@REM Detect whether the installed proxy edition must be switched
@REM Purpose:    Compare installed and required proxy core editions
@REM Parameters: <geosite>, <subscriptionFiles>
@REM Returns:    Sets proxyEditionChanged to 1 when the installed edition differs
@REM ============================================================================
:detectProxyEditionChange <geosite> <subscriptionFiles>
set "proxyEditionChanged=0"

call :detectInstalledProxyEdition installedEdition installedEditionFound
call :detectRequiredEdition "%~1" %~2

set "targetEdition=0"
if "!useClashMeta!" == "1" set "targetEdition=1"
if "!useVerneMihomo!" == "1" set "targetEdition=2"

if "!installedEditionFound!" == "1" if "!installedEdition!" NEQ "!targetEdition!" (
    set "proxyEditionChanged=1"
    call :resolveCoreDisplayName oldEdition !installedEdition!
    call :resolveCoreDisplayName newEdition !targetEdition!

    @echo [%ESC%[!warnColor!m提示%ESC%[0m] 配置%ESC%[91m不兼容%ESC%[0m，代理程序需从 %ESC%[!warnColor!m!oldEdition!%ESC%[0m 切换至 %ESC%[!warnColor!m!newEdition!%ESC%[0m
)
goto :eof

@REM ============================================================================
@REM Detect Smart proxy groups
@REM Purpose:    Detect Smart proxy groups
@REM Parameters: <result>
@REM ============================================================================
:detectSmartGroup <result>
set "%~1=0"
call :findYamlSectionValue smartGroupType "!configFile!" "proxy-groups" "type" "smart"
if /i "!smartGroupType!" == "smart" set "%~1=1"
goto :eof

@REM ============================================================================
@REM Detect ASN-based rules
@REM Purpose:    Detect ASN-based rules
@REM Parameters: <result>
@REM ============================================================================
:detectAsnRules <result>
set "%~1=0"
call :findYamlSectionLine asnRule "!configFile!" "rules" "- IP-ASN," "- SRC-IP-ASN,"
if "!asnRule!" NEQ "" set "%~1=1"
goto :eof

@REM ============================================================================
@REM Detect Smart groups using ASN preference
@REM Purpose:    Detect Smart groups using ASN preference
@REM Parameters: <result>
@REM ============================================================================
:detectSmartPreferAsn <result>
set "%~1=0"
call :findYamlSectionListItemValue smartPreferAsn "!configFile!" "proxy-groups" "type" "smart" "prefer-asn" "true"
if /i "!smartPreferAsn!" == "true" set "%~1=1"
goto :eof

@REM ============================================================================
@REM Detect whether the ASN database is required
@REM Purpose:    Detect whether the ASN database is required
@REM Parameters: <result>
@REM ============================================================================
:detectAsnNeeded <result>
set "%~1=0"

call :detectAsnRules asnRules
if "!asnRules!" == "1" (
    set "%~1=1"
    goto :eof
)

if "!useVerneMihomo!" == "1" (
    call :detectSmartPreferAsn smartAsn
    if "!smartAsn!" == "1" set "%~1=1"
)
goto :eof

@REM ============================================================================
@REM Quickly update subscriptions and rule providers
@REM Purpose:    Quickly update subscriptions and rule providers
@REM Parameters: <edition>
@REM ============================================================================
:quickUpdate <edition>
set "%~1=0"

@REM Configuration
call :updateConfig 1

@REM Subscriptions
if "!excludeUpdates!" == "0" call :updateSubscriptions subscriptionFiles 1

@REM Rulesets
call :updateRules 1

@REM Detect whether the core edition must be switched
call :detectProxyEditionChange geoSiteNeeded !subscriptionFiles!
if "!proxyEditionChanged!" == "1" (
    set "%~1=1"
    goto :eof
)

@REM Reload
if "!changed!" == "1" (goto :reloadConfig) else (goto :eof)

@REM ============================================================================
@REM Search rule text for unsupported rule types
@REM Purpose:    Search rule text for unsupported rule types
@REM Parameters: <notFound>, <text>
@REM Returns:    Sets <notFound> with the computed value or status
@REM ============================================================================
:searchRules <notFound> <text>
set "%~1=1"
set "rulesets=%~2"

for /F "tokens=1* delims=;" %%f in ("!rulesets!") do (
    :: set "rule=%%f"
    call :trim rule "%%f"
    if /i "!rule:~0,1!"=="-" (
        set "%~1=0"
        goto :eof
    )

    if "%%g" NEQ "" call :searchRules %~1 "%%g"
)
goto :eof

@REM ============================================================================
@REM Update subscription-managed configuration
@REM Purpose:    Update subscription-managed configuration
@REM Parameters: <subscriptionFiles>, <force>
@REM ============================================================================
:updateSubscriptions <subscriptionFiles> <force>
call :trim force "%~2"
if "!force!" == "" set "force=1"

if "!force!" == "1" (
    @echo [%ESC%[!infoColor!m信息%ESC%[0m] 检查并更新订阅，仅刷新 %ESC%[!warnColor!mHTTP%ESC%[0m 类型的订阅
)

call :refreshReferencedFiles changed "proxy-providers" "!force!" subscriptionFiles "proxies"
set "%~1=!subscriptionFiles!"
goto :eof

@REM ============================================================================
@REM Split a file path into directory and file name
@REM Purpose:    Split a file path into directory and file name
@REM Parameters: <directory>, <fileName>, <filePath>
@REM Returns:    Sets <directory> with the computed value or status
@REM ============================================================================
:splitPath <directory> <fileName> <filePath>
set "%~1=%~dp3"
set "%~2=%~nx3"

if "!%~1:~-1!" == "\" set "%~1=!%~1:~0,-1!"
goto :eof

@REM ============================================================================
@REM Convert a path to an absolute path
@REM Purpose:    Convert a path to an absolute path
@REM Parameters: <result>, <fileName>
@REM Returns:    Sets <result> with the computed value or status
@REM ============================================================================
:convertToAbsolutePath <result> <fileName>
call :trim filePath %~2
set "%~1="

if "!filePath!" == "" goto :eof

@echo "!filePath!" | findstr ":" >nul 2>nul && (
    set "%~1=!filePath!"
    goto :eof
) || (
    if "!dest!" NEQ "" (set "baseDir=!dest!") else (set "baseDir=%~dp0")
    if "!baseDir:~-1!" == "\" set "baseDir=!baseDir:~0,-1!"

    if "!filePath!" == "." (
        set "%~1=!baseDir!"
        goto :eof
    )

    set "filePath=!filePath:/=\!"
    if "!filePath:~0,3!" == ".\\" (
        set "%~1=!baseDir!\!filePath:~3!"
    ) else if "!filePath:~0,2!" == ".\" (
        set "%~1=!baseDir!\!filePath:~2!"
    ) else (
        set "%~1=!baseDir!\!filePath!"
    )
)
goto :eof

@REM ============================================================================
@REM Test network connectivity
@REM Purpose:    Test network connectivity
@REM Parameters: <result>, <allowed>
@REM Returns:    Sets <result> with the computed value or status
@REM ============================================================================
:testConnection <result> <allowed>
@REM Running status
set "%~1=0"
call :trim output "%~2"
if "!output!" == "" set "output=1"

call :isProcessRunning status
if "!status!" == "0" (
    if "!output!" == "1" (
        @echo [%ESC%[!warnColor!m提示%ESC%[0m] 网络%ESC%[91m不可用%ESC%[0m，代理程序%ESC%[91m已退出%ESC%[0m
    )

    goto :eof
)

@REM Call :getSystemProxy server
call :generateSystemProxy server

@REM Detect whether the network is available
call :checkNetworkAvailable status "!output!" "https://www.google.com" "!server!"
set "%~1=!status!"
goto :eof

@REM ============================================================================
@REM Check whether the network is reachable
@REM Purpose:    Check whether the network is reachable
@REM Parameters: <result>, <allowed>, <url>, <proxyServer>
@REM Returns:    Sets <result> with the computed value or status
@REM ============================================================================
:checkNetworkAvailable <result> <allowed> <url> <proxyServer>
set "%~1=0"
call :trim output "%~2"
call :trim url "%~3"
call :trim proxyServer "%~4"

if "!output!" == "" set "output=1"
if "!url!" == "" set "url=https://www.google.com"

@REM Check status
set "statusCode=000"
if "!proxyServer!" == "" (
    for /f %%a in ('curl --retry 3 --retry-max-time 10 -m 5 --connect-timeout 5 -L -s -o nul -w "%%{http_code}" "!url!"') do set "statusCode=%%a"
) else (
    for /f %%a in ('curl -x !proxyServer! --retry 3 --retry-max-time 10 -m 5 --connect-timeout 5 -L -s -o nul -w "%%{http_code}" "!url!"') do set "statusCode=%%a"
)

if "!statusCode!" == "200" (
    set "%~1=1"
    if "!output!" == "1" (
        @echo [%ESC%[!infoColor!m信息%ESC%[0m] 代理网络不存在问题，能够%ESC%[!infoColor!m正常%ESC%[0m使用
    )
) else (
    set "%~1=0"
    if "!output!" == "1" (
        call :postProcess

        @echo [%ESC%[!warnColor!m提示%ESC%[0m] 代理网络%ESC%[91m不可用%ESC%[0m，可%ESC%[!warnColor!m再次测试%ESC%[0m或使用命令 "%ESC%[!warnColor!m!batchName! -o%ESC%[0m" %ESC%[!warnColor!m重载%ESC%[0m 或者 "%ESC%[!warnColor!m!batchName! -r%ESC%[0m" %ESC%[!warnColor!m重启%ESC%[0m 或者 "%ESC%[!warnColor!m!batchName! -f%ESC%[0m" %ESC%[!warnColor!m修复%ESC%[0m
    )
)
goto :eof

@REM ============================================================================
@REM Build the system proxy server value
@REM Purpose:    Build the system proxy server value
@REM Parameters: <result>
@REM ============================================================================
:generateSystemProxy <result>
set "%~1="

call :getSystemProxy server
if "!server!" NEQ "" (
    set "%~1=!server!"
    goto :eof
)

@REM Extract from the configuration file
if exist "!configFile!" (
    call :isTunEnabled enabled
    if "!enabled!" == "1" goto :eof
    call :extractProxyPort port
    if "!port!" == "" goto :eof

    set "tips=[%ESC%[!warnColor!m提示%ESC%[0m] 系统代理%ESC%[91m未配置%ESC%[0m，是否设置？(%ESC%[!warnColor!mY%ESC%[0m/%ESC%[!warnColor!mN%ESC%[0m) "
    if "!msTerminal!" == "1" (
        choice /t 5 /d y /n /m "!tips!"
    ) else (
        set /p "=!tips!" <nul
        choice /t 5 /d y /n
    )
    if !errorlevel! == 2 goto :eof

    call :enableSystemProxy "127.0.0.1:!port!"
    set "%~1=127.0.0.1:!port!"
    goto :eof
)
goto :eof

@REM ============================================================================
@REM Create a directory tree when missing
@REM Purpose:    Create a directory tree when missing
@REM Parameters: <result>, <directory>
@REM Returns:    Sets <result> with the computed value or status
@REM ============================================================================
:createDirectories <result> <directory>
set "%~1=0"
call :trim directory "%~2"
if "!directory!" == "" (
    @echo [%ESC%[!warnColor!m警告%ESC%[0m] 路径为空，创建目录失败
    goto :eof
)

if not exist "!directory!" (
    mkdir "!directory!"
    if "!errorlevel!" == "0" set "%~1=1"
) else (set "%~1=1")
goto :eof

@REM ============================================================================
@REM Detect whether TUN mode is enabled
@REM Purpose:    Detect whether TUN mode is enabled
@REM Parameters: <enabled>
@REM ============================================================================
:isTunEnabled <enabled>
set "%~1=0"
set "text="

@REM Not work in batch but works fine in cmd, why?
@REM For /f "tokens=*" %%a in ('findstr /i /r /c:"^tun:[ ]*" "!configFile!"') do set "text=%%a"

for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"tun:[ ]*" "!configFile!"') do set "text=%%a"

@REM Skip when not required
call :trim text "!text!"
if "!text!" == "tun" set "%~1=1"
goto :eof

@REM ============================================================================
@REM Download and update Wintun when required
@REM Purpose:    Download and update Wintun when required
@REM Parameters: <changed>, <force>
@REM Returns:    Sets <changed> with the computed value or status
@REM ============================================================================
:downloadWintun <changed> <force>
set "%~1=0"

call :trim force "%~2"
if "!force!" == "" set "force=0"

@REM Has been integrated in MetaCubeX Mihomo
if "!useClashMeta!" == "1" exit /b

@REM Check whether the component is required
call :isTunEnabled enabled
if "!enabled!" == "0" exit /b

if "!force!" == "0" set "checkWintun=0"

@REM Existing file check
if exist "!dest!\wintun.dll" if "!checkWintun!" == "0" goto :eof

set "content="
set "wintunUrl=https://www.wintun.net"

for /f delims^=^"^ tokens^=2 %%a in ('curl --retry 5 --retry-max-time 60 --connect-timeout 15 -s -L "!wintunUrl!" ^| findstr /i /r "builds/wintun-.*.zip"') do set "content=%%a"
call :trim content !content!

if "!content!" == "" (
    @echo [%ESC%[!warnColor!m警告%ESC%[0m] 无法获取 wintun 下载链接
    goto :eof
)

call :getArch archVersion
if "!archVersion!" == "386" (
    set "archVersion=x86"
) else if "!archVersion!" == "armv7" (
    set "archVersion=arm"
)

set "wintunUrl=!wintunUrl!/!content!"
@echo [%ESC%[!infoColor!m信息%ESC%[0m] 开始下载 wintun，下载链接："!wintunUrl!"

call :retryDownload "!wintunUrl!" "!temp!\wintun.zip"
if exist "!temp!\wintun.zip" (
    @REM Extract the archive
    tar -xzf "!temp!\wintun.zip" -C !temp! >nul 2>nul

    @REM Clean the workspace
    del /f /q "!temp!\wintun.zip" >nul 2>nul

    set "wintunFile=!temp!\wintun\bin\!archVersion!\wintun.dll"
    if exist "!wintunFile!" (
        @REM Compare and update files
        call :compareMd5 diff "!wintunFile!" "!dest!\wintun.dll"
        if "!diff!" == "1" (
            set "%~1=1"

            @REM Delete the existing file when present
            del /f /q "!dest!\wintun.dll" >nul 2>nul
            move "!wintunFile!" "!dest!" >nul 2>nul
        )
    ) else (
        @echo [%ESC%[!warnColor!m警告%ESC%[0m] 下载 wintun 成功，但未找到 wintun.dll
    )
) else (
    @echo [%ESC%[!warnColor!m警告%ESC%[0m] wintun 下载失败，请确认下载链接是否正确
)
goto :eof

@REM ============================================================================
@REM Download required executable and data files
@REM Purpose:    Download required executable and data files
@REM Parameters: <fileNames>, <outputEnabled>
@REM ============================================================================
:downloadFiles <fileNames> <outputEnabled>
set "%~1="
call :trim outputEnabled "%~2"
if "!outputEnabled!" == "" set "outputEnabled=1"

@REM This component is deprecated, so keep its changed flag disabled
set "outputEnabled=0"

if "!outputEnabled!" == "1" (
    @echo [%ESC%[!infoColor!m信息%ESC%[0m] 开始下载代理程序、域名及 IP 地址等数据
)

set "downloadedFileList="

@REM Download the Clash core
if "!clashUrl!" NEQ "" (
    if /i "!clashUrl:~0,8!" NEQ "https://" (
        @echo [%ESC%[91m错误%ESC%[0m] !proxyExecutableName! 下载地址解析失败："!clashUrl!"
    ) else (
        @echo [%ESC%[!infoColor!m信息%ESC%[0m] 开始下载 %ESC%[!warnColor!m!proxyExecutableName!%ESC%[0m 至 %ESC%[!warnColor!m!dest!%ESC%[0m
        call :retryDownload "!clashUrl!" "!temp!\clash.zip"
        if exist "!temp!\clash.zip" (
            @REM Extract the archive
            tar -xzf "!temp!\clash.zip" -C !temp! >nul 2>nul

            @REM Clean the workspace
            del /f /q "!temp!\clash.zip"
        ) else (
            @echo [%ESC%[91m错误%ESC%[0m] !proxyExecutableName! 下载失败，下载链接："!clashUrl!"
        )

        if exist "!temp!\!clashExe!" (
            @REM Rename the downloaded file
            ren "!temp!\!clashExe!" !proxyExecutableName!

            set "downloadedFileList=!proxyExecutableName!"
        ) else (
            @echo [%ESC%[91m错误%ESC%[0m] "!temp!\!clashExe!" 不存在，下载链接："!clashUrl!"
        )
    )
)

for %%u in (country geoSite geoAsn geoIp lgbm) do (
    set "currentUrl=!%%uUrl!"
    set "currentFile=!%%uFile!"
    call :downloadManagedFile downloaded "!currentUrl!" "!currentFile!"
    if "!downloaded!" == "1" call :appendDownloadedFile downloadedFileList "!currentFile!"
)

set "%~1=!downloadedFileList!"
goto :eof

@REM ============================================================================
@REM Download a managed file and mark it as downloaded
@REM Purpose:    Download a managed file and mark it as downloaded
@REM Parameters: <result>, <url>, <fileName>
@REM Returns:    Sets <result> with the computed value or status
@REM ============================================================================
:downloadManagedFile <result> <url> <fileName>
set "%~1=0"
call :trim managedUrl "%~2"
call :trim managedFile "%~3"

if "!managedUrl!" == "" goto :eof
if "!managedFile!" == "" goto :eof

if /i "!managedUrl:~0,8!" NEQ "https://" (
    @echo [%ESC%[91m错误%ESC%[0m] !managedFile! 下载地址解析失败："!managedUrl!"
    goto :eof
)

@echo [%ESC%[!infoColor!m信息%ESC%[0m] 开始下载 %ESC%[!warnColor!m!managedFile!%ESC%[0m 至 %ESC%[!warnColor!m!dest!%ESC%[0m
call :retryDownload "!managedUrl!" "!temp!\!managedFile!"

if exist "!temp!\!managedFile!" (
    set "%~1=1"
) else (
    @echo [%ESC%[91m错误%ESC%[0m] "!temp!\!managedFile!" 不存在，下载链接："!managedUrl!"
)
goto :eof

@REM ============================================================================
@REM Append a file name to the downloaded file list
@REM Purpose:    Append a file name to the downloaded file list
@REM Parameters: <listVar>, <fileName>
@REM ============================================================================
:appendDownloadedFile <listVar> <fileName>
call :trim appendedFile "%~2"
if "!appendedFile!" == "" goto :eof

if "!%~1!" == "" (
    set "%~1=!appendedFile!"
) else (
    set "%~1=!%~1!;!appendedFile!"
)
goto :eof

@REM ============================================================================
@REM Download a file with retry support
@REM Purpose:    Download a file with retry support
@REM Parameters: <url>, <fileName>
@REM ============================================================================
:retryDownload <url> <fileName>
set maxRetries=3
call :trim downloadUrl "%~1"
call :trim savePath "%~2"

if "!downloadUrl!" == "" goto :eof
if "!savePath!" == "" goto :eof

if exist "!savePath!" del /f /q "!savePath!" >nul 2>nul
set /a "count=0"

:retry
if !count! GEQ !maxRetries! (
    @echo [%ESC%[91m错误%ESC%[0m] 文件 %ESC%[!warnColor!m!savePath!%ESC%[0m 下载失败，已达最大重试次数，请尝试再次执行此命令
    if exist "!savePath!" del /f /q "!savePath!" >nul 2>nul
    goto :eof
)

call :applyGithubProxy realDownloadUrl "!downloadUrl!"
curl.exe --retry 5 --retry-max-time 120 --connect-timeout 20 -f -s -L -C - -o "!savePath!" "!realDownloadUrl!"
set "failFlag=!errorlevel!"
if not exist "!savePath!" set "failFlag=1"

if "!failFlag!" NEQ "0" (
    set /a "count+=1"

    @echo [%ESC%[!warnColor!m提示%ESC%[0m] 文件下载失败，正在进行第 %ESC%[!warnColor!m!count!%ESC%[0m 次重试，下载链接：!realDownloadUrl!
    goto :retry
)
goto :eof

@REM ============================================================================
@REM Detect downloaded files that differ from installed files
@REM Purpose:    Detect downloaded files that differ from installed files
@REM Parameters: <result>, <fileNames>
@REM Returns:    Sets <result> with the computed value or status
@REM ============================================================================
:detectChangedFiles <result> <fileNames>
set "%~1=0"
set "fileNames=%~2"

for %%a in (!fileNames!) do (
    set "fileName=%%a"

    if not exist "!temp!\!fileName!" (
        @echo [%ESC%[91m错误%ESC%[0m] %ESC%[!warnColor!m!fileName!%ESC%[0m 下载成功，但在 "!temp!" 文件夹下未找到，请确认是否已被删除
        goto :eof
    )

    if "!repairFlag!" == "1" (
        @REM Delete the installed file to force an upgrade
        del /f /q "!dest!\!fileName!" >nul 2>nul
    )

    @REM Found a new file
    if not exist "!dest!\!fileName!" (
        set "%~1=1"
        call :upgradeFiles "!fileNames!"
        exit /b
    )

    @REM Compare and update files
    call :compareMd5 diff "!temp!\!fileName!" "!dest!\!fileName!"
    if "!diff!" == "1" (
        set "%~1=1"
        @echo [%ESC%[!infoColor!m信息%ESC%[0m] 发现新版本，文件名：%ESC%[!warnColor!m!fileName!%ESC%[0m
        call :upgradeFiles "!fileNames!"
        exit /b
    )
)
goto :eof

@REM ============================================================================
@REM Compare two files by MD5 hash
@REM Purpose:    Compare two files by MD5 hash
@REM Parameters: <changed>, <source>, <target>
@REM Returns:    Sets <changed> with the computed value or status
@REM ============================================================================
:compareMd5 <changed> <source> <target>
set "%~1=0"

call :trim source "%~2"
call :trim target "%~3"

if not exist "!source!" if not exist "!target!" goto :eof
if not exist "!source!" goto :eof
if not exist "!target!" (
    set "%~1=1"
    goto :eof
)

@REM Source MD5
set "original=" & for /F "skip=1 delims=" %%h in ('2^> nul CertUtil -hashfile "!source!" MD5') do if not defined original set "original=%%h"
@REM Target MD5
set "received=" & for /F "skip=1 delims=" %%h in ('2^> nul CertUtil -hashfile "!target!" MD5') do if not defined received set "received=%%h"

if "!original!" NEQ "!received!" (set "%~1=1")
goto :eof

@REM ============================================================================
@REM Replace installed proxy files with downloaded files
@REM Purpose:    Replace installed proxy files with downloaded files
@REM Parameters: <fileNames>
@REM ============================================================================
:upgradeFiles <fileNames>
call :trim fileNames "%~1"
if "!fileNames!" == "" goto :eof

@REM Ensure the downloaded file exists
set "existingFiles="
for %%a in (!fileNames!) do (
    if exist "!temp!\%%a" (
        if "!existingFiles!" == "" (
            set "existingFiles=%%a"
        ) else (
            set "existingFiles=!existingFiles!;%%a"
        )
    )
)

@REM Missing file
if "!existingFiles!" == "" goto :terminate

@REM Stop Clash before replacing files
call :killProcessWrapper

@REM Copy files
for %%a in (!fileNames!) do (
    set "fileName=%%a"

    @REM Delete the old file when present
    if exist "!dest!\!fileName!" (
        del /f /q "!dest!\!fileName!" >nul 2>nul
    )

    @REM Move the new file into the destination directory
    move "!temp!\!fileName!" "!dest!" >nul 2>nul
)
goto :eof

@REM ============================================================================
@REM Start the selected proxy core
@REM Purpose:    Start the selected proxy core
@REM ============================================================================
:startClash
call :isProcessRunning status

if "!status!" == "0" (
    @REM Start the proxy program
    call :runClashWrapper 0
) else (
    @echo [%ESC%[!infoColor!m信息%ESC%[0m] 订阅和代理规则更新完毕，即将重新加载
    goto :reloadConfig
)
goto :eof

@REM ============================================================================
@REM Run an operation with administrator privileges when needed
@REM Purpose:    Run an operation with administrator privileges when needed
@REM Parameters: <args>, <showWindow>
@REM ============================================================================
:runElevated <args> <showWindow>
set "elevatedShowWindow=0"
set "operation=%~1"
set "scriptPath=%~f0"
if "!operation!" == "" (
    @echo [%ESC%[91m错误%ESC%[0m] 非法操作，必须指定函数名
    exit /b 1
)

@REM Parse the window visibility parameter
call :trim param "%~2"
set "display=" & for /f "delims=0123456789" %%i in ("!param!") do set "display=%%i"
if defined display (set "elevatedShowWindow=0") else (set "elevatedShowWindow=!param!")
if "!elevatedShowWindow!" NEQ "0" set "elevatedShowWindow=1"

@REM Call Start-Process through PowerShell
cacls "%SystemDrive%\System Volume Information" >nul 2>&1 && (
    if "!elevatedShowWindow!" == "0" (
        !operation!
        exit /b
    ) else (
        start "" "%ComSpec%" /k ""!scriptPath!" %~1"
        exit /b
    )
) || (
    if "!elevatedShowWindow!" == "0" (
        powershell -Command "Start-Process -FilePath '!scriptPath!' -ArgumentList '%~1' -Verb RunAs -WindowStyle Hidden"
    ) else (
        powershell -Command "Start-Process -FilePath $env:ComSpec -ArgumentList '/k ""!scriptPath!"" %~1' -Verb RunAs"
    )
    exit /b
)
goto :eof

@REM ============================================================================
@REM Run the proxy executable with a configuration file
@REM Purpose:    Run the proxy executable with a configuration file
@REM Parameters: <config>, <executable>
@REM ============================================================================
:runClash <config> <executable>
call :trim runConfigFile "%~1"
if "!runConfigFile:~0,13!" == "goto :runClash" (
    for /f "tokens=1-4 delims= " %%a in ("!runConfigFile!") do set "runConfigFile=%%c"
)
call :convertToAbsolutePath runConfigFile "!runConfigFile!"
call :trim runExecutable "%~2"

if "!runConfigFile!" == "" (
    @echo [%ESC%[!infoColor!m信息%ESC%[0m] 配件文件路径无效，无法启动代理程序
    goto :eof
)

@REM Privilege escalation
call :enableNoPromptRunAs success

call :splitPath filePath fileName "!runConfigFile!"
if "!runExecutable!" == "" (
    call :resolveProxyExecutableName
    set "runExecutable=!proxyExecutableName!"
)
if not exist "!runConfigFile!" (
    @echo [%ESC%[91m错误%ESC%[0m] 配置文件 "%ESC%[!warnColor!m!runConfigFile!%ESC%[0m" 不存在，无法启动代理程序
    goto :eof
)
if not exist "!filePath!\!runExecutable!" (
    @echo [%ESC%[91m错误%ESC%[0m] 代理程序 "%ESC%[!warnColor!m!filePath!\!runExecutable!%ESC%[0m" 不存在，无法启动
    goto :eof
)
@echo [%ESC%[!infoColor!m信息%ESC%[0m] 正在启动代理程序："!filePath!\!runExecutable!" -d "!filePath!" -f "!runConfigFile!"
"!filePath!\!runExecutable!" -d "!filePath!" -f "!runConfigFile!"
goto :eof

@REM ============================================================================
@REM Prepare and update required runtime components
@REM Purpose:    Prepare and update required runtime components
@REM Parameters: <changed>, <force>, <downloadedAlready>
@REM Returns:    Sets <changed> with the computed value or status
@REM ============================================================================
:prepareComponents <changed> <force> <downloadedAlready>
set "%~1=0"
set "componentChanged=0"

call :trim downloadForce "%~2"
if "!downloadForce!" == "" set "downloadForce=0"

call :trim downloadedAlready "%~3"
if "!downloadedAlready!" == "" set "downloadedAlready=0"

@REM Check and update the configuration
if "!downloadedAlready!" == "0" call :updateConfig "!downloadForce!"

@REM Parse the API server path
call :extractControllerServer clashServer

@REM Dashboard directory name
call :extractDashboardPath dashboard

@REM Update flag subscriptions
if "!downloadedAlready!" == "0" if "!excludeUpdates!" == "0" call :updateSubscriptions subscriptionFiles "!downloadForce!"

@REM Parse frequently used configuration flags once
call :loadConfigSummary !subscriptionFiles!

@REM Resolve download URLs and file names
call :detectProxyEditionChange geoSiteNeeded !subscriptionFiles!
if "!proxyEditionChanged!" == "1" set "componentChanged=1"

call :resolveProxyExecutableName

@REM Clash Premium is not available now
if "!useClashPremium!" == "1" if not exist "!dest!\!proxyExecutableName!" (
    @echo [%ESC%[91m错误%ESC%[0m] 代理程序 %ESC%[!warnColor!m!clashPremiumName!%ESC%[0m 暂时 %ESC%[91m无法使用%ESC%[0m，请选择 %ESC%[!warnColor!m!metaCubeXMihomoName!%ESC%[0m
    exit /b 1
)

if "!useClashPremium!" == "0" if "!useClashMeta!" == "0" (
    set "useClashMeta=1"
    call :detectInstalledProxyEdition localEdition localEditionFound
    if "!localEditionFound!" == "1" if "!localEdition!" == "0" (
            set "useClashPremium=1"
            set "useClashMeta=0"
    )
    call :resolveProxyExecutableName
)

@REM Resolve the download URL
call :resolveDownloadUrls "!downloadForce!" "!geoSiteNeeded!"

@REM Skip Mihomo download when the local executable already matches the release URL
call :skipMihomoDownloadIfCurrent

@REM Clean the workspace before downloading
call :cleanWorkspace "!temp!"

@REM Update flag dashboard
if "!downloadedAlready!" == "0" call :updateDashboard "!downloadForce!"

@REM Update flag rule files
if "!downloadedAlready!" == "0" call :updateRules "!downloadForce!"

@REM Wintun.dll
call :downloadWintun newWintun "!downloadForce!"
if "!newWintun!" == "1" set "componentChanged=1"

@REM Download proxy executable and geoip.data and so on
call :downloadFiles fileNames "!downloadForce!"

@REM Detect file changes by MD5
call :detectChangedFiles changed "!fileNames!"
if "!changed!" == "1" set "componentChanged=1"

set "%~1=!componentChanged!"

goto :eof

@REM ============================================================================
@REM Configure post-install startup and shortcuts
@REM Purpose:    Configure post-install startup and shortcuts
@REM ============================================================================
:postProcess
call :runElevated "goto :enableNoPromptRunAs" 0

@REM User prompts
call :outputProxyHint

@REM Add the script directory to the user PATH
call :addToUserPath

@REM Allow startup at user login
call :configureAutostart

@REM Allow automatic update checks
call :configureAutoUpdate

@REM Create the desktop shortcut
call :createDesktopShortcut
goto :eof

@REM ============================================================================
@REM Extract the external controller server address
@REM Purpose:    Extract the external controller server address
@REM Parameters: <result>
@REM ============================================================================
:extractControllerServer <result>
set "%~1="
call :parseYamlValue serverHost "external-controller:[ ][ ]*"
if "!serverHost!" NEQ "" if "!serverHost:~0,1!" == ":" set "serverHost=127.0.0.1!serverHost!"

set "%~1=http://!serverHost!"
goto :eof

@REM ============================================================================
@REM Validate and start the proxy core
@REM Purpose:    Validate and start the proxy core
@REM Parameters: <shouldCheck>
@REM ============================================================================
:runClashWrapper <shouldCheck>
call :trim shouldCheck "%~1"
if "!shouldCheck!" == "" set "shouldCheck=0"
if "!shouldCheck!" == "1" (call :prepareComponents changed 0 0)
call :resolveProxyExecutableName

@REM Verify config
if not exist "!dest!\!proxyExecutableName!" (
    @echo [%ESC%[91m错误%ESC%[0m] 网络代理启动%ESC%[91m失败%ESC%[0m，"%ESC%[!warnColor!m!dest!\!proxyExecutableName!%ESC%[0m" 缺失
    goto :eof
)

if not exist "!configFile!" (
    @echo [%ESC%[91m错误%ESC%[0m] 网络代理启动%ESC%[91m失败%ESC%[0m，配置文件 "%ESC%[!warnColor!m!configFile!%ESC%[0m" 不存在
    goto :eof
)

if "!verifyConfig!" == "1" (
    set "testOutput=!temp!\clashtestout.txt"
    del /f /q "!testOutput!" >nul 2>nul

    @REM Test the configuration file
    "!dest!\!proxyExecutableName!" -d "!dest!" -t "!configFile!" > "!testOutput!"

    @REM Handle failure
    if !errorlevel! NEQ 0 (
        set "messages="
        if exist "!testOutput!" (
            for /f "tokens=1* delims==" %%a in ('findstr /i /r /c:"[ ]ERR[ ]\[config\][ ].*" "!testOutput!"') do set "messages=%%b"
            del /f /q "!testOutput!" >nul 2>nul
        )

        if "!messages!" == "" set "messages=文件校验失败，%ESC%[!warnColor!m!proxyExecutableName!%ESC%[0m 或配置文件 %ESC%[!warnColor!m!configFile!%ESC%[0m 存在问题"
        @echo [%ESC%[91m错误%ESC%[0m] 网络代理启动%ESC%[91m失败%ESC%[0m，配置文件 "%ESC%[!warnColor!m!configFile!%ESC%[0m" 存在错误
        @echo [%ESC%[91m错误%ESC%[0m] 错误信息："!messages!"
        exit /b 1
    )

    @REM Delete test output
    del /f /q "!testOutput!" >nul 2>nul
)

@REM Run the proxy executable with the configuration
call :runElevated "goto :runClash !configFile! !proxyExecutableName!" !showWindow!

for /l %%i in (1,1,6) do (
    @REM Check running status
    call :isProcessRunning status
    if "!status!" == "1" (
        @REM Detect abnormal process state
        call :isProcessAbnormal state

        if "!state!" == "1" (
            set "tips=[%ESC%[!warnColor!m警告%ESC%[0m] 代理进程%ESC%[91m异常%ESC%[0m，需%ESC%[91m删除并重新下载%ESC%[0m %ESC%[!warnColor!m!dest!\!proxyExecutableName!%ESC%[0m，是否继续？(%ESC%[!warnColor!mY%ESC%[0m/%ESC%[!warnColor!mN%ESC%[0m) "
            if "!msTerminal!" == "1" (
                choice /t 5 /d y /n /m "!tips!"
            ) else (
                set /p "=!tips!" <nul
                choice /t 5 /d y /n
            )
            if !errorlevel! == 1 (
                @REM Delete the existing proxy executable
                del /f /q "!dest!\!proxyExecutableName!" >nul 2>nul

                @REM Download components and restart
                goto :restartProgram
            ) else (
                @echo [%ESC%[91m错误%ESC%[0m] 代理程序启动%ESC%[91m失败%ESC%[0m，请检查代理程序 %ESC%[!warnColor!m!dest!\!proxyExecutableName!%ESC%[0m 是否完好
                goto :eof
            )
        ) else (
            if "!dashboard!" == "" (
                @echo [%ESC%[!infoColor!m信息%ESC%[0m] 代理程序启动%ESC%[!infoColor!m成功%ESC%[0m
            ) else (
                set "message=[%ESC%[!infoColor!m信息%ESC%[0m] 代理程序启动%ESC%[!infoColor!m成功%ESC%[0m，可在浏览器中访问 %ESC%[!warnColor!m!clashServer!/ui%ESC%[0m 查看详细信息"
                call :parseYamlValue secret "secret:[ ][ ]*"
                if "!secret!" NEQ "" set "message=!message!，密码：%ESC%[!warnColor!m!secret!%ESC%[0m"
                @echo !message!
            )
            call :postProcess
            exit /b
        )
    ) else (
        @REM Wait before continuing
        timeout /t 1 /nobreak >nul 2>nul
    )
)

@echo [%ESC%[91m错误%ESC%[0m] 代理程序启动%ESC%[91m失败%ESC%[0m，请检查配置 %ESC%[91m!configuration!%ESC%[0m 是否正确
goto :eof

@REM ============================================================================
@REM Search a port value in the configuration file
@REM Purpose:    Search a port value in the configuration file
@REM Parameters: <result>, <key>
@REM Returns:    Sets <result> with the computed value or status
@REM ============================================================================
:searchPort <result> <key>
set "%~1="
call :trim key "%~2"
if "!key!" == "" goto :eof

call :findConfigKeyEntry portKey port "!configFile!" "!key!" "[0-9][0-9]*"
if "!port!" NEQ "" set "%~1=!port!"
goto :eof

@REM ============================================================================
@REM Extract the HTTP proxy port
@REM Purpose:    Extract the HTTP proxy port
@REM Parameters: <result>
@REM ============================================================================
:extractProxyPort <result>
set "%~1=7890"
set "keys=mixed-port;port;socks-port"
for %%a in (!keys!) do (
    call :searchPort port "%%a"
    if "!port!" NEQ "" (
        set "%~1=!port!"
        exit /b
    )
)
goto :eof

@REM ============================================================================
@REM Print system proxy guidance
@REM Purpose:    Print system proxy guidance
@REM ============================================================================
:outputProxyHint
call :isTunEnabled enabled
call :getSystemProxy server
if "!enabled!" == "1" (
    if "!server!" NEQ "" (
        @echo [%ESC%[!warnColor!m提示%ESC%[0m] 程序正以 %ESC%[!warnColor!mtun%ESC%[0m 模式运行，系统代理设置已被禁用
        call :disableSystemProxy
    )
    goto :eof
)

call :extractProxyPort proxyPort
if "!proxyPort!" == "" set "proxyPort=7890"

@REM Enable the system proxy
set "proxyServer=127.0.0.1:!proxyPort!"
if "!proxyServer!" NEQ "!server!" (
    set "tips=[%ESC%[!warnColor!m提示%ESC%[0m] 系统代理%ESC%[91m未配置%ESC%[0m，是否设置？(%ESC%[!warnColor!mY%ESC%[0m/%ESC%[!warnColor!mN%ESC%[0m) "
    if "!msTerminal!" == "1" (
        choice /t 5 /d y /n /m "!tips!"
    ) else (
        set /p "=!tips!" <nul
        choice /t 5 /d y /n
    )
    if !errorlevel! == 1 call :enableSystemProxy "!proxyServer!"
)

@REM Print user guidance
@echo [%ESC%[!warnColor!m提示%ESC%[0m] 如果无法正常使用网络代理，请到 "%ESC%[!warnColor!m设置 -^> 网络和 Internet -^> 代理%ESC%[0m" 确认是否已设置为 "%ESC%[!warnColor!m!proxyServer!%ESC%[0m"
goto :eof

@REM ============================================================================
@REM Add the script directory to the user PATH
@REM Purpose:    Add the script directory to the user PATH
@REM ============================================================================
:addToUserPath
set "scriptDir=%~dp0"
set "scriptDir=!scriptDir:~0,-1!"

@REM Read the current PATH values
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "currentPath=%%b"

@REM Check whether the path is already present
echo !currentPath! | findstr /i /c:"!scriptDir!" >nul
if !errorlevel! == 0 goto :eof

set "tips=[%ESC%[!warnColor!m提示%ESC%[0m] 是否将脚本路径 %ESC%[!warnColor!m!scriptDir!%ESC%[0m 加入到用户 PATH 路径？(%ESC%[!warnColor!mY%ESC%[0m/%ESC%[!warnColor!mN%ESC%[0m) "
if "!msTerminal!" == "1" (
    choice /t 5 /d y /n /m "!tips!"
) else (
    set /p "=!tips!" <nul
    choice /t 5 /d y /n
)

if !errorlevel! == 1 (
    @REM Rewrite the user PATH environment variable
    set "newPath=!currentPath!;!scriptDir!"
    reg add "HKCU\Environment" /v Path /t REG_EXPAND_SZ /d "!newPath!" /f >nul 2>nul

    @echo [%ESC%[!infoColor!m信息%ESC%[0m] 添加 %ESC%[!warnColor!m!scriptDir!%ESC%[0m 到用户 PATH 路径%ESC%[!infoColor!m成功%ESC%[0m
)

goto :eof

@REM ============================================================================
@REM Restart the proxy program
@REM Purpose:    Restart the proxy program
@REM ============================================================================
:restartProgram
@REM Check running status
call :isProcessRunning status
if "!status!" == "1" (
    @REM Stop the proxy process
    call :killProcessWrapper

    @REM Check running status
    call :isProcessRunning status

    if "!status!" == "1" (
        call :getRunningProxyExecutable runningExecutable
        if "!runningExecutable!" == "" set "runningExecutable=!proxyExecutableName!"
        @echo [%ESC%[91m错误%ESC%[0m] 无法关闭进程，代理程序重启%ESC%[91m失败%ESC%[0m，请到%ESC%[91m任务管理中心%ESC%[0m手动退出 %ESC%[!warnColor!m!runningExecutable!%ESC%[0m
        goto :eof
    )
)

@REM Alpha versions may not provide a Clash Premium download
if "!useClashPremium!" == "1" set "alpha=0"

@REM Start the proxy program
call :runClashWrapper 1
exit /b

@REM ============================================================================
@REM Stop the proxy program with elevation when needed
@REM Purpose:    Stop the proxy program with elevation when needed
@REM ============================================================================
:killProcessWrapper
call :getRunningProxyExecutable runningExecutable
if "!runningExecutable!" == "" set "runningExecutable=!proxyExecutableName!"
call :isProcessRunning status
if "!status!" == "0" goto :eof

call :runElevated "goto :killProcess" 0

@REM Detect current state
for /l %%i in (1,1,6) do (
    call :isProcessRunning status
    if "!status!" == "0" (
        @echo [%ESC%[!infoColor!m信息%ESC%[0m] 代理程序关闭%ESC%[!infoColor!m成功%ESC%[0m，可使用 "%ESC%[!warnColor!m!batchName! -r%ESC%[0m" 命令重启

        @REM Disable the system proxy
        @REM Call :isTunEnabled enabled
        @REM If "!enabled!" == "0" call :disableSystemProxy

        call :disableSystemProxy
        exit /b
    ) else (
        @REM Wait briefly before continuing
        timeout /t 1 /nobreak >nul 2>nul
    )
)

call :getRunningProxyExecutable runningExecutable
if "!runningExecutable!" == "" set "runningExecutable=!proxyExecutableName!"
@echo [%ESC%[91m错误%ESC%[0m] 代理程序关闭%ESC%[91m失败%ESC%[0m，请到%ESC%[91m任务管理中心%ESC%[0m手动退出 %ESC%[!warnColor!m!runningExecutable!%ESC%[0m
goto :eof

@REM ============================================================================
@REM Terminate running proxy processes
@REM Purpose:    Terminate running proxy processes
@REM ============================================================================
:killProcess
call :terminateProxyExecutable "!clashExecutableName!"
call :terminateProxyExecutable "!mihomoExecutableName!"

@REM Disable prompts when possible
call :enableNoPromptRunAs success

@REM Detect current state
for /l %%i in (1,1,6) do (
    @REM Detect current state running status
    call :isProcessRunning status
    if "!status!" == "0" (
        @echo [%ESC%[!infoColor!m信息%ESC%[0m] 网络代理已关闭
        goto :eof
    ) else (
        @REM Wait before continuing for release
        timeout /t 1 /nobreak >nul 2>nul
    )
)

call :getRunningProxyExecutable runningExecutable
if "!runningExecutable!" == "" set "runningExecutable=!proxyExecutableName!"
@echo [%ESC%[91m错误%ESC%[0m] 网络代理关闭失败，请到%ESC%[91m任务管理中心%ESC%[0m手动结束 %ESC%[!warnColor!m!runningExecutable!%ESC%[0m 进程
goto :eof

@REM ============================================================================
@REM Resolve the currently running proxy executable name
@REM Purpose:    Report and close the actual process without relying on target core
@REM Parameters: <result>
@REM ============================================================================
:getRunningProxyExecutable <result>
set "%~1="
call :resolveProxyExecutableName
call :isExecutableRunning running "!proxyExecutableName!"
if "!running!" == "1" set "%~1=!proxyExecutableName!"
if "!%~1!" == "" if /i "!proxyExecutableName!" NEQ "!clashExecutableName!" (
    call :isExecutableRunning running "!clashExecutableName!"
    if "!running!" == "1" set "%~1=!clashExecutableName!"
)
if "!%~1!" == "" if /i "!proxyExecutableName!" NEQ "!mihomoExecutableName!" (
    call :isExecutableRunning running "!mihomoExecutableName!"
    if "!running!" == "1" set "%~1=!mihomoExecutableName!"
)
goto :eof

@REM ============================================================================
@REM Detect whether an executable image is running
@REM Purpose:    Match exact proxy image names instead of loose text search
@REM Parameters: <result>, <executable>
@REM ============================================================================
:isExecutableRunning <result> <executable>
set "%~1=0"
call :trim executableName "%~2"
if "!executableName!" == "" goto :eof
tasklist /fi "imagename eq !executableName!" /nh | findstr /i /c:"!executableName!" >nul 2>nul && set "%~1=1"
goto :eof

@REM ============================================================================
@REM Terminate a proxy executable image
@REM Purpose:    Try taskkill first, then Stop-Process, and keep useful errors
@REM Parameters: <executable>
@REM ============================================================================
:terminateProxyExecutable <executable>
call :trim executableName "%~1"
if "!executableName!" == "" goto :eof

call :isExecutableRunning running "!executableName!"
if "!running!" == "0" goto :eof

set "killOutput=!temp!\kill-!executableName!.txt"
del /f /q "!killOutput!" >nul 2>nul

taskkill /im "!executableName!" /f /t > "!killOutput!" 2>&1
call :isExecutableRunning running "!executableName!"
if "!running!" == "0" (
    del /f /q "!killOutput!" >nul 2>nul
    goto :eof
)

set "processName=!executableName:.exe=!"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Process -Name '!processName!' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction Stop" >> "!killOutput!" 2>&1
call :isExecutableRunning running "!executableName!"
if "!running!" == "0" (
    del /f /q "!killOutput!" >nul 2>nul
    goto :eof
)

if exist "!killOutput!" (
    for /f "usebackq delims=" %%a in ("!killOutput!") do @echo [%ESC%[91m错误%ESC%[0m] %%a
    del /f /q "!killOutput!" >nul 2>nul
)
goto :eof

@REM ============================================================================
@REM Detect whether the proxy process is running
@REM Purpose:    Detect whether the proxy process is running
@REM Parameters: <result>
@REM ============================================================================
:isProcessRunning <result>
call :getRunningProxyExecutable runningExecutable
if "!runningExecutable!" == "" (set "%~1=0") else (set "%~1=1")
goto :eof

@REM ============================================================================
@REM Detect abnormal proxy process state
@REM Purpose:    Detect abnormal proxy process state
@REM Parameters: <result>
@REM ============================================================================
:isProcessAbnormal <result>
set "%~1=1"

@REM Memory usage check
set "usage="

call :resolveProxyExecutableName
for /f "tokens=5 delims= " %%a in ('tasklist /nh ^|findstr /i "!proxyExecutableName!"') do set "usage=%%a"
if "!usage!" == "" if /i "!proxyExecutableName!" NEQ "!clashExecutableName!" for /f "tokens=5 delims= " %%a in ('tasklist /nh ^|findstr /i "!clashExecutableName!"') do set "usage=%%a"
if "!usage!" == "" if /i "!proxyExecutableName!" NEQ "!mihomoExecutableName!" for /f "tokens=5 delims= " %%a in ('tasklist /nh ^|findstr /i "!mihomoExecutableName!"') do set "usage=%%a"
if "!usage!" NEQ "" (
    @REM Remove commas from the numeric value
    set "usage=!usage:,=!"

    if !usage! GTR 5120 (set "%~1=0")
)

goto :eof

@REM ============================================================================
@REM Resolve component download URLs
@REM Purpose:    Resolve component download URLs
@REM Parameters: <force>, <enabled>
@REM ============================================================================
:resolveDownloadUrls <force> <enabled>
@REM Country database
call :trim force "%~1"
if "!force!" == "" set "force=0"

@REM Dashboard
if "!zashboard!" == "1" (
    set "metaCubeXDashboard=0"
    set "yacd=0"
)
if "!metaCubeXDashboard!" == "1" set "yacd=0"

call :trim geoSiteFlag "%~2"
if "!geoSiteFlag!" == "" set "geoSiteFlag=0"

set "needDownload=0"
set "countryUrl=https://raw.githubusercontent.com/Hackl0us/GeoIP2-CN/release/Country.mmdb"

@REM GeoSite and GeoIP file names
set "countryFile=Country.mmdb"
set "geoSiteFile=GeoSite.dat"
set "geoIpFile=GeoIP.dat"
set "geoAsnFile=ASN.mmdb"
set "lgbmFile=Model.bin"

@REM Dashboard url
set "dashboardUrl=https://github.com/Dreamacro/clash-dashboard/archive/refs/heads/gh-pages.zip"
set "dashboardDirectory=clash-dashboard-gh-pages"

set "clashUrl="
set "proxyDownloadUrl="

@REM Detect OS and CPU architecture
call :getArch archVersion
call :resolveProxyExecutableName

if "!archVersion!" == "" (
    @echo [%ESC%[91m错误%ESC%[0m] 未知 操作系统 及 CPU 架构信息，获取 clash 下载链接失败
    goto :eof
)

@REM Determine whether the proxy executable must be downloaded
if not exist "!dest!\!proxyExecutableName!" (set "needDownload=1") else (set "needDownload=!force!")
if "!proxyEditionChanged!" == "1" set "needDownload=1"

if "!useClashMeta!" == "0" (
    @echo [%ESC%[!warnColor!m提示%ESC%[0m] %ESC%[!warnColor!m!clashPremiumName!%ESC%[0m 暂%ESC%[!warnColor!m不提供%ESC%[0m下载，建议使用 %ESC%[!warnColor!m-m%ESC%[0m 或 %ESC%[!warnColor!m--meta%ESC%[0m 切换到 %ESC%[!warnColor!m!metaCubeXMihomoName!%ESC%[0m

    set "clashExe=clash-windows-!archVersion!.exe"

    if "!needDownload!" == "1" (
        if "!alpha!" == "0" (
            for /f "tokens=1* delims=:" %%a in ('curl --retry 5 -s -L "https://api.github.com/repos/Dreamacro/clash/releases/tags/premium" ^| findstr /i /r /c:"https://github.com/Dreamacro/clash/releases/download/premium/clash-windows-!archVersion!-[^v][^3].*.zip"') do set "proxyDownloadUrl=%%b"

            @REM Remove whitespace
            call :trim proxyDownloadUrl "!proxyDownloadUrl!"
            if !proxyDownloadUrl! == "" (
                @echo [%ESC%[91m错误%ESC%[0m] 获取 !clashPremiumName! 下载链接失败
                goto :eof
            )
            set "proxyDownloadUrl=!proxyDownloadUrl:~1,-1!"
        ) else (
            @echo [%ESC%[!warnColor!m警告%ESC%[0m] %ESC%[!warnColor!m!clashPremiumName!%ESC%[0m 预览版下载链接可能%ESC%[91m无法访问%ESC%[0m，想要使用该版本请确保网络正常
            set "proxyDownloadUrl=https://release.dreamacro.workers.dev/latest/clash-windows-!archVersion!-latest.zip"
        )
    )

    if "!yacd!" == "1" (
        set "dashboardUrl=https://github.com/haishanh/yacd/archive/refs/heads/gh-pages.zip"
        set "dashboardDirectory=yacd-gh-pages"
    )

    if "!metaCubeXDashboard!" == "1" (
        set "dashboardUrl=https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip"
        set "dashboardDirectory=metacubexd-gh-pages"
    )

    if "!zashboard!" == "1" (
        set "dashboardUrl=https://github.com/Zephyruso/zashboard/archive/refs/heads/gh-pages.zip"
        set "dashboardDirectory=zashboard-gh-pages"
    )
) else (
    set "clashExe=mihomo-windows-!archVersion!.exe"
    set "geoSiteUrl=https://raw.githubusercontent.com/Loyalsoldier/domain-list-custom/release/geosite.dat"
    set "geoIpUrl=https://raw.githubusercontent.com/Loyalsoldier/geoip/release/geoip-only-cn-private.dat"
    set "geoAsnUrl=https://raw.githubusercontent.com/xishang0128/geoip/refs/heads/release/GeoLite2-ASN.mmdb"

    if "!needDownload!" == "1" (
        if "!useVerneMihomo!" == "1" (
            for /f "tokens=1* delims=:" %%a in ('curl --retry 5 -s -L "https://api.github.com/repos/vernesong/mihomo/releases/tags/Prerelease-Alpha" ^| findstr /i /r /c:"https://github.com/vernesong/mihomo/releases/download/Prerelease-Alpha/mihomo-windows-!archVersion!-alpha-smart-.*.zip"') do set "proxyDownloadUrl=%%b"
        ) else if "!alpha!" == "1" (
            for /f "tokens=1* delims=:" %%a in ('curl --retry 5 -s -L "https://api.github.com/repos/MetaCubeX/mihomo/releases?prerelease=true&per_page=10" ^| findstr /i /r "https://github.com/MetaCubeX/mihomo/releases/download/Prerelease-Alpha/mihomo-windows-!archVersion!-alpha-.*.zip"') do set "proxyDownloadUrl=%%b"
        ) else (
            for /f "tokens=1* delims=:" %%a in ('curl --retry 5 -s -L "https://api.github.com/repos/MetaCubeX/mihomo/releases/latest?per_page=1" ^| findstr /i /r "https://github.com/MetaCubeX/mihomo/releases/download/.*/mihomo-windows-!archVersion!-v[0-9]*\.[0-9]*\.[0-9]*.zip"') do set "proxyDownloadUrl=%%b"
        )

        call :trim proxyDownloadUrl "!proxyDownloadUrl!"
        if !proxyDownloadUrl! == "" (
            if "!alpha!" == "1" (set "version=预览版") else (set "version=稳定版")
            if "!useVerneMihomo!" == "1" (set "coreName=!smartMihomoName!") else (set "coreName=!metaCubeXMihomoName!")
            @echo [%ESC%[91m错误%ESC%[0m] 获取 !coreName! 下载链接失败，版本："!version!"
            goto :eof
        )

        set "proxyDownloadUrl=!proxyDownloadUrl:~1,-1!"
    )

    @REM GeoSite data download URL
    if "!geoSiteFlag!" == "0" (
        set "geoSiteUrl="
    ) else (
        if "!cfgGeoSiteUrl!" NEQ "" set "geoSiteUrl=!cfgGeoSiteUrl!"
    )

    @REM Geo data mode
    set "geoDataMode=!cfgGeoDataMode!"
    if "!geoDataMode!" == "" set "geoDataMode=false"

    @REM GeoIP data download URL
    if "!geoDataMode!" == "false" (
        set "geoIpUrl="
        if "!cfgCountryUrl!" NEQ "" set "countryUrl=!cfgCountryUrl!"
    ) else (
        set "countryUrl="
        if "!cfgGeoIpUrl!" NEQ "" set "geoIpUrl=!cfgGeoIpUrl!"
    )

    @REM ASN database download URL
    set "needGeoAsn=0"
    if "!cfgHasAsnRule!" == "1" set "needGeoAsn=1"
    if "!useVerneMihomo!" == "1" if "!cfgHasSmartPreferAsn!" == "1" set "needGeoAsn=1"
    if "!needGeoAsn!" == "0" (
        set "geoAsnUrl="
    ) else (
        if "!cfgGeoAsnUrl!" NEQ "" set "geoAsnUrl=!cfgGeoAsnUrl!"
    )

    if "!yacd!" == "1" (
        set "dashboardUrl=https://github.com/MetaCubeX/Yacd-meta/archive/refs/heads/gh-pages.zip"
        set "dashboardDirectory=Yacd-meta-gh-pages"
    ) else if "!metaCubeXDashboard!" == "1" (
        set "dashboardUrl=https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip"
        set "dashboardDirectory=metacubexd-gh-pages"
    ) else (
        set "dashboardUrl=https://github.com/Zephyruso/zashboard/archive/refs/heads/gh-pages.zip"
        set "dashboardDirectory=zashboard-gh-pages"
    )
)

@REM Prefer external-ui-url from config unless dashboard was explicitly specified
call :selectDashboardUrl

@REM Clash download URL
set "proxyDownloadForce=!force!"
if "!proxyEditionChanged!" == "1" set "proxyDownloadForce=1"
call :generateDownloadUrl clashUrl "!proxyDownloadUrl!" "!proxyExecutableName!" "!proxyDownloadForce!"

@REM Dashboard download URL
if "!dashboard!" == "" (
    @REM Dashboard is not needed
    set "dashboardUrl="
) else (
    set "needDashboard=!force!"
    if not exist "!dashboard!\index.html" set "needDashboard=1"
    if "!needDashboard!" == "0" (
        set "dashboardUrl="
    )
)

@REM Country database URL
call :generateDownloadUrl countryUrl "!countryUrl!" "!countryFile!" "!force!"

@REM GeoSite URL
call :generateDownloadUrl geoSiteUrl "!geoSiteUrl!" "!geoSiteFile!" "!force!"

@REM GeoASN URL
call :generateDownloadUrl geoAsnUrl "!geoAsnUrl!" "!geoAsnFile!" "!force!"

@REM GeoIP URL
call :generateDownloadUrl geoIpUrl "!geoIpUrl!" "!geoIpFile!" "!force!"

@REM LightGBM model
if "!useVerneMihomo!" == "0" set "lgbmUrl="
call :generateDownloadUrl lgbmUrl "!lgbmUrl!" "!lgbmFile!" "!force!"
goto :eof

@REM ============================================================================
@REM Select the dashboard download URL
@REM Purpose:    Select the dashboard download URL
@REM ============================================================================
:selectDashboardUrl
if "!dashboardForced!" == "1" goto :eof

set "configDashboardUrl=!cfgExternalUiUrl!"
if "!configDashboardUrl!" == "" goto :eof

set "dashboardUrl=!configDashboardUrl!"
call :inferDashboardDirectory dashboardDirectory "!dashboardUrl!" "!dashboardDirectory!"
goto :eof

@REM ============================================================================
@REM Infer a dashboard archive directory name
@REM Purpose:    Infer a dashboard archive directory name
@REM Parameters: <result>, <url>, <default>
@REM Returns:    Sets <result> with the computed value or status
@REM ============================================================================
:inferDashboardDirectory <result> <url> <default>
set "%~1=%~3"
call :trim rawUrl "%~2"
if "!rawUrl!" == "" goto :eof

if "!rawUrl:Dreamacro/clash-dashboard=!" NEQ "!rawUrl!" set "%~1=clash-dashboard-gh-pages"
if "!rawUrl:haishanh/yacd=!" NEQ "!rawUrl!" set "%~1=yacd-gh-pages"
if "!rawUrl:MetaCubeX/Yacd-meta=!" NEQ "!rawUrl!" set "%~1=Yacd-meta-gh-pages"
if "!rawUrl:MetaCubeX/metacubexd=!" NEQ "!rawUrl!" set "%~1=metacubexd-gh-pages"
if "!rawUrl:Zephyruso/zashboard=!" NEQ "!rawUrl!" set "%~1=zashboard-gh-pages"
goto :eof

@REM ============================================================================
@REM Skip Mihomo download when the local version is current
@REM Purpose:    Skip Mihomo download when the local version is current
@REM ============================================================================
:skipMihomoDownloadIfCurrent
if "!clashUrl!" == "" goto :eof
if "!useClashMeta!" NEQ "1" goto :eof
if "!proxyEditionChanged!" == "1" goto :eof
if not exist "!dest!\!proxyExecutableName!" goto :eof

if "!clashUrl:MetaCubeX/mihomo=!" == "!clashUrl!" if "!clashUrl:vernesong/mihomo=!" == "!clashUrl!" goto :eof

call :extractMihomoVersionFromUrl remoteMihomoVersion "!clashUrl!"
if "!remoteMihomoVersion!" == "" goto :eof

set "localMihomoVersionLine="
for /f "usebackq delims=" %%a in (`""!dest!\!proxyExecutableName!" -v 2^>nul"`) do if "!localMihomoVersionLine!" == "" set "localMihomoVersionLine=%%a"
if "!localMihomoVersionLine!" == "" goto :eof

echo !localMihomoVersionLine! | findstr /l /i /c:"!remoteMihomoVersion!" >nul 2>nul && (
    @echo [%ESC%[!infoColor!m信息%ESC%[0m] 代理程序 %ESC%[!warnColor!m!proxyExecutableName!%ESC%[0m 当前已是最新版本 %ESC%[!infoColor!m!remoteMihomoVersion!%ESC%[0m，跳过下载
    set "clashUrl="
)
goto :eof

@REM ============================================================================
@REM Extract the Mihomo version from a download URL
@REM Purpose:    Extract the Mihomo version from a download URL
@REM Parameters: <result>, <url>
@REM Returns:    Sets <result> with the computed value or status
@REM ============================================================================
:extractMihomoVersionFromUrl <result> <url>
set "%~1="
call :trim mihomoUrl "%~2"
if "!mihomoUrl!" == "" goto :eof

set "mihomoFile=!mihomoUrl:/= !"
for %%a in (!mihomoFile!) do set "mihomoFile=%%a"
set "mihomoFile=!mihomoFile:"=!"
set "mihomoFile=!mihomoFile:,=!"

set "mihomoVersion=!mihomoFile:.zip=!"
set "mihomoVersion=!mihomoVersion:mihomo-windows-=!"
set "mihomoVersion=!mihomoVersion:%archVersion%-=!"

if "!mihomoVersion!" == "!mihomoFile!" goto :eof
if "!mihomoVersion!" == "" goto :eof
set "%~1=!mihomoVersion!"
goto :eof

@REM ============================================================================
@REM Generate the final download URL
@REM Purpose:    Generate the final download URL
@REM Parameters: <result>, <url>, <fileName>, <force>
@REM Returns:    Sets <result> with the computed value or status
@REM ============================================================================
:generateDownloadUrl <result> <url> <fileName> <force>
set "%~1="

call :trim url "%~2"
if "!url!" == "" goto :eof

call :trim fileName "%~3"
if "!fileName!" == "" goto :eof

call :trim downloadForce "%~4"
if "!downloadForce!" == "" set "downloadForce=0"

if not exist "!dest!\!fileName!" (set "needDownload=1") else (set "needDownload=!downloadForce!")
if "!needDownload!" == "0" goto :eof

set "%~1=!url!"
goto :eof

@REM ============================================================================
@REM Detect operating system and CPU architecture
@REM Purpose:    Detect operating system and CPU architecture
@REM Parameters: <version>
@REM ============================================================================
:getArch <version>
set "%~1="
if "!PROCESSOR_ARCHITECTURE!" == "AMD64" (
    set "%~1=amd64"
) else if "!PROCESSOR_ARCHITECTURE!" == "ARM64" (
    set "%~1=arm64"
) else if "!PROCESSOR_ARCHITECTURE!" == "X86" (
    set "%~1=386"
) else (set "%~1=armv7")

goto :eof

@REM ============================================================================
@REM Trim surrounding whitespace
@REM Purpose:    Trim surrounding whitespace
@REM Parameters: <result>, <rawText>
@REM Returns:    Sets <result> with the computed value or status
@REM ============================================================================
:trim <result> <rawText>
set "rawText=%~2"
set "%~1="
if "!rawText!" == "" goto :eof

for /f "tokens=* delims= " %%a in ("!rawText!") do set "rawText=%%a"

@REM For /l %%a in (1,1,100) do if "!rawText:~-1!"==" " set "rawText=!rawText:~0,-1!"

@REM Limit iterations for performance
for /l %%a in (1,1,10) do if "!rawText:~-1!"==" " set "rawText=!rawText:~0,-1!"

set "%~1=!rawText!"
goto :eof

@REM ============================================================================
@REM Apply a GitHub download proxy when configured
@REM Purpose:    Apply a GitHub download proxy when configured
@REM Parameters: <result>, <rawUrl>
@REM Returns:    Sets <result> with the computed value or status
@REM ============================================================================
:applyGithubProxy <result> <rawUrl>
set "%~1="
call :trim rawUrl "%~2"
if "!rawUrl!" == "" goto :eof

@REM Apply the selected GitHub proxy list: https://github.com/XIU2/UserScript/blob/master/GithubEnhanced-High-Speed-Download.user.js
set proxy_urls[0]=https://ghfast.top
set proxy_urls[1]=https://proxy.api.030101.xyz
set proxy_urls[2]=https://git.udrone.vip
set proxy_urls[3]=https://gh.noki.icu
set proxy_urls[4]=https://ghproxy.monkeyray.net
set proxy_urls[5]=https://ghproxy.net

@REM Pick a random index in [0, 5]
set /a num=!random! %% 6
set "ghProxy=!proxy_urls[%num%]!"

@REM Apply the selected GitHub proxy
if "!rawUrl:~0,18!" == "https://github.com" set "rawUrl=!ghProxy!/!rawUrl!"
if "!rawUrl:~0,33!" == "https://raw.githubusercontent.com" set "rawUrl=!ghProxy!/!rawUrl!"
if "!rawUrl:~0,34!" == "https://gist.githubusercontent.com" set "rawUrl=!ghProxy!/!rawUrl!"

set "%~1=!rawUrl!"
goto :eof

@REM ============================================================================
@REM Find matching config context lines
@REM Purpose:    Find matching config context lines
@REM Parameters: <filePath>, <regex>, <resultFile>, <lines>
@REM ============================================================================
:findByContext <filePath> <regex> <resultFile> <lines>
call :trim filePath %~1
if "!filePath!" == "" goto :eof

set "regex=%~2"
if "!regex!" == "" goto :eof

call :trim result %~3
if "!result!" == "" goto :eof

call :trim context %~4
if not defined context (set "context=5")

powershell -command "& {&'Get-Content' '!filePath!' | &'Select-String' -Pattern '!regex!' -Context !context!,!context! | &'Set-Content' -Encoding 'utf8' '!result!'}";
goto :eof

@REM ============================================================================
@REM Find a colon-separated configuration entry
@REM Purpose:    Find a colon-separated configuration entry
@REM Parameters: <keyResult>, <valueResult>, <filePath>, <regex>
@REM Returns:    Sets <keyResult> with the computed value or status
@REM ============================================================================
:findConfigEntry <keyResult> <valueResult> <filePath> <regex>
set "%~1="
set "%~2="
call :trim filePath %~3
if "!filePath!" == "" goto :eof
if not exist "!filePath!" goto :eof

set "regex=%~4"
if "!regex!" == "" goto :eof

call :trim keepCommentedKey "%~5"
if "!keepCommentedKey!" == "" set "keepCommentedKey=0"

set "key="
set "text="
for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"!regex!" "!filePath!"') do (
    set "key=%%a"
    set "text=%%b"
)

call :trim key "!key!"
if "!key!" == "" goto :eof
if "!key:~0,1!" == "#" (
    if "!keepCommentedKey!" == "1" set "%~1=!key!"
    goto :eof
)

call :removeQuotes value "!text!"
set "%~1=!key!"
set "%~2=!value!"
goto :eof

@REM ============================================================================
@REM Find a configuration entry by key and value pattern
@REM Purpose:    Find a configuration entry by key and value pattern
@REM Parameters: <keyResult>, <valueResult>, <filePath>, <key>, <valuePattern>
@REM Returns:    Sets <keyResult> with the computed value or status
@REM ============================================================================
:findConfigKeyEntry <keyResult> <valueResult> <filePath> <key> <valuePattern>
set "%~1="
set "%~2="
call :trim filePath %~3
if "!filePath!" == "" goto :eof
if not exist "!filePath!" goto :eof

call :trim entryKey "%~4"
if "!entryKey!" == "" goto :eof

set "valuePattern=%~5"
if "!valuePattern!" == "" set "valuePattern=.*"

set "key="
set "text="
for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"^^!entryKey!:[ ][ ]*!valuePattern!" "!filePath!"') do (
    set "key=%%a"
    set "text=%%b"
)

call :trim key "!key!"
if "!key!" == "" goto :eof
if "!key:~0,1!" == "#" goto :eof

call :removeQuotes value "!text!"
set "%~1=!key!"
set "%~2=!value!"
goto :eof

@REM ============================================================================
@REM Find a YAML section value
@REM Purpose:    Find a YAML section value
@REM Parameters: <result>, <filePath>, <section>, <key>, [expectedValue]
@REM Returns:    Sets <result> with the computed value or status
@REM ============================================================================
:findYamlSectionValue <result> <filePath> <section> <key> [expectedValue]
set "%~1="
call :trim filePath %~2
if "!filePath!" == "" goto :eof
if not exist "!filePath!" goto :eof

call :trim sectionName "%~3"
if "!sectionName!" == "" goto :eof

call :trim targetKey "%~4"
if "!targetKey!" == "" goto :eof

call :trim expectedValue "%~5"

set "insideSection=0"
for /f "usebackq delims=" %%l in ("!filePath!") do (
    set "line=%%l"
    call :trim configLine "!line!"

    if "!configLine!" NEQ "" if "!configLine:~0,1!" NEQ "#" (
        if /i "!configLine!" == "!sectionName!:" (
            set "insideSection=1"
        ) else if "!insideSection!" == "1" (
            set "firstChar=!line:~0,1!"
            if "!firstChar!" NEQ " " if "!firstChar!" NEQ "-" set "insideSection=0"

            if "!insideSection!" == "1" (
                for /f "tokens=1* delims=:" %%a in ("!configLine!") do (
                    call :trim sectionKey "%%a"
                    if /i "!sectionKey!" == "!targetKey!" (
                        call :removeQuotes sectionValue "%%b"
                        if "!expectedValue!" == "" (
                            set "%~1=!sectionValue!"
                            goto :eof
                        ) else if /i "!sectionValue!" == "!expectedValue!" (
                            set "%~1=!sectionValue!"
                            goto :eof
                        )
                    )
                )
            )
        )
    )
)
goto :eof

@REM ============================================================================
@REM Find a line in a YAML section
@REM Purpose:    Find a line in a YAML section
@REM Parameters: <result>, <filePath>, <section>, <prefix1>, [prefix2]
@REM Returns:    Sets <result> with the matching line
@REM ============================================================================
:findYamlSectionLine <result> <filePath> <section> <prefix1> [prefix2]
set "%~1="
call :trim filePath %~2
if "!filePath!" == "" goto :eof
if not exist "!filePath!" goto :eof

call :trim sectionName "%~3"
if "!sectionName!" == "" goto :eof

call :trim matchPrefix1 "%~4"
call :trim matchPrefix2 "%~5"
if "!matchPrefix1!" == "" if "!matchPrefix2!" == "" goto :eof

set "insideSection=0"
for /f "usebackq delims=" %%l in ("!filePath!") do (
    set "line=%%l"
    call :trim configLine "!line!"

    if "!configLine!" NEQ "" if "!configLine:~0,1!" NEQ "#" (
        if /i "!configLine!" == "!sectionName!:" (
            set "insideSection=1"
        ) else if "!insideSection!" == "1" (
            set "firstChar=!line:~0,1!"
            if "!firstChar!" NEQ " " if "!firstChar!" NEQ "-" set "insideSection=0"

            if "!insideSection!" == "1" (
                echo(!configLine! | findstr /i /b /c:"!matchPrefix1!" >nul
                if not errorlevel 1 (
                    set "%~1=!configLine!"
                    goto :eof
                )

                if "!matchPrefix2!" NEQ "" (
                    echo(!configLine! | findstr /i /b /c:"!matchPrefix2!" >nul
                    if not errorlevel 1 (
                        set "%~1=!configLine!"
                        goto :eof
                    )
                )
            )
        )
    )
)
goto :eof

@REM ============================================================================
@REM Find a value in a YAML section list item
@REM Purpose:    Find a value in a YAML section list item by another key/value pair
@REM Parameters: <result>, <filePath>, <section>, <matchKey>, <matchValue>, <targetKey>, <targetValue>
@REM Returns:    Sets <result> with the matching target value
@REM ============================================================================
:findYamlSectionListItemValue <result> <filePath> <section> <matchKey> <matchValue> <targetKey> <targetValue>
set "%~1="
call :trim filePath %~2
if "!filePath!" == "" goto :eof
if not exist "!filePath!" goto :eof

call :trim sectionName "%~3"
if "!sectionName!" == "" goto :eof

call :trim matchKey "%~4"
call :trim matchValue "%~5"
call :trim targetKey "%~6"
call :trim targetValue "%~7"
if "!matchKey!" == "" goto :eof
if "!matchValue!" == "" goto :eof
if "!targetKey!" == "" goto :eof
if "!targetValue!" == "" goto :eof

set "insideSection=0"
set "itemHasMatch=0"
set "itemHasTarget=0"
for /f "usebackq delims=" %%l in ("!filePath!") do (
    set "line=%%l"
    call :trim configLine "!line!"

    if "!configLine!" NEQ "" if "!configLine:~0,1!" NEQ "#" (
        if /i "!configLine!" == "!sectionName!:" (
            set "insideSection=1"
            set "itemHasMatch=0"
            set "itemHasTarget=0"
        ) else if "!insideSection!" == "1" (
            set "firstChar=!line:~0,1!"
            if "!firstChar!" NEQ " " if "!firstChar!" NEQ "-" (
                if "!itemHasMatch!" == "1" if "!itemHasTarget!" == "1" set "%~1=!targetValue!"
                goto :eof
            )

            if /i "!configLine:~0,2!" == "- " (
                if not "!configLine!" == "!configLine::=!" (
                    if "!itemHasMatch!" == "1" if "!itemHasTarget!" == "1" (
                        set "%~1=!targetValue!"
                        goto :eof
                    )

                    set "itemHasMatch=0"
                    set "itemHasTarget=0"
                )
            )

            for /f "tokens=1* delims=:" %%a in ("!configLine!") do (
                call :trim itemKey "%%a"
                if /i "!itemKey:~0,2!" == "- " call :trim itemKey "!itemKey:~2!"
                call :removeQuotes itemValue "%%b"

                if /i "!itemKey!" == "!matchKey!" if /i "!itemValue!" == "!matchValue!" set "itemHasMatch=1"
                if /i "!itemKey!" == "!targetKey!" if /i "!itemValue!" == "!targetValue!" set "itemHasTarget=1"
            )
        )
    )
)

if "!itemHasMatch!" == "1" if "!itemHasTarget!" == "1" set "%~1=!targetValue!"
goto :eof

@REM ============================================================================
@REM Remove surrounding quotes
@REM Purpose:    Remove surrounding quotes
@REM Parameters: <result>, <str>
@REM Returns:    Sets <result> with the computed value or status
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
@REM Parse a YAML value from the main configuration
@REM Purpose:    Parse a YAML value from the main configuration
@REM Parameters: <result>, <regex>
@REM Returns:    Sets <result> with the computed value or status
@REM ============================================================================
:parseYamlValue <result> <regex>
call :findConfigEntry yamlKey "%~1" "!configFile!" "%~2"
goto :eof

@REM ============================================================================
@REM Parse a geox-url value
@REM Purpose:    Parse a geox-url value
@REM Parameters: <result>, <name>
@REM Returns:    Sets <result> with the computed value or status
@REM ============================================================================
:parseGeoxUrl <result> <name>
call :findYamlSectionValue "%~1" "!configFile!" "geox-url" "%~2"
goto :eof

@REM ============================================================================
@REM Reload proxy configuration through the API
@REM Purpose:    Reload proxy configuration through the API
@REM ============================================================================
:reloadConfig
if not exist "!configFile!" goto :eof

@REM Parse the API server path
if "!clashServer!" == "" call :extractControllerServer clashServer

if "!clashServer!" == "" (
    @echo [%ESC%[91m错误%ESC%[0m] %ESC%[91m不支持%ESC%[0m重载，可使用 "%ESC%[!warnColor!m!batchName! -r%ESC%[0m" 重启或者在文件 "%ESC%[!warnColor!m!configFile!%ESC%[0m" 配置 "%ESC%[!warnColor!mexternal-controller%ESC%[0m" 属性以启用该功能
    goto :eof
)

set "clashApi=!clashServer!/configs?force=true"

@REM API secret
call :parseYamlValue secret "secret:[ ][ ]*"

@REM Detect whether the proxy is running
call :isProcessRunning status

if "!status!" == "1" (
    @REM Escape backslashes for JSON
    set "filePath=!configFile:\=\\!"

    @REM Call the API to reload configuration
    set "statusCode=000"
    set "output=!temp!\clashout.txt"
    if exist "!output!" del /f /q "!output!" >nul 2>nul

    if "!secret!" NEQ "" (
        for /f %%a in ('curl --retry 3 -L -s -o "!output!" -w "%%{http_code}" -H "Content-Type: application/json" -H "Authorization: Bearer !secret!" -X PUT -d "{""path"":""!filePath!""}" "!clashApi!"') do set "statusCode=%%a"
    ) else (
        for /f %%a in ('curl --retry 3 -L -s -o "!output!" -w "%%{http_code}" -H "Content-Type: application/json" -X PUT -d "{""path"":""!filePath!""}" "!clashApi!"') do set "statusCode=%%a"
    )

    if "!statusCode!" == "204" (
        @echo [%ESC%[!infoColor!m信息%ESC%[0m] 网络代理程序重载%ESC%[!infoColor!m成功%ESC%[0m，祝你使用愉快
        call :postProcess
    ) else if "!statusCode!" == "401" (
        @echo [%ESC%[!infoColor!m信息%ESC%[0m] %ESC%[!warnColor!msecret%ESC%[0m 已被修改，请使用 "%ESC%[!warnColor!m!batchName! -r%ESC%[0m" 重启
    ) else (
        set "content="

        if exist "!output!" (
            @REM Read API output
            for /f "delims=" %%a in (!output!) do set "content=%%a"
        )

        @echo [%ESC%[91m错误%ESC%[0m] 网络代理程序重载%ESC%[91m失败%ESC%[0m，请检查配置文件 "%ESC%[!warnColor!m!configFile!%ESC%[0m" 是否有效
        if "!content!" NEQ "" (
            @echo [%ESC%[91m错误%ESC%[0m] 错误信息："!content!"
        )

        @echo.
    )

    @REM Delete the item
    del /f /q "!output!" >nul 2>nul
) else (
    @echo [%ESC%[91m错误%ESC%[0m] 网络代理程序%ESC%[91m未启动%ESC%[0m，可使用命令 "%ESC%[!warnColor!m!batchName! -r%ESC%[0m" 启动
)
goto :eof

@REM ============================================================================
@REM Update the main configuration file
@REM Purpose:    Update the main configuration file
@REM Parameters: <force>
@REM ============================================================================
:updateConfig <force>
call :trim force "%~1"
if "!force!" == "" set "force=1"
if exist "!configFile!" if "!force!" == "0" goto :eof

set "downloadPath=!temp!\clashconf.yaml"
del /f /q "!downloadPath!" >nul 2>nul

@REM Extract the remote configuration URL
set "subscriptionFile=!dest!\subscriptions.txt"
set "subscription="

if exist "!subscriptionFile!" (
    for /f "tokens=*" %%a in ('findstr /i /r /c:"^http.*://" "!subscriptionFile!"') do set "subscription=%%a"
    if "!subscription!" NEQ "" (
        call :trim subscription "!subscription!"
        if "!subscription:~0,1!" NEQ "#" set "remoteConfigUrl=!subscription!"
    )
)

if "!enableRemoteConfig!" == "1" if "!remoteConfigUrl!" NEQ "" (
    curl.exe --retry 5 --retry-max-time 90 -m 120 --connect-timeout 15 -H "User-Agent: Clash" -s -L -C - "!remoteConfigUrl!" > "!downloadPath!"
    if not exist "!downloadPath!" (
        @echo [%ESC%[!warnColor!m警告%ESC%[0m] 配置文件下载失败，如有需要，请重试或点击 %ESC%[!warnColor!m!remoteConfigUrl!%ESC%[0m 手动下载并替换
        goto :eof
    )

    call :resolveProxyExecutableName
    if exist "!dest!\!proxyExecutableName!" (
        @REM Check the downloaded file
        for %%a in ("!downloadPath!") do set "fileSize=%%~za"
        if !fileSize! LSS 32 (
            del /f /q "!downloadPath!" >nul 2>nul
            @echo [%ESC%[!warnColor!m警告%ESC%[0m] 配置文件下载失败，如有需要，请重试或点击 %ESC%[!warnColor!m!remoteConfigUrl!%ESC%[0m 手动下载并替换
            exit /b 1
        )

        @REM Test the configuration file
        "!dest!\!proxyExecutableName!" -d "!dest!" -t -f "!downloadPath!" >nul 2>nul

        @REM Handle failure
        if !errorlevel! NEQ 0 (
            @echo [%ESC%[91m错误%ESC%[0m] 配置文件 %ESC%[!warnColor!m!remoteConfigUrl!%ESC%[0m 存在错误，无法更新
            del /f /q "!downloadPath!" >nul 2>nul
            exit /b 1
        )
    )

    @REM Compare downloaded files with md5
    call :compareMd5 diff "!downloadPath!" "!configFile!"
    if "!diff!" == "0" (
        del /f /q "!downloadPath!" >nul 2>nul
        goto :eof
    )

    set "backupFile=config.yaml.bak"
    @echo [%ESC%[!infoColor!m信息%ESC%[0m] 发现较新配置，原有文件将备份为 %ESC%[!warnColor!m!dest!\!backupFile!%ESC%[0m

    @REM Back up the current file
    del /f /q "!dest!\!backupFile!" >nul 2>nul
    ren "!configFile!" !backupFile!

    @REM Move the new configuration file into place
    move "!downloadPath!" "!configFile!" >nul 2>nul
)
goto :eof

@REM ============================================================================
@REM Update managed rule provider files
@REM Purpose:    Update managed rule provider files
@REM Parameters: <force>
@REM ============================================================================
:updateRules <force>
call :trim force "%~1"
if "!force!" == "" set "force=1"

if "!force!" == "1" (
    @echo [%ESC%[!infoColor!m信息%ESC%[0m] 开始检查并更新类型为 %ESC%[!warnColor!mHTTP%ESC%[0m 的代理规则
)

call :refreshReferencedFiles changed "rule-providers" "!force!" ruleFiles "payload"
goto :eof

@REM ============================================================================
@REM Count leading spaces in a line
@REM Purpose:    Count leading spaces in a line
@REM Parameters: <result>, <line>
@REM Returns:    Sets <result> with the computed value or status
@REM ============================================================================
:countLeadingSpaces <result> <line>
set "%~1=0"
set "indentText=%~2"
:countLeadingSpacesLoop
if "!indentText:~0,1!" == " " (
    set /a %~1+=1
    set "indentText=!indentText:~1!"
    goto :countLeadingSpacesLoop
)
goto :eof

@REM ============================================================================
@REM Append a referenced provider entry
@REM Purpose:    Append a referenced provider entry
@REM Parameters: <resultFile>, <url>, <path>
@REM ============================================================================
:appendReferencedEntry <resultFile> <url> <path>
call :trim entryUrl "%~2"
call :trim entryPath "%~3"
if "!entryUrl!" == "" goto :eof
if "!entryPath!" == "" goto :eof
if /i "!entryUrl:~0,7!" NEQ "http://" if /i "!entryUrl:~0,8!" NEQ "https://" goto :eof
>>"%~1" echo !entryUrl!^|!entryPath!
goto :eof

@REM ============================================================================
@REM Extract referenced provider URL and path pairs
@REM Purpose:    Extract referenced provider URL and path pairs
@REM Parameters: <section>, <resultFile>
@REM ============================================================================
:extractReferencedEntries <section> <resultFile>
call :trim extractSection "%~1"
call :trim extractResult "%~2"
if "!extractSection!" == "" goto :eof
if "!extractResult!" == "" goto :eof
if not exist "!configFile!" goto :eof

powershell -NoProfile -ExecutionPolicy Bypass -Command "& {$section='!extractSection!'; $out='!extractResult!'; $lines=Get-Content -LiteralPath '!configFile!'; $inside=$false; $sectionIndent=-1; $itemIndent=-1; $propertyIndent=-1; $script:url=''; $script:path=''; function Reset-Entry {$script:url=''; $script:path=''; $script:propertyIndent=-1}; function Add-Entry {if (($script:url -match '^https?://') -and $script:path) {($script:url + '|' + $script:path) | Add-Content -Encoding utf8 -LiteralPath $out}}; foreach ($line in $lines) {$text=$line.Trim(); if ((-not $text) -or $text.StartsWith('#')) {continue}; $indent=$line.Length - $line.TrimStart(' ').Length; if (-not $inside) {if ($text -ieq ($section + ':')) {$inside=$true; $sectionIndent=$indent; $itemIndent=-1; Reset-Entry}; continue}; if ($indent -le $sectionIndent) {Add-Entry; $inside=$false; $itemIndent=-1; Reset-Entry; if ($text -ieq ($section + ':')) {$inside=$true; $sectionIndent=$indent}; continue}; if ($itemIndent -lt 0) {$itemIndent=$indent; Reset-Entry} elseif ($indent -le $itemIndent) {Add-Entry; $itemIndent=$indent; Reset-Entry} else {if ($propertyIndent -lt 0) {$propertyIndent=$indent}; if ($indent -eq $propertyIndent) {$parts=$text -split ':',2; if ($parts.Count -eq 2) {$key=$parts[0].Trim(); $value=$parts[1].Trim().Trim([char]34).Trim([char]39); if ($key -ieq 'url') {$script:url=$value}; if ($key -ieq 'path') {$script:path=$value}}}}}; if ($inside) {Add-Entry}}"
goto :eof

@REM ============================================================================
@REM Refresh referenced subscription or rule files
@REM Purpose:    Refresh referenced subscription or rule files
@REM Parameters: <result>, <section>, <force>, <filePaths>, <check>
@REM Returns:    Sets <result> with the computed value or status
@REM ============================================================================
:refreshReferencedFiles <result> <section> <force> <filePaths> <check>
set "%~1=0"
call :trim sectionName "%~2"
set "%~4="

call :trim check "%~5"

call :trim force "%~3"
if "!force!" == "" set "force=1"

if "!sectionName!" == "" (
    @echo [%ESC%[!warnColor!m警告%ESC%[0m] 未指定关键信息，跳过更新
    goto :eof
)

if not exist "!configFile!" goto :eof

set "tempFile=!temp!\clashupdate.txt"
del /f /q "!tempFile!" >nul 2>nul
set "filePaths="

call :extractReferencedEntries "!sectionName!" "!tempFile!"

if not exist "!tempFile!" (
    if "!force!" == "0" goto :eof

    @echo [%ESC%[!warnColor!m警告%ESC%[0m] 未发现订阅或代理规则相关配置，跳过更新，文件："!configFile!"
    goto :eof
)

for /f "usebackq tokens=1* delims=|" %%u in ("!tempFile!") do (
    call :trim url "%%u"
    call :trim rawPath "%%v"

    @REM Generate the target file path
    call :convertToAbsolutePath targetFile "!rawPath!"
    if "!targetFile!" == "" (
        @echo [%ESC%[91m错误%ESC%[0m] 配置无效，订阅或代理规则更新失败
        goto :eof
    )

    set "filePaths=!filePaths!,!targetFile!"
    if /i "!url:~0,8!"=="https://" (
        set "needDownload=0"
        if not exist "!targetFile!" set "needDownload=1"
        if "!force!" == "1" set "needDownload=1"
        @REM Determine whether the file should be downloaded
        if "!needDownload!" == "1" (
            @REM Resolve the target directory
            call :splitPath filePath fileName "!targetFile!"

            @REM Create the directory when missing
            call :createDirectories success "!filePath!"

            @REM Download and save the file
            del /f /q "!temp!\!fileName!" >nul 2>nul
            call :retryDownload "!url!" "!temp!\!fileName!"

            @REM Check the downloaded file size
            set "fileSize=0"
            if exist "!temp!\!fileName!" (
                for %%a in ("!temp!\!fileName!") do set "fileSize=%%~za"
            )

            @REM Check the downloaded file content
            call :verifyFileSection match "!temp!\!fileName!" "!check!"

            if !fileSize! GTR 16 if "!match!" == "1" (
                @REM Delete the old file when present
                del /f /q "!targetFile!" >nul 2>nul

                @REM Move the new file into the destination directory
                move "!temp!\!fileName!" "!filePath!" >nul 2>nul

                @REM Mark the change status
                set "%~1=1"
            ) else (
                @echo [%ESC%[91m错误%ESC%[0m] 文件 %ESC%[!warnColor!m!fileName!%ESC%[0m 下载失败，下载链接："!url!"
            )
        )
    )
)

set "%~4=!filePaths!"
if exist "!tempFile!" del /f /q "!tempFile!" >nul 2>nul
goto :eof

@REM ============================================================================
@REM Extract the dashboard path from configuration
@REM Purpose:    Extract the dashboard path from configuration
@REM Parameters: <result>
@REM ============================================================================
:extractDashboardPath <result>
set "%~1="

if not exist "!configFile!" goto :eof

call :findConfigEntry keyName content "!configFile!" "external-ui:[ ][ ]*" 1

@REM External-ui was not found in the configuration file
if "!keyName!" NEQ "external-ui" (
    set "flag=1"
    if "!keyName!" NEQ "" set "flag=0"
    if "!brief!" == "1" set "flag=0"
    if "!clashServer!" == "" set "flag=0"

    if "!flag!" == "0" goto :eof

    set "tmpConfig=!configFile!.tmp"

    @REM Add the external-ui configuration entry
    @echo external-ui: dashboard > "!tmpConfig!"
    type "!configFile!" >> "!tmpConfig!"

    @REM Replace the configuration file
    del /f /q "!configFile!" >nul 2>nul
    move "!tmpConfig!" "!configFile!" >nul 2>nul

    @REM Reset temporary state
    set "tmpConfig="
    set "content=dashboard"
)

call :trim content "!content!"
if "!content!" == "" goto :eof

call :convertToAbsolutePath directory "!content!"
set "%~1=!directory!"
goto :eof

@REM ============================================================================
@REM Verify that a file contains a required section
@REM Purpose:    Verify that a file contains a required section
@REM Parameters: <result>, <file>, <check>
@REM Returns:    Sets <result> with the computed value or status
@REM ============================================================================
:verifyFileSection <result> <file> <check>
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

@REM Skip when not required
call :trim text "!text!"

if "!text!" == "!check!" set "%~1=1"
goto :eof

@REM ============================================================================
@REM Download and replace the dashboard files
@REM Purpose:    Download and replace the dashboard files
@REM Parameters: <force>
@REM ============================================================================
:updateDashboard <force>
call :trim force "%~1"
if "!force!" == "" set "force=0"

if "!dashboardUrl!" == "" (
    if "!force!" == "0" goto :eof

    @echo [%ESC%[!infoColor!m信息%ESC%[0m] 控制面板%ESC%[!warnColor!m未启用%ESC%[0m，跳过更新
    goto :eof
)

if "!dashboard!" == "" (
    @echo [%ESC%[91m错误%ESC%[0m] 无法获取控制面板保存路径
    goto :eof
)

@REM Existing file check
if exist "!dashboard!\index.html" if "!force!" == "0" goto :eof
call :createDirectories success "!dashboard!"

@echo [%ESC%[!infoColor!m信息%ESC%[0m] 开始下载并更新控制面板
call :retryDownload "!dashboardUrl!" "!temp!\dashboard.zip"

if not exist "!temp!\dashboard.zip" (
    @echo [%ESC%[!warnColor!m警告%ESC%[0m] 控制面板下载失败，下载链接："!dashboardUrl!"
    goto :eof
)

@REM Extract the archive
tar -xzf "!temp!\dashboard.zip" -C !temp! >nul 2>nul
del /f /q "!temp!\dashboard.zip" >nul 2>nul

@REM Resolve base path and directory name
call :splitPath dashPath dashName "!dashboard!"
if "!dashPath!" == "" (
    @echo [%ESC%[91m错误%ESC%[0m] 无法获取控制面板保存路径
    goto :eof
)

if "!dashName!" == "" (
    @echo [%ESC%[91m错误%ESC%[0m] 无法获取控制面板文件夹名
    goto :eof
)

@REM Rename the extracted directory
ren "!temp!\!dashboardDirectory!" !dashName!

@REM Replace dashboard files after a successful download
dir /a /s /b "!temp!\!dashName!" | findstr . >nul && (
    call :replaceDirectory "!temp!\!dashName!" "!dashboard!"
    @echo [%ESC%[!infoColor!m信息%ESC%[0m] 控制面板已更新至最新版本
) || (
    @echo [%ESC%[!warnColor!m警告%ESC%[0m] 控制面板下载失败，下载链接："!dashboardUrl!"
)
goto :eof

@REM ============================================================================
@REM Replace one directory with another
@REM Purpose:    Replace one directory with another
@REM Parameters: <src>, <dest>
@REM ============================================================================
:replaceDirectory <src> <dest>
set "src=%~1"
set "target=%~2"

if "!src!" == "" (
    @echo [%ESC%[!warnColor!m警告%ESC%[0m] 移动失败，源文件夹路径为空
    goto :eof
)

if "!target!" == "" (
    @echo [%ESC%[!warnColor!m警告%ESC%[0m] 移动失败，目标路径为空
    goto :eof
)

if not exist "!src!" (
    @echo [%ESC%[91m错误%ESC%[0m] 文件夹移动失败，源文件夹不存在："!src!"
    goto :eof
)

@REM Delete the old folder when present
if exist "!target!" rd "!target!" /s /q >nul 2>nul

@REM Copy files to the destination
xcopy "!src!" "!target!" /h /e /y /q /i >nul 2>nul

@REM Delete the item source dashboard
rd "!src!" /s /q >nul 2>nul
goto :eof

@REM ============================================================================
@REM Clean temporary update files
@REM Purpose:    Clean temporary update files
@REM ============================================================================
:cleanWorkspace
set "directory=%~1"
if "!directory!" == "" set "directory=!temp!"

if exist "!directory!\clash.zip" del /f /q "!directory!\clash.zip" >nul
if exist "!directory!\!clashExecutableName!" del /f /q "!directory!\!clashExecutableName!" >nul
if exist "!directory!\!mihomoExecutableName!" del /f /q "!directory!\!mihomoExecutableName!" >nul

@REM Wintun
if exist "!directory!\wintun.zip" del /f /q "!directory!\wintun.zip"
if exist "!directory!\wintun" rd "!directory!\wintun" /s /q >nul 2>nul

if "!clashExe!" NEQ "" (
    if exist "!directory!\!clashExe!" del /f /q "!directory!\!clashExe!" >nul
)

if "!countryFile!" NEQ "" (
    if exist "!directory!\!countryFile!" del /f /q "!directory!\!countryFile!" >nul
)

if "!geoSiteFile!" NEQ "" (
    if exist "!directory!\!geoSiteFile!" del /f /q "!directory!\!geoSiteFile!" >nul
)

if "!geoAsnFile!" NEQ "" (
    if exist "!directory!\!geoAsnFile!" del /f /q "!directory!\!geoAsnFile!" >nul
)

if "!geoIpFile!" NEQ "" (
    if exist "!directory!\!geoIpFile!" del /f /q "!directory!\!geoIpFile!" >nul
)

@REM Delete the item directory
if "!dashboardDirectory!" NEQ "" (
    if exist "!directory!\!dashboardDirectory!" rd "!directory!\!dashboardDirectory!" /s /q >nul
)

if "!dashboard!" == "" goto :eof
if exist "!directory!\!dashboard!.zip" del /f /q "!directory!\!dashboard!.zip" >nul
if exist "!directory!\!dashboard!" rd "!directory!\!dashboard!" /s /q >nul 2>nul
goto :eof

@REM ============================================================================
@REM Normalize path separators
@REM Purpose:    Normalize path separators
@REM Parameters: <result>, <directory>
@REM Returns:    Sets <result> with the computed value or status
@REM ============================================================================
:normalizePath <result> <directory>
set "%~1="
call :trim directory "%~2"

if "!directory!" == "" goto :eof

@REM Collapse duplicate backslashes
set "directory=!directory:\\=\!"

@REM Convert forward slashes to backslashes
set "directory=!directory:/=\!"

@REM Remove a trailing backslash
if "!directory:~-1!" == "\" set "directory=!directory:~0,-1!"
set "%~1=!directory!"
goto :eof

@REM ============================================================================
@REM Exit with an update failure message
@REM Purpose:    Exit with an update failure message
@REM ============================================================================
:terminate
@echo [%ESC%[91m错误%ESC%[0m] 更新失败，代理程序、域名及 IP 地址数据库或控制面板缺失
call :cleanWorkspace "!temp!"
exit /b 1
goto :eof

@REM ============================================================================
@REM Close the running proxy program
@REM Purpose:    Close the running proxy program
@REM ============================================================================
:closeProxy
call :isProcessRunning status
if "!status!" == "0" (
    @echo [%ESC%[!infoColor!m信息%ESC%[0m] 网络代理程序%ESC%[!warnColor!m未运行%ESC%[0m，无须关闭
    goto :eof
)

set "tips=[%ESC%[!warnColor!m警告%ESC%[0m] 此操作将会关闭代理网络，是否继续？(%ESC%[!warnColor!mY%ESC%[0m/%ESC%[!warnColor!mN%ESC%[0m) "
if "!msTerminal!" == "1" (
    choice /t 6 /d y /n /m "!tips!"
) else (
    set /p "=!tips!" <nul
    choice /t 6 /d y /n
)
if !errorlevel! == 2 exit /b 1
goto :killProcessWrapper

@REM ============================================================================
@REM Initialize ANSI escape sequence support
@REM Purpose:    Initialize ANSI escape sequence support
@REM ============================================================================
:setEsc
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do (
  set ESC=%%b
  exit /b 0
)
exit /b 0

@REM ============================================================================
@REM Enable the Windows system proxy
@REM Purpose:    Enable the Windows system proxy
@REM Parameters: <server>
@REM ============================================================================
:enableSystemProxy <server>
call :trim server "%~1"
if "!server!" == "" goto :eof

reg add "!proxyRegPath!" /v ProxyEnable /t REG_DWORD /d 1 /f >nul 2>nul
reg add "!proxyRegPath!" /v ProxyServer /t REG_SZ /d "!server!" /f >nul 2>nul
reg add "!proxyRegPath!" /v ProxyOverride /t REG_SZ /d "<local>" /f >nul 2>nul
goto :eof

@REM ============================================================================
@REM Disable the Windows system proxy
@REM Purpose:    Disable the Windows system proxy
@REM ============================================================================
:disableSystemProxy
reg add "!proxyRegPath!" /v ProxyServer /t REG_SZ /d "" /f >nul 2>nul
reg add "!proxyRegPath!" /v ProxyEnable /t REG_DWORD /d 0 /f >nul 2>nul
reg add "!proxyRegPath!" /v ProxyOverride /t REG_SZ /d "" /f >nul 2>nul
goto :eof

@REM ============================================================================
@REM Read the current Windows system proxy
@REM Purpose:    Read the current Windows system proxy
@REM Parameters: <result>
@REM ============================================================================
:getSystemProxy <result>
set "%~1="

@REM Read the enabled flag
call :queryRegistry enable "!proxyRegPath!" "ProxyEnable" "REG_DWORD"
if "!enable!" NEQ "0x1" goto :eof

@REM Read the proxy server
call :queryRegistry server "!proxyRegPath!" "ProxyServer" "REG_SZ"
if "!server!" NEQ "" set "%~1=!server!"
goto :eof

@REM ============================================================================
@REM Configure startup at user login
@REM Purpose:    Configure startup at user login
@REM ============================================================================
:configureAutostart
call :queryRegistry exeName "!autostartRegPath!" "Clash" "REG_SZ"
if "!startupVbs!" NEQ "!exeName!" (
    set "tips=[%ESC%[!warnColor!m提示%ESC%[0m] 是否允许网络代理程序开机自启？(%ESC%[!warnColor!mY%ESC%[0m/%ESC%[!warnColor!mN%ESC%[0m) "
    if "!msTerminal!" == "1" (
        choice /t 5 /d y /n /m "!tips!"
    ) else (
        set /p "=!tips!" <nul
        choice /t 5 /d y /n
    )
    if !errorlevel! == 2 exit /b 1

    call :enableNoPromptRunAs success
    if "!success!" == "0" (
        @echo [%ESC%[91m错误%ESC%[0m] 权限受限，%ESC%[91m无法设置%ESC%[0m开机自启
        goto :eof
    )

    call :generateStartupVbs "!startupVbs!" "-r"
    call :registerStartupScript success "!startupVbs!"
    if "!success!" == "1" (
        @echo [%ESC%[!infoColor!m信息%ESC%[0m] 网络代理程序开机自启设置%ESC%[!infoColor!m完成%ESC%[0m
    ) else (
        @echo [%ESC%[91m错误%ESC%[0m] 网络代理程序开机自启设置%ESC%[91m失败%ESC%[0m
    )
)
goto :eof

@REM ============================================================================
@REM Disable startup at user login
@REM Purpose:    Disable startup at user login
@REM Parameters: <result>
@REM ============================================================================
:disableAutostart <result>
set "%~1=0"
call :queryRegistry exeName "!autostartRegPath!" "Clash" "REG_SZ"

if "!exeName!" == "" (
    set "%~1=1"
) else (
    set "shouldDelete=1"
    if "!startupVbs!" NEQ "!exeName!" (
        set "tips=[%ESC%[!warnColor!m警告%ESC%[0m] 发现相同名字但执行路径不同的配置，是否继续？(%ESC%[!warnColor!mY%ESC%[0m/%ESC%[!warnColor!mN%ESC%[0m) "
        if "!msTerminal!" == "1" (
            choice /t 5 /d n /n /m "!tips!"
        ) else (
            set /p "=!tips!" <nul
            choice /t 5 /d n /n
        )
        if !errorlevel! == 2 set "shouldDelete=0"
    )
    if "!shouldDelete!" == "1" (
        reg delete "!autostartRegPath!" /v "Clash" /f >nul 2>nul
        if "!errorlevel!" == "0" set "%~1=1"

        @REM Disable the integration
        reg delete "!startupApprovedRegPath!" /v "Clash" /f >nul 2>nul
    )
)
goto :eof

@REM ============================================================================
@REM Configure scheduled automatic updates
@REM Purpose:    Configure scheduled automatic updates
@REM Parameters: <refresh>
@REM ============================================================================
:configureAutoUpdate <refresh>
call :trim refresh "%~1"
if "!refresh!" == "" set "refresh=0"
set "taskName=ClashUpdater"

call :getTaskStatus ready "!taskName!"
if "!refresh!" == "1" set "ready=0"

if "!ready!" == "0" (
    set "tips=[%ESC%[!warnColor!m提示%ESC%[0m] 是否设置自动检查更新代理应用及规则？(%ESC%[!warnColor!mY%ESC%[0m/%ESC%[!warnColor!mN%ESC%[0m) "
    if "!msTerminal!" == "1" (
        choice /t 5 /d n /n /m "!tips!"
    ) else (
        set /p "=!tips!" <nul
        choice /t 5 /d y /n
    )
    if !errorlevel! == 2 exit /b 1

    @REM Generate the update VBS script
    call :generateUpdateVbs

    @REM Delete the old scheduled task
    call :deleteScheduledTask success "!taskName!"

    @REM Create the new scheduled task
    call :createScheduledTask success "!updateVbs!" "!taskName!"
    if "!success!" == "1" (
        @echo [%ESC%[!infoColor!m信息%ESC%[0m] 自动检查更新设置%ESC%[!infoColor!m成功%ESC%[0m
    ) else (
        @echo [%ESC%[91m错误%ESC%[0m] 自动检查更新设置%ESC%[91m失败%ESC%[0m
    )
)
goto :eof

@REM ============================================================================
@REM Generate the scheduled update script
@REM Purpose:    Generate the scheduled update script
@REM ============================================================================
:generateUpdateVbs
set "operation=-u"
if "!useClashPremium!" == "1" set "operation=!operation! -n"
if "!useVerneMihomo!" == "1" (
    set "operation=!operation! -v"
) else (
    if "!useClashMeta!" == "1" set "operation=!operation! -m"
)

if "!alpha!" == "1" set "operation=!operation! -a"
if "!yacd!" == "1" set "operation=!operation! -y"
if "!metaCubeXDashboard!" == "1" set "operation=!operation! -x"
if "!zashboard!" == "1" set "operation=!operation! -z"

@REM Generate and write the script file
call :generateStartupVbs "!updateVbs!" "!operation!"

goto :eof

@REM ============================================================================
@REM Create the scheduled update task
@REM Purpose:    Create the scheduled update task
@REM Parameters: <result>, <path>, <taskName>
@REM Returns:    Sets <result> with the computed value or status
@REM ============================================================================
:createScheduledTask <result> <path> <taskName>
set "%~1=0"
call :trim exeName "%~2"
if "!exeName!" == "" goto :eof

call :trim taskName "%~3"
if "!taskName!" == "" goto :eof

@REM Resolve the task start time
call :promptScheduleTime startTime

@REM Create the task
schtasks /create /tn "!taskName!" /tr "!exeName!" /sc daily /mo 1 /ri 480 /st !startTime! /du 0012:00 /f >nul 2>nul
if "!errorlevel!" == "0" set "%~1=1"
goto :eof

@REM ============================================================================
@REM Prompt for the scheduled update time
@REM Purpose:    Prompt for the scheduled update time
@REM Parameters: <time>
@REM ============================================================================
:promptScheduleTime <time>
set "%~1="
set "userTime="
set "defaultTime=09:15"

@REM Choose whether to customize the time
set "tips=[%ESC%[!warnColor!m提示%ESC%[0m] 正在设置更新时间，默认为 %ESC%[!warnColor!m09:15%ESC%[0m，是否需要修改？(%ESC%[!warnColor!mY%ESC%[0m/%ESC%[!warnColor!mN%ESC%[0m) "
if "!msTerminal!" == "1" (
    choice /c yn /n /d n /t 5 /m "!tips!"
) else (
    set /p "=!tips!" <nul
    choice /c yn /n /d n /t 5
)

if !errorlevel! == 2 (
    set "%~1=!defaultTime!"
    goto :eof
)

@REM Prompt for a time value
call :promptTimeInput inputTime "!defaultTime!" 0
set "%~1=!inputTime!"
goto :eof

@REM ============================================================================
@REM Prompt for a time value
@REM Purpose:    Prompt for a time value
@REM Parameters: <result>, <default>, <retry>
@REM Returns:    Sets <result> with the computed value or status
@REM ============================================================================
:promptTimeInput <result> <default> <retry>
set "%~1="

set "tips=[%ESC%[!warnColor!m提示%ESC%[0m] 请输入一个格式为 %ESC%[!warnColor!mHH:MM%ESC%[0m 的 %ESC%[!warnColor!m24小时制%ESC%[0m 时间："

call :trim retryFlag "%~3"
if "!retryFlag!" == "1" (
    set "tips=[%ESC%[91m错误%ESC%[0m] 输入的时间%ESC%[91m无效%ESC%[0m或%ESC%[91m格式不正确%ESC%[0m，请重新输入："
    set "retryFlag=0"
)

set /p "userInput=!tips!"
if not defined userInput (set "userInput=%~2")

@REM Validate user input
call :validateTimeInput "%~1" "%~2" "!userInput!"
goto :eof

@REM ============================================================================
@REM Validate a time value
@REM Purpose:    Validate a time value
@REM Parameters: <result>, <default>, <input>
@REM Returns:    Sets <result> with the computed value or status
@REM ============================================================================
:validateTimeInput <result> <default> <input>
set "%~1="

@REM Trim user input
call :trim userTime "%~3"

set "validFlag=0"
for /f "tokens=1-2 delims=:" %%a in ("!userTime!") do (
    set "hours=%%a" 2>nul
    set "minutes=%%b" 2>nul

    call :isNumber hourFlag !hours!
    call :isNumber minuteFlag !minutes!

    if !hourFlag! == 1 if !minuteFlag! == 1 if !hours! lss 24 if !minutes! lss 60 if !hours! geq 0 if !minutes! geq 0 (
        set "validFlag=1"
    )
)

if "!validFlag!" == "0" (call :promptTimeInput "%~1" "%~2" 1) else (set "%~1=!userTime!")
goto :eof

@REM ============================================================================
@REM Check whether a value is a non-negative integer
@REM Purpose:    Check whether a value is a non-negative integer
@REM Parameters: <result>, <variable>
@REM Returns:    Sets <result> with the computed value or status
@REM ============================================================================
:isNumber <result> <variable>
set "%~1=0"
call :trim variable "%~2"

@echo !variable! | findstr /r /c:"^[0-9][0-9][ ]*$" >nul 2>nul && (set "%~1=1")

goto :eof

@REM ============================================================================
@REM Read scheduled task status
@REM Purpose:    Read scheduled task status
@REM Parameters: <status>, <taskName>
@REM Returns:    Sets <status> with the computed value or status
@REM ============================================================================
:getTaskStatus <status> <taskName>
set "%~1=0"
call :trim taskName "%~2"
if "!taskName!" == "" goto :eof

@REM Query the current value
schtasks /query /tn "!taskName!" >nul 2>nul
if "!errorlevel!" NEQ "0" goto :eof

@REM Compare the scheduled script path with the current script path
set "commandPath="
for /f "tokens=3 delims=<>" %%a in ('schtasks /query /tn "!taskName!" /xml ^| findstr "<Command>"') do set "commandPath=%%a"
call :trim commandPath "!commandPath!"

if "!commandPath!" NEQ "!updateVbs!" goto :eof

set "status="
for /f "usebackq skip=3 tokens=4" %%a in (`schtasks /query /tn "!taskName!"`) do set "status=%%a"
call :trim status "!status!"

if "!status!" == "Ready" set "%~1=1"

goto :eof

@REM ============================================================================
@REM Delete the scheduled update task
@REM Purpose:    Delete the scheduled update task
@REM Parameters: <result>, <taskName>
@REM Returns:    Sets <result> with the computed value or status
@REM ============================================================================
:deleteScheduledTask <result> <taskName>
set "%~1=0"
call :trim taskName "%~2"
if "!taskName!" == "" goto :eof

schtasks /query /tn "!taskName!" >nul 2>nul
@REM Item not found
if "!errorlevel!" NEQ "0" (
    set "%~1=1"
    goto :eof
)

@REM Remove the item
call :runElevated "goto :cancelScheduledTask !taskName!" 0

@REM Check deletion status
for /l %%i in (1,1,5) do (
    schtasks /query /tn "!taskName!" >nul 2>nul
    if "!errorlevel!" == "0" (
        @REM Wait before continuing
        timeout /t 1 /nobreak >nul 2>nul
    ) else (
        set "%~1=1"
        exit /b
    )
)
goto :eof

@REM ============================================================================
@REM Cancel a scheduled task using elevation
@REM Purpose:    Cancel a scheduled task using elevation
@REM Parameters: <taskName>
@REM ============================================================================
:cancelScheduledTask <taskName>
@REM Delete the item
schtasks /delete /tn "%~1" /f  >nul 2>nul

@REM Request administrator privileges
call :enableNoPromptRunAs result
goto :eof

@REM ============================================================================
@REM Register the startup script
@REM Purpose:    Register the startup script
@REM Parameters: <result>, <path>
@REM Returns:    Sets <result> with the computed value or status
@REM ============================================================================
:registerStartupScript <result> <path>
set "%~1=0"
call :trim exeName "%~2"
if "!exeName!" == "" goto :eof
if not exist "!exeName!" goto :eof

@REM Delete the item
reg delete "!autostartRegPath!" /v "Clash" /f >nul 2>nul
@REM Register the startup command
reg add "!autostartRegPath!" /v "Clash" /t "REG_SZ" /d "!exeName!" >nul 2>nul
if "!errorlevel!" NEQ "0" goto :eof

@REM Approve startup in StartupApproved
reg delete "!startupApprovedRegPath!" /v "Clash" /f >nul 2>nul
@REM Register the startup command
reg add "!startupApprovedRegPath!" /v "Clash" /t "REG_BINARY" /d "02 00 00 00 00 00 00 00 00 00 00 00" >nul 2>nul

if "!errorlevel!" == "0" set "%~1=1"
goto :eof

@REM ============================================================================
@REM Generate the startup VBS script
@REM Purpose:    Generate the startup VBS script
@REM Parameters: <path>, <operation>
@REM ============================================================================
:generateStartupVbs <path> <operation>
call :trim startScript "%~1"
if "!startScript!" == "" goto :eof

call :trim operation "%~2"
if "!operation!" == "" goto :eof

@echo set ws = WScript.CreateObject^("WScript.Shell"^) > "!startScript!"
@echo ws.Run "%~dp0!batchName! !operation! -w !dest! -c !configFile!", 0 >> "!startScript!"
@echo set ws = Nothing >> "!startScript!"
goto :eof

@REM ============================================================================
@REM Detect whether Windows Home edition is running
@REM Purpose:    Detect whether Windows Home edition is running
@REM Parameters: <result>
@REM ============================================================================
:isHomeEdition <result>
set "%~1=1"

set "content="
for /f %%a in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "(Get-CimInstance -ClassName Win32_OperatingSystem).OperatingSystemSKU"') do set "content=%%a"
call :trim content "!content!"

@REM 2/3/5/26 represent home edition
if "!content!" NEQ "2" if "!content!" NEQ "3" if "!content!" NEQ "5" if "!content!" NEQ "26" (
    for /f "delims=" %%a in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "(Get-CimInstance -ClassName Win32_OperatingSystem).Caption" ^| findstr /i /c:"pro" /c:"professional"') do set "content=%%a"
    call :trim content "!content!"
    if "!content!" NEQ "" set "%~1=0"
)
goto :eof

@REM ============================================================================
@REM Enable silent RunAs policy when possible
@REM Purpose:    Enable silent RunAs policy when possible
@REM Parameters: <result>
@REM ============================================================================
:enableSilentRunAs <result>
set "%~1=1"

call :isHomeEdition edition
if "!edition!" == "0" goto :eof

set "packagesFile=!temp!\grouppolicypackages.txt"

@REM Find Group Policy package files
dir /b "C:\Windows\servicing\Packages\Microsoft-Windows-GroupPolicy-ClientExtensions-Package~3*.mum" > "!packagesFile!"
dir /b "C:\Windows\servicing\Packages\Microsoft-Windows-GroupPolicy-ClientTools-Package~3*.mum" >> "!packagesFile!"

@REM Install the package files
for /f %%i in ('findstr /i . "!packagesFile!" 2^>nul') do dism /online /norestart /add-package:"C:\Windows\servicing\Packages\%%i" >nul 2>nul
if "!errorlevel!" NEQ "0" set "%~1=0"

del /f /q "!packagesFile!" >nul 2>nul
goto :eof

@REM ============================================================================
@REM Disable UAC prompts for administrator elevation
@REM Purpose:    Disable UAC prompts for administrator elevation
@REM Parameters: <result>
@REM ============================================================================
:enableNoPromptRunAs <result>
set "%~1=0"

@REM Registry path and key
set "groupPolicyRegPath=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
set "groupPolicyRunAsKey=ConsentPromptBehaviorAdmin"

call :queryRegistry code "!groupPolicyRegPath!" "!groupPolicyRunAsKey!" "REG_DWORD"
if "!code!" == "0x0" (
    set "%~1=1"
    exit /b
)

call :enableSilentRunAs enable
if "!enable!" == "0" goto :eof

@REM Update the registry value
reg delete "!groupPolicyRegPath!" /v ConsentPromptBehaviorAdmin /f >nul 2>nul
reg add "!groupPolicyRegPath!" /v ConsentPromptBehaviorAdmin /t REG_DWORD /d 0 /f >nul 2>nul
if "!errorlevel!" == "0" set "%~1=1"
goto :eof

@REM ============================================================================
@REM Remove proxy settings and generated integration
@REM Purpose:    Remove proxy settings and generated integration
@REM ============================================================================
:purge
set "tips=[%ESC%[!warnColor!m警告%ESC%[0m] 即将关闭系统代理并禁用开机自启，是否继续？(%ESC%[!warnColor!mY%ESC%[0m/%ESC%[!warnColor!mN%ESC%[0m) "
if "!msTerminal!" == "1" (
    choice /t 6 /d n /n /m "!tips!"
) else (
    set /p "=!tips!" <nul
    choice /t 6 /d n /n
)
if !errorlevel! == 2 exit /b 1

@REM Disable the system proxy
call :disableSystemProxy

@REM Disable startup at user login
call :disableAutostart success
if "!success!" == "0" (
    @echo [%ESC%[91m错误%ESC%[0m] 开机自启%ESC%[91m禁用失败%ESC%[0m，可在%ESC%[!warnColor!m任务管理中心%ESC%[0m手动设置
)

@REM Delete the scheduled update task
call :deleteScheduledTask success "ClashUpdater"
if "!success!" == "0" (
    @echo [%ESC%[91m错误%ESC%[0m] 自动检查跟新取消%ESC%[91m失败%ESC%[0m，可在%ESC%[!warnColor!m任务计划程序%ESC%[0m中手动删除
)

@REM Stop the proxy process
call :killProcessWrapper

@REM Remove the desktop shortcut
call :deleteDesktopShortcut

@echo [%ESC%[!infoColor!m信息%ESC%[0m] 清理%ESC%[!infoColor!m完毕%ESC%[0m, bye~
goto :eof

@REM ============================================================================
@REM Read a registry value
@REM Purpose:    Read a registry value
@REM Parameters: <result>, <path>, <key>, <type>
@REM Returns:    Sets <result> with the computed value or status
@REM ============================================================================
:queryRegistry <result> <path> <key> <type>
set "%~1="
set "value="

@REM Registry path
call :trim registryPath "%~2"
if "!registryPath!" == "" goto :eof

@REM Registry key
call :trim registryKey "%~3"
if "!registryKey!" == "" goto :eof

@REM Registry value type
call :trim registryType "%~4"
if "!registryType!" == "" set "registryType=REG_SZ"

@REM Query the current value
reg query "!registryPath!" /V "!registryKey!" >nul 2>nul
if "!errorlevel!" NEQ "0" goto :eof

for /f "tokens=3" %%a in ('reg query "!registryPath!" /V "!registryKey!" ^| findstr /r /i "!registryType!"') do set "value=%%a"
call :trim value "!value!"
set "%~1=!value!"
goto :eof

@REM ============================================================================
@REM Download the application icon
@REM Purpose:    Download the application icon
@REM Parameters: <result>, <iconName>
@REM Returns:    Sets <result> with the computed value or status
@REM ============================================================================
:downloadIcon <result> <iconName>
set "%~1=0"

call :trim iconName "%~2"
if "!iconName!" == "" goto :eof

set "iconUrl=https://raw.githubusercontent.com/wzdnzd/batches/main/icons/clash.ico"
set "iconTempFile=!temp!\!iconName!"
if exist "!iconTempFile!" del /f /q "!iconTempFile!" >nul 2>nul
call :retryDownload "!iconUrl!" "!iconTempFile!"

if exist "!iconTempFile!" (
    move /y "!iconTempFile!" "!dest!\!iconName!" >nul 2>nul
    if exist "!dest!\!iconName!" set "%~1=1"
)
goto :eof

@REM ============================================================================
@REM Create a Windows shortcut
@REM Purpose:    Create a Windows shortcut
@REM Parameters: <result>, <linkDest>, <target>, <iconName>
@REM Returns:    Sets <result> with the computed value or status
@REM ============================================================================
:createShortcut <result> <linkDest> <target> <iconName>
set "%~1=0"
call :trim linkDest "%~2"
call :trim target "%~3"
call :trim iconName "%~4"


if "!linkDest!" == "" goto :eof
if "!target!" == "" goto :eof
if "!iconName!" == "" set "iconName=clash.ico"
if exist "!linkDest!" del /f /q "!linkDest!" >nul

set "vbsPath=!temp!\createshortcut.vbs"
((
    @echo set ows = WScript.CreateObject^("WScript.Shell"^)
    @echo slinkfile = ows.ExpandEnvironmentStrings^("!linkDest!"^)
    @echo set olink = ows.CreateShortcut^(slinkfile^)
    @echo olink.TargetPath = ows.ExpandEnvironmentStrings^("!target!"^)
    @echo olink.IconLocation = ows.ExpandEnvironmentStrings^("!dest!\!iconName!"^)
    @echo olink.WorkingDirectory = ows.ExpandEnvironmentStrings^("!dest!"^)
    @echo olink.Save
) 1>!vbsPath!

cscript //nologo "!vbsPath!"
if "!errorlevel!" == "0" set "%~1=1"

del /f /q "!vbsPath!"
) >nul
goto :eof

@REM ============================================================================
@REM Create the desktop shortcut
@REM Purpose:    Create the desktop shortcut
@REM ============================================================================
:createDesktopShortcut
if "!enableShortcut!" == "0" goto :eof

set "iconName=clash.ico"
set "linkDest=!HOMEDRIVE!!HOMEPATH!\Desktop\Clash.lnk"

set "exePath="
@REM Parse the existing shortcut target
if exist "!linkDest!" (
    set "shortcutPath=!linkDest!"
    for /f "usebackq delims=" %%a in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$shortcut=(New-Object -ComObject WScript.Shell).CreateShortcut($env:shortcutPath); $shortcut.TargetPath"`) do set "exePath=%%a"
    set "shortcutPath="
)

call :trim exePath "!exePath!"
if "!exePath!" == "!startupVbs!" goto :eof

set "tips=[%ESC%[!warnColor!m提示%ESC%[0m] 是否添加桌面快捷方式？(%ESC%[!warnColor!mY%ESC%[0m/%ESC%[!warnColor!mN%ESC%[0m) "
if "!msTerminal!" == "1" (
    choice /t 5 /d y /n /m "!tips!"
) else (
    set /p "=!tips!" <nul
    choice /t 5 /d y /n
)
if !errorlevel! == 2 goto :eof

if not exist "!dest!\!iconName!" (
    call :downloadIcon finished "!iconName!"
    if "!finished!" == "0" (
        @echo [%ESC%[91m错误%ESC%[0m] 应用图标文件下载%ESC%[91m失败%ESC%[0m，无法创建桌面快捷方式
        goto :eof
    )
)

call :createShortcut finished "!linkDest!" "!startupVbs!" "!iconName!"
if "!finished!" == "0" (
    @echo [%ESC%[91m错误%ESC%[0m] 桌面快捷方式添加%ESC%[91m失败%ESC%[0m，如有需要，请自行创建
) else (
    @echo [%ESC%[!infoColor!m信息%ESC%[0m] 桌面快捷方式添加%ESC%[!infoColor!m成功%ESC%[0m
)
goto :eof

@REM ============================================================================
@REM Delete the desktop shortcut
@REM Purpose:    Delete the desktop shortcut
@REM ============================================================================
:deleteDesktopShortcut
set "linkPath=!HOMEDRIVE!!HOMEPATH!\Desktop\Clash.lnk"
del /f /q "!linkPath!" >nul 2>nul
goto :eof

@REM ============================================================================
@REM Detect whether the script runs in Windows Terminal
@REM Purpose:    Detect whether the script runs in Windows Terminal
@REM Parameters: <result>
@REM ============================================================================
:isMicrosoftTerminal <result>
set "%~1=0"

call :getTerminalName output 3
call :trim output "!output!"

set "retry=0"
if /i "!output!" == "powershell" set "retry=1"
if /i "!output!" == "pwsh" set "retry=1"

if "!retry!" == "1" (
    call :getTerminalName output 4
    call :trim output "!output!"
)

if /i "!output!" == "WindowsTerminal" (
    set "%~1=1"
    goto :eof
)
goto :eof

@REM ============================================================================
@REM Get the current terminal process name
@REM Purpose:    Get the current terminal process name
@REM Parameters: <result>, <num>
@REM Returns:    Sets <result> with the computed value or status
@REM ============================================================================
:getTerminalName <result> <num>
set "%~1="
call :trim num "%~2"
if "!num!" == "" set "num=3"

@REM Set "psCommand=$current = Get-CimInstance -ClassName win32_process -filter ('ProcessID='+$pid); $parent = Get-Process -id ($current.parentprocessID); if ($parent.ProcessName -eq 'WindowsTerminal') {echo 'true';} else {$cimgrandparent = Get-CimInstance -ClassName win32_process -filter ('Processid='+($($parent.id))); $grandparent = Get-Process -id ($cimgrandparent.parentProcessId); if (($grandparent.processname) -eq 'WindowsTerminal') {echo 'true';} else {echo 'false';}}"

@REM Reference: https://stackoverflow.com/questions/53447286/in-a-cmd-batch-file-can-i-determine-if-it-was-run-from-powershell
set "psCommand=$ppid=$pid;while($i++ -lt !num! -and ($ppid=(Get-CimInstance Win32_Process -Filter ('ProcessID='+$ppid)).ParentProcessId)) {}; (Get-Process -EA Ignore -ID $ppid).Name"

for /f "tokens=*" %%a in ('powershell -noprofile -command "!psCommand!"') do set "%~1=%%a"
goto :eof


endlocal
