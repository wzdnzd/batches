@REM ============================================================================
@REM Clash / Mihomo Network Proxy Controller
@REM ============================================================================
@REM Description: Comprehensive management tool for Clash.Meta and Mihomo proxy
@REM              service on Windows. Supports installation, configuration,
@REM              updates, dashboard management, startup tasks, and maintenance.
@REM Author:      wzdnzd
@REM Date:        2022-08-24
@REM Repository:  https://github.com/wzdnzd/batches
@REM ============================================================================

@echo off & PUSHD %~DP0 & cd /d "%~dp0"

@REM Use UTF-8 so Chinese messages and symbols render correctly
chcp 65001 >nul 2>nul

@REM https://blog.csdn.net/sanqima/article/details/37818115
setlocal enableDelayedExpansion

@REM Initialize ANSI color support for console output
call :setEsc

@REM Start main workflow
goto :mainWorkflow


@REM ============================================================================
@REM FUNCTION DEFINITIONS
@REM ============================================================================

@REM ============================================================================
@REM MAIN WORKFLOW - Parse options and dispatch the requested operation
@REM ============================================================================
:mainWorkflow
@REM batch file name
set "batchName=%~nx0"

@REM microsoft terminal displays differently from cmd and powershell
@REM call :isMicrosoftTerminal msTerminal
set "msTerminal=1"

@REM enable create shortcut 
set "enableShortcut=1"

@REM enable download config from remote
set "enableRemoteConfig=1"
set "remoteConfigUrl="

@REM validate configuration files before starting
set "verifyConfig=0"

@REM check and update wintun.dll
set "checkWintun=0"

@REM info color
set "infoColor=92"
set "warnColor=93"

if "!msTerminal!" == "1" (
    set "infoColor=95"
    set "warnColor=97"
)

@REM print heart
set "customize=0"
set "drawHeart=0"

@REM exit flag
set "shouldExit=0"

@REM init
set "initFlag=0"

@REM configuration file name
set "configuration=config.yaml"

@REM subscription link
set "subscriptionLink="
set "isWebLink=0"

@REM check
set "testFlag=0"

@REM repairFlag
set "repairFlag=0"

@REM only reload
set "reloadOnly=0"

@REM restart clash.exe
set "restartFlag=0"

@REM close proxy
set "killFlag=0"

@REM update
set "updateFlag=0"

@REM purge
set "purgeFlag=0"

@REM only update subscriptions and rulesets
set "quickFlag=0"

@REM don't update subscription
set "excludeUpdates=0"

@REM use clash.meta
set "useClashMeta=0"

@REM use clash.premium
set "useClashPremium=0"

@REM use vernesong/mihomo smart group core
set "useVerneMihomo=0"

@REM core edition explicitly specified by arguments
set "coreForced=0"

@REM LightGBM model
set "lgbmUrl="
set "lgbmFile=Model.bin"

@REM alpha version allowed
set "alpha=0"

@REM simplified mode
set "brief=0"

@REM regenerates auto update script
set "regenerate=0"

@REM yacd dashboard, see https://github.com/MetaCubeX/Yacd-meta or https://github.com/haishanh/yacd
set "yacd=0"

@REM metacubexd, see https://github.com/MetaCubeX/metacubexd
set "metacubexd=0"

@REM zashboard, see https://github.com/Zephyruso/zashboard
set "zashboard=0"

@REM dashboard explicitly specified by arguments
set "dashboardForced=0"

@REM run on background
set "asDaemon=0"

@REM showWindow window
set "showWindow=0"

@REM setting workspace
set "dest="

@REM network proxy registry configuration path
set "proxyRegPath=HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings"

@REM autostart registry configuration path
set "autostartRegPath=HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
set "startupApprovedRegPath=HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"

@REM parse arguments
call :parseArgs %*

@REM invalid arguments
if "!shouldExit!" == "1" exit /b 1

@REM regular file path
if "!dest!" == "" set "dest=%~dp0"
call :normalizePath dest "!dest!"

@REM auto start vb script
set "startupVbs=!dest!\startup.vbs"

@REM auto update vb script
set "updateVbs=!dest!\update.vbs"

@REM draw a heart
if "!drawHeart!"== "1" goto :printHeart

@REM close network proxy
if "!killFlag!" == "1" goto :closeProxy

@REM clean all setting
if "!purgeFlag!" == "1" goto :purge

@REM prevent configuration validation when no action was requested
if "!reloadOnly!" == "0" if "!restartFlag!" == "0" if "!repairFlag!" == "0" if "!testFlag!" == "0" if "!updateFlag!" == "0" if "!initFlag!" == "0" (
    @REM @echo [%ESC%[91m错误%ESC%[0m] 必须包含 [%ESC%[!warnColor!m-f%ESC%[0m %ESC%[!warnColor!m-i%ESC%[0m %ESC%[!warnColor!m-k%ESC%[0m %ESC%[!warnColor!m-r%ESC%[0m %ESC%[!warnColor!m-t%ESC%[0m %ESC%[!warnColor!m-u%ESC%[0m] 中的一种操作
    @REM @echo.

    if "!shouldExit!" == "0" goto :usage
    exit /b
)

@REM config file path
call :validateConfiguration configFile
if "!configFile!" == "" exit /b 1

@REM connectivity test
if "!testFlag!" == "1" (
    call :testConnection available 1
    exit /b
)

@REM reload config
if "!reloadOnly!" == "1" goto :reloadConfig

@REM update
if "!restartFlag!" == "1" goto :restartProgram

@REM check issues
if "!repairFlag!" == "1" goto :resolveIssues

@REM update
if "!updateFlag!" == "1" goto :updateComponents

@REM init
if "!initFlag!" == "1" goto :initialize

@REM unknown command
@REM if "!shouldExit!" == "0" goto :usage

exit /b


@REM ============================================================================
@REM Validate and process the Clash configuration file
@REM Parameters: <result> - Return variable for the validated config file path
@REM Purpose:    Accepts a local YAML file or downloads a subscription URL
@REM ============================================================================
:validateConfiguration <result>
set "%~1="
set "subscriptionFile=!temp!\clashsub.yaml"

@REM absolute path
call :convertToAbsolutePath configLocation "!configuration!"
call :normalizePath configLocation "!configLocation!"

if "!configLocation!" == "" (
    @echo [%ESC%[91m错误%ESC%[0m] 配置文件路径%ESC%[91m无效%ESC%[0m
    exit /b 1
)

@REM cannot contain whitespace in path
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

    @REM try to download
    del /f /q "!subscriptionFile!" >nul 2>nul

    set "statusCode=000"
    for /f %%a in ('curl --retry 3 --retry-max-time 30 -m 60 --connect-timeout 30 -L -s -o "!subscriptionFile!" -w "%%{http_code}" -H "User-Agent: Clash" "!subscriptionLink!"') do set "statusCode=%%a"

    @REM download success
    if "!statusCode!" == "200" (
        set "fileSize=0"
        if exist "!subscriptionFile!" (for %%a in ("!subscriptionFile!") do set "fileSize=%%~za")
        if !fileSize! GTR 64 (
            @REM validate
            set "content="
            for /f "tokens=*" %%a in ('findstr /i /r /c:"^external-controller:[ ][ ]*.*:[0-9][0-9]*.*" !subscriptionFile!') do set "content=%%a"
            if "!content!" == "" (
                @echo [%ESC%[91m错误%ESC%[0m] 订阅 "%ESC%[!warnColor!m!subscriptionLink!%ESC%[0m" 无效，请检查确认
                exit /b 1
            )

            del /f /q "!configLocation!" >nul 2>nul
            call :splitPath filepath filename "!configLocation!"
            call :createDirectories success "!filepath!"
            if "!success!" == "0" (
                @echo [%ESC%[91m错误%ESC%[0m] 创建文件夹 "%ESC%[!warnColor!m!filepath!%ESC%[0m" %ESC%[91m失败%ESC%[0m，请确认路径是否合法 
                exit /b 1
            )

            move "!subscriptionFile!" "!configLocation!" >nul 2>nul
            @echo [%ESC%[!infoColor!m信息%ESC%[0m] 订阅下载%ESC%[!infoColor!m成功%ESC%[0m

            @REM 保存订阅链接
            @echo !subscriptionLink! > "!filepath!\subscriptions.txt"
        ) else (
            @REM output is empty
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

@REM validate
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
@REM Purpose:    First-time setup that downloads required components and starts Clash
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
@REM Diagnose and repair network proxy issues
@REM Purpose:    Offers reload, restart, or restore actions and verifies connectivity
@REM ============================================================================
:resolveIssues
@REM mandatory use of the stable version
set "alpha=0"

@echo [%ESC%[!infoColor!m信息%ESC%[0m] 开始检查并尝试修复网络代理，请稍等

@REM check status
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
    @REM running detect
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
    @REM kill clash process
    call :killProcessWrapper

    @REM lazy check
    if "!lazyCheck!" == "1" (
        call :checkNetworkWrapper continue 0
        if "!continue!" == "0" exit /b
    )

    @REM restore plugins
    call :updateComponents
) else (
    :: cancel
    exit /b
)

for /l %%i in (1,1,5) do (
    @REM recheck
    call :testConnection available 0
    if "!available!" == "1" (
        @echo [%ESC%[!infoColor!m信息%ESC%[0m] 问题修复%ESC%[!infoColor!m成功%ESC%[0m，网络代理可%ESC%[!infoColor!m正常%ESC%[0m使用
        exit /b
    ) else (
        @REM wait
        timeout /t 1 /nobreak >nul 2>nul
    )
)

@echo [%ESC%[91m错误%ESC%[0m] 问题修复%ESC%[91m失败%ESC%[0m， 网络代理仍%ESC%[91m无法%ESC%[0m使用， 请尝试其他方法
goto :eof


@REM check if the network is available
:checkNetworkWrapper <result> <enable>
set "%~1=1"
call :trim logLevel "%~2"
if "!logLevel!" == "" set "logLevel=1"

call :checkNetworkAvailable available 0 "https://www.baidu.com" ""
if "!available!" == "0" (
    @echo [%ESC%[91m错误%ESC%[0m] 网络%ESC%[91m不可用%ESC%[0m， 但代理程序%ESC%[91m并未运行%ESC%[0m，请检查你的%ESC%[!warnColor!m本地网络%ESC%[0m是否正常

    @REM should terminate
    set "%~1=0"
    exit /b
)

if "!logLevel!" == "1" (
    @echo [%ESC%[!warnColor!m提示%ESC%[0m] 网络代理%ESC%[91m没有开启%ESC%[0m， 推荐选择 %ESC%[!warnColor!mRestart%ESC%[0m 开启
)
goto :eof


@REM ============================================================================
@REM Update all Clash components
@REM Purpose:    Updates core, subscriptions, rules, geodata, dashboard, and starts Clash
@REM ============================================================================
:updateComponents
set "downloadedAlready=0"

if "!quickFlag!" == "1" (
    call :quickUpdate modified
    if "!modified!" == "0" (exit /b 0) else (set "downloadedAlready=1")
)

@REM run as admin
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

@REM prepare all plugins
call :prepareComponents changed 1 !downloadedAlready!

@REM no new version found
if "!changed!" == "0" (
    @echo [%ESC%[!infoColor!m信息%ESC%[0m] 当前已是最新版本，无需更新
) else (
    @REM wait for overwrite files
    timeout /t 1 /nobreak >nul 2>nul
)

@REM postclean
call :cleanWorkspace "!temp!"

@REM startup
call :startClash

@REM regenerate auto update script
if "!regenerate!" == "1" call :generateUpdateVbs

goto :eof


@REM ============================================================================
@REM Parse and validate command line arguments
@REM Purpose:    Sets operation flags and option values from user arguments
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
    @REM validate argument
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

        @REM include '"' see https://stackoverflow.com/questions/46238709/how-to-detect-if-input-is-quote
        @REM @echo !subscription! | findstr /i /r /c:"\"^" >nul && (set "invalid=1")

        @REM replace '"' to ''
        set "subscription=!subscription:"=!"

        @REM contain whitespace
        if "!subscription!" neq "!subscription: =!" set "invalid=1"
        @REM match url
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
    @REM vernesong/mihomo still uses the mihomo download and geodata branch
    set "useClashMeta=1"
    set "useClashPremium=0"
    set "coreForced=1"
    set result=false
    shift & goto :parseArgs
)

if "%1" == "-w" set result=true
if "%1" == "--workspace" set result=true
if "!result!" == "true" (
    @REM validate argument
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
    set "metacubexd=1"
    set "dashboardForced=1"
    set "yacd=0"
    set "zashboard=0"
    set result=false
    shift & goto :parseArgs
)

if "%1" == "-y" set result=true
if "%1" == "--yacd" set result=true
if "!result!" == "true" (
    set "metacubexd=0"
    set "yacd=1"
    set "dashboardForced=1"
    set "zashboard=0"
    set result=false
    shift & goto :parseArgs
)

if "%1" == "-z" set result=true
if "%1" == "--zashboard" set result=true
if "!result!" == "true" (
    set "metacubexd=0"
    set "yacd=0"
    set "zashboard=1"
    set "dashboardForced=1"
    set result=false
    shift & goto :parseArgs
)

@REM will throw exception if this code not in here or delete it or merge with <if "%1" NEQ "">. why?
if "%1" == "" goto :eof

if "%1" NEQ "" (
    call :trim syntax "%~1"
    if "!syntax!" == "goto" (
        call :trim funcname "%~2"
        if "!funcname!" == "" (
            @echo [%ESC%[91m错误%ESC%[0m] 无效的语法，调用 "%ESC%[!warnColor!mgoto%ESC%[0m" 时必须提供函数名
            goto :usage
        )

        for /f "tokens=1-2,* delims= " %%a in ("%*") do set "params=%%c"
        if "!params!" == "" (
            call !funcname!
            exit /b
        ) else (
            call !funcname! !params!
            exit /b
        )
    )

    @echo [%ESC%[91m错误%ESC%[0m] 未知参数：%ESC%[91m%1%ESC%[0m
    @echo.
    goto :usage
)

goto :eof


@REM help
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
set "usageLine=-u, --update          更有所有组件，包括 clash.exe、订阅、代理规则以及 IP 地址数据库等"
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
set "usageLine=-m, --meta            如果配置兼容，使用 clash.meta 代替 clash.premium，搭配 %ESC%[!warnColor!m-i%ESC%[0m 或 %ESC%[!warnColor!m-u%ESC%[0m 使用"
@echo(!usageLine!
set "usageLine=-n, --native          使用 clash.premium，搭配 %ESC%[!warnColor!m-i%ESC%[0m 或 %ESC%[!warnColor!m-u%ESC%[0m 使用"
@echo(!usageLine!
set "usageLine=-q, --quick           仅更新新订阅和代理规则，搭配 %ESC%[!warnColor!m-u%ESC%[0m 使用"
@echo(!usageLine!
set "usageLine=-s, --show            新窗口中执行，默认为当前窗口"
@echo(!usageLine!
set "usageLine=-v, --verne           使用 vernesong/mihomo 内核，搭配 %ESC%[!warnColor!m-i%ESC%[0m 或 %ESC%[!warnColor!m-u%ESC%[0m 使用"
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

@REM draw heart
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


@REM confirm download url and filename according parameters
:detectRequiredEdition <geosite> <subscriptionFiles>
set "%~1=0"
set "content="
set "needGeoSite=0"

@REM yacd dashboard
if "!metacubexd!" == "0" if "!zashboard!" == "0" if "!dashboard!" NEQ "" if exist "!dashboard!\yacd.ico" set "yacd=1"

@REM metacubexd dashboard
if "!yacd!" == "0" if "!zashboard!" == "0" if "!dashboard!" NEQ "" if exist "!dashboard!\maskable-icon-512x512.png" set "metacubexd=1"

@REM zashboard dashboard
if "!yacd!" == "0" if "!metacubexd!" == "0" if "!dashboard!" NEQ "" if exist "!dashboard!\pwa-maskable-512x512.png" set "zashboard=1"

@REM force use clash.premium
if "!useClashPremium!" == "1" (
    set "useVerneMihomo=0"
    set "lgbmUrl="
    set "useClashMeta=0"
    goto :eof
)

if "!coreForced!" == "0" (
    set "useVerneMihomo=0"
    call :detectSmartGroup smartgroup
    if "!smartgroup!" == "1" (
        set "useVerneMihomo=1"
        set "useClashMeta=1"
        set "useClashPremium=0"
    )
)

set "lgbmUrl="
if "!useVerneMihomo!" == "1" (
    set "useClashMeta=1"
    set "useClashPremium=0"

    call :parseYamlValue uselightgbm "uselightgbm:[ ][ ]*true"
    if /i "!uselightgbm:~0,4!" == "true" (
        call :parseYamlValue lgbmUrl "lgbm-url:.*http.*://"
        if "!lgbmUrl!" == "" set "lgbmUrl=https://github.com/vernesong/mihomo/releases/download/LightGBM-Model/Model.bin"
    )
)

for /f "tokens=*" %%i in ('findstr /i /r "GEOSITE,.*" "!configFile!"') do set "content=!content!;%%i"
call :searchRules notFound "!content!"

if "!notFound!" == "1" (
    for /f "tokens=*" %%i in ('findstr /i /r "SUB-RULE,.* AND,.* OR,.* NOT,.* IN-TYPE,.*" "!configFile!"') do set "content=!content!;%%i"
    call :searchRules notFound "!content!"
) else (
    set "needGeoSite=1"
)

@REM rulesets include GEOSITE, must be clash.meta
if "!notFound!" == "0" (set "useClashMeta=1")
if "!useClashMeta!" == "1" (
    set "%~1=!needGeoSite!"
    set "useClashPremium=0"
    goto :eof
)

@REM rules include IP-ASN/SRC-IP-ASN, must be clash.meta
call :detectAsnRules needgeoasn
if "!needgeoasn!" == "1" (
    set "useClashMeta=1"
    set "useClashPremium=0"
    set "%~1=!needGeoSite!"
    goto :eof
)

@REM clash.meta not support SCRIPT rule
set "content="
for /f "tokens=*" %%i in ('findstr /i /r "SCRIPT,.*" "!configFile!"') do set "content=!content!;%%i"
call :searchRules notFound "!content!"

@REM rulesets include SCRIPT, must be clash.premium
if "!notFound!" == "0" (
    set "useClashMeta=0"
    set "useClashPremium=1"
    goto :eof
)

@REM include sniffer, must be clash.meta
for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"sniffer:[ ]*" "!configFile!"') do (
    call :trim sniffer %%a
    if "!sniffer!" == "sniffer" (
        set "useClashMeta=1"
        set "useClashPremium=0"
        goto :eof
    )
)

@REM proxy-groups include exclude-filter, must be clash.meta
for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"^[ ][ ]*exclude-filter:[ ][ ]*.*" "!configFile!"') do (
    call :trim excludekey %%a

    if /i "!excludekey:~0,1!" NEQ "#" (
        set "useClashMeta=1"
        set "useClashPremium=0"
        goto :eof
    )
)

@REM include vless or hysteria, must be clash.meta
call :trim subscriptionFiles "%~2"

set "subscriptionFiles=!configFile!,!subscriptionFiles!"
set "tempFile=!temp!\clashproxies.txt"
set "regex=^\s+(type:\s+(vless|hysteria)|client-fingerprint:\s+|flow:\s+xtls-).*"

del /f /q "!tempFile!" >nul 2>nul
for %%f in (!subscriptionFiles!) do (
    if "%%f" NEQ "" if exist %%f (
        call :findByContext "%%f" "!regex!" "!tempFile!" 1
        if exist "!tempFile!" (
            set "useClashMeta=1"
            set "useClashPremium=0"
            del /f /q "!tempFile!" >nul 2>nul
            goto :eof
        )   
    )
)

@REM proxy-groups include filter, must be clash.meta
@REM set "tempFile=!temp!\clashproxygroups.txt"
@REM set "regex=^\s+type:\s+(select|url-test|fallback|load-balance|relay).*"

@REM del /f /q "!tempFile!" >nul 2>nul
@REM call :findByContext "!configFile!" "!regex!" "!tempFile!" 10
@REM if exist "!tempFile!" (
@REM     for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"^[ ][ ]*filter:[ ][ ]*.*" "!tempFile!"') do (
@REM         call :trim includeKey %%a
@REM         if /i "!includeKey:~0,1!" NEQ "#" (
@REM             set "useClashMeta=1"
@REM             set "useClashPremium=0"
@REM             del /f /q "!tempFile!" >nul 2>nul
@REM             goto :eof
@REM         )
@REM     )

@REM     del /f /q "!tempFile!" >nul 2>nul
@REM )

@REM old edittion
if exist "!dest!\clash.exe" ("!dest!\clash.exe" -v | findstr /i "Meta" >nul 2>nul && (
        set "useClashMeta=1"
        set "useClashPremium=0"
    )
)
goto :eof


@REM detect smart proxy group in proxy-groups section
:detectSmartGroup <result>
set "%~1=0"
if not exist "!configFile!" goto :eof

set "insideProxyGroups=0"
for /f "usebackq delims=" %%l in ("!configFile!") do (
    set "line=%%l"
    call :trim configLine "!line!"

    if "!configLine!" NEQ "" if "!configLine:~0,1!" NEQ "#" (
        if /i "!configLine:~0,13!" == "proxy-groups:" (
            set "insideProxyGroups=1"
        ) else if "!insideProxyGroups!" == "1" (
            set "firstChar=!line:~0,1!"
            if "!firstChar!" NEQ " " if "!firstChar!" NEQ "-" if /i "!configLine:~0,5!" NEQ "type:" set "insideProxyGroups=0"

            if "!insideProxyGroups!" == "1" if /i "!configLine!" == "type: smart" (
                set "%~1=1"
                goto :eof
            )
        )
    )
)
goto :eof


@REM detect IP-ASN/SRC-IP-ASN rules in rules section
:detectAsnRules <result>
set "%~1=0"
if not exist "!configFile!" goto :eof

set "insideRules=0"
for /f "usebackq delims=" %%l in ("!configFile!") do (
    set "line=%%l"
    call :trim configLine "!line!"

    if "!configLine!" NEQ "" if "!configLine:~0,1!" NEQ "#" (
        if /i "!configLine!" == "rules:" (
            set "insideRules=1"
        ) else if "!insideRules!" == "1" (
            set "firstChar=!line:~0,1!"
            if "!firstChar!" NEQ " " if "!firstChar!" NEQ "-" set "insideRules=0"

            if "!insideRules!" == "1" (
                if /i "!configLine:~0,9!" == "- IP-ASN," (
                    set "%~1=1"
                    goto :eof
                )

                if /i "!configLine:~0,13!" == "- SRC-IP-ASN," (
                    set "%~1=1"
                    goto :eof
                )
            )
        )
    )
)
goto :eof


@REM detect smart proxy group with prefer-asn: true
:detectSmartPreferAsn <result>
set "%~1=0"
if not exist "!configFile!" goto :eof

set "insideProxyGroups=0"
set "groupIsSmart=0"
set "groupPreferAsn=0"
for /f "usebackq delims=" %%l in ("!configFile!") do (
    set "line=%%l"
    call :trim configLine "!line!"

    if "!configLine!" NEQ "" if "!configLine:~0,1!" NEQ "#" (
        if /i "!configLine:~0,13!" == "proxy-groups:" (
            set "insideProxyGroups=1"
            set "groupIsSmart=0"
            set "groupPreferAsn=0"
        ) else if "!insideProxyGroups!" == "1" (
            set "firstChar=!line:~0,1!"
            if "!firstChar!" NEQ " " if "!firstChar!" NEQ "-" if /i "!configLine:~0,5!" NEQ "type:" (
                if "!groupIsSmart!" == "1" if "!groupPreferAsn!" == "1" (
                    set "%~1=1"
                    goto :eof
                )
                set "insideProxyGroups=0"
            )

            if "!insideProxyGroups!" == "1" (
                if /i "!configLine:~0,2!" == "- " (
                    if "!groupIsSmart!" == "1" if "!groupPreferAsn!" == "1" (
                        set "%~1=1"
                        goto :eof
                    )

                    set "groupIsSmart=0"
                    set "groupPreferAsn=0"
                )

                if /i "!configLine!" == "type: smart" set "groupIsSmart=1"
                if /i "!configLine!" == "prefer-asn: true" set "groupPreferAsn=1"
            )
        )
    )
)

if "!groupIsSmart!" == "1" if "!groupPreferAsn!" == "1" set "%~1=1"
goto :eof


@REM detect whether ASN database is needed
:detectAsnNeeded <result>
set "%~1=0"

call :detectAsnRules asnrules
if "!asnrules!" == "1" (
    set "%~1=1"
    goto :eof
)

if "!useVerneMihomo!" == "1" (
    call :detectSmartPreferAsn smartasn
    if "!smartasn!" == "1" set "%~1=1"
)
goto :eof


@REM quickly update subscriptions and rulesets
:quickUpdate <edition>
set "%~1=0"

@REM configration
call :updateConfig 1

@REM subscriptions
if "!excludeUpdates!" == "0" call :updateSubscriptions subscriptionFiles 1

@REM rulesets
call :updateRules 1

@REM detect new edition
set "clashEdition=0"
if exist "!dest!\clash.exe" (
    "!dest!\clash.exe" -v | findstr /i "Meta" >nul 2>nul && (set "clashEdition=1")
    "!dest!\clash.exe" -v | findstr /i "smart" >nul 2>nul && (set "clashEdition=2")
)
call :detectRequiredEdition geoSiteNeeded !subscriptionFiles!

set "targetEdition=0"
if "!useClashMeta!" == "1" set "targetEdition=1"
if "!useVerneMihomo!" == "1" set "targetEdition=2"

if "!clashEdition!" NEQ "!targetEdition!" (
    set "%~1=1"
    set "oldEdition=clash.premium"
    if "!clashEdition!" == "1" set "oldEdition=clash.meta"
    if "!clashEdition!" == "2" set "oldEdition=vernesong/mihomo"

    set "newEdition=clash.premium"
    if "!targetEdition!" == "1" set "newEdition=clash.meta"
    if "!targetEdition!" == "2" set "newEdition=vernesong/mihomo"

    @echo [%ESC%[!warnColor!m提示%ESC%[0m] 配置%ESC%[91m不兼容%ESC%[0m，代理程序需从 %ESC%[!warnColor!m!oldEdition!%ESC%[0m 切换至 %ESC%[!warnColor!m!newEdition!%ESC%[0m
    goto :eof
)

@REM reload
if "!changed!" == "1" (goto :reloadConfig) else (goto :eof)


@REM check if special rules are included
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


@REM update subscriptions
:updateSubscriptions <subscriptionFiles> <force>
call :trim force "%~2"
if "!force!" == "" set "force=1"

if "!force!" == "1" (
    @echo [%ESC%[!infoColor!m信息%ESC%[0m] 检查并更新订阅，仅刷新 %ESC%[!warnColor!mHTTP%ESC%[0m 类型的订阅
)

call :refreshReferencedFiles changed "^\s+(health-check:(\s+)?|<<:\s+\*.*)$|^proxy-providers:(\s+)?$" "www.gstatic.com cp.cloudflare.com" "!force!" subscriptionFiles "proxies"
set "%~1=!subscriptionFiles!"
goto :eof


:splitPath <directory> <filename> <filepath>
set "%~1=%~dp3"
set "%~2=%~nx3"

if "!%~1:~-1!" == "\" set "%~1=!%~1:~0,-1!"
goto :eof


@REM to absolute path
:convertToAbsolutePath <result> <filename>
call :trim filepath %~2
set "%~1="

if "!filepath!" == "" goto :eof

@echo "!filepath!" | findstr ":" >nul 2>nul && (
    set "%~1=!filepath!"
    goto :eof
) || (
    if "!dest!" NEQ "" (set "baseDir=!dest!") else (set "baseDir=%~dp0")
    if "!baseDir:~-1!" == "\" set "baseDir=!baseDir:~0,-1!"
    
    if "!filepath!" == "." (
        set "%~1=!baseDir!"
        goto :eof
    )

    set "filepath=!filepath:/=\!"
    if "!filepath:~0,3!" == ".\\" (
        set "%~1=!baseDir!\!filepath:~3!"
    ) else if "!filepath:~0,2!" == ".\" (
        set "%~1=!baseDir!\!filepath:~2!"
    ) else (
        set "%~1=!baseDir!\!filepath!"
    )
)
goto :eof


@REM connectivity
:testConnection <result> <allowed>
@REM running status
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

@REM call :getSystemProxy server
call :generateSystemProxy server

@REM detect network is available
call :checkNetworkAvailable status "!output!" "https://www.google.com" "!server!"
set "%~1=!status!"
goto :eof


@REM check network
:checkNetworkAvailable <result> <allowed> <url> <proxyServer>
set "%~1=0"
call :trim output "%~2"
call :trim url "%~3"
call :trim proxyServer "%~4"

if "!output!" == "" set "output=1"
if "!url!" == "" set "url=https://www.google.com"

@REM check
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


@REM query proxy address
:generateSystemProxy <result>
set "%~1="

call :getSystemProxy server
if "!server!" NEQ "" (
    set "%~1=!server!"
    goto :eof
)

@REM extract from config file
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


@REM create if directory not exists
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


@REM tun enabled
:isTunEnabled <enabled>
set "%~1=0"
set "text="

@REM not work in batch but works fine in cmd, why?
@REM for /f "tokens=*" %%a in ('findstr /i /r /c:"^tun:[ ]*" "!configFile!"') do set "text=%%a"

for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"tun:[ ]*" "!configFile!"') do set "text=%%a"

@REM not required
call :trim text "!text!"
if "!text!" == "tun" set "%~1=1"
goto :eof


@REM wintun
:downloadWintun <changed> <force>
set "%~1=0"

call :trim force "%~2"
if "!force!" == "" set "force=0"

@REM has been integrated in clash.meta
if "!useClashMeta!" == "1" exit /b

@REM check if required
call :isTunEnabled enabled
if "!enabled!" == "0" exit /b

if "!force!" == "0" set "checkWintun=0"

@REM exists
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
    @REM unzip
    tar -xzf "!temp!\wintun.zip" -C !temp! >nul 2>nul

    @REM clean workspace
    del /f /q "!temp!\wintun.zip" >nul 2>nul

    set "wintunFile=!temp!\wintun\bin\!archVersion!\wintun.dll"
    if exist "!wintunFile!" (
        @REM compare and update
        call :compareMd5 diff "!wintunFile!" "!dest!\wintun.dll"
        if "!diff!" == "1" (
            set "%~1=1"

            @REM delete if exist
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


@REM download binary file and data
:downloadFiles <filenames> <outputEnabled>
set "%~1="
call :trim outputEnabled "%~2"
if "!outputEnabled!" == "" set "outputEnabled=1"

@REM deprecated and no longer needed, so set it to 0
set "outputEnabled=0"

if "!outputEnabled!" == "1" (
    @echo [%ESC%[!infoColor!m信息%ESC%[0m] 开始下载 clash.exe、域名及 IP 地址等数据
)

set "downloadedFileList="

@REM download clash
if "!clashUrl!" NEQ "" (
    if /i "!clashUrl:~0,8!" NEQ "https://" (
        @echo [%ESC%[91m错误%ESC%[0m] clash.exe 下载地址解析失败："!clashUrl!"
    ) else (
        @echo [%ESC%[!infoColor!m信息%ESC%[0m] 开始下载 %ESC%[!warnColor!mclash.exe%ESC%[0m 至 %ESC%[!warnColor!m!dest!%ESC%[0m

        call :retryDownload "!clashUrl!" "!temp!\clash.zip"
        if exist "!temp!\clash.zip" (
            @REM unzip
            tar -xzf "!temp!\clash.zip" -C !temp! >nul 2>nul

            @REM clean workspace
            del /f /q "!temp!\clash.zip"
        ) else (
            @echo [%ESC%[91m错误%ESC%[0m] clash.exe 下载失败，下载链接："!clashUrl!"
        )

        if exist "!temp!\!clashExe!" (
            @REM rename file
            ren "!temp!\!clashExe!" clash.exe

            set "downloadedFileList=clash.exe"
        ) else (
            @echo [%ESC%[91m错误%ESC%[0m] "!temp!\!clashExe!" 不存在，下载链接："!clashUrl!"
        )
    )
)

@REM download Country.mmdb
if "!countryUrl!" NEQ "" (
    @echo [%ESC%[!infoColor!m信息%ESC%[0m] 开始下载 %ESC%[!warnColor!m!countryFile!%ESC%[0m 至 %ESC%[!warnColor!m!dest!%ESC%[0m

    call :retryDownload "!countryUrl!" "!temp!\!countryFile!"
    if exist "!temp!\!countryFile!" (
        if "!downloadedFileList!" == "" (
            set "downloadedFileList=!countryFile!"
        ) else (
            set "downloadedFileList=!downloadedFileList!;!countryFile!"
        )
    ) else (
        @echo [%ESC%[91m错误%ESC%[0m] "!temp!\!countryFile!" 不存在，下载链接："!countryUrl!"
    )
)

@REM download GeoSite.dat
if "!geoSiteUrl!" NEQ "" (
    @echo [%ESC%[!infoColor!m信息%ESC%[0m] 开始下载 %ESC%[!warnColor!m!geoSiteFile!%ESC%[0m 至 %ESC%[!warnColor!m!dest!%ESC%[0m

    call :retryDownload "!geoSiteUrl!" "!temp!\!geoSiteFile!" 
    if exist "!temp!\!geoSiteFile!" (
        if "!downloadedFileList!" == "" (
            set "downloadedFileList=!geoSiteFile!"
        ) else (
            set "downloadedFileList=!downloadedFileList!;!geoSiteFile!"
        )
    ) else (
        @echo [%ESC%[91m错误%ESC%[0m] "!temp!\!geoSiteFile!" 不存在，下载链接："!geoSiteUrl!"
    )
)

@REM download ASN.mmdb
if "!geoAsnUrl!" NEQ "" (
    @echo [%ESC%[!infoColor!m信息%ESC%[0m] 开始下载 %ESC%[!warnColor!m!geoAsnFile!%ESC%[0m 至 %ESC%[!warnColor!m!dest!%ESC%[0m

    call :retryDownload "!geoAsnUrl!" "!temp!\!geoAsnFile!" 
    if exist "!temp!\!geoAsnFile!" (
        if "!downloadedFileList!" == "" (
            set "downloadedFileList=!geoAsnFile!"
        ) else (
            set "downloadedFileList=!downloadedFileList!;!geoAsnFile!"
        )
    ) else (
        @echo [%ESC%[91m错误%ESC%[0m] "!temp!\!geoAsnFile!" 不存在，下载链接："!geoAsnUrl!"
    )
)

@REM download GeoIP.dat
if "!geoIpUrl!" NEQ "" (
    @echo [%ESC%[!infoColor!m信息%ESC%[0m] 开始下载 %ESC%[!warnColor!m!geoIpFile!%ESC%[0m 至 %ESC%[!warnColor!m!dest!%ESC%[0m

    call :retryDownload "!geoIpUrl!" "!temp!\!geoIpFile!"
    if exist "!temp!\!geoIpFile!" (
        if "!downloadedFileList!" == "" (
            set "downloadedFileList=!geoIpFile!"
        ) else (
            set "downloadedFileList=!downloadedFileList!;!geoIpFile!"
        )
    ) else (
        @echo [%ESC%[91m错误%ESC%[0m] "!temp!\!geoIpFile!" 不存在，下载链接："!geoIpUrl!"
    )
)

@REM download LightGBM model
if "!lgbmUrl!" NEQ "" (
    @echo [%ESC%[!infoColor!m信息%ESC%[0m] 开始下载 %ESC%[!warnColor!m!lgbmFile!%ESC%[0m 至 %ESC%[!warnColor!m!dest!%ESC%[0m

    call :retryDownload "!lgbmUrl!" "!temp!\!lgbmFile!"
    if exist "!temp!\!lgbmFile!" (
        if "!downloadedFileList!" == "" (
            set "downloadedFileList=!lgbmFile!"
        ) else (
            set "downloadedFileList=!downloadedFileList!;!lgbmFile!"
        )
    ) else (
        @echo [%ESC%[91merror%ESC%[0m] "!temp!\!lgbmFile!" not found, url: "!lgbmUrl!"
    )
)

set "%~1=!downloadedFileList!"
goto :eof


@REM download with retry
:retryDownload <url> <filename>
set maxretries=3
call :trim downloadUrl "%~1"
call :trim savePath "%~2"

if "!downloadUrl!" == "" goto :eof
if "!savePath!" == "" goto :eof

set /a "count=0"

:retry
if !count! GEQ !maxretries! (
    @echo [%ESC%[91m错误%ESC%[0m] 文件 %ESC%[!warnColor!m!savePath!%ESC%[0m 下载失败，已达最大重试次数，请尝试再次执行此命令
    goto :eof
)

curl.exe --retry 5 --retry-max-time 120 --connect-timeout 20 -s -L -C - -o "!savePath!" "!downloadUrl!"
set "failFlag=!errorlevel!"
if not exist "!savePath!" set "failFlag=1"

if "!failFlag!" NEQ "0" (
    set /a "count+=1"
    
    @echo [%ESC%[!warnColor!m提示%ESC%[0m] 文件下载失败，正在进行第 %ESC%[!warnColor!m!count!%ESC%[0m 次重试，下载链接：!downloadUrl!
    goto :retry
)
goto :eof


@REM compare
:detectChangedFiles <result> <filenames>
set "%~1=0"
set "filenames=%~2"

for %%a in (!filenames!) do (
    set "fileName=%%a"

    if not exist "!temp!\!fileName!" (
        @echo [%ESC%[91m错误%ESC%[0m] %ESC%[!warnColor!m!fileName!%ESC%[0m 下载成功，但在 "!temp!" 文件夹下未找到，请确认是否已被删除
        goto :eof
    )

    if "!repairFlag!" == "1" (
        @REM delete for triggering upgrade
        del /f /q "!dest!\!fileName!" >nul 2>nul
    )

    @REM found new file
    if not exist "!dest!\!fileName!" (
        set "%~1=1"
        call :upgradeFiles "!filenames!"
        exit /b
    )

    @REM compare and update
    call :compareMd5 diff "!temp!\!fileName!" "!dest!\!fileName!"
    if "!diff!" == "1" (
        set "%~1=1"
        @echo [%ESC%[!infoColor!m信息%ESC%[0m] 发现新版本，文件名：%ESC%[!warnColor!m!fileName!%ESC%[0m
        call :upgradeFiles "!filenames!"
        exit /b
    )
)
goto :eof


@REM compare file with md5
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

@REM source md5
set "original=" & for /F "skip=1 delims=" %%h in ('2^> nul CertUtil -hashfile "!source!" MD5') do if not defined original set "original=%%h"
@REM target md5
set "received=" & for /F "skip=1 delims=" %%h in ('2^> nul CertUtil -hashfile "!target!" MD5') do if not defined received set "received=%%h"

if "!original!" NEQ "!received!" (set "%~1=1")
goto :eof


@REM update clash.exe and data
:upgradeFiles <filenames>
call :trim filenames "%~1"
if "!filenames!" == "" goto :eof

@REM make sure the file exists
set "existingFiles="
for %%a in (!filenames!) do (
    if exist "!temp!\%%a" (
        if "!existingFiles!" == "" (
            set "existingFiles=%%a"
        ) else (
            set "existingFiles=!existingFiles!;%%a"
        )
    )
)

@REM file missing
if "!existingFiles!" == "" goto :terminate

@REM stop clash
call :killProcessWrapper

@REM copy file
for %%a in (!filenames!) do (
    set "fileName=%%a"

    @REM delete if old file exists
    if exist "!dest!\!fileName!" (
        del /f /q "!dest!\!fileName!" >nul 2>nul
    )
    
    @REM move new file to dest
    move "!temp!\!fileName!" "!dest!" >nul 2>nul
)
goto :eof


@REM start
:startClash
call :isProcessRunning status

if "!status!" == "0" (
    @REM startup clash
    call :runClashWrapper 0
) else (
    @echo [%ESC%[!infoColor!m信息%ESC%[0m] 订阅和代理规则更新完毕，即将重新加载
    goto :reloadConfig
)
goto :eof


@REM privilege escalation
:runElevated <args> <showWindow>
set "showwindow=0"
set "operation=%~1"
if "!operation!" == "" (
    @echo [%ESC%[91m错误%ESC%[0m] 非法操作，必须指定函数名
    exit /b 1
)

@REM parse window parameter
call :trim param "%~2"
set "display=" & for /f "delims=0123456789" %%i in ("!param!") do set "display=%%i"
if defined display (set "showwindow=0") else (set "showwindow=!param!")
if "!showwindow!" NEQ "0" set "showwindow=1"

@REM call Start-Process with powershell
cacls "%SystemDrive%\System Volume Information" >nul 2>&1 && (
    if "!showwindow!" == "0" (
        !operation!
        exit /b
    ) else (
        powershell -Command "Start-Process '%~snx0' -ArgumentList '%~1' -Verb RunAs"
        exit /b
    )
) || (
    if "!showwindow!" == "0" (
        powershell -Command "Start-Process '%~snx0' -ArgumentList '%~1' -Verb RunAs -WindowStyle Hidden"
    ) else (
        powershell -Command "Start-Process '%~snx0' -ArgumentList '%~1' -Verb RunAs"
    )
    exit /b
)
goto :eof


@REM execute
:runClash <config>
call :trim cfile "%~1"
if "!cfile:~0,13!" == "goto :runClash" (
    for /f "tokens=1-4 delims= " %%a in ("!cfile!") do set "cfile=%%c"
)

if "!cfile!" == "" (
    @echo [%ESC%[!infoColor!m信息%ESC%[0m] 配件文件路径无效，无法启动代理程序
    goto :eof
)

@REM privilege escalation
call :enableNoPromptRunAs success

call :splitPath filepath filename "!cfile!" 
"!filepath!\clash.exe" -d "!filepath!" -f "!cfile!"
goto :eof


@REM ensure all plugins exist
:prepareComponents <changed> <force> <downloadedAlready>
set "%~1=0"

call :trim downloadForce "%~2"
if "!downloadForce!" == "" set "downloadForce=0"

call :trim downloadedAlready "%~3"
if "!downloadedAlready!" == "" set "downloadedAlready=0"

@REM check and update configration
if "!downloadedAlready!" == "0" call :updateConfig "!downloadForce!"

@REM parse api server path
call :extractControllerServer clashServer

@REM dashboard directory name
call :extractDashboardPath dashboard

@REM update subscriptions
if "!downloadedAlready!" == "0" if "!excludeUpdates!" == "0" call :updateSubscriptions subscriptionFiles "!downloadForce!"

@REM confirm download url and filename
call :detectRequiredEdition geoSiteNeeded !subscriptionFiles!

@REM clash.core or clash.premium is not available now
if "!useClashPremium!" == "1" if not exist "!dest!\clash.exe" (
    @echo [%ESC%[91m错误%ESC%[0m] 代理程序 %ESC%[!warnColor!mclash.core%ESC%[0m 或 %ESC%[!warnColor!mclash.premium%ESC%[0m 暂时 %ESC%[91m无法使用%ESC%[0m，请选择 %ESC%[!warnColor!mclash.meta%ESC%[0m
    exit /b 1
)

if "!useClashPremium!" == "0" if "!useClashMeta!" == "0" (
    set "useClashMeta=1"
    if exist "!dest!\clash.exe" ("!dest!\clash.exe" -v | findstr /i "Meta" >nul 2>nul || (
            set "useClashPremium=1"
            set "useClashMeta=0"
        )
    )
)

@REM confirm donwload url
call :resolveDownloadUrls "!downloadForce!" "!geoSiteNeeded!"

@REM precleann workspace
call :cleanWorkspace "!temp!"

@REM update dashboard
if "!downloadedAlready!" == "0" call :updateDashboard "!downloadForce!"

@REM update rulefiles
if "!downloadedAlready!" == "0" call :updateRules "!downloadForce!"

@REM wintun.dll
call :downloadWintun newwintun "!downloadForce!"
set "%~1=!newwintun!"

@REM download clah.exe and geoip.data and so on
call :downloadFiles filenames "!downloadForce!"

@REM judge file changed with md5
call :detectChangedFiles changed "!filenames!"
if "!changed!" == "1" set "%~1=!changed!"

goto :eof


@REM config autostart and auto update
:postProcess
call :runElevated "goto :enableNoPromptRunAs" 0

@REM tips
call :outputProxyHint

@REM add script to user path
call :addToUserPath

@REM allow auto start when user login
call :configureAutostart

@REM allow auto check update
call :configureAutoUpdate

@REM create shortcut on desktop
call :createDesktopShortcut
goto :eof


@REM parse clash server path
:extractControllerServer <result>
set "%~1="
call :parseYamlValue serverHost "external-controller:[ ][ ]*"
if "!serverHost!" NEQ "" if "!serverHost:~0,1!" == ":" set "serverHost=127.0.0.1!serverHost!"

set "%~1=http://!serverHost!"
goto :eof


@REM privilege escalation
:runClashWrapper <shouldCheck>
call :trim shouldCheck "%~1"
if "!shouldCheck!" == "" set "shouldCheck=0"
if "!shouldCheck!" == "1" (call :prepareComponents changed 0 0)

@REM verify config
if not exist "!dest!\clash.exe" (
    @echo [%ESC%[91m错误%ESC%[0m] 网络代理启动%ESC%[91m失败%ESC%[0m，"%ESC%[!warnColor!m!dest!\clash.exe%ESC%[0m" 缺失
    goto :eof
)

if not exist "!configFile!" (
    @echo [%ESC%[91m错误%ESC%[0m] 网络代理启动%ESC%[91m失败%ESC%[0m，配置文件 "%ESC%[!warnColor!m!configFile!%ESC%[0m" 不存在
    goto :eof
)

if "!verifyConfig!" == "1" (
    set "testOutput=!temp!\clashtestout.txt"
    del /f /q "!testOutput!" >nul 2>nul

    @REM test config file
    "!dest!\clash.exe" -d "!dest!" -t "!configFile!" > "!testOutput!"

    @REM failed
    if !errorlevel! NEQ 0 (
        set "messages="
        if exist "!testOutput!" (
            for /f "tokens=1* delims==" %%a in ('findstr /i /r /c:"[ ]ERR[ ]\[config\][ ].*" "!testOutput!"') do set "messages=%%b"
            del /f /q "!testOutput!" >nul 2>nul
        )

        if "!messages!" == "" set "messages=文件校验失败，%ESC%[!warnColor!mclash.exe%ESC%[0m 或配置文件 %ESC%[!warnColor!m!configFile!%ESC%[0m 存在问题"
        @echo [%ESC%[91m错误%ESC%[0m] 网络代理启动%ESC%[91m失败%ESC%[0m，配置文件 "%ESC%[!warnColor!m!configFile!%ESC%[0m" 存在错误
        @echo [%ESC%[91m错误%ESC%[0m] 错误信息："!messages!"
        exit /b 1
    )

    @REM delete test output
    del /f /q "!testOutput!" >nul 2>nul
)

@REM run clash.exe with config
call :runElevated "goto :runClash !configFile!" !showWindow!

for /l %%i in (1,1,6) do (
    @REM check running status
    call :isProcessRunning status
    if "!status!" == "1" (
        @REM abnormal detect
        call :isProcessAbnormal state

        if "!state!" == "1" (
            set "tips=[%ESC%[!warnColor!m警告%ESC%[0m] 代理进程%ESC%[91m异常%ESC%[0m，需%ESC%[91m删除并重新下载%ESC%[0m %ESC%[!warnColor!m!dest!\clash.exe%ESC%[0m，是否继续？(%ESC%[!warnColor!mY%ESC%[0m/%ESC%[!warnColor!mN%ESC%[0m) "
            if "!msTerminal!" == "1" (
                choice /t 5 /d y /n /m "!tips!"
            ) else (
                set /p "=!tips!" <nul
                choice /t 5 /d y /n
            )
            if !errorlevel! == 1 (
                @REM delete exist clash.exe
                del /f /q "!dest!\clash.exe" >nul 2>nul

                @REM download and restart
                goto :restartProgram
            ) else (
                @echo [%ESC%[91m错误%ESC%[0m] 代理程序启动%ESC%[91m失败%ESC%[0m，请检查代理程序 %ESC%[!warnColor!m!dest!\clash.exe%ESC%[0m 是否完好
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
        @REM waiting
        timeout /t 1 /nobreak >nul 2>nul
    )
)

@echo [%ESC%[91m错误%ESC%[0m] 代理程序启动%ESC%[91m失败%ESC%[0m，请检查配置 %ESC%[91m!configuration!%ESC%[0m 是否正确
goto :eof


@REM search port on config file with keyword
:searchPort <result> <key>
set "%~1="
set "content="
call :trim key "%~2"
if "!key!" == "" goto :eof

@REM search
for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"^^!key!:[ ][ ]*[0-9][0-9]*" "!configFile!"') do set "content=%%b"
if "!content!" == "" goto :eof

call :trim port "!content!"
if "!port!" NEQ "" set "%~1=!port!"
goto :eof


@REM extract proxy port
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


@REM print warning if tun is disabled
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

@REM set proxy
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

@REM hint
@echo [%ESC%[!warnColor!m提示%ESC%[0m] 如果无法正常使用网络代理，请到 "%ESC%[!warnColor!m设置 -^> 网络和 Internet -^> 代理%ESC%[0m" 确认是否已设置为 "%ESC%[!warnColor!m!proxyServer!%ESC%[0m"
goto :eof


@REM add current script to user's environment path
:addToUserPath
set "scriptDir=%~dp0"
set "scriptDir=!scriptDir:~0,-1!"

@REM get current path values
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "currentPath=%%b"

@REM check if already added
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
    @REM rewrite Path environment
    set "newPath=!currentPath!;!scriptDir!"
    reg add "HKCU\Environment" /v Path /t REG_EXPAND_SZ /d "!newPath!" /f >nul 2>nul

    @echo [%ESC%[!infoColor!m信息%ESC%[0m] 添加 %ESC%[!warnColor!m!scriptDir!%ESC%[0m 到用户 PATH 路径%ESC%[!infoColor!m成功%ESC%[0m
) 

goto :eof


@REM restart program
:restartProgram
@REM check running status
call :isProcessRunning status
if "!status!" == "1" (
    @REM kill process
    call :killProcessWrapper

    @REM check running status
    call :isProcessRunning status

    if "!status!" == "1" (
        @echo [%ESC%[91m错误%ESC%[0m] 无法关闭进程，代理程序重启%ESC%[91m失败%ESC%[0m，请到%ESC%[91m任务管理中心%ESC%[0m手动退出 %ESC%[!warnColor!mclash.exe%ESC%[0m
        goto :eof
    )
)

@REM if alpha=1 may cause clash.premiun download failure
if "!useClashPremium!" == "1" set "alpha=0"

@REM startup
call :runClashWrapper 1
exit /b


@REM run as admin
:killProcessWrapper
call :isProcessRunning status
if "!status!" == "0" goto :eof

call :runElevated "goto :killProcess" 0

@REM detect
for /l %%i in (1,1,6) do (
    call :isProcessRunning status
    if "!status!" == "0" (
        @echo [%ESC%[!infoColor!m信息%ESC%[0m] 代理程序关闭%ESC%[!infoColor!m成功%ESC%[0m，可使用 "%ESC%[!warnColor!m!batchName! -r%ESC%[0m" 命令重启

        @REM disable proxy
        @REM call :isTunEnabled enabled
        @REM if "!enabled!" == "0" call :disableSystemProxy

        call :disableSystemProxy
        exit /b
    ) else (
        @REM wait a moment
        timeout /t 1 /nobreak >nul 2>nul
    )
)

@echo [%ESC%[91m错误%ESC%[0m] 代理程序关闭%ESC%[91m失败%ESC%[0m，请到%ESC%[91m任务管理中心%ESC%[0m手动退出 %ESC%[!warnColor!mclash.exe%ESC%[0m
goto :eof


@REM stop
:killProcess
tasklist | findstr /i "clash.exe" >nul 2>nul && taskkill /im "clash.exe" /f >nul 2>nul
set "exitCode=!errorlevel!"

@REM no prompt
call :enableNoPromptRunAs success

@REM detect
for /l %%i in (1,1,6) do (
    @REM detect running status
    call :isProcessRunning status
    if "!status!" == "0" (
        @echo [%ESC%[!infoColor!m信息%ESC%[0m] 网络代理已关闭
        goto :eof
    ) else (
        @REM waiting for release
        timeout /t 1 /nobreak >nul 2>nul
    )
)

@echo [%ESC%[91m错误%ESC%[0m] 网络代理关闭失败，请到%ESC%[91m任务管理中心%ESC%[0m手动结束 %ESC%[!warnColor!mclash.exe%ESC%[0m 进程
goto :eof


@REM delect running status
:isProcessRunning <result>
tasklist | findstr /i "clash.exe" >nul 2>nul && set "%~1=1" || set "%~1=0"
goto :eof


@REM check clash.exe process is normal
:isProcessAbnormal <result>
set "%~1=1"

@REM memory usage
set "usage="

for /f "tokens=5 delims= " %%a in ('tasklist /nh ^|findstr /i clash.exe') do set "usage=%%a"
if "!usage!" NEQ "" (
    @REM remove comma from number
    set "usage=!usage:,=!"

    if !usage! GTR 5120 (set "%~1=0")
)

goto :eof


@REM get donwload url
:resolveDownloadUrls <force> <enabled>
@REM country data
call :trim force "%~1"
if "!force!" == "" set "force=0"

@REM dashboard
if "!zashboard!" == "1" (
    set "metacubexd=0"
    set "yacd=0"
)
if "!metacubexd!" == "1" set "yacd=0"

call :trim geoSiteFlag "%~2"
if "!geoSiteFlag!" == "" set "geoSiteFlag=0"

set "needDownload=0"
set "countryUrl=https://raw.githubusercontent.com/Hackl0us/GeoIP2-CN/release/Country.mmdb"

@REM geosite/geoip filename
set "countryFile=Country.mmdb"
set "geoSiteFile=GeoSite.dat"
set "geoIpFile=GeoIP.dat"
set "geoAsnFile=ASN.mmdb"
set "lgbmFile=Model.bin"

@REM dashboard url
set "dashboardUrl=https://github.com/Dreamacro/clash-dashboard/archive/refs/heads/gh-pages.zip"
set "dashboardDirectory=clash-dashboard-gh-pages"

set "clashUrl="

@REM get os and cpu version
call :getArch archVersion

if "!archVersion!" == "" (
    @echo [%ESC%[91m错误%ESC%[0m] 未知 操作系统 及 CPU 架构信息，获取 clash 下载链接失败
    goto :eof
)

@REM determine whether to download clash.exe
if not exist "!dest!\clash.exe" (set "needDownload=1") else (set "needDownload=!force!")

if "!useClashMeta!" == "0" (
    @echo [%ESC%[!warnColor!m提示%ESC%[0m] %ESC%[!warnColor!mclash.premium%ESC%[0m 暂%ESC%[!warnColor!m不提供%ESC%[0m下载，建议切使用 %ESC%[!warnColor!m-m%ESC%[0m 或 %ESC%[!warnColor!m--meta%ESC%[0m 换到 %ESC%[!warnColor!mclash.meta%ESC%[0m

    set "clashExe=clash-windows-!archVersion!.exe"

    if "!needDownload!" == "1" (
        if "!alpha!" == "0" (
            for /f "tokens=1* delims=:" %%a in ('curl --retry 5 -s -L "https://api.github.com/repos/Dreamacro/clash/releases/tags/premium" ^| findstr /i /r /c:"https://github.com/Dreamacro/clash/releases/download/premium/clash-windows-!archVersion!-[^v][^3].*.zip"') do set "clashUrl=%%b"
            
            @REM remove whitespace
            call :trim clashUrl "!clashUrl!"
            if !clashUrl! == "" (
                @echo [%ESC%[91m错误%ESC%[0m] 获取 clash.premium 下载链接失败
                goto :eof
            )
            set "clashUrl=!clashUrl:~1,-1!"
        ) else (
            @echo [%ESC%[!warnColor!m警告%ESC%[0m] %ESC%[!warnColor!mclash.premium%ESC%[0m 预览版下载链接可能%ESC%[91m无法访问%ESC%[0m，想要使用该版本请确保网络正常
            set "clashUrl=https://release.dreamacro.workers.dev/latest/clash-windows-!archVersion!-latest.zip"
        )
    )

    if "!yacd!" == "1" (
        set "dashboardUrl=https://github.com/haishanh/yacd/archive/refs/heads/gh-pages.zip"
        set "dashboardDirectory=yacd-gh-pages"
    )

    if "!metacubexd!" == "1" (
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
            for /f "tokens=1* delims=:" %%a in ('curl --retry 5 -s -L "https://api.github.com/repos/vernesong/mihomo/releases/tags/Prerelease-Alpha" ^| findstr /i /r /c:"https://github.com/vernesong/mihomo/releases/download/Prerelease-Alpha/mihomo-windows-!archVersion!-alpha-smart-.*.zip"') do set "clashUrl=%%b"
        ) else if "!alpha!" == "1" (
            for /f "tokens=1* delims=:" %%a in ('curl --retry 5 -s -L "https://api.github.com/repos/MetaCubeX/mihomo/releases?prerelease=true&per_page=10" ^| findstr /i /r "https://github.com/MetaCubeX/mihomo/releases/download/Prerelease-Alpha/mihomo-windows-!archVersion!-alpha-.*.zip"') do set "clashUrl=%%b"
        ) else (
            for /f "tokens=1* delims=:" %%a in ('curl --retry 5 -s -L "https://api.github.com/repos/MetaCubeX/mihomo/releases/latest?per_page=1" ^| findstr /i /r "https://github.com/MetaCubeX/mihomo/releases/download/.*/mihomo-windows-!archVersion!-v[0-9]*\.[0-9]*\.[0-9]*.zip"') do set "clashUrl=%%b"
        )

        call :trim clashUrl "!clashUrl!"
        if !clashUrl! == "" (
            if "!alpha!" == "1" (set "version=预览版") else (set "version=稳定版")
            @echo [%ESC%[91m错误%ESC%[0m] 获取 clash.meta 下载链接失败，版本："!version!"
            goto :eof
        )

        set "clashUrl=!clashUrl:~1,-1!"
    )

    @REM geosite.data download url
    if "!geoSiteFlag!" == "0" (
        set "geoSiteUrl="
    ) else (
        for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"^[ ][ ]*geosite:[ ][ ]*" "!configFile!"') do (
            call :trim geositekey %%a

            @REM commented
            if /i "!geositekey:~0,1!" NEQ "#" call :trim geoSiteUrl %%b
        )
    )

    @REM geodata-mode
    set "geoDataMode=false"
    for /f "tokens=1,2 delims=:" %%a in ('findstr /i /r /c:"^geodata-mode:[ ][ ]*" "!configFile!"') do (
        call :trim gmn %%a

        @REM commented
        if /i "!gmn:~0,1!" NEQ "#" call :trim geoDataMode %%b
    )

    @REM geoip.data
    if "!geoDataMode!" == "false" (
        set "geoIpUrl="

        for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"^[ ][ ]*mmdb:[ ][ ]*" "!configFile!"') do (
            call :trim mmdbkey %%a

            @REM commented
            if /i "!mmdbkey:~0,1!" NEQ "#" call :trim countryUrl %%b
        )
    ) else (
        set "countryUrl="

        for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"^[ ][ ]*geoip:[ ][ ]*http.*://" "!configFile!"') do (
            call :trim geoipkey %%a
            
            @REM commented
            if /i "!geoipkey:~0,1!" NEQ "#" call :trim geoIpUrl %%b
        )
    )

    @REM ASN database download url
    call :detectAsnNeeded needgeoasn
    if "!needgeoasn!" == "0" (
        set "geoAsnUrl="
    ) else (
        call :parseGeoxUrl customGeoAsnUrl "asn"
        if "!customGeoAsnUrl!" NEQ "" set "geoAsnUrl=!customGeoAsnUrl!"
    )

    if "!yacd!" == "1" (
        set "dashboardUrl=https://github.com/MetaCubeX/Yacd-meta/archive/refs/heads/gh-pages.zip"
        set "dashboardDirectory=Yacd-meta-gh-pages"
    ) else if "!metacubexd!" == "1" (
        set "dashboardUrl=https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip"
        set "dashboardDirectory=metacubexd-gh-pages"
    ) else (        
        set "dashboardUrl=https://github.com/Zephyruso/zashboard/archive/refs/heads/gh-pages.zip"
        set "dashboardDirectory=zashboard-gh-pages"
    )
)

@REM prefer external-ui-url from config unless dashboard was explicitly specified
call :selectDashboardUrl

@REM clashUrl
call :generateDownloadUrl clashUrl "!clashUrl!" "clash.exe" "!force!"

@REM dashboardUrl
if "!dashboard!" == "" (
    @REM don't need dashboard
    set "dashboardUrl="
) else (
    set "needDashboard=!force!"
    if not exist "!dashboard!\index.html" set "needDashboard=1"
    if "!needDashboard!" == "0" (
        set "dashboardUrl="
    ) else (
        call :applyGithubProxy dashboardUrl !dashboardUrl!
    )
)

@REM countryUrl
call :generateDownloadUrl countryUrl "!countryUrl!" "!countryFile!" "!force!"

@REM geoSiteUrl
call :generateDownloadUrl geoSiteUrl "!geoSiteUrl!" "!geoSiteFile!" "!force!"

@REM geoAsnUrl
call :generateDownloadUrl geoAsnUrl "!geoAsnUrl!" "!geoAsnFile!" "!force!"

@REM geoIpUrl
call :generateDownloadUrl geoIpUrl "!geoIpUrl!" "!geoIpFile!" "!force!"

@REM LightGBM model
if "!useVerneMihomo!" == "0" set "lgbmUrl="
call :generateDownloadUrl lgbmUrl "!lgbmUrl!" "!lgbmFile!" "!force!"
goto :eof


@REM select dashboard download url
:selectDashboardUrl
if "!dashboardForced!" == "1" goto :eof

set "configDashboardUrl="
call :parseYamlValue configDashboardUrl "external-ui-url:.*http.*://"
if "!configDashboardUrl!" == "" goto :eof

set "dashboardUrl=!configDashboardUrl!"
call :inferDashboardDirectory dashboardDirectory "!dashboardUrl!" "!dashboardDirectory!"
goto :eof


@REM infer dashboard archive directory from common GitHub archive URLs
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


@REM generate real download url
:generateDownloadUrl <result> <url> <filename> <force>
set "%~1="

call :trim url "%~2"
if "!url!" == "" goto :eof

call :trim filename "%~3"
if "!filename!" == "" goto :eof

if not exist "!dest!\!filename!" (set "needDownload=1") else (set "needDownload=!force!")
if "!needDownload!" == "0" goto :eof

call :applyGithubProxy downloadUrl !url!

set "%~1=!downloadUrl!"
goto :eof


@REM get cpu and os version, see: https://github.com/MetaCubeX/mihomo/releases
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


@REM leading and trailing whitespace
:trim <result> <rawText>
set "rawText=%~2"
set "%~1="
if "!rawText!" == "" goto :eof

for /f "tokens=* delims= " %%a in ("!rawText!") do set "rawText=%%a"

@REM for /l %%a in (1,1,100) do if "!rawText:~-1!"==" " set "rawText=!rawText:~0,-1!"

@REM for speed, iteration set to 10
for /l %%a in (1,1,10) do if "!rawText:~-1!"==" " set "rawText=!rawText:~0,-1!"

set "%~1=!rawText!"
goto :eof


@REM wrapper github
:applyGithubProxy <result> <rawUrl>
set "%~1="
call :trim rawUrl %~2
if "!rawUrl!" == "" goto :eof

@REM github proxy list: https://github.com/XIU2/UserScript/blob/master/GithubEnhanced-High-Speed-Download.user.js
set proxy_urls[0]=https://ghfast.top
set proxy_urls[1]=https://proxy.api.030101.xyz
set proxy_urls[2]=https://git.udrone.vip
set proxy_urls[3]=https://gh.noki.icu
set proxy_urls[4]=https://ghProxy.monkeyray.net
set proxy_urls[5]=https://ghProxy.net

@REM random [0, 5]
set /a num=!random! %% 6
set "ghProxy=!proxy_urls[%num%]!"

@REM github proxy
if "!rawUrl:~0,18!" == "https://github.com" set "rawUrl=!ghProxy!/!rawUrl!"
if "!rawUrl:~0,33!" == "https://raw.githubusercontent.com" set "rawUrl=!ghProxy!/!rawUrl!"
if "!rawUrl:~0,34!" == "https://gist.githubusercontent.com" set "rawUrl=!ghProxy!/!rawUrl!"

set "%~1=!rawUrl!"
goto :eof


@REM search keywords with powershell
:findByContext <filepath> <regex> <resultfile> <lines>
call :trim filepath %~1
if "!filepath!" == "" goto :eof

set "regex=%~2"
if "!regex!" == "" goto :eof

call :trim result %~3
if "!result!" == "" goto :eof

call :trim context %~4
if not defined context (set "context=5")

powershell -command "& {&'Get-Content' '!filepath!' | &'Select-String' -Pattern '!regex!' -Context !context!,!context! | &'Set-Content' -Encoding 'utf8' '!result!'}";
goto :eof


@REM remove leading and trailing quotes
:removeQuotes <result> <str>
set "%~1="
call :trim str "%~2"
if "!str!" == "" goto :eof

if !str:~0^,1!!str:~-1! equ "" set "str=!str:~1,-1!"
if "!str:~0,1!!str:~0,1!" == "''" set "str=!str:~1!"
if "!str:~-1!!str:~-1!" == "''" set "str=!str:~0,-1!"
set "%~1=!str!"
goto :eof


@REM query value from yaml
:parseYamlValue <result> <regex>
set "%~1="
set "regex=%~2"
if "!regex!" == "" goto :eof

set "key="
set "text="
for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"!regex!" "!configFile!"') do (
    set "key=%%a"
    set "text=%%b"
)

call :trim key "!key!"
if "!key!" == "" goto :eof
@REM commened 
if "!key:~0,1!" == "#" goto :eof

call :removeQuotes value "!text!"
set "%~1=!value!"
goto :eof


@REM query value from geox-url section
:parseGeoxUrl <result> <name>
set "%~1="
call :trim targetKey "%~2"
if "!targetKey!" == "" goto :eof
if not exist "!configFile!" goto :eof

set "insideGeoxUrl=0"
for /f "usebackq delims=" %%l in ("!configFile!") do (
    set "line=%%l"
    call :trim configLine "!line!"

    if "!configLine!" NEQ "" if "!configLine:~0,1!" NEQ "#" (
        if /i "!configLine!" == "geox-url:" (
            set "insideGeoxUrl=1"
        ) else if "!insideGeoxUrl!" == "1" (
            set "firstChar=!line:~0,1!"
            if "!firstChar!" NEQ " " if "!firstChar!" NEQ "-" set "insideGeoxUrl=0"

            if "!insideGeoxUrl!" == "1" (
                for /f "tokens=1* delims=:" %%a in ("!configLine!") do (
                    call :trim geoxkey "%%a"
                    if /i "!geoxkey!" == "!targetKey!" (
                        call :removeQuotes geoxvalue "%%b"
                        set "%~1=!geoxvalue!"
                        goto :eof
                    )
                )
            )
        )
    )
)
goto :eof


@REM reload config
:reloadConfig
if not exist "!configFile!" goto :eof

@REM parse api server path
if "!clashServer!" == "" call :extractControllerServer clashServer

if "!clashServer!" == "" (
    @echo [%ESC%[91m错误%ESC%[0m] %ESC%[91m不支持%ESC%[0m重载，可使用 "%ESC%[!warnColor!m!batchName! -r%ESC%[0m" 重启或者在文件 "%ESC%[!warnColor!m!configFile!%ESC%[0m" 配置 "%ESC%[!warnColor!mexternal-controller%ESC%[0m" 属性以启用该功能
    goto :eof
)

set "clashApi=!clashServer!/configs?force=true"

@REM secret
call :parseYamlValue secret "secret:[ ][ ]*"

@REM running detect
call :isProcessRunning status

if "!status!" == "1" (
    @REM '\' to '\\'
    set "filepath=!configFile:\=\\!"

    @REM call api for reload
    set "statusCode=000"
    set "output=!temp!\clashout.txt"
    if exist "!output!" del /f /q "!output!" >nul 2>nul

    if "!secret!" NEQ "" (
        for /f %%a in ('curl --retry 3 -L -s -o "!output!" -w "%%{http_code}" -H "Content-Type: application/json" -H "Authorization: Bearer !secret!" -X PUT -d "{""path"":""!filepath!""}" "!clashApi!"') do set "statusCode=%%a"
    ) else (
        for /f %%a in ('curl --retry 3 -L -s -o "!output!" -w "%%{http_code}" -H "Content-Type: application/json" -X PUT -d "{""path"":""!filepath!""}" "!clashApi!"') do set "statusCode=%%a"
    )

    if "!statusCode!" == "204" (
        @echo [%ESC%[!infoColor!m信息%ESC%[0m] 网络代理程序重载%ESC%[!infoColor!m成功%ESC%[0m，祝你使用愉快
        call :postProcess
    ) else if "!statusCode!" == "401" (
        @echo [%ESC%[!infoColor!m信息%ESC%[0m] %ESC%[!warnColor!msecret%ESC%[0m 已被修改，请使用 "%ESC%[!warnColor!m!batchName! -r%ESC%[0m" 重启
    ) else (
        set "content="

        if exist "!output!" (
            @REM read output
            for /f "delims=" %%a in (!output!) do set "content=%%a"
        )

        @echo [%ESC%[91m错误%ESC%[0m] 网络代理程序重载%ESC%[91m失败%ESC%[0m，请检查配置文件 "%ESC%[!warnColor!m!configFile!%ESC%[0m" 是否有效
        if "!content!" NEQ "" (
            @echo [%ESC%[91m错误%ESC%[0m] 错误信息："!content!"
        )

        @echo.
    )

    @REM delete
    del /f /q "!output!" >nul 2>nul
) else (
    @echo [%ESC%[91m错误%ESC%[0m] 网络代理程序%ESC%[91m未启动%ESC%[0m，可使用命令 "%ESC%[!warnColor!m!batchName! -r%ESC%[0m" 启动
)
goto :eof


@REM update config
:updateConfig <force>
call :trim force "%~1"
if "!force!" == "" set "force=1"
if exist "!configFile!" if "!force!" == "0" goto :eof

set "downloadPath=!temp!\clashconf.yaml"
del /f /q "!downloadPath!" >nul 2>nul

@REM extract remote config url
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

    if exist "!dest!\clash.exe" (
        @REM check file
        for %%a in ("!downloadPath!") do set "fileSize=%%~za"
        if !fileSize! LSS 32 (
            del /f /q "!downloadPath!" >nul 2>nul
            @echo [%ESC%[!warnColor!m警告%ESC%[0m] 配置文件下载失败，如有需要，请重试或点击 %ESC%[!warnColor!m!remoteConfigUrl!%ESC%[0m 手动下载并替换
            exit /b 1
        )
        
        @REM test config file
        "!dest!\clash.exe" -d "!dest!" -t -f "!downloadPath!" >nul 2>nul

        @REM failed
        if !errorlevel! NEQ 0 (
            @echo [%ESC%[91m错误%ESC%[0m] 配置文件 %ESC%[!warnColor!m!remoteConfigUrl!%ESC%[0m 存在错误，无法更新
            del /f /q "!downloadPath!" >nul 2>nul
            exit /b 1
        )
    )

    @REM compare with md5
    call :compareMd5 diff "!downloadPath!" "!configFile!"
    if "!diff!" == "0" (
        del /f /q "!downloadPath!" >nul 2>nul
        goto :eof
    )

    set "backupFile=config.yaml.bak"
    @echo [%ESC%[!infoColor!m信息%ESC%[0m] 发现较新配置，原有文件将备份为 %ESC%[!warnColor!m!dest!\!backupFile!%ESC%[0m

    @REM backup
    del /f /q "!dest!\!backupFile!" >nul 2>nul
    ren "!configFile!" !backupFile!

    @REM move new configration file to dest
    move "!downloadPath!" "!configFile!" >nul 2>nul
)
goto :eof


@REM update rules
:updateRules <force>
call :trim force "%~1"
if "!force!" == "" set "force=1"

if "!force!" == "1" (
    @echo [%ESC%[!infoColor!m信息%ESC%[0m] 开始检查并更新类型为 %ESC%[!warnColor!mHTTP%ESC%[0m 的代理规则
)

call :refreshReferencedFiles changed "^\s+behavior:\s+.*" "www.gstatic.com cp.cloudflare.com" "!force!" rulefiles "payload"
goto :eof


@REM refresh subsribe and rulesets
:refreshReferencedFiles <result> <regex> <filter> <force> <filePaths> <check>
set "%~1=0"
set "regex=%~2"
set "%~5="

call :trim filter "%~3"
if "!filter!" == "" set "filter=www.gstatic.com cp.cloudflare.com"

call :trim check "%~6"

call :trim force "%~4"
if "!force!" == "" set "force=1"

if "!regex!" == "" (
    @echo [%ESC%[!warnColor!m警告%ESC%[0m] 未指定关键信息，跳过更新
    goto :eof
)

set textUrls=
set localFiles=

if not exist "!configFile!" goto :eof

@REM temp file
set "tempFile=!temp!\clashupdate.txt"
set "filePaths=" 

call :findByContext "!configFile!" "!regex!" "!tempFile!" 5
if not exist "!tempFile!" (
    if "!force!" == "0" goto :eof

    @echo [%ESC%[!warnColor!m警告%ESC%[0m] 未发现订阅或代理规则相关配置，跳过更新，文件："!configFile!"
    goto :eof
)

@REM urls and file path
for /f "tokens=1* delims=:" %%i in ('findstr /i /r /c:"^[ ][ ]*url:[ ][ ]*http.*://.*" !tempFile!') do (
    call :trim propertity %%i
    if "!propertity:~0,1!" NEQ "#" (
        @echo "%%j" | findstr /i "!filter!" >nul 2>nul || set "textUrls=!textUrls!,%%j"
    )
)

for /f "tokens=1* delims=:" %%i in ('findstr /i /r /c:"^[ ][ ]*path:[ ][ ]*.*" !tempFile!') do (
    call :trim propertity %%i
    if "!propertity:~0,1!" NEQ "#" (
        set "localFiles=!localFiles!,%%j"
    )
)

for %%r in (!localFiles!) do (
    @REM generate file path
    call :convertToAbsolutePath targetFile %%r
    if "!targetFile!" == "" (
        @echo [%ESC%[91m错误%ESC%[0m] 配置无效，订阅或代理规则更新失败
        goto :eof  
    )

    set "filePaths=!filePaths!,!targetFile!"
    for /f "tokens=1* delims=," %%u in ("!textUrls!") do (
        call :trim url %%u
        set "textUrls=%%v"

        if /i "!url:~0,8!"=="https://" (
            @REM ghProxy
            call :applyGithubProxy url !url!

            set "needDownload=0"
            if not exist "!targetFile!" set "needDownload=1"
            if "!force!" == "1" set "needDownload=1"
            @REM should download
            if "!needDownload!" == "1" (
                @REM get directory
                call :splitPath filepath filename "!targetFile!"

                @REM mkdir if not exists
                call :createDirectories success "!filepath!"

                @REM request and save
                del /f /q "!temp!\!filename!" >nul 2>nul
                call :retryDownload "!url!" "!temp!\!filename!"

                @REM check file size
                set "fileSize=0"
                if exist "!temp!\!filename!" (
                    for %%a in ("!temp!\!filename!") do set "fileSize=%%~za"
                )

                @REM check file content
                call :verifyFileSection match "!temp!\!filename!" "!check!"

                if !fileSize! GTR 16 if "!match!" == "1" (
                    @REM delete if old file exists
                    del /f /q "!targetFile!" >nul 2>nul

                    @REM move new file to dest
                    move "!temp!\!filename!" "!filepath!" >nul 2>nul

                    @REM changed status 
                    set "%~1=1"
                ) else (
                    @echo [%ESC%[91m错误%ESC%[0m] 文件 %ESC%[!warnColor!m!filename!%ESC%[0m 下载失败，下载链接："!url!"
                )
            )
        )
    )
)

set "%~5=!filePaths!"
@REM delete tempFile
if exist "!tempFile!" del /f /q "!tempFile!" >nul 2>nul
goto :eof


@REM extract dashboard path
:extractDashboardPath <result>
set "%~1="

if not exist "!configFile!" goto :eof

set "keyName="
set "content="
for /f "tokens=1,* delims=:" %%a in ('findstr /i /r /c:"external-ui:[ ][ ]*" "!configFile!"') do (
    set "keyName=%%a"
    set "content=%%b"
)

@REM not found 'external-ui' configuration in config file
call :trim keyName "!keyName!"

if "!keyName!" NEQ "external-ui" (
    set "flag=1"
    if "!keyName!" NEQ "" set "flag=0"
    if "!brief!" == "1" set "flag=0"
    if "!clashServer!" == "" set "flag=0"

    if "!flag!" == "0" goto :eof

    set "tmpConfig=!configFile!.tmp"

    @REM append 'external-ui' configuration
    @echo external-ui: dashboard > "!tmpConfig!"
    type "!configFile!" >> "!tmpConfig!"

    @REM replace config file
    del /f /q "!configFile!" >nul 2>nul
    move "!tmpConfig!" "!configFile!" >nul 2>nul

    @REM reset
    set "tmpConfig="
    set "content=dashboard"
)

call :trim content "!content!"
if "!content!" == "" goto :eof

call :convertToAbsolutePath directory "!content!"
set "%~1=!directory!"
goto :eof


@REM check file is validate
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

@REM not required
call :trim text "!text!"

if "!text!" == "!check!" set "%~1=1"
goto :eof


@REM upgrade dashboard
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

@REM exists
if exist "!dashboard!\index.html" if "!force!" == "0" goto :eof
call :createDirectories success "!dashboard!"

@echo [%ESC%[!infoColor!m信息%ESC%[0m] 开始下载并更新控制面板
call :retryDownload "!dashboardUrl!" "!temp!\dashboard.zip"

if not exist "!temp!\dashboard.zip" (
    @echo [%ESC%[!warnColor!m警告%ESC%[0m] 控制面板下载失败，下载链接："!dashboardUrl!"
    goto :eof
)

@REM unzip
tar -xzf "!temp!\dashboard.zip" -C !temp! >nul 2>nul
del /f /q "!temp!\dashboard.zip" >nul 2>nul

@REM base path and directory name
call :splitPath dashpath dashname "!dashboard!"
if "!dashpath!" == "" (
    @echo [%ESC%[91m错误%ESC%[0m] 无法获取控制面板保存路径
    goto :eof
)

if "!dashname!" == "" (
    @echo [%ESC%[91m错误%ESC%[0m] 无法获取控制面板文件夹名
    goto :eof
)

@REM rename
ren "!temp!\!dashboardDirectory!" !dashname!

@REM replace if dashboard download success
dir /a /s /b "!temp!\!dashname!" | findstr . >nul && (
    call :replaceDirectory "!temp!\!dashname!" "!dashboard!"
    @echo [%ESC%[!infoColor!m信息%ESC%[0m] 控制面板已更新至最新版本
) || (
    @echo [%ESC%[!warnColor!m警告%ESC%[0m] 控制面板下载失败，下载链接："!dashboardUrl!"
)
goto :eof


@REM overwrite files
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

@REM delete old folder if exists
if exist "!target!" rd "!target!" /s /q >nul 2>nul

@REM copy to dest
xcopy "!src!" "!target!" /h /e /y /q /i >nul 2>nul

@REM delete source dashboard
rd "!src!" /s /q >nul 2>nul
goto :eof


@REM delete if file exists
:cleanWorkspace
set "directory=%~1"
if "!directory!" == "" set "directory=!temp!"

if exist "!directory!\clash.zip" del /f /q "!directory!\clash.zip" >nul
if exist "!directory!\clash.exe" del /f /q "!directory!\clash.exe" >nul

@REM wintun
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

@REM delete directory
if "!dashboardDirectory!" NEQ "" (
    if exist "!directory!\!dashboardDirectory!" rd "!directory!\!dashboardDirectory!" /s /q >nul
)

if "!dashboard!" == "" goto :eof
if exist "!directory!\!dashboard!.zip" del /f /q "!directory!\!dashboard!.zip" >nul
if exist "!directory!\!dashboard!" rd "!directory!\!dashboard!" /s /q >nul 2>nul
goto :eof


@REM replace '\\' to '\' for directory 
:normalizePath <result> <directory>
set "%~1="
call :trim directory "%~2"

if "!directory!" == "" goto :eof

@REM '\\' to '\'
set "directory=!directory:\\=\!"

@REM '/' to '\'
set "directory=!directory:/=\!"

@REM remove last '\'
if "!directory:~-1!" == "\" set "directory=!directory:~0,-1!"
set "%~1=!directory!"
goto :eof


@REM define exit function
:terminate
@echo [%ESC%[91m错误%ESC%[0m] 更新失败，代理程序、域名及 IP 地址数据库或控制面板缺失
call :cleanWorkspace "!temp!"
exit /b 1
goto :eof


@REM close
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


@REM Initialize ANSI color support for console output
:setEsc
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do (
  set ESC=%%b
  exit /b 0
)
exit /b 0


@REM set proxy
:enableSystemProxy <server>
call :trim server "%~1"
if "!server!" == "" goto :eof

reg add "!proxyRegPath!" /v ProxyEnable /t REG_DWORD /d 1 /f >nul 2>nul
reg add "!proxyRegPath!" /v ProxyServer /t REG_SZ /d "!server!" /f >nul 2>nul
reg add "!proxyRegPath!" /v ProxyOverride /t REG_SZ /d "<local>" /f >nul 2>nul
goto :eof


@REM cancel proxy
:disableSystemProxy
reg add "!proxyRegPath!" /v ProxyServer /t REG_SZ /d "" /f >nul 2>nul
reg add "!proxyRegPath!" /v ProxyEnable /t REG_DWORD /d 0 /f >nul 2>nul
reg add "!proxyRegPath!" /v ProxyOverride /t REG_SZ /d "" /f >nul 2>nul
goto :eof


@REM query proxy status
:getSystemProxy <result>
set "%~1="

@REM enabled
call :queryRegistry enable "!proxyRegPath!" "ProxyEnable" "REG_DWORD"
if "!enable!" NEQ "0x1" goto :eof

@REM proxy server
call :queryRegistry server "!proxyRegPath!" "ProxyServer" "REG_SZ"
if "!server!" NEQ "" set "%~1=!server!"
goto :eof


@REM auto start when user login
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


@REM disable auto start
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

        @REM disable
        reg delete "!startupApprovedRegPath!" /v "Clash" /f >nul 2>nul
    )
)
goto :eof


@REM add scheduled tasks
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

    @REM generate vbs for update
    call :generateUpdateVbs

    @REM delete old task
    call :deleteScheduledTask success "!taskName!"

    @REM create new task
    call :createScheduledTask success "!updateVbs!" "!taskName!"
    if "!success!" == "1" (
        @echo [%ESC%[!infoColor!m信息%ESC%[0m] 自动检查更新设置%ESC%[!infoColor!m成功%ESC%[0m
    ) else (
        @echo [%ESC%[91m错误%ESC%[0m] 自动检查更新设置%ESC%[91m失败%ESC%[0m
    )
)
goto :eof


@REM generate vbs for update
:generateUpdateVbs
set "operation=-u"
if "!useClashMeta!" == "1" set "operation=!operation! -m"
if "!useClashPremium!" == "1" set "operation=!operation! -n"
if "!alpha!" == "1" set "operation=!operation! -a"
if "!yacd!" == "1" set "operation=!operation! -y"
if "!metacubexd!" == "1" set "operation=!operation! -x"
if "!zashboard!" == "1" set "operation=!operation! -z"

@REM generate and write to file
call :generateStartupVbs "!updateVbs!" "!operation!"

goto :eof


@REM create scheduled tasks
:createScheduledTask <result> <path> <taskName>
set "%~1=0"
call :trim exeName "%~2"
if "!exeName!" == "" goto :eof

call :trim taskName "%~3"
if "!taskName!" == "" goto :eof

@REM input start time
call :promptScheduleTime startTime

@REM create
schtasks /create /tn "!taskName!" /tr "!exeName!" /sc daily /mo 1 /ri 480 /st !startTime! /du 0012:00 /f >nul 2>nul
if "!errorlevel!" == "0" set "%~1=1"
goto :eof


@REM prompt user input task start time 
:promptScheduleTime <time>
set "%~1="
set "userTime="
set "defaultTime=09:15"

@REM choose
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

@REM prompt user input time
call :promptTimeInput inputTime "!defaultTime!" 0
set "%~1=!inputTime!"
goto :eof


@REM input and validate
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

@REM validate user input
call :validateTimeInput "%~1" "%~2" "!userInput!"
goto :eof


@REM validate user input time
:validateTimeInput <result> <default> <input>
set "%~1="

@REM trim user input
call :trim userTime "%~3"

set "validFlag=0"
for /f "tokens=1-2 delims=:" %%a in ("!userTime!") do (
    set "hours=%%a" 2>nul
    set "minutes=%%b" 2>nul

    call :isNumber hour_flag !hours!
    call :isNumber minute_flag !minutes!

    if !hour_flag! == 1 if !minute_flag! == 1 if !hours! lss 24 if !minutes! lss 60 if !hours! geq 0 if !minutes! geq 0 (
        set "validFlag=1"
    )
)

if "!validFlag!" == "0" (call :promptTimeInput "%~1" "%~2" 1) else (set "%~1=!userTime!")
goto :eof


@REM check if a variable is zero or a positive integer
:isNumber <result> <variable>
set "%~1=0"
call :trim variable "%~2"

@echo !variable! | findstr /r /c:"^[0-9][0-9][ ]*$" >nul 2>nul && (set "%~1=1")

goto :eof


@REM query scheduled tasks
:getTaskStatus <status> <taskName>
set "%~1=0"
call :trim taskName "%~2"
if "!taskName!" == "" goto :eof

@REM query
schtasks /query /tn "!taskName!" >nul 2>nul
if "!errorlevel!" NEQ "0" goto :eof

@REM compare script path is same as current path
set "commandPath="
for /f "tokens=3 delims=<>" %%a in ('schtasks /query /tn "!taskName!" /xml ^| findstr "<Command>"') do set "commandPath=%%a"
call :trim commandPath "!commandPath!"

if "!commandPath!" NEQ "!updateVbs!" goto :eof

set "status="
for /f "usebackq skip=3 tokens=4" %%a in (`schtasks /query /tn "!taskName!"`) do set "status=%%a"
call :trim status "!status!"

if "!status!" == "Ready" set "%~1=1"

goto :eof


@REM delete update tasks
:deleteScheduledTask <result> <taskName>
set "%~1=0"
call :trim taskName "%~2"
if "!taskName!" == "" goto :eof

schtasks /query /tn "!taskName!" >nul 2>nul
@REM not found
if "!errorlevel!" NEQ "0" (
    set "%~1=1"
    goto :eof
)

@REM remove
call :runElevated "goto :cancelScheduledTask !taskName!" 0

@REM get delete status
for /l %%i in (1,1,5) do (
    schtasks /query /tn "!taskName!" >nul 2>nul
    if "!errorlevel!" == "0" (
        @REM wait
        timeout /t 1 /nobreak >nul 2>nul
    ) else (
        set "%~1=1"
        exit /b
    )
)
goto :eof


@REM remove scheduled task
:cancelScheduledTask <taskName>
@REM delete
schtasks /delete /tn "%~1" /f  >nul 2>nul

@REM get administrator privileges
call :enableNoPromptRunAs result
goto :eof


@REM add to 
:registerStartupScript <result> <path>
set "%~1=0"
call :trim exeName "%~2"
if "!exeName!" == "" goto :eof
if not exist "!exeName!" goto :eof

@REM delete
reg delete "!autostartRegPath!" /v "Clash" /f >nul 2>nul
@REM register
reg add "!autostartRegPath!" /v "Clash" /t "REG_SZ" /d "!exeName!" >nul 2>nul
if "!errorlevel!" NEQ "0" goto :eof

@REM approved
reg delete "!startupApprovedRegPath!" /v "Clash" /f >nul 2>nul
@REM register
reg add "!startupApprovedRegPath!" /v "Clash" /t "REG_BINARY" /d "02 00 00 00 00 00 00 00 00 00 00 00" >nul 2>nul

if "!errorlevel!" == "0" set "%~1=1"
goto :eof


@REM vbs for startup
:generateStartupVbs <path> <operation>
call :trim startScript "%~1"
if "!startScript!" == "" goto :eof

call :trim operation "%~2"
if "!operation!" == "" goto :eof

@echo set ws = WScript.CreateObject^("WScript.Shell"^) > "!startScript!"
@echo ws.Run "%~dp0!batchName! !operation! -w !dest! -c !configFile!", 0 >> "!startScript!"
@echo set ws = Nothing >> "!startScript!"
goto :eof


@REM judge os caption
:isHomeEdition <result>
set "%~1=1"

set "content=" 
for /f %%a in ('wmic os get OperatingSystemSKU ^| findstr /r /i /c:"^[1-9][0-9]*"') do set "content=%%a"
call :trim content "!content!"

@REM 2/3/5/26 represent home edition
if "!content!" NEQ "2" if "!content!" NEQ "3" if "!content!" NEQ "5" if "!content!" NEQ "26" (
    for /f "delims=" %%a in ('wmic os get caption ^| findstr /i /c:"pro" /c:"professional"') do set "content=%%a"
    call :trim content "!content!"
    if "!content!" NEQ "" set "%~1=0"
)
goto :eof


@REM enable run as admin
:enableSilentRunAs <result>
set "%~1=1"

call :isHomeEdition edition
if "!edition!" == "0" goto :eof

set "packagesFile=!temp!\grouppolicypackages.txt"

@REM find all groupPolicyRegPath pakcages
dir /b "C:\Windows\servicing\Packages\Microsoft-Windows-GroupPolicy-ClientExtensions-Package~3*.mum" > "!packagesFile!"
dir /b "C:\Windows\servicing\Packages\Microsoft-Windows-GroupPolicy-ClientTools-Package~3*.mum" >> "!packagesFile!"

@REM install
for /f %%i in ('findstr /i . "!packagesFile!" 2^>nul') do dism /online /norestart /add-package:"C:\Windows\servicing\Packages\%%i" >nul 2>nul
if "!errorlevel!" NEQ "0" set "%~1=0"

del /f /q "!packagesFile!" >nul 2>nul
goto :eof


@REM no prompt when run as admin
:enableNoPromptRunAs <result>
set "%~1=0"

@REM regedit path and key
set "groupPolicyRegPath=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
set "groupPolicyRunAsKey=ConsentPromptBehaviorAdmin"

call :queryRegistry code "!groupPolicyRegPath!" "!groupPolicyRunAsKey!" "REG_DWORD"
if "!code!" == "0x0" (
    set "%~1=1"
    exit /b  
)

call :enableSilentRunAs enable
if "!enable!" == "0" goto :eof

@REM change regedit
reg delete "!groupPolicyRegPath!" /v ConsentPromptBehaviorAdmin /f >nul 2>nul
reg add "!groupPolicyRegPath!" /v ConsentPromptBehaviorAdmin /t REG_DWORD /d 0 /f >nul 2>nul
if "!errorlevel!" == "0" set "%~1=1"
goto :eof


@REM clean data
:purge
set "tips=[%ESC%[!warnColor!m警告%ESC%[0m] 即将关闭系统代理并禁用开机自启，是否继续？(%ESC%[!warnColor!mY%ESC%[0m/%ESC%[!warnColor!mN%ESC%[0m) "
if "!msTerminal!" == "1" (
    choice /t 6 /d n /n /m "!tips!"
) else (
    set /p "=!tips!" <nul
    choice /t 6 /d n /n
)
if !errorlevel! == 2 exit /b 1

@REM close system proxy
call :disableSystemProxy

@REM disable auto start
call :disableAutostart success
if "!success!" == "0" (
    @echo [%ESC%[91m错误%ESC%[0m] 开机自启%ESC%[91m禁用失败%ESC%[0m，可在%ESC%[!warnColor!m任务管理中心%ESC%[0m手动设置
)

@REM delete scheduled
call :deleteScheduledTask success "ClashUpdater"
if "!success!" == "0" (
    @echo [%ESC%[91m错误%ESC%[0m] 自动检查跟新取消%ESC%[91m失败%ESC%[0m，可在%ESC%[!warnColor!m任务计划程序%ESC%[0m中手动删除 
)

@REM stop process
call :killProcessWrapper

@REM remote shortcut
call :deleteDesktopShortcut

@echo [%ESC%[!infoColor!m信息%ESC%[0m] 清理%ESC%[!infoColor!m完毕%ESC%[0m, bye~
goto :eof


@REM query value form register
:queryRegistry <result> <path> <key> <type>
set "%~1="
set "value="

@REM path
call :trim rpath "%~2"
if "!rpath!" == "" goto :eof

@REM key
call :trim rkey "%~3"
if "!rkey!" == "" goto :eof

@REM type
call :trim rtype "%~4"
if "!rtype!" == "" set "rtype=REG_SZ"

@REM query
reg query "!rpath!" /V "!rkey!" >nul 2>nul
if "!errorlevel!" NEQ "0" goto :eof

for /f "tokens=3" %%a in ('reg query "!rpath!" /V "!rkey!" ^| findstr /r /i "!rtype!"') do set "value=%%a"
call :trim value "!value!"
set "%~1=!value!"
goto :eof


@REM icon generation
:downloadIcon <result> <iconName>
set "%~1=0"

call :trim iconName "%~2"
if "!iconName!" == "" goto :eof

call :applyGithubProxy iconUrl "https://raw.githubusercontent.com/wzdnzd/batches/main/icons/clash.ico"
set "statusCode=000"
for /f %%a in ('curl --retry 3 --retry-max-time 60 -m 60 --connect-timeout 30 -L -s -o "!dest!\!iconName!" -w "%%{http_code}" "!iconUrl!"') do set "statusCode=%%a"

if "!statusCode!" == "200" set "%~1=1"
goto :eof


@REM create desktop shortcut
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


@REM send to desktop
:createDesktopShortcut
if "!enableShortcut!" == "0" goto :eof

set "iconName=clash.ico"
set "linkDest=!HOMEDRIVE!!HOMEPATH!\Desktop\Clash.lnk"

set "exePath="
@REM parse target if link exists
if exist "!linkDest!" (
    for /f "delims=" %%a in ('wmic path win32_shortcutfile where "name='!linkDest:\=\\!'" get target /value') do (
        for /f "tokens=2 delims==" %%b in ("%%~a") do set "exePath=%%b"
    )
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


@REM remove shortcut from desktop
:deleteDesktopShortcut
set "linkPath=!HOMEDRIVE!!HOMEPATH!\Desktop\Clash.lnk"
del /f /q "!linkPath!" >nul 2>nul
goto :eof


@REM determine whether it is a microsoft terminal
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


@REM get current terminal name
:getTerminalName <result> <num>
set "%~1="
call :trim num "%~2"
if "!num!" == "" set "num=3"

@REM set "psCommand=$current = Get-CimInstance -ClassName win32_process -filter ('ProcessID='+$pid); $parent = Get-Process -id ($current.parentprocessID); if ($parent.ProcessName -eq 'WindowsTerminal') {echo 'true';} else {$cimgrandparent = Get-CimInstance -ClassName win32_process -filter ('Processid='+($($parent.id))); $grandparent = Get-Process -id ($cimgrandparent.parentProcessId); if (($grandparent.processname) -eq 'WindowsTerminal') {echo 'true';} else {echo 'false';}}"

@REM reference: https://stackoverflow.com/questions/53447286/in-a-cmd-batch-file-can-i-determine-if-it-was-run-from-powershell
set "psCommand=$ppid=$pid;while($i++ -lt !num! -and ($ppid=(Get-CimInstance Win32_Process -Filter ('ProcessID='+$ppid)).ParentProcessId)) {}; (Get-Process -EA Ignore -ID $ppid).Name"

for /f "tokens=*" %%a in ('powershell -noprofile -command "!psCommand!"') do set "%~1=%%a"
goto :eof


endlocal


