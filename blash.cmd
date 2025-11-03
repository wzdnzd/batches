@REM author: wzdnzd
@REM date: 2022-08-24
@REM describe: network proxy controller for clash

@echo off & PUSHD %~DP0 & cd /d "%~dp0"

@REM change encoding
chcp 65001 >nul 2>nul

@REM https://blog.csdn.net/sanqima/article/details/37818115
setlocal enableDelayedExpansion

@REM output with color
call :setESC

@REM call workflow
goto :workflow


@REM ########################
@REM function define blow ###
@REM ########################

@REM process pipeline
:workflow
@REM batch file name
set "batname=%~nx0"

@REM microsoft terminal displays differently from cmd and powershell
@REM call :ismsterminal msterminal
set "msterminal=1"

@REM enable create shortcut 
set "enableshortcut=1"

@REM enable download config from remote
set "enableremoteconf=1"
set "remoteurl="

@REM validate configuration files before starting
set "verifyconf=0"

@REM check and update wintun.dll
set "checkwintun=0"

@REM info color
set "infocolor=92"
set "warncolor=93"

if "!msterminal!" == "1" (
    set "infocolor=95"
    set "warncolor=97"
)

@REM print heart
set "customize=0"
set "drawheart=0"

@REM exit flag
set "shouldexit=0"

@REM init
set "initflag=0"

@REM configuration file name
set "configuration=config.yaml"

@REM subscription link
set "sublink="
set "isweblink=0"

@REM check
set "testflag=0"

@REM repair
set "repair=0"

@REM only reload
set "reloadonly=0"

@REM restart clash.exe
set "restartflag=0"

@REM close proxy
set "killflag=0"

@REM update
set "updateflag=0"

@REM purge
set "purgeflag=0"

@REM only update subscriptions and rulesets
set "quickflag=0"

@REM don't update subscription
set "exclude=0"

@REM use clash.meta
set "clashmeta=0"

@REM use clash.premium
set "clashpremium=0"

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

@REM run on background
set "asdaemon=0"

@REM show window
set "show=0"

@REM setting workspace
set "dest="

@REM network proxy registry configuration path
set "proxyregpath=HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings"

@REM autostart registry configuration path
set "autostartregpath=HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
set "startupapproved=HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"

@REM parse arguments
call :argsparse %*

@REM invalid arguments
if "!shouldexit!" == "1" exit /b 1

@REM regular file path
if "!dest!" == "" set "dest=%~dp0"
call :pathregular dest "!dest!"

@REM auto start vb script
set "startupvbs=!dest!\startup.vbs"

@REM auto update vb script
set "updatevbs=!dest!\update.vbs"

@REM draw a heart
if "!drawheart!"== "1" goto :printheart

@REM close network proxy
if "!killflag!" == "1" goto :closeproxy

@REM clean all setting
if "!purgeflag!" == "1" goto :purge

@REM prevent precheck if no action
if "!reloadonly!" == "0" if "!restartflag!" == "0" if "!repair!" == "0" if "!testflag!" == "0" if "!updateflag!" == "0" if "!initflag!" == "0" (
    @REM @echo [%ESC%[91m错误%ESC%[0m] 必须包含 [%ESC%[!warncolor!m-f%ESC%[0m %ESC%[!warncolor!m-i%ESC%[0m %ESC%[!warncolor!m-k%ESC%[0m %ESC%[!warncolor!m-r%ESC%[0m %ESC%[!warncolor!m-t%ESC%[0m %ESC%[!warncolor!m-u%ESC%[0m] 中的一种操作
    @REM @echo.

    if "!shouldexit!" == "0" goto :usage
    exit /b
)

@REM config file path
call :precheck configfile
if "!configfile!" == "" exit /b 1

@REM connectivity test
if "!testflag!" == "1" (
    call :checkconnect available 1
    exit /b
)

@REM reload config
if "!reloadonly!" == "1" goto :reload

@REM update
if "!restartflag!" == "1" goto :restartprogram

@REM check issues
if "!repair!" == "1" goto :resolveissues

@REM update
if "!updateflag!" == "1" goto :updateplugins

@REM init
if "!initflag!" == "1" goto :initialize

@REM unknown command
@REM if "!shouldexit!" == "0" goto :usage

exit /b


@REM check if the configuration file exists
:precheck <result>
set "%~1="
set "subfile=!temp!\clashsub.yaml"

@REM absolute path
call :pathconvert conflocation "!configuration!"
call :pathregular conflocation "!conflocation!"

if "!conflocation!" == "" (
    @echo [%ESC%[91m错误%ESC%[0m] 配置文件路径%ESC%[91m无效%ESC%[0m
    exit /b 1
)

@REM cannot contain whitespace in path
if "!conflocation!" NEQ "!conflocation: =!" (
    @echo [%ESC%[91m错误%ESC%[0m] 无效的配置文件 "%ESC%[!warncolor!m!conflocation!%ESC%[0m"， 路径不能包含%ESC%[!warncolor!m空格%ESC%[0m
    exit /b 1
)

if "!isweblink!" == "1" (
    if exist "!conflocation!" (
        set "tips=[%ESC%[!warncolor!m警告%ESC%[0m] %ESC%[!warncolor!m已存在%ESC%[0m配置文件 "%ESC%[!warncolor!m!conflocation!%ESC%[0m" 会被%ESC%[91m覆盖%ESC%[0m，是否继续？ (%ESC%[!warncolor!mY%ESC%[0m/%ESC%[!warncolor!mN%ESC%[0m) "
        if "!msterminal!" == "1" (
            choice /t 6 /d n /n /m "!tips!"
        ) else (
            set /p "=!tips!" <nul
            choice /t 6 /d n /n
        )
        if !errorlevel! == 2 exit /b 1
    )

    @REM try to download
    del /f /q "!subfile!" >nul 2>nul

    set "statuscode=000"
    for /f %%a in ('curl --retry 3 --retry-max-time 30 -m 60 --connect-timeout 30 -L -s -o "!subfile!" -w "%%{http_code}" -H "User-Agent: Clash" "!sublink!"') do set "statuscode=%%a"

    @REM download success
    if "!statuscode!" == "200" (
        set "filesize=0"
        if exist "!subfile!" (for %%a in ("!subfile!") do set "filesize=%%~za")
        if !filesize! GTR 64 (
            @REM validate
            set "content="
            for /f "tokens=*" %%a in ('findstr /i /r /c:"^external-controller:[ ][ ]*.*:[0-9][0-9]*.*" !subfile!') do set "content=%%a"
            if "!content!" == "" (
                @echo [%ESC%[91m错误%ESC%[0m] 订阅 "%ESC%[!warncolor!m!sublink!%ESC%[0m" 无效，请检查确认
                exit /b 1
            )

            del /f /q "!conflocation!" >nul 2>nul
            call :splitpath filepath filename "!conflocation!"
            call :makedirs success "!filepath!"
            if "!success!" == "0" (
                @echo [%ESC%[91m错误%ESC%[0m] 创建文件夹 "%ESC%[!warncolor!m!filepath!%ESC%[0m" %ESC%[91m失败%ESC%[0m，请确认路径是否合法 
                exit /b 1
            )

            move "!subfile!" "!conflocation!" >nul 2>nul
            @echo [%ESC%[!infocolor!m信息%ESC%[0m] 订阅下载%ESC%[!infocolor!m成功%ESC%[0m

            @REM 保存订阅链接
            @echo !sublink! > "!filepath!\subscriptions.txt"
        ) else (
            @REM output is empty
            set "statuscode=000"
        )
    )

    if "!statuscode!" NEQ "200" (
        @echo [%ESC%[91m错误%ESC%[0m] 订阅下载%ESC%[91m失败%ESC%[0m， 请检查确认此订阅是否有效
        exit /b 1
    )
)

if not exist "!conflocation!" (
    @echo [%ESC%[91m错误%ESC%[0m] 配置文件 "%ESC%[!warncolor!m!conflocation!%ESC%[0m" %ESC%[91m不存在%ESC%[0m
    goto :eof
)

@REM validate
set "content="
for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"^proxy-groups:[ ]*" "!conflocation!"') do set "content=%%a"
call :trim content "!content!"
if "!content!" NEQ "proxy-groups" (
    @echo [%ESC%[91m错误%ESC%[0m] %ESC%[91m无效%ESC%[0m的配置文件 "%ESC%[!warncolor!m!conflocation!%ESC%[0m"
    exit /b 1
)

set "%~1=!conflocation!"
goto :eof


@REM Initialize network proxy
:initialize
set "tips=[%ESC%[!warncolor!m提示%ESC%[0m] 网络代理程序将在目录 "%ESC%[!warncolor!m!dest!%ESC%[0m" 安装并运行，是否继续？(%ESC%[!warncolor!mY%ESC%[0m/%ESC%[!warncolor!mN%ESC%[0m) "
if "!msterminal!" == "1" (
    choice /t 5 /d n /n /m "!tips!"
) else (
    set /p "=!tips!" <nul
    choice /t 5 /d n /n
)
if !errorlevel! == 2 exit /b 1

set "quickflag=0"
set "exclude=1"
call :updateplugins
goto :eof


@REM fix network issues
:resolveissues
@REM mandatory use of the stable version
set "alpha=0"

@echo [%ESC%[!infocolor!m信息%ESC%[0m] 开始检查并尝试修复网络代理，请稍等

@REM check status
call :checkconnect available 0
set "lazycheck=0"
if "!available!" == "1" (
    set "tips=[%ESC%[!warncolor!m提示%ESC%[0m] 代理网络运行%ESC%[!infocolor!m正常%ESC%[0m，%ESC%[91m不存在%ESC%[0m问题，是否继续？(%ESC%[!warncolor!mY%ESC%[0m/%ESC%[!warncolor!mN%ESC%[0m) "
    if "!msterminal!" == "1" (
        choice /t 5 /d n /n /m "!tips!"
    ) else (
        set /p "=!tips!" <nul
        choice /t 5 /d n /n
    )
    if !errorlevel! == 2 exit /b 1
) else (
    @REM running detect
    call :isrunning status
    if "!status!" == "0" (
        call :checkwapper continue 1
        if "!continue!" == "0" exit /b
    ) else set "lazycheck=1"
)

@REM O: Reload | R: Restart | U: Restore | N: Cancel
set "tips=[%ESC%[!warncolor!m提示%ESC%[0m] 按 %ESC%[!warncolor!mO%ESC%[0m %ESC%[!warncolor!m重载%ESC%[0m，按 %ESC%[!warncolor!mR%ESC%[0m %ESC%[!warncolor!m重启%ESC%[0m，按 %ESC%[!warncolor!mU%ESC%[0m %ESC%[!warncolor!m恢复%ESC%[0m至默认，按 %ESC%[!warncolor!mN%ESC%[0m %ESC%[!warncolor!m取消%ESC%[0m (%ESC%[!warncolor!mO%ESC%[0m/%ESC%[!warncolor!mR%ESC%[0m/%ESC%[!warncolor!mU%ESC%[0m/%ESC%[!warncolor!mN%ESC%[0m) "
if "!msterminal!" == "1" (
    choice /t 6 /c ORUN /d R /n /m "!tips!"
) else (
    set /p "=!tips!" <nul
    choice /t 6 /c ORUN /d R /n
)

if !errorlevel! == 1 (
    call :reload
) else if !errorlevel! == 2 (
    call :restartprogram
) else if !errorlevel! == 3 (
    @REM kill clash process
    call :killprocesswrapper

    @REM lazy check
    if "!lazycheck!" == "1" (
        call :checkwapper continue 0
        if "!continue!" == "0" exit /b
    )

    @REM restore plugins
    call :updateplugins
) else (
    :: cancel
    exit /b
)

for /l %%i in (1,1,5) do (
    @REM recheck
    call :checkconnect available 0
    if "!available!" == "1" (
        @echo [%ESC%[!infocolor!m信息%ESC%[0m] 问题修复%ESC%[!infocolor!m成功%ESC%[0m，网络代理可%ESC%[!infocolor!m正常%ESC%[0m使用
        exit /b
    ) else (
        @REM wait
        timeout /t 1 /nobreak >nul 2>nul
    )
)

@echo [%ESC%[91m错误%ESC%[0m] 问题修复%ESC%[91m失败%ESC%[0m， 网络代理仍%ESC%[91m无法%ESC%[0m使用， 请尝试其他方法
goto :eof


@REM check if the network is available
:checkwapper <result> <enable>
set "%~1=1"
call :trim loglevel "%~2"
if "!loglevel!" == "" set "loglevel=1"

call :isavailable available 0 "https://www.baidu.com" ""
if "!available!" == "0" (
    @echo [%ESC%[91m错误%ESC%[0m] 网络%ESC%[91m不可用%ESC%[0m， 但代理程序%ESC%[91m并未运行%ESC%[0m，请检查你的%ESC%[!warncolor!m本地网络%ESC%[0m是否正常

    @REM should terminate
    set "%~1=0"
    exit /b
)

if "!loglevel!" == "1" (
    @echo [%ESC%[!warncolor!m提示%ESC%[0m] 网络代理%ESC%[91m没有开启%ESC%[0m， 推荐选择 %ESC%[!warncolor!mRestart%ESC%[0m 开启
)
goto :eof


@REM update workflow
:updateplugins
set "downloaded=0"

if "!quickflag!" == "1" (
    call :quickupdate modified
    if "!modified!" == "0" (exit /b 0) else (set "downloaded=1")
)

@REM run as admin
if "!asdaemon!" == "1" (
    cacls "%SystemDrive%\System Volume Information" >nul 2>&1 || (
        if "!show!" == "1" (
            powershell -Command "Start-Process '%~snx0' -ArgumentList ' %*' -Verb RunAs"
        ) else (
            powershell -Command "Start-Process '%~snx0' -ArgumentList ' %*' -Verb RunAs -WindowStyle Hidden"
        )
        exit /b
    )
)

@REM prepare all plugins
call :prepare changed 1 !downloaded!

@REM no new version found
if "!changed!" == "0" (
    @echo [%ESC%[!infocolor!m信息%ESC%[0m] 当前已是最新版本，无需更新
) else (
    @REM wait for overwrite files
    timeout /t 1 /nobreak >nul 2>nul
)

@REM postclean
call :cleanworkspace "!temp!"

@REM startup
call :startclash

@REM regenerate auto update script
if "!regenerate!" == "1" call :generateupdatevbs

goto :eof


@REM parse and validate arguments
:argsparse
set result=false

if "%1" == "-a" set result=true
if "%1" == "--alpha" set result=true
if "!result!" == "true" (
    set "alpha=1"
    set result=false
    shift & goto :argsparse
)

if "%1" == "-b" set result=true
if "%1" == "--brief" set result=true
if "!result!" == "true" (
    set "brief=1"
    set result=false
    shift & goto :argsparse
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
        @echo [%ESC%[91m错误%ESC%[0m] 如果指定参数 "%ESC%[!warncolor!m--conf%ESC%[0m" 或者 "%ESC%[!warncolor!m-c%ESC%[0m" 则必须提供有效的%ESC%[!warncolor!m配置文件%ESC%[0m或%ESC%[!warncolor!m订阅%ESC%[0m
        @echo.
        goto :usage
    )

    if "!subscription:~0,8!" == "https://" set "isweblink=1"
    if "!subscription:~0,7!" == "http://" set "isweblink=1"
    if "!isweblink!" == "1" (
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
            set "shouldexit=1"

            @echo [%ESC%[91m错误%ESC%[0m] 无效的订阅链接 "%ESC%[!warncolor!m!subscription!%ESC%[0m"
            @echo.
            goto :eof
        ) 
        set "sublink=!subscription!"
    ) else (
        set "invalid=1"
        if "!subscription:~-5!" == ".yaml" (set "invalid=0") else (
            if "!subscription:~-4!" == ".yml" (set "invalid=0")
        )
        if "!invalid!" == "0" (
            set "configuration=!subscription!"
        ) else (
            set "shouldexit=1"

            @echo [%ESC%[91m错误%ESC%[0m] 无效的配置文件 "%ESC%[!warncolor!m!subscription!%ESC%[0m"，仅支持 "%ESC%[!warncolor!m.yaml%ESC%[0m" 和 "%ESC%[!warncolor!m.yml%ESC%[0m" 格式
            @echo.
            goto :eof
        )
    )
    shift & shift & goto :argsparse
)

if "%1" == "-d" set result=true
if "%1" == "--daemon" set result=true
if "!result!" == "true" (
    set "asdaemon=1"
    set result=false
    shift & goto :argsparse
)

if "%1" == "-e" set result=true
if "%1" == "--exclude" set result=true
if "!result!" == "true" (
    set "exclude=1"
    set result=false
    shift & goto :argsparse
)

if "%1" == "-f" set result=true
if "%1" == "--fix" set result=true
if "!result!" == "true" (
    set "repair=1"
    set result=false
    shift & goto :argsparse
)

if "%1" == "-g" set result=true
if "%1" == "--generate" set result=true
if "!result!" == "true" (
    set "regenerate=1"
    set result=false
    shift & goto :argsparse
)

if "%1" == "-h" set result=true
if "%1" == "--help" set result=true
if "!result!" == "true" (
    call :usage
)

if "%1" == "-i" set result=true
if "%1" == "--init" set result=true
if "!result!" == "true" (
    set "initflag=1"
    set result=false
    shift & goto :argsparse
)

if "%1" == "-k" set result=true
if "%1" == "--kill" set result=true
if "!result!" == "true" (
    set "killflag=1"
    set result=false
    shift & goto :argsparse
)

if "%1" == "-l" set result=true
if "%1" == "--love" set result=true
if "!result!" == "true" (
    if "!customize!" == "1" (
        set "drawheart=1"
        set result=false
        shift & goto :argsparse
    ) else (
        @echo [%ESC%[91m错误%ESC%[0m] 未知参数：%ESC%[91m%1%ESC%[0m
        @echo.
        goto :usage
    )
)

if "%1" == "-m" set result=true
if "%1" == "--meta" set result=true
if "!result!" == "true" (
    set "clashmeta=1"
    set result=false
    shift & goto :argsparse
)

if "%1" == "-n" set result=true
if "%1" == "--native" set result=true
if "!result!" == "true" (
    set "clashpremium=1"
    set result=false
    shift & goto :argsparse
)

if "%1" == "-o" set result=true
if "%1" == "--overload" set result=true
if "!result!" == "true" (
    set "reloadonly=1"
    set result=false
    shift & goto :argsparse
)

if "%1" == "-p" set result=true
if "%1" == "--purge" set result=true
if "!result!" == "true" (
    set "purgeflag=1"
    set result=false
    shift & goto :argsparse
)

if "%1" == "-q" set result=true
if "%1" == "--quick" set result=true
if "!result!" == "true" (
    set "quickflag=1"
    set result=false
    shift & goto :argsparse
)

if "%1" == "-r" set result=true
if "%1" == "--restart" set result=true
if "!result!" == "true" (
    set "restartflag=1"
    set result=false
    shift & goto :argsparse
)

if "%1" == "-s" set result=true
if "%1" == "--show" set result=true
if "!result!" == "true" (
    set "show=1"
    set result=false
    shift & goto :argsparse
)

if "%1" == "-t" set result=true
if "%1" == "--test" set result=true
if "!result!" == "true" (
    set "testflag=1"
    set result=false
    shift & goto :argsparse
)

if "%1" == "-u" set result=true
if "%1" == "--update" set result=true
if "!result!" == "true" (
    set "updateflag=1"
    set result=false
    shift & goto :argsparse
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
        @echo [%ESC%[91m错误%ESC%[0m] 无效的参数，如果指定 "%ESC%[!warncolor!m--workspace%ESC%[0m"，"%ESC%[!warncolor!m!param!%ESC%[0m"，则需提供有效的路径
        @echo.
        goto :usage
    )

    call :pathconvert directory "!param!"
    if not exist "!directory!" (
        call :makedirs success "!directory!"
        if "!success!" == "1" (rd "!directory!" /s /q >nul 2>nul) else (set "shouldexit=1")
    )

    if "!shouldexit!" == "1" (
        @echo [%ESC%[91m错误%ESC%[0m] 参数 "%ESC%[!warncolor!m--workspace%ESC%[0m" 指定的文件夹路径 "%ESC%[!warncolor!m!directory!%ESC%[0m" %ESC%[91m无效%ESC%[0m
        @echo.
        goto :eof
    )

    set "dest=!directory!"
    set result=false
    shift & shift & goto :argsparse
)

if "%1" == "-x" set result=true
if "%1" == "--metacubexd" set result=true
if "!result!" == "true" (
    set "metacubexd=1"
    set "yacd=0"
    set "zashboard=0"
    set result=false
    shift & goto :argsparse
)

if "%1" == "-y" set result=true
if "%1" == "--yacd" set result=true
if "!result!" == "true" (
    set "metacubexd=0"
    set "yacd=1"
    set "zashboard=0"
    set result=false
    shift & goto :argsparse
)

if "%1" == "-z" set result=true
if "%1" == "--zashboard" set result=true
if "!result!" == "true" (
    set "metacubexd=0"
    set "yacd=0"
    set "zashboard=1"
    set result=false
    shift & goto :argsparse
)

@REM will throw exception if this code not in here or delete it or merge with <if "%1" NEQ "">. why?
if "%1" == "" goto :eof

if "%1" NEQ "" (
    call :trim syntax "%~1"
    if "!syntax!" == "goto" (
        call :trim funcname "%~2"
        if "!funcname!" == "" (
            @echo [%ESC%[91m错误%ESC%[0m] 无效的语法，调用 "%ESC%[!warncolor!mgoto%ESC%[0m" 时必须提供函数名
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
@echo 使用方法：!batname! [%ESC%[!warncolor!m功能选项%ESC%[0m] [%ESC%[!warncolor!m其他参数%ESC%[0m]，支持 %ESC%[!warncolor!m-%ESC%[0m 和 %ESC%[!warncolor!m--%ESC%[0m 两种模式
@echo.
@echo 功能选项：
@REM @echo. if this line contains Chinese output, it will be garbled. Why? ? ? >_<
@echo -f, --fix             检查并尝试修复代理网络
@echo -h, --help            打印帮助信息
@echo -i, --init            利用 %ESC%[!warncolor!m--conf%ESC%[0m 提供的配置文件创建代理网络
@REM @echo. if this line contains Chinese output, it will be garbled. Why? ? ? >_<
@echo -k, --kill            退出网络代理程序
@REM @echo. if this line contains Chinese output, it will be garbled. Why? ? ? >_<
if "!customize!" == "1" (
    @echo -l, --love            当然是大声告诉我宝我爱她啦🤪🤪🤪
)
@REM @echo. if this line contains Chinese output, it will be garbled. Why? ? ? >_<
@echo -o, --overload        重新加载配置文件
@echo -p, --purge           关闭系统代理并禁止程序开机自启，取消自动更新
@REM @echo. if this line contains Chinese output, it will be garbled. Why? ? ? >_<
@echo -r, --restart         重启网络代理程序
@echo -t, --test            测试代理网络是否可用
@echo -u, --update          更有所有组件，包括 clash.exe、订阅、代理规则以及 IP 地址数据库等
echo.
@echo 其他参数：
@REM @echo. if this line contains Chinese output, it will be garbled. Why? ? ? >_<
@echo -a, --alpha           是否允许使用预览版，默认为稳定版，搭配 %ESC%[!warncolor!m-i%ESC%[0m 或者 %ESC%[!warncolor!m-u%ESC%[0m 使用
@REM @echo. if this line contains Chinese output, it will be garbled. Why? ? ? >_<
@echo -b, --brief           精简模式运行，没有明确配置dashboard情况下，无法使用可视化页面
@REM @echo. if this line contains Chinese output, it will be garbled. Why? ? ? >_<
@echo -c, --conf            配置文件，支持本地配置文件和订阅链接，默认为当前目录下的 %ESC%[!warncolor!mconfig.yaml%ESC%[0m
@REM @echo. if this line contains Chinese output, it will be garbled. Why? ? ? >_<
@echo -d, --daemon          后台静默执行，禁止打印日志
@REM @echo. if this line contains Chinese output, it will be garbled. Why? ? ? >_<
@echo -e, --exclude         更新时跳过代理集中配置的订阅
@REM @echo. if this line contains Chinese output, it will be garbled. Why? ? ? >_<
@echo -g, --generate        重新生成自动检查更新的脚本，搭配 %ESC%[!warncolor!m-u%ESC%[0m 使用
@REM @echo. if this line contains Chinese output, it will be garbled. Why? ? ? >_<
@echo -m, --meta            如果配置兼容，使用 clash.meta 代替 clash.premium，搭配 %ESC%[!warncolor!m-i%ESC%[0m 或 %ESC%[!warncolor!m-u%ESC%[0m 使用
@REM @echo. if this line contains Chinese output, it will be garbled. Why? ? ? >_<
@echo -n, --native          强制使用 clash.premium，搭配 %ESC%[!warncolor!m-i%ESC%[0m 或 %ESC%[!warncolor!m-u%ESC%[0m 使用
@echo -q, --quick           仅更新新订阅和代理规则，搭配 %ESC%[!warncolor!m-u%ESC%[0m 使用
@REM @echo. if this line contains Chinese output, it will be garbled. Why? ? ? >_<
@echo -s, --show            新窗口中执行，默认为当前窗口
@REM @echo. if this line contains Chinese output, it will be garbled. Why? ? ? >_<
@echo -w, --workspace       代理程序运行路径，默认为当前脚本所在目录
@REM @echo. if this line contains Chinese output, it will be garbled. Why? ? ? >_<
@echo -x, --metacubexd      使用 %ESC%[!warncolor!mmetacubexd%ESC%[0m 控制面板，搭配 %ESC%[!warncolor!m-i%ESC%[0m 或 %ESC%[!warncolor!m-u%ESC%[0m 使用
@REM @echo. if this line contains Chinese output, it will be garbled. Why? ? ? >_<
@echo -y, --yacd            使用 %ESC%[!warncolor!myacd%ESC%[0m 控制面板，搭配 %ESC%[!warncolor!m-i%ESC%[0m 或 %ESC%[!warncolor!m-u%ESC%[0m 使用
@REM @echo. if this line contains Chinese output, it will be garbled. Why? ? ? >_<
@echo -z, --zashboard       使用 %ESC%[!warncolor!mzashboard%ESC%[0m 控制面板，搭配 %ESC%[!warncolor!m-i%ESC%[0m 或 %ESC%[!warncolor!m-u%ESC%[0m 使用
@echo.

set "shouldexit=1"
goto :eof


@REM draw heart
:printheart
set "wthitespace="  

@echo.
@echo !wthitespace!        *********           *********
@echo !wthitespace!    *****************   *****************
@echo !wthitespace!  *****************************************
@echo !wthitespace! *******************************************
@echo !wthitespace!*********************************************
@echo !wthitespace!**********************************************
@echo !wthitespace!**********************************************
@echo !wthitespace!**********************************************
if "!msterminal!" == "1" (
    @echo !wthitespace!***********  %ESC%[91m我的宝，我爱你 ♥♥♥%ESC%[0m  *************
) else (
    @echo !wthitespace!*********** %ESC%[91m我的宝，我爱你 ♥♥♥%ESC%[0m ***************
)

@echo !wthitespace!**********                        ***********
@echo !wthitespace! ******** %ESC%[91m因为有你，生活可爱了许多%ESC%[0m *********
@echo !wthitespace!  *****************************************
@echo !wthitespace!   ***************************************
@echo !wthitespace!    *************************************
@echo !wthitespace!     ***********************************
@echo !wthitespace!      *********************************
@echo !wthitespace!        *****************************
@echo !wthitespace!          *************************
@echo !wthitespace!            *********************
@echo !wthitespace!               ***************
@echo !wthitespace!                  *********
@echo !wthitespace!                     ***
@echo !wthitespace!                      *
@echo.
exit /b
goto :eof


@REM confirm download url and filename according parameters
:versioned <geosite> <subfiles>
set "%~1=0"
set "content="
set "needgeosite=0"

@REM yacd dashboard
if "!metacubexd!" == "0" if "!zashboard!" == "0" if "!dashboard!" NEQ "" if exist "!dashboard!\yacd.ico" set "yacd=1"

@REM metacubexd dashboard
if "!yacd!" == "0" if "!zashboard!" == "0" if "!dashboard!" NEQ "" if exist "!dashboard!\maskable-icon-512x512.png" set "metacubexd=1"

@REM zashboard dashboard
if "!yacd!" == "0" if "!metacubexd!" == "0" if "!dashboard!" NEQ "" if exist "!dashboard!\pwa-maskable-512x512.png" set "zashboard=1"

@REM force use clash.premium
if "!clashpremium!" == "1" (
    set "clashmeta=0"
    goto :eof
)

for /f "tokens=*" %%i in ('findstr /i /r "GEOSITE,.*" "!configfile!"') do set "content=!content!;%%i"
call :searchrules notfound "!content!"

if "!notfound!" == "1" (
    for /f "tokens=*" %%i in ('findstr /i /r "SUB-RULE,.* AND,.* OR,.* NOT,.* IN-TYPE,.*" "!configfile!"') do set "content=!content!;%%i"
    call :searchrules notfound "!content!"
) else (
    set "needgeosite=1"
)

@REM rulesets include GEOSITE, must be clash.meta
if "!notfound!" == "0" (set "clashmeta=1")
if "!clashmeta!" == "1" (
    set "%~1=!needgeosite!"
    set "clashpremium=0"
    goto :eof
)

@REM clash.meta not support SCRIPT rule
set "content="
for /f "tokens=*" %%i in ('findstr /i /r "SCRIPT,.*" "!configfile!"') do set "content=!content!;%%i"
call :searchrules notfound "!content!"

@REM rulesets include SCRIPT, must be clash.premium
if "!notfound!" == "0" (
    set "clashmeta=0"
    set "clashpremium=1"
    goto :eof
)

@REM include sniffer, must be clash.meta
for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"sniffer:[ ]*" "!configfile!"') do (
    call :trim sniffer %%a
    if "!sniffer!" == "sniffer" (
        set "clashmeta=1"
        set "clashpremium=0"
        goto :eof
    )
)

@REM proxy-groups include exclude-filter, must be clash.meta
for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"^[ ][ ]*exclude-filter:[ ][ ]*.*" "!configfile!"') do (
    call :trim excludekey %%a

    if /i "!excludekey:~0,1!" NEQ "#" (
        set "clashmeta=1"
        set "clashpremium=0"
        goto :eof
    )
)

@REM include vless or hysteria, must be clash.meta
call :trim subfiles "%~2"

set "subfiles=!configfile!,!subfiles!"
set "tempfile=!temp!\clashproxies.txt"
set "regex=^\s+(type:\s+(vless|hysteria)|client-fingerprint:\s+|flow:\s+xtls-).*"

del /f /q "!tempfile!" >nul 2>nul
for %%f in (!subfiles!) do (
    if "%%f" NEQ "" if exist %%f (
        call :findby "%%f" "!regex!" "!tempfile!" 1
        if exist "!tempfile!" (
            set "clashmeta=1"
            set "clashpremium=0"
            del /f /q "!tempfile!" >nul 2>nul
            goto :eof
        )   
    )
)

@REM proxy-groups include filter, must be clash.meta
@REM set "tempfile=!temp!\clashproxygroups.txt"
@REM set "regex=^\s+type:\s+(select|url-test|fallback|load-balance|relay).*"

@REM del /f /q "!tempfile!" >nul 2>nul
@REM call :findby "!configfile!" "!regex!" "!tempfile!" 10
@REM if exist "!tempfile!" (
@REM     for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"^[ ][ ]*filter:[ ][ ]*.*" "!tempfile!"') do (
@REM         call :trim includekey %%a
@REM         if /i "!includekey:~0,1!" NEQ "#" (
@REM             set "clashmeta=1"
@REM             set "clashpremium=0"
@REM             del /f /q "!tempfile!" >nul 2>nul
@REM             goto :eof
@REM         )
@REM     )

@REM     del /f /q "!tempfile!" >nul 2>nul
@REM )

@REM old edittion
if exist "!dest!\clash.exe" ("!dest!\clash.exe" -v | findstr /i "Meta" >nul 2>nul && (
        set "clashmeta=1"
        set "clashpremium=0"
    )
)
goto :eof


@REM quickly update subscriptions and rulesets
:quickupdate <edition>
set "%~1=0"

@REM configration
call :updateconfig 1

@REM subscriptions
if "!exclude!" == "0" call :updatesubs subfiles 1

@REM rulesets
call :updaterules 1

@REM detect new edition
set "clashedition=0"
if exist "!dest!\clash.exe" ("!dest!\clash.exe" -v | findstr /i "Meta" >nul 2>nul && (set "clashedition=1"))
call :versioned geositeneed !subfiles!

if "!clashedition!" NEQ "!clashmeta!" (
    set "%~1=1"
    if "!clashmeta!" == "1" (
        set "oldedition=clash.premium"
        set "newedition=clash.meta"
    ) else (
        set "oldedition=clash.meta"
        set "newedition=clash.premium"
    )
    @echo [%ESC%[!warncolor!m提示%ESC%[0m] 配置%ESC%[91m不兼容%ESC%[0m，代理程序需从 %ESC%[!warncolor!m!oldedition!%ESC%[0m 切换至 %ESC%[!warncolor!m!newedition!%ESC%[0m
    goto :eof
)

@REM reload
if "!changed!" == "1" (goto :reload) else (goto :eof)


@REM check if special rules are included
:searchrules <notfound> <text>
set "%~1=1"
set "rulesets=%~2"

for /F "tokens=1* delims=;" %%f in ("!rulesets!") do (
    :: set "rule=%%f"
    call :trim rule "%%f"
    if /i "!rule:~0,1!"=="-" (
        set "%~1=0"
        goto :eof
    )

    if "%%g" NEQ "" call :searchrules %~1 "%%g"
)
goto :eof


@REM update subscriptions
:updatesubs <subfiles> <force>
call :trim force "%~2"
if "!force!" == "" set "force=1"

if "!force!" == "1" (
    @echo [%ESC%[!infocolor!m信息%ESC%[0m] 检查并更新订阅，仅刷新 %ESC%[!warncolor!mHTTP%ESC%[0m 类型的订阅
)

call :filerefresh changed "^\s+(health-check:(\s+)?|<<:\s+\*.*)$|^proxy-providers:(\s+)?$" "www.gstatic.com cp.cloudflare.com" "!force!" subfiles "proxies"
set "%~1=!subfiles!"
goto :eof


:splitpath <directory> <filename> <filepath>
set "%~1=%~dp3"
set "%~2=%~nx3"

if "!%~1:~-1!" == "\" set "%~1=!%~1:~0,-1!"
goto :eof


@REM to absolute path
:pathconvert <result> <filename>
call :trim filepath %~2
set "%~1="

if "!filepath!" == "" goto :eof

@echo "!filepath!" | findstr ":" >nul 2>nul && (
    set "%~1=!filepath!"
    goto :eof
) || (
    if "!dest!" NEQ "" (set "basedir=!dest!") else (set "basedir=%~dp0")
    if "!basedir:~-1!" == "\" set "basedir=!basedir:~0,-1!"
    
    if "!filepath!" == "." (
        set "%~1=!basedir!"
        goto :eof
    )

    set "filepath=!filepath:/=\!"
    if "!filepath:~0,3!" == ".\\" (
        set "%~1=!basedir!\!filepath:~3!"
    ) else if "!filepath:~0,2!" == ".\" (
        set "%~1=!basedir!\!filepath:~2!"
    ) else (
        set "%~1=!basedir!\!filepath!"
    )
)
goto :eof


@REM connectivity
:checkconnect <result> <allowed>
@REM running status
set "%~1=0"
call :trim output "%~2"
if "!output!" == "" set "output=1"

call :isrunning status
if "!status!" == "0" (
    if "!output!" == "1" (
        @echo [%ESC%[!warncolor!m提示%ESC%[0m] 网络%ESC%[91m不可用%ESC%[0m，代理程序%ESC%[91m已退出%ESC%[0m
    )

    goto :eof
)

@REM call :systemproxy server
call :generateproxy server

@REM detect network is available
call :isavailable status "!output!" "https://www.google.com" "!server!"
set "%~1=!status!"
goto :eof


@REM check network
:isavailable <result> <allowed> <url> <proxyserver>
set "%~1=0"
call :trim output "%~2"
call :trim url "%~3"
call :trim proxyserver "%~4"

if "!output!" == "" set "output=1"
if "!url!" == "" set "url=https://www.google.com"

@REM check
set "statuscode=000"
if "!proxyserver!" == "" (
    for /f %%a in ('curl --retry 3 --retry-max-time 10 -m 5 --connect-timeout 5 -L -s -o nul -w "%%{http_code}" "!url!"') do set "statuscode=%%a"
) else (
    for /f %%a in ('curl -x !proxyserver! --retry 3 --retry-max-time 10 -m 5 --connect-timeout 5 -L -s -o nul -w "%%{http_code}" "!url!"') do set "statuscode=%%a"
)

if "!statuscode!" == "200" (
    set "%~1=1"
    if "!output!" == "1" (
        @echo [%ESC%[!infocolor!m信息%ESC%[0m] 代理网络不存在问题，能够%ESC%[!infocolor!m正常%ESC%[0m使用
    )
) else (
    set "%~1=0"
    if "!output!" == "1" (
        call :postprocess

        @echo [%ESC%[!warncolor!m提示%ESC%[0m] 代理网络%ESC%[91m不可用%ESC%[0m，可%ESC%[!warncolor!m再次测试%ESC%[0m或使用命令 "%ESC%[!warncolor!m!batname! -o%ESC%[0m" %ESC%[!warncolor!m重载%ESC%[0m 或者 "%ESC%[!warncolor!m!batname! -r%ESC%[0m" %ESC%[!warncolor!m重启%ESC%[0m 或者 "%ESC%[!warncolor!m!batname! -f%ESC%[0m" %ESC%[!warncolor!m修复%ESC%[0m
    )
)
goto :eof


@REM query proxy address
:generateproxy <result>
set "%~1="

call :systemproxy server
if "!server!" NEQ "" (
    set "%~1=!server!"
    goto :eof
)

@REM extract from config file
if exist "!configfile!" (
    call :istunenabled enabled
    if "!enabled!" == "1" goto :eof
    call :extractport port
    if "!port!" == "" goto :eof

    set "tips=[%ESC%[!warncolor!m提示%ESC%[0m] 系统代理%ESC%[91m未配置%ESC%[0m，是否设置？(%ESC%[!warncolor!mY%ESC%[0m/%ESC%[!warncolor!mN%ESC%[0m) "
    if "!msterminal!" == "1" (
        choice /t 5 /d y /n /m "!tips!"
    ) else (
        set /p "=!tips!" <nul
        choice /t 5 /d y /n
    )
    if !errorlevel! == 2 goto :eof

    call :enableproxy "127.0.0.1:!port!"
    set "%~1=127.0.0.1:!port!"
    goto :eof
)
goto :eof


@REM create if directory not exists
:makedirs <result> <directory>
set "%~1=0"
call :trim directory "%~2"
if "!directory!" == "" (
    @echo [%ESC%[!warncolor!m警告%ESC%[0m] 路径为空，创建目录失败
    goto :eof
)

if not exist "!directory!" (
    mkdir "!directory!"
    if "!errorlevel!" == "0" set "%~1=1"
) else (set "%~1=1")
goto :eof


@REM tun enabled
:istunenabled <enabled>
set "%~1=0"
set "text="

@REM not work in batch but works fine in cmd, why?
@REM for /f "tokens=*" %%a in ('findstr /i /r /c:"^tun:[ ]*" "!configfile!"') do set "text=%%a"

for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"tun:[ ]*" "!configfile!"') do set "text=%%a"

@REM not required
call :trim text "!text!"
if "!text!" == "tun" set "%~1=1"
goto :eof


@REM wintun
:downloadwintun <changed> <force>
set "%~1=0"

call :trim force "%~2"
if "!force!" == "" set "force=0"

@REM has been integrated in clash.meta
if "!clashmeta!" == "1" exit /b

@REM check if required
call :istunenabled enabled
if "!enabled!" == "0" exit /b

if "!force!" == "0" set "checkwintun=0"

@REM exists
if exist "!dest!\wintun.dll" if "!checkwintun!" == "0" goto :eof

set "content="
set "wintunurl=https://www.wintun.net"

for /f delims^=^"^ tokens^=2 %%a in ('curl --retry 5 --retry-max-time 60 --connect-timeout 15 -s -L "!wintunurl!" ^| findstr /i /r "builds/wintun-.*.zip"') do set "content=%%a"
call :trim content !content!

if "!content!" == "" (
    @echo [%ESC%[!warncolor!m警告%ESC%[0m] 无法获取 wintun 下载链接
    goto :eof
)

call :get_arch arch_version
if "!arch_version!" == "386" (
    set "arch_version=x86"
) else if "!arch_version!" == "armv7" (
    set "arch_version=arm"
)

set "wintunurl=!wintunurl!/!content!"
@echo [%ESC%[!infocolor!m信息%ESC%[0m] 开始下载 wintun，下载链接："!wintunurl!"

call :retrydownload "!wintunurl!" "!temp!\wintun.zip"
if exist "!temp!\wintun.zip" (
    @REM unzip
    tar -xzf "!temp!\wintun.zip" -C !temp! >nul 2>nul

    @REM clean workspace
    del /f /q "!temp!\wintun.zip" >nul 2>nul

    set "wintunfile=!temp!\wintun\bin\!arch_version!\wintun.dll"
    if exist "!wintunfile!" (
        @REM compare and update
        call :md5compare diff "!wintunfile!" "!dest!\wintun.dll"
        if "!diff!" == "1" (
            set "%~1=1"

            @REM delete if exist
            del /f /q "!dest!\wintun.dll" >nul 2>nul
            move "!wintunfile!" "!dest!" >nul 2>nul
        )
    ) else (
        @echo [%ESC%[!warncolor!m警告%ESC%[0m] 下载 wintun 成功，但未找到 wintun.dll
    )
) else (
    @echo [%ESC%[!warncolor!m警告%ESC%[0m] wintun 下载失败，请确认下载链接是否正确
)
goto :eof


@REM download binary file and data
:donwloadfiles <filenames> <outenable>
set "%~1="
call :trim outenable "%~2"
if "!outenable!" == "" set "outenable=1"

@REM deprecated and no longer needed, so set it to 0
set "outenable=0"

if "!outenable!" == "1" (
    @echo [%ESC%[!infocolor!m信息%ESC%[0m] 开始下载 clash.exe、域名及 IP 地址等数据
)

set "dfiles="

@REM download clash
if "!clashurl!" NEQ "" (
    if /i "!clashurl:~0,8!" NEQ "https://" (
        @echo [%ESC%[91m错误%ESC%[0m] clash.exe 下载地址解析失败："!clashurl!"
    ) else (
        @echo [%ESC%[!infocolor!m信息%ESC%[0m] 开始下载 %ESC%[!warncolor!mclash.exe%ESC%[0m 至 %ESC%[!warncolor!m!dest!%ESC%[0m

        call :retrydownload "!clashurl!" "!temp!\clash.zip"
        if exist "!temp!\clash.zip" (
            @REM unzip
            tar -xzf "!temp!\clash.zip" -C !temp! >nul 2>nul

            @REM clean workspace
            del /f /q "!temp!\clash.zip"
        ) else (
            @echo [%ESC%[91m错误%ESC%[0m] clash.exe 下载失败，下载链接："!clashurl!"
        )

        if exist "!temp!\!clashexe!" (
            @REM rename file
            ren "!temp!\!clashexe!" clash.exe

            set "dfiles=clash.exe"
        ) else (
            @echo [%ESC%[91m错误%ESC%[0m] "!temp!\!clashexe!" 不存在，下载链接："!clashurl!"
        )
    )
)

@REM download Country.mmdb
if "!countryurl!" NEQ "" (
    @echo [%ESC%[!infocolor!m信息%ESC%[0m] 开始下载 %ESC%[!warncolor!m!countryfile!%ESC%[0m 至 %ESC%[!warncolor!m!dest!%ESC%[0m

    call :retrydownload "!countryurl!" "!temp!\!countryfile!"
    if exist "!temp!\!countryfile!" (
        if "!dfiles!" == "" (
            set "dfiles=!countryfile!"
        ) else (
            set "dfiles=!dfiles!;!countryfile!"
        )
    ) else (
        @echo [%ESC%[91m错误%ESC%[0m] "!temp!\!countryfile!" 不存在，下载链接："!countryurl!"
    )
)

@REM download GeoSite.dat
if "!geositeurl!" NEQ "" (
    @echo [%ESC%[!infocolor!m信息%ESC%[0m] 开始下载 %ESC%[!warncolor!m!geositefile!%ESC%[0m 至 %ESC%[!warncolor!m!dest!%ESC%[0m

    call :retrydownload "!geositeurl!" "!temp!\!geositefile!" 
    if exist "!temp!\!geositefile!" (
        if "!dfiles!" == "" (
            set "dfiles=!geositefile!"
        ) else (
            set "dfiles=!dfiles!;!geositefile!"
        )
    ) else (
        @echo [%ESC%[91m错误%ESC%[0m] "!temp!\!geositefile!" 不存在，下载链接："!geositeurl!"
    )
)

@REM download GeoIP.dat
if "!geoipurl!" NEQ "" (
    @echo [%ESC%[!infocolor!m信息%ESC%[0m] 开始下载 %ESC%[!warncolor!m!geoipfile!%ESC%[0m 至 %ESC%[!warncolor!m!dest!%ESC%[0m

    call :retrydownload "!geoipurl!" "!temp!\!geoipfile!"
    if exist "!temp!\!geoipfile!" (
        if "!dfiles!" == "" (
            set "dfiles=!geoipfile!"
        ) else (
            set "dfiles=!dfiles!;!geoipfile!"
        )
    ) else (
        @echo [%ESC%[91m错误%ESC%[0m] "!temp!\!geoipfile!" 不存在，下载链接："!geoipurl!"
    )
)

set "%~1=!dfiles!"
goto :eof


@REM download with retry
:retrydownload <url> <filename>
set maxretries=3
call :trim downloadurl "%~1"
call :trim savepath "%~2"

if "!downloadurl!" == "" goto :eof
if "!savepath!" == "" goto :eof

set /a "count=0"

:retry
if !count! GEQ !maxretries! (
    @echo [%ESC%[91m错误%ESC%[0m] 文件 %ESC%[!warncolor!m!savepath!%ESC%[0m 下载失败，已达最大重试次数，请尝试再次执行此命令
    goto :eof
)

curl.exe --retry 5 --retry-max-time 120 --connect-timeout 20 -s -L -C - -o "!savepath!" "!downloadurl!"
set "failflag=!errorlevel!"
if not exist "!savepath!" set "failflag=1"

if "!failflag!" NEQ "0" (
    set /a "count+=1"
    
    @echo [%ESC%[!warncolor!m提示%ESC%[0m] 文件下载失败，正在进行第 %ESC%[!warncolor!m!count!%ESC%[0m 次重试，下载链接：!downloadurl!
    goto :retry
)
goto :eof


@REM compare
:detect <result> <filenames>
set "%~1=0"
set "filenames=%~2"

for %%a in (!filenames!) do (
    set "fname=%%a"

    if not exist "!temp!\!fname!" (
        @echo [%ESC%[91m错误%ESC%[0m] %ESC%[!warncolor!m!fname!%ESC%[0m 下载成功，但在 "!temp!" 文件夹下未找到，请确认是否已被删除
        goto :eof
    )

    if "!repair!" == "1" (
        @REM delete for triggering upgrade
        del /f /q "!dest!\!fname!" >nul 2>nul
    )

    @REM found new file
    if not exist "!dest!\!fname!" (
        set "%~1=1"
        call :upgrade "!filenames!"
        exit /b
    )

    @REM compare and update
    call :md5compare diff "!temp!\!fname!" "!dest!\!fname!"
    if "!diff!" == "1" (
        set "%~1=1"
        @echo [%ESC%[!infocolor!m信息%ESC%[0m] 发现新版本，文件名：%ESC%[!warncolor!m!fname!%ESC%[0m
        call :upgrade "!filenames!"
        exit /b
    )
)
goto :eof


@REM compare file with md5
:md5compare <changed> <source> <target>
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
:upgrade <filenames>
call :trim filenames "%~1"
if "!filenames!" == "" goto :eof

@REM make sure the file exists
set "existfiles="
for %%a in (!filenames!) do (
    if exist "!temp!\%%a" (
        if "!existfiles!" == "" (
            set "existfiles=%%a"
        ) else (
            set "existfiles=!existfiles!;%%a"
        )
    )
)

@REM file missing
if "!existfiles!" == "" goto :terminate

@REM stop clash
call :killprocesswrapper

@REM copy file
for %%a in (!filenames!) do (
    set "fname=%%a"

    @REM delete if old file exists
    if exist "!dest!\!fname!" (
        del /f /q "!dest!\!fname!" >nul 2>nul
    )
    
    @REM move new file to dest
    move "!temp!\!fname!" "!dest!" >nul 2>nul
)
goto :eof


@REM start
:startclash
call :isrunning status

if "!status!" == "0" (
    @REM startup clash
    call :executewrapper 0
) else (
    @echo [%ESC%[!infocolor!m信息%ESC%[0m] 订阅和代理规则更新完毕，即将重新加载
    goto :reload
)
goto :eof


@REM privilege escalation
:privilege <args> <show>
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
:execute <config>
call :trim cfile "%~1"
if "!cfile:~0,13!" == "goto :execute" (
    for /f "tokens=1-4 delims= " %%a in ("!cfile!") do set "cfile=%%c"
)

if "!cfile!" == "" (
    @echo [%ESC%[!infocolor!m信息%ESC%[0m] 配件文件路径无效，无法启动代理程序
    goto :eof
)

@REM privilege escalation
call :nopromptrunas success

call :splitpath filepath filename "!cfile!" 
"!filepath!\clash.exe" -d "!filepath!" -f "!cfile!"
goto :eof


@REM ensure all plugins exist
:prepare <changed> <force> <downloaded>
set "%~1=0"

call :trim downforce "%~2"
if "!downforce!" == "" set "downforce=0"

call :trim downloaded "%~3"
if "!downloaded!" == "" set "downloaded=0"

@REM check and update configration
if "!downloaded!" == "0" call :updateconfig "!downforce!"

@REM parse api server path
call :extractserver clashserver

@REM dashboard directory name
call :extractpath dashboard

@REM update subscriptions
if "!downloaded!" == "0" if "!exclude!" == "0" call :updatesubs subfiles "!downforce!"

@REM confirm download url and filename
call :versioned geositeneed !subfiles!

@REM clash.core or clash.premium is not available now
if "!clashpremium!" == "1" if not exist "!dest!\clash.exe" (
    @echo [%ESC%[91m错误%ESC%[0m] 代理程序 %ESC%[!warncolor!mclash.core%ESC%[0m 或 %ESC%[!warncolor!mclash.premium%ESC%[0m 暂时 %ESC%[91m无法使用%ESC%[0m，请选择 %ESC%[!warncolor!mclah.meta%ESC%[0m
    exit /b 1
)

if "!clashpremium!" == "0" if "!clashmeta!" == "0" (
    set "clashmeta=1"
    if exist "!dest!\clash.exe" ("!dest!\clash.exe" -v | findstr /i "Meta" >nul 2>nul || (
            set "clashpremium=1"
            set "clashmeta=0"
        )
    )
)

@REM confirm donwload url
call :confirmurl "!downforce!" "!geositeneed!"

@REM precleann workspace
call :cleanworkspace "!temp!"

@REM update dashboard
if "!downloaded!" == "0" call :dashboardupdate "!downforce!"

@REM update rulefiles
if "!downloaded!" == "0" call :updaterules "!downforce!"

@REM wintun.dll
call :downloadwintun newwintun "!downforce!"
set "%~1=!newwintun!"

@REM download clah.exe and geoip.data and so on
call :donwloadfiles filenames "!downforce!"

@REM judge file changed with md5
call :detect changed "!filenames!"
if "!changed!" == "1" set "%~1=!changed!"

goto :eof


@REM config autostart and auto update
:postprocess
call :privilege "goto :nopromptrunas" 0

@REM tips
call :outputhint

@REM add script to user path
call :addpath

@REM allow auto start when user login
call :autostart

@REM allow auto check update
call :autoupdate

@REM create shortcut on desktop
call :adddesktop
goto :eof


@REM parse clash server path
:extractserver <result>
set "%~1="
call :parsevalue serverhost "external-controller:[ ][ ]*"
if "!serverhost!" NEQ "" if "!serverhost:~0,1!" == ":" set "serverhost=127.0.0.1!serverhost!"

set "%~1=http://!serverhost!"
goto :eof


@REM privilege escalation
:executewrapper <shouldcheck>
call :trim shouldcheck "%~1"
if "!shouldcheck!" == "" set "shouldcheck=0"
if "!shouldcheck!" == "1" (call :prepare changed 0 0)

@REM verify config
if not exist "!dest!\clash.exe" (
    @echo [%ESC%[91m错误%ESC%[0m] 网络代理启动%ESC%[91m失败%ESC%[0m，"%ESC%[!warncolor!m!dest!\clash.exe%ESC%[0m" 缺失
    goto :eof
)

if not exist "!configfile!" (
    @echo [%ESC%[91m错误%ESC%[0m] 网络代理启动%ESC%[91m失败%ESC%[0m，配置文件 "%ESC%[!warncolor!m!configfile!%ESC%[0m" 不存在
    goto :eof
)

if "!verifyconf!" == "1" (
    set "testoutput=!temp!\clashtestout.txt"
    del /f /q "!testoutput!" >nul 2>nul

    @REM test config file
    "!dest!\clash.exe" -d "!dest!" -t "!configfile!" > "!testoutput!"

    @REM failed
    if !errorlevel! NEQ 0 (
        set "messages="
        if exist "!testoutput!" (
            for /f "tokens=1* delims==" %%a in ('findstr /i /r /c:"[ ]ERR[ ]\[config\][ ].*" "!testoutput!"') do set "messages=%%b"
            del /f /q "!testoutput!" >nul 2>nul
        )

        if "!messages!" == "" set "messages=文件校验失败，%ESC%[!warncolor!mclash.exe%ESC%[0m 或配置文件 %ESC%[!warncolor!m!configfile!%ESC%[0m 存在问题"
        @echo [%ESC%[91m错误%ESC%[0m] 网络代理启动%ESC%[91m失败%ESC%[0m，配置文件 "%ESC%[!warncolor!m!configfile!%ESC%[0m" 存在错误
        @echo [%ESC%[91m错误%ESC%[0m] 错误信息："!messages!"
        exit /b 1
    )

    @REM delete test output
    del /f /q "!testoutput!" >nul 2>nul
)

@REM run clash.exe with config
call :privilege "goto :execute !configfile!" !show!

for /l %%i in (1,1,6) do (
    @REM check running status
    call :isrunning status
    if "!status!" == "1" (
        @REM abnormal detect
        call :abnormal state

        if "!state!" == "1" (
            set "tips=[%ESC%[!warncolor!m警告%ESC%[0m] 代理进程%ESC%[91m异常%ESC%[0m，需%ESC%[91m删除并重新下载%ESC%[0m %ESC%[!warncolor!m!dest!\clash.exe%ESC%[0m，是否继续？(%ESC%[!warncolor!mY%ESC%[0m/%ESC%[!warncolor!mN%ESC%[0m) "
            if "!msterminal!" == "1" (
                choice /t 5 /d y /n /m "!tips!"
            ) else (
                set /p "=!tips!" <nul
                choice /t 5 /d y /n
            )
            if !errorlevel! == 1 (
                @REM delete exist clash.exe
                del /f /q "!dest!\clash.exe" >nul 2>nul

                @REM download and restart
                goto :restartprogram
            ) else (
                @echo [%ESC%[91m错误%ESC%[0m] 代理程序启动%ESC%[91m失败%ESC%[0m，请检查代理程序 %ESC%[!warncolor!m!dest!\clash.exe%ESC%[0m 是否完好
                goto :eof
            )
        ) else (
            if "!dashboard!" == "" (
                @echo [%ESC%[!infocolor!m信息%ESC%[0m] 代理程序启动%ESC%[!infocolor!m成功%ESC%[0m
            ) else (
                set "message=[%ESC%[!infocolor!m信息%ESC%[0m] 代理程序启动%ESC%[!infocolor!m成功%ESC%[0m，可在浏览器中访问 %ESC%[!warncolor!m!clashserver!/ui%ESC%[0m 查看详细信息"
                call :parsevalue secret "secret:[ ][ ]*"
                if "!secret!" NEQ "" set "message=!message!，密码：%ESC%[!warncolor!m!secret!%ESC%[0m"
                @echo !message!
            )
            call :postprocess
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
:searchport <result> <key>
set "%~1="
set "content="
call :trim key "%~2"
if "!key!" == "" goto :eof

@REM search
for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"^^!key!:[ ][ ]*[0-9][0-9]*" "!configfile!"') do set "content=%%b"
if "!content!" == "" goto :eof

call :trim port "!content!"
if "!port!" NEQ "" set "%~1=!port!"
goto :eof


@REM extract proxy port
:extractport <result>
set "%~1=7890"
set "keys=mixed-port;port;socks-port"
for %%a in (!keys!) do (
    call :searchport port "%%a"
    if "!port!" NEQ "" (
        set "%~1=!port!"
        exit /b
    )
)
goto :eof


@REM print warning if tun is disabled
:outputhint
call :istunenabled enabled
call :systemproxy server
if "!enabled!" == "1" (
    if "!server!" NEQ "" (
        @echo [%ESC%[!warncolor!m提示%ESC%[0m] 程序正以 %ESC%[!warncolor!mtun%ESC%[0m 模式运行，系统代理设置已被禁用
        call :disableproxy
    )
    goto :eof
)

call :extractport proxyport
if "!proxyport!" == "" set "proxyport=7890"

@REM set proxy
set "proxyserver=127.0.0.1:!proxyport!"
if "!proxyserver!" NEQ "!server!" (
    set "tips=[%ESC%[!warncolor!m提示%ESC%[0m] 系统代理%ESC%[91m未配置%ESC%[0m，是否设置？(%ESC%[!warncolor!mY%ESC%[0m/%ESC%[!warncolor!mN%ESC%[0m) "
    if "!msterminal!" == "1" (
        choice /t 5 /d y /n /m "!tips!"
    ) else (
        set /p "=!tips!" <nul
        choice /t 5 /d y /n
    )
    if !errorlevel! == 1 call :enableproxy "!proxyserver!"
)

@REM hint
@echo [%ESC%[!warncolor!m提示%ESC%[0m] 如果无法正常使用网络代理，请到 "%ESC%[!warncolor!m设置 -^> 网络和 Internet -^> 代理%ESC%[0m" 确认是否已设置为 "%ESC%[!warncolor!m!proxyserver!%ESC%[0m"
goto :eof


@REM add current script to user's environment path
:addpath
set "script_dir=%~dp0"
set "script_dir=!script_dir:~0,-1!"

@REM get current path values
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "current_path=%%b"

@REM check if already added
echo !current_path! | findstr /i /c:"!script_dir!" >nul
if !errorlevel! == 0 goto :eof

set "tips=[%ESC%[!warncolor!m提示%ESC%[0m] 是否将脚本路径 %ESC%[!warncolor!m!script_dir!%ESC%[0m 加入到用户 PATH 路径？(%ESC%[!warncolor!mY%ESC%[0m/%ESC%[!warncolor!mN%ESC%[0m) "
if "!msterminal!" == "1" (
    choice /t 5 /d y /n /m "!tips!"
) else (
    set /p "=!tips!" <nul
    choice /t 5 /d y /n
)

if !errorlevel! == 1 (
    @REM rewrite Path environment
    set "new_path=!current_path!;!script_dir!"
    reg add "HKCU\Environment" /v Path /t REG_EXPAND_SZ /d "!new_path!" /f >nul 2>nul

    @echo [%ESC%[!infocolor!m信息%ESC%[0m] 添加 %ESC%[!warncolor!m!script_dir!%ESC%[0m 到用户 PATH 路径%ESC%[!infocolor!m成功%ESC%[0m
) 

goto :eof


@REM restart program
:restartprogram
@REM check running status
call :isrunning status
if "!status!" == "1" (
    @REM kill process
    call :killprocesswrapper

    @REM check running status
    call :isrunning status

    if "!status!" == "1" (
        @echo [%ESC%[91m错误%ESC%[0m] 无法关闭进程，代理程序重启%ESC%[91m失败%ESC%[0m，请到%ESC%[91m任务管理中心%ESC%[0m手动退出 %ESC%[!warncolor!mclash.exe%ESC%[0m
        goto :eof
    )
)

@REM if alpha=1 may cause clash.premiun download failure
if "!clashpremiun!" == "1" set "alpha=0"

@REM startup
call :executewrapper 1
exit /b


@REM run as admin
:killprocesswrapper
call :isrunning status
if "!status!" == "0" goto :eof

call :privilege "goto :killprocess" 0

@REM detect
for /l %%i in (1,1,6) do (
    call :isrunning status
    if "!status!" == "0" (
        @echo [%ESC%[!infocolor!m信息%ESC%[0m] 代理程序关闭%ESC%[!infocolor!m成功%ESC%[0m，可使用 "%ESC%[!warncolor!m!batname! -r%ESC%[0m" 命令重启

        @REM disable proxy
        @REM call :istunenabled enabled
        @REM if "!enabled!" == "0" call :disableproxy

        call :disableproxy
        exit /b
    ) else (
        @REM wait a moment
        timeout /t 1 /nobreak >nul 2>nul
    )
)

@echo [%ESC%[91m错误%ESC%[0m] 代理程序关闭%ESC%[91m失败%ESC%[0m，请到%ESC%[91m任务管理中心%ESC%[0m手动退出 %ESC%[!warncolor!mclash.exe%ESC%[0m
goto :eof


@REM stop
:killprocess
tasklist | findstr /i "clash.exe" >nul 2>nul && taskkill /im "clash.exe" /f >nul 2>nul
set "exitcode=!errorlevel!"

@REM no prompt
call :nopromptrunas success

@REM detect
for /l %%i in (1,1,6) do (
    @REM detect running status
    call :isrunning status
    if "!status!" == "0" (
        @echo [%ESC%[!infocolor!m信息%ESC%[0m] 网络代理已关闭
        goto :eof
    ) else (
        @REM waiting for release
        timeout /t 1 /nobreak >nul 2>nul
    )
)

@echo [%ESC%[91m错误%ESC%[0m] 网络代理关闭失败，请到%ESC%[91m任务管理中心%ESC%[0m手动结束 %ESC%[!warncolor!mclash.exe%ESC%[0m 进程
goto :eof


@REM delect running status
:isrunning <result>
tasklist | findstr /i "clash.exe" >nul 2>nul && set "%~1=1" || set "%~1=0"
goto :eof


@REM check clash.exe process is normal
:abnormal <result>
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
:confirmurl <force> <enabled>
@REM country data
call :trim force "%~1"
if "!force!" == "" set "force=0"

@REM dashboard
if "!zashboard!" == "1" (
    set "metacubexd=0"
    set "yacd=0"
)
if "!metacubexd!" == "1" set "yacd=0"

call :trim geositeflag "%~2"
if "!geositeflag!" == "" set "geositeflag=0"

set "needdownload=0"
set "countryurl=https://raw.githubusercontent.com/Hackl0us/GeoIP2-CN/release/Country.mmdb"

@REM geosite/geoip filename
set "countryfile=Country.mmdb"
set "geositefile=GeoSite.dat"
set "geoipfile=GeoIP.dat"

@REM dashboard url
set "dashboardurl=https://github.com/Dreamacro/clash-dashboard/archive/refs/heads/gh-pages.zip"
set "dashdirectory=clash-dashboard-gh-pages"

set "clashurl="

@REM get os and cpu version
call :get_arch arch_version

if "!arch_version!" == "" (
    @echo [%ESC%[91m错误%ESC%[0m] 未知 操作系统 及 CPU 架构信息，获取 clash 下载链接失败
    goto :eof
)

@REM determine whether to download clash.exe
if not exist "!dest!\clash.exe" (set "needdownload=1") else (set "needdownload=!force!")

if "!clashmeta!" == "0" (
    @echo [%ESC%[!warncolor!m提示%ESC%[0m] %ESC%[!warncolor!mclash.premium%ESC%[0m 暂%ESC%[!warncolor!m不提供%ESC%[0m下载，建议切使用 %ESC%[!warncolor!m-m%ESC%[0m 或 %ESC%[!warncolor!m--meta%ESC%[0m 换到 %ESC%[!warncolor!mclash.meta%ESC%[0m

    set "clashexe=clash-windows-!arch_version!.exe"

    if "!needdownload!" == "1" (
        if "!alpha!" == "0" (
            for /f "tokens=1* delims=:" %%a in ('curl --retry 5 -s -L "https://api.github.com/repos/Dreamacro/clash/releases/tags/premium" ^| findstr /i /r /c:"https://github.com/Dreamacro/clash/releases/download/premium/clash-windows-!arch_version!-[^v][^3].*.zip"') do set "clashurl=%%b"
            
            @REM remove whitespace
            call :trim clashurl "!clashurl!"
            if !clashurl! == "" (
                @echo [%ESC%[91m错误%ESC%[0m] 获取 clash.premium 下载链接失败
                goto :eof
            )
            set "clashurl=!clashurl:~1,-1!"
        ) else (
            @echo [%ESC%[!warncolor!m警告%ESC%[0m] %ESC%[!warncolor!mclash.premium%ESC%[0m 预览版下载链接可能%ESC%[91m无法访问%ESC%[0m，想要使用该版本请确保网络正常
            set "clashurl=https://release.dreamacro.workers.dev/latest/clash-windows-!arch_version!-latest.zip"
        )
    )

    if "!yacd!" == "1" (
        set "dashboardurl=https://github.com/haishanh/yacd/archive/refs/heads/gh-pages.zip"
        set "dashdirectory=yacd-gh-pages"
    )

    if "!metacubexd!" == "1" (
        set "dashboardurl=https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip"
        set "dashdirectory=metacubexd-gh-pages"
    )

    if "!zashboard!" == "1" (
        set "dashboardurl=https://github.com/Zephyruso/zashboard/archive/refs/heads/gh-pages.zip"
        set "dashdirectory=zashboard-gh-pages"
    )
) else (
    set "clashexe=mihomo-windows-!arch_version!.exe"
    set "geositeurl=https://raw.githubusercontent.com/Loyalsoldier/domain-list-custom/release/geosite.dat"
    set "geoipurl=https://raw.githubusercontent.com/Loyalsoldier/geoip/release/geoip-only-cn-private.dat"

    if "!needdownload!" == "1" (
        if "!alpha!" == "1" (
            for /f "tokens=1* delims=:" %%a in ('curl --retry 5 -s -L "https://api.github.com/repos/MetaCubeX/mihomo/releases?prerelease=true&per_page=10" ^| findstr /i /r "https://github.com/MetaCubeX/mihomo/releases/download/Prerelease-Alpha/mihomo-windows-!arch_version!-alpha-.*.zip"') do set "clashurl=%%b"
        ) else (
            for /f "tokens=1* delims=:" %%a in ('curl --retry 5 -s -L "https://api.github.com/repos/MetaCubeX/mihomo/releases/latest?per_page=1" ^| findstr /i /r "https://github.com/MetaCubeX/mihomo/releases/download/.*/mihomo-windows-!arch_version!-v[0-9]*\.[0-9]*\.[0-9]*.zip"') do set "clashurl=%%b"
        )

        call :trim clashurl "!clashurl!"
        if !clashurl! == "" (
            if "!alpha!" == "1" (set "version=预览版") else (set "version=稳定版")
            @echo [%ESC%[91m错误%ESC%[0m] 获取 clash.meta 下载链接失败，版本："!version!"
            goto :eof
        )

        set "clashurl=!clashurl:~1,-1!"
    )

    @REM geosite.data download url
    if "!geositeflag!" == "0" (
        set "geositeurl="
    ) else (
        for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"^[ ][ ]*geosite:[ ][ ]*" "!configfile!"') do (
            call :trim geositekey %%a

            @REM commented
            if /i "!geositekey:~0,1!" NEQ "#" call :trim geositeurl %%b
        )
    )

    @REM geodata-mode
    set "geodatamode=false"
    for /f "tokens=1,2 delims=:" %%a in ('findstr /i /r /c:"^geodata-mode:[ ][ ]*" "!configfile!"') do (
        call :trim gmn %%a

        @REM commented
        if /i "!gmn:~0,1!" NEQ "#" call :trim geodatamode %%b
    )

    @REM geoip.data
    if "!geodatamode!" == "false" (
        set "geoipurl="

        for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"^[ ][ ]*mmdb:[ ][ ]*" "!configfile!"') do (
            call :trim mmdbkey %%a

            @REM commented
            if /i "!mmdbkey:~0,1!" NEQ "#" call :trim countryurl %%b
        )
    ) else (
        set "countryurl="

        for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"^[ ][ ]*geoip:[ ][ ]*http.*://" "!configfile!"') do (
            call :trim geoipkey %%a
            
            @REM commented
            if /i "!geoipkey:~0,1!" NEQ "#" call :trim geoipurl %%b
        )
    )

    if "!yacd!" == "1" (
        set "dashboardurl=https://github.com/MetaCubeX/Yacd-meta/archive/refs/heads/gh-pages.zip"
        set "dashdirectory=Yacd-meta-gh-pages"
    ) else if "!metacubexd!" == "1" (
        set "dashboardurl=https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip"
        set "dashdirectory=metacubexd-gh-pages"
    ) else (        
        set "dashboardurl=https://github.com/Zephyruso/zashboard/archive/refs/heads/gh-pages.zip"
        set "dashdirectory=zashboard-gh-pages"
    )
)

@REM clashurl
call :generateurl clashurl "!clashurl!" "clash.exe" "!force!"

@REM dashboardurl
if "!dashboard!" == "" (
    @REM don't need dashboard
    set "dashboardurl="
) else (
    set "needdash=!force!"
    if not exist "!dashboard!\index.html" set "needdash=1"
    if "!needdash!" == "0" (
        set "dashboardurl="
    ) else (
        call :ghproxywrapper dashboardurl !dashboardurl!
    )
)

@REM countryurl
call :generateurl countryurl "!countryurl!" "!countryfile!" "!force!"

@REM geositeurl
call :generateurl geositeurl "!geositeurl!" "!geositefile!" "!force!"

@REM geoipurl
call :generateurl geoipurl "!geoipurl!" "!geoipfile!" "!force!"
goto :eof


@REM generate real download url
:generateurl <result> <url> <filename> <force>
set "%~1="

call :trim url "%~2"
if "!url!" == "" goto :eof

call :trim filename "%~3"
if "!filename!" == "" goto :eof

if not exist "!dest!\!filename!" (set "needdownload=1") else (set "needdownload=!force!")
if "!needdownload!" == "0" goto :eof

call :ghproxywrapper downloadurl !url!

set "%~1=!downloadurl!"
goto :eof


@REM get cpu and os version, see: https://github.com/MetaCubeX/mihomo/releases
:get_arch <version>
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
:trim <result> <rawtext>
set "rawtext=%~2"
set "%~1="
if "!rawtext!" == "" goto :eof

for /f "tokens=* delims= " %%a in ("!rawtext!") do set "rawtext=%%a"

@REM for /l %%a in (1,1,100) do if "!rawtext:~-1!"==" " set "rawtext=!rawtext:~0,-1!"

@REM for speed, iteration set to 10
for /l %%a in (1,1,10) do if "!rawtext:~-1!"==" " set "rawtext=!rawtext:~0,-1!"

set "%~1=!rawtext!"
goto :eof


@REM wrapper github
:ghproxywrapper <result> <rawurl>
set "%~1="
call :trim rawurl %~2
if "!rawurl!" == "" goto :eof

@REM github proxy list: https://github.com/XIU2/UserScript/blob/master/GithubEnhanced-High-Speed-Download.user.js
set proxy_urls[0]=https://ghproxy.cfd
set proxy_urls[1]=https://gh-proxy.com
set proxy_urls[2]=https://gh.ddlc.top
set proxy_urls[3]=https://hub.gitmirror.com
set proxy_urls[4]=https://proxy.api.030101.xyz

@REM random [0, 4]
set /a num=!random! %% 5
set "ghproxy=!proxy_urls[%num%]!"

@REM github proxy
if "!rawurl:~0,18!" == "https://github.com" set "rawurl=!ghproxy!/!rawurl!"
if "!rawurl:~0,33!" == "https://raw.githubusercontent.com" set "rawurl=!ghproxy!/!rawurl!"
if "!rawurl:~0,34!" == "https://gist.githubusercontent.com" set "rawurl=!ghproxy!/!rawurl!"

set "%~1=!rawurl!"
goto :eof


@REM search keywords with powershell
:findby <filepath> <regex> <resultfile> <lines>
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
:removequotes <result> <str>
set "%~1="
call :trim str "%~2"
if "!str!" == "" goto :eof

if !str:~0^,1!!str:~-1! equ "" set "str=!str:~1,-1!"
if "!str:~0,1!!str:~0,1!" == "''" set "str=!str:~1!"
if "!str:~-1!!str:~-1!" == "''" set "str=!str:~0,-1!"
set "%~1=!str!"
goto :eof


@REM query value from yaml
:parsevalue <result> <regex>
set "%~1="
set "regex=%~2"
if "!regex!" == "" goto :eof

set "key="
set "text="
for /f "tokens=1* delims=:" %%a in ('findstr /i /r /c:"!regex!" "!configfile!"') do (
    set "key=%%a"
    set "text=%%b"
)

call :trim key "!key!"
if "!key!" == "" goto :eof
@REM commened 
if "!key:~0,1!" == "#" goto :eof

call :removequotes value "!text!"
set "%~1=!value!"
goto :eof


@REM reload config
:reload
if not exist "!configfile!" goto :eof

@REM parse api server path
if "!clashserver!" == "" call :extractserver clashserver

if "!clashserver!" == "" (
    @echo [%ESC%[91m错误%ESC%[0m] %ESC%[91m不支持%ESC%[0m重载，可使用 "%ESC%[!warncolor!m!batname! -r%ESC%[0m" 重启或者在文件 "%ESC%[!warncolor!m!configfile!%ESC%[0m" 配置 "%ESC%[!warncolor!mexternal-controller%ESC%[0m" 属性以启用该功能
    goto :eof
)

set "clashapi=!clashserver!/configs?force=true"

@REM secret
call :parsevalue secret "secret:[ ][ ]*"

@REM running detect
call :isrunning status

if "!status!" == "1" (
    @REM '\' to '\\'
    set "filepath=!configfile:\=\\!"

    @REM call api for reload
    set "statuscode=000"
    set "output=!temp!\clashout.txt"
    if exist "!output!" del /f /q "!output!" >nul 2>nul

    if "!secret!" NEQ "" (
        for /f %%a in ('curl --retry 3 -L -s -o "!output!" -w "%%{http_code}" -H "Content-Type: application/json" -H "Authorization: Bearer !secret!" -X PUT -d "{""path"":""!filepath!""}" "!clashapi!"') do set "statuscode=%%a"
    ) else (
        for /f %%a in ('curl --retry 3 -L -s -o "!output!" -w "%%{http_code}" -H "Content-Type: application/json" -X PUT -d "{""path"":""!filepath!""}" "!clashapi!"') do set "statuscode=%%a"
    )

    if "!statuscode!" == "204" (
        @echo [%ESC%[!infocolor!m信息%ESC%[0m] 网络代理程序重载%ESC%[!infocolor!m成功%ESC%[0m，祝你使用愉快
        call :postprocess
    ) else if "!statuscode!" == "401" (
        @echo [%ESC%[!infocolor!m信息%ESC%[0m] %ESC%[!warncolor!msecret%ESC%[0m 已被修改，请使用 "%ESC%[!warncolor!m!batname! -r%ESC%[0m" 重启
    ) else (
        set "content="

        if exist "!output!" (
            @REM read output
            for /f "delims=" %%a in (!output!) do set "content=%%a"
        )

        @echo [%ESC%[91m错误%ESC%[0m] 网络代理程序重载%ESC%[91m失败%ESC%[0m，请检查配置文件 "%ESC%[!warncolor!m!configfile!%ESC%[0m" 是否有效
        if "!content!" NEQ "" (
            @echo [%ESC%[91m错误%ESC%[0m] 错误信息："!content!"
        )

        @echo.
    )

    @REM delete
    del /f /q "!output!" >nul 2>nul
) else (
    @echo [%ESC%[91m错误%ESC%[0m] 网络代理程序%ESC%[91m未启动%ESC%[0m，可使用命令 "%ESC%[!warncolor!m!batname! -r%ESC%[0m" 启动
)
goto :eof


@REM update config
:updateconfig <force>
call :trim force "%~1"
if "!force!" == "" set "force=1"
if exist "!configfile!" if "!force!" == "0" goto :eof

set "downloadpath=!temp!\clashconf.yaml"
del /f /q "!downloadpath!" >nul 2>nul

@REM extract remote config url
set "subfile=!dest!\subscriptions.txt"
set "subscription="

if exist "!subfile!" (
    for /f "tokens=*" %%a in ('findstr /i /r /c:"^http.*://" "!subfile!"') do set "subscription=%%a"
    if "!subscription!" NEQ "" (
        call :trim subscription "!subscription!"
        if "!subscription:~0,1!" NEQ "#" set "remoteurl=!subscription!"
    )
)

if "!enableremoteconf!" == "1" if "!remoteurl!" NEQ "" (
    curl.exe --retry 5 --retry-max-time 90 -m 120 --connect-timeout 15 -H "User-Agent: Clash" -s -L -C - "!remoteurl!" > "!downloadpath!"
    if not exist "!downloadpath!" (
        @echo [%ESC%[!warncolor!m警告%ESC%[0m] 配置文件下载失败，如有需要，请重试或点击 %ESC%[!warncolor!m!remoteurl!%ESC%[0m 手动下载并替换
        goto :eof
    )

    if exist "!dest!\clash.exe" (
        @REM check file
        for %%a in ("!downloadpath!") do set "filesize=%%~za"
        if !filesize! LSS 32 (
            del /f /q "!downloadpath!" >nul 2>nul
            @echo [%ESC%[!warncolor!m警告%ESC%[0m] 配置文件下载失败，如有需要，请重试或点击 %ESC%[!warncolor!m!remoteurl!%ESC%[0m 手动下载并替换
            exit /b 1
        )
        
        @REM test config file
        "!dest!\clash.exe" -d "!dest!" -t -f "!downloadpath!" >nul 2>nul

        @REM failed
        if !errorlevel! NEQ 0 (
            @echo [%ESC%[91m错误%ESC%[0m] 配置文件 %ESC%[!warncolor!m!remoteurl!%ESC%[0m 存在错误，无法更新
            del /f /q "!downloadpath!" >nul 2>nul
            exit /b 1
        )
    )

    @REM compare with md5
    call :md5compare diff "!downloadpath!" "!configfile!"
    if "!diff!" == "0" (
        del /f /q "!downloadpath!" >nul 2>nul
        goto :eof
    )

    set "backupfile=config.yaml.bak"
    @echo [%ESC%[!infocolor!m信息%ESC%[0m] 发现较新配置，原有文件将备份为 %ESC%[!warncolor!m!dest!\!backupfile!%ESC%[0m

    @REM backup
    del /f /q "!dest!\!backupfile!" >nul 2>nul
    ren "!configfile!" !backupfile!

    @REM move new configration file to dest
    move "!downloadpath!" "!configfile!" >nul 2>nul
)
goto :eof


@REM update rules
:updaterules <force>
call :trim force "%~1"
if "!force!" == "" set "force=1"

if "!force!" == "1" (
    @echo [%ESC%[!infocolor!m信息%ESC%[0m] 开始检查并更新类型为 %ESC%[!warncolor!mHTTP%ESC%[0m 的代理规则
)

call :filerefresh changed "^\s+behavior:\s+.*" "www.gstatic.com cp.cloudflare.com" "!force!" rulefiles "payload"
goto :eof


@REM refresh subsribe and rulesets
:filerefresh <result> <regex> <filter> <force> <filepaths> <check>
set "%~1=0"
set "regex=%~2"
set "%~5="

call :trim filter "%~3"
if "!filter!" == "" set "filter=www.gstatic.com cp.cloudflare.com"

call :trim check "%~6"

call :trim force "%~4"
if "!force!" == "" set "force=1"

if "!regex!" == "" (
    @echo [%ESC%[!warncolor!m警告%ESC%[0m] 未指定关键信息，跳过更新
    goto :eof
)

set texturls=
set localfiles=

if not exist "!configfile!" goto :eof

@REM temp file
set "tempfile=!temp!\clashupdate.txt"
set "filepaths=" 

call :findby "!configfile!" "!regex!" "!tempfile!" 5
if not exist "!tempfile!" (
    if "!force!" == "0" goto :eof

    @echo [%ESC%[!warncolor!m警告%ESC%[0m] 未发现订阅或代理规则相关配置，跳过更新，文件："!configfile!"
    goto :eof
)

@REM urls and file path
for /f "tokens=1* delims=:" %%i in ('findstr /i /r /c:"^[ ][ ]*url:[ ][ ]*http.*://.*" !tempfile!') do (
    call :trim propertity %%i
    if "!propertity:~0,1!" NEQ "#" (
        @echo "%%j" | findstr /i "!filter!" >nul 2>nul || set "texturls=!texturls!,%%j"
    )
)

for /f "tokens=1* delims=:" %%i in ('findstr /i /r /c:"^[ ][ ]*path:[ ][ ]*.*" !tempfile!') do (
    call :trim propertity %%i
    if "!propertity:~0,1!" NEQ "#" (
        set "localfiles=!localfiles!,%%j"
    )
)

for %%r in (!localfiles!) do (
    @REM generate file path
    call :pathconvert tfile %%r
    if "!tfile!" == "" (
        @echo [%ESC%[91m错误%ESC%[0m] 配置无效，订阅或代理规则更新失败
        goto :eof  
    )

    set "filepaths=!filepaths!,!tfile!"
    for /f "tokens=1* delims=," %%u in ("!texturls!") do (
        call :trim url %%u
        set "texturls=%%v"

        if /i "!url:~0,8!"=="https://" (
            @REM ghproxy
            call :ghproxywrapper url !url!

            set "needdownload=0"
            if not exist "!tfile!" set "needdownload=1"
            if "!force!" == "1" set "needdownload=1"
            @REM should download
            if "!needdownload!" == "1" (
                @REM get directory
                call :splitpath filepath filename "!tfile!"

                @REM mkdir if not exists
                call :makedirs success "!filepath!"

                @REM request and save
                del /f /q "!temp!\!filename!" >nul 2>nul
                call :retrydownload "!url!" "!temp!\!filename!"

                @REM check file size
                set "filesize=0"
                if exist "!temp!\!filename!" (
                    for %%a in ("!temp!\!filename!") do set "filesize=%%~za"
                )

                @REM check file content
                call :verify match "!temp!\!filename!" "!check!"

                if !filesize! GTR 16 if "!match!" == "1" (
                    @REM delete if old file exists
                    del /f /q "!tfile!" >nul 2>nul

                    @REM move new file to dest
                    move "!temp!\!filename!" "!filepath!" >nul 2>nul

                    @REM changed status 
                    set "%~1=1"
                ) else (
                    @echo [%ESC%[91m错误%ESC%[0m] 文件 %ESC%[!warncolor!m!filename!%ESC%[0m 下载失败，下载链接："!url!"
                )
            )
        )
    )
)

set "%~5=!filepaths!"
@REM delete tempfile
if exist "!tempfile!" del /f /q "!tempfile!" >nul 2>nul
goto :eof


@REM extract dashboard path
:extractpath <result>
set "%~1="

if not exist "!configfile!" goto :eof

set "keyname="
set "content="
for /f "tokens=1,* delims=:" %%a in ('findstr /i /r /c:"external-ui:[ ][ ]*" "!configfile!"') do (
    set "keyname=%%a"
    set "content=%%b"
)

@REM not found 'external-ui' configuration in config file
call :trim keyname "!keyname!"

if "!keyname!" NEQ "external-ui" (
    set "flag=1"
    if "!keyname!" NEQ "" set "flag=0"
    if "!brief!" == "1" set "flag=0"
    if "!clashserver!" == "" set "flag=0"

    if "!flag!" == "0" goto :eof

    set "tmpconfig=!configfile!.tmp"

    @REM append 'external-ui' configuration
    @echo external-ui: dashboard > "!tmpconfig!"
    type "!configfile!" >> "!tmpconfig!"

    @REM replace config file
    del /f /q "!configfile!" >nul 2>nul
    move "!tmpconfig!" "!configfile!" >nul 2>nul

    @REM reset
    set "tmpconfig="
    set "content=dashboard"
)

call :trim content "!content!"
if "!content!" == "" goto :eof

call :pathconvert directory "!content!"
set "%~1=!directory!"
goto :eof


@REM check file is validate
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

@REM not required
call :trim text "!text!"

if "!text!" == "!check!" set "%~1=1"
goto :eof


@REM upgrade dashboard
:dashboardupdate <force>
call :trim force "%~1"
if "!force!" == "" set "force=0"

if "!dashboardurl!" == "" (
    if "!force!" == "0" goto :eof

    @echo [%ESC%[!infocolor!m信息%ESC%[0m] 控制面板%ESC%[!warncolor!m未启用%ESC%[0m，跳过更新
    goto :eof
)

if "!dashboard!" == "" (
    @echo [%ESC%[91m错误%ESC%[0m] 无法获取控制面板保存路径
    goto :eof
)

@REM exists
if exist "!dashboard!\index.html" if "!force!" == "0" goto :eof
call :makedirs success "!dashboard!"

@echo [%ESC%[!infocolor!m信息%ESC%[0m] 开始下载并更新控制面板
call :retrydownload "!dashboardurl!" "!temp!\dashboard.zip"

if not exist "!temp!\dashboard.zip" (
    @echo [%ESC%[!warncolor!m警告%ESC%[0m] 控制面板下载失败，下载链接："!dashboardurl!"
    goto :eof
)

@REM unzip
tar -xzf "!temp!\dashboard.zip" -C !temp! >nul 2>nul
del /f /q "!temp!\dashboard.zip" >nul 2>nul

@REM base path and directory name
call :splitpath dashpath dashname "!dashboard!"
if "!dashpath!" == "" (
    @echo [%ESC%[91m错误%ESC%[0m] 无法获取控制面板保存路径
    goto :eof
)

if "!dashname!" == "" (
    @echo [%ESC%[91m错误%ESC%[0m] 无法获取控制面板文件夹名
    goto :eof
)

@REM rename
ren "!temp!\!dashdirectory!" !dashname!

@REM replace if dashboard download success
dir /a /s /b "!temp!\!dashname!" | findstr . >nul && (
    call :replacedir "!temp!\!dashname!" "!dashboard!"
    @echo [%ESC%[!infocolor!m信息%ESC%[0m] 控制面板已更新至最新版本
) || (
    @echo [%ESC%[!warncolor!m警告%ESC%[0m] 控制面板下载失败，下载链接："!dashboardurl!"
)
goto :eof


@REM overwrite files
:replacedir <src> <dest>
set "src=%~1"
set "target=%~2"

if "!src!" == "" (
    @echo [%ESC%[!warncolor!m警告%ESC%[0m] 移动失败，源文件夹路径为空
    goto :eof
)

if "!target!" == "" (
    @echo [%ESC%[!warncolor!m警告%ESC%[0m] 移动失败，目标路径为空
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
:cleanworkspace
set "directory=%~1"
if "!directory!" == "" set "directory=!temp!"

if exist "!directory!\clash.zip" del /f /q "!directory!\clash.zip" >nul
if exist "!directory!\clash.exe" del /f /q "!directory!\clash.exe" >nul

@REM wintun
if exist "!directory!\wintun.zip" del /f /q "!directory!\wintun.zip"
if exist "!directory!\wintun" rd "!directory!\wintun" /s /q >nul 2>nul

if "!clashexe!" NEQ "" (
    if exist "!directory!\!clashexe!" del /f /q "!directory!\!clashexe!" >nul
)

if "!countryfile!" NEQ "" (
    if exist "!directory!\!countryfile!" del /f /q "!directory!\!countryfile!" >nul
)

if "!geositefile!" NEQ "" (
    if exist "!directory!\!geositefile!" del /f /q "!directory!\!geositefile!" >nul
)

if "!geoipfile!" NEQ "" (
    if exist "!directory!\!geoipfile!" del /f /q "!directory!\!geoipfile!" >nul
)

@REM delete directory
if "!dashdirectory!" NEQ "" (
    if exist "!directory!\!dashdirectory!" rd "!directory!\!dashdirectory!" /s /q >nul
)

if "!dashboard!" == "" goto :eof
if exist "!directory!\!dashboard!.zip" del /f /q "!directory!\!dashboard!.zip" >nul
if exist "!directory!\!dashboard!" rd "!directory!\!dashboard!" /s /q >nul 2>nul
goto :eof


@REM replace '\\' to '\' for directory 
:pathregular <result> <directory>
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
call :cleanworkspace "!temp!"
exit /b 1
goto :eof


@REM close
:closeproxy
call :isrunning status
if "!status!" == "0" (
    @echo [%ESC%[!infocolor!m信息%ESC%[0m] 网络代理程序%ESC%[!warncolor!m未运行%ESC%[0m，无须关闭
    goto :eof
)

set "tips=[%ESC%[!warncolor!m警告%ESC%[0m] 此操作将会关闭代理网络，是否继续？(%ESC%[!warncolor!mY%ESC%[0m/%ESC%[!warncolor!mN%ESC%[0m) "
if "!msterminal!" == "1" (
    choice /t 6 /d y /n /m "!tips!"
) else (
    set /p "=!tips!" <nul
    choice /t 6 /d y /n
)
if !errorlevel! == 2 exit /b 1
goto :killprocesswrapper


@REM output with color
:setESC
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do (
  set ESC=%%b
  exit /b 0
)
exit /b 0


@REM set proxy
:enableproxy <server>
call :trim server "%~1"
if "!server!" == "" goto :eof

reg add "!proxyregpath!" /v ProxyEnable /t REG_DWORD /d 1 /f >nul 2>nul
reg add "!proxyregpath!" /v ProxyServer /t REG_SZ /d "!server!" /f >nul 2>nul
reg add "!proxyregpath!" /v ProxyOverride /t REG_SZ /d "<local>" /f >nul 2>nul
goto :eof


@REM cancel proxy
:disableproxy
reg add "!proxyregpath!" /v ProxyServer /t REG_SZ /d "" /f >nul 2>nul
reg add "!proxyregpath!" /v ProxyEnable /t REG_DWORD /d 0 /f >nul 2>nul
reg add "!proxyregpath!" /v ProxyOverride /t REG_SZ /d "" /f >nul 2>nul
goto :eof


@REM query proxy status
:systemproxy <result>
set "%~1="

@REM enabled
call :regquery enable "!proxyregpath!" "ProxyEnable" "REG_DWORD"
if "!enable!" NEQ "0x1" goto :eof

@REM proxy server
call :regquery server "!proxyregpath!" "ProxyServer" "REG_SZ"
if "!server!" NEQ "" set "%~1=!server!"
goto :eof


@REM auto start when user login
:autostart
call :regquery exename "!autostartregpath!" "Clash" "REG_SZ"
if "!startupvbs!" NEQ "!exename!" (
    set "tips=[%ESC%[!warncolor!m提示%ESC%[0m] 是否允许网络代理程序开机自启？(%ESC%[!warncolor!mY%ESC%[0m/%ESC%[!warncolor!mN%ESC%[0m) "
    if "!msterminal!" == "1" (
        choice /t 5 /d y /n /m "!tips!"
    ) else (
        set /p "=!tips!" <nul
        choice /t 5 /d y /n
    )
    if !errorlevel! == 2 exit /b 1

    call :nopromptrunas success
    if "!success!" == "0" (
        @echo [%ESC%[91m错误%ESC%[0m] 权限受限，%ESC%[91m无法设置%ESC%[0m开机自启
        goto :eof
    )

    call :generatestartvbs "!startupvbs!" "-r"
    call :registerexe success "!startupvbs!"
    if "!success!" == "1" (
        @echo [%ESC%[!infocolor!m信息%ESC%[0m] 网络代理程序开机自启设置%ESC%[!infocolor!m完成%ESC%[0m
    ) else (
        @echo [%ESC%[91m错误%ESC%[0m] 网络代理程序开机自启设置%ESC%[91m失败%ESC%[0m
    )
)
goto :eof


@REM disable auto start
:disableautostart <result>
set "%~1=0"
call :regquery exename "!autostartregpath!" "Clash" "REG_SZ"

if "!exename!" == "" (
    set "%~1=1"
) else (
    set "shoulddelete=1"
    if "!startupvbs!" NEQ "!exename!" (
        set "tips=[%ESC%[!warncolor!m警告%ESC%[0m] 发现相同名字但执行路径不同的配置，是否继续？(%ESC%[!warncolor!mY%ESC%[0m/%ESC%[!warncolor!mN%ESC%[0m) "
        if "!msterminal!" == "1" (
            choice /t 5 /d n /n /m "!tips!"
        ) else (
            set /p "=!tips!" <nul
            choice /t 5 /d n /n
        )
        if !errorlevel! == 2 set "shoulddelete=0"
    )
    if "!shoulddelete!" == "1" (
        reg delete "!autostartregpath!" /v "Clash" /f >nul 2>nul
        if "!errorlevel!" == "0" set "%~1=1"

        @REM disable
        reg delete "!startupapproved!" /v "Clash" /f >nul 2>nul
    )
)
goto :eof


@REM add scheduled tasks
:autoupdate <refresh>
call :trim refresh "%~1"
if "!refresh!" == "" set "refresh=0"
set "taskname=ClashUpdater"

call :taskstatus ready "!taskname!"
if "!refresh!" == "1" set "ready=0"

if "!ready!" == "0" (
    set "tips=[%ESC%[!warncolor!m提示%ESC%[0m] 是否设置自动检查更新代理应用及规则？(%ESC%[!warncolor!mY%ESC%[0m/%ESC%[!warncolor!mN%ESC%[0m) "
    if "!msterminal!" == "1" (
        choice /t 5 /d n /n /m "!tips!"
    ) else (
        set /p "=!tips!" <nul
        choice /t 5 /d y /n
    )
    if !errorlevel! == 2 exit /b 1

    @REM generate vbs for update
    call :generateupdatevbs

    @REM delete old task
    call :deletetask success "!taskname!"

    @REM create new task
    call :createtask success "!updatevbs!" "!taskname!"
    if "!success!" == "1" (
        @echo [%ESC%[!infocolor!m信息%ESC%[0m] 自动检查更新设置%ESC%[!infocolor!m成功%ESC%[0m
    ) else (
        @echo [%ESC%[91m错误%ESC%[0m] 自动检查更新设置%ESC%[91m失败%ESC%[0m
    )
)
goto :eof


@REM generate vbs for update
:generateupdatevbs
set "operation=-u"
if "!clashmeta!" == "1" set "operation=!operation! -m"
if "!clashpremium!" == "1" set "operation=!operation! -n"
if "!alpha!" == "1" set "operation=!operation! -a"
if "!yacd!" == "1" set "operation=!operation! -y"
if "!metacubexd!" == "1" set "operation=!operation! -x"
if "!zashboard!" == "1" set "operation=!operation! -z"

@REM generate and write to file
call :generatestartvbs "!updatevbs!" "!operation!"

goto :eof


@REM create scheduled tasks
:createtask <result> <path> <taskname>
set "%~1=0"
call :trim exename "%~2"
if "!exename!" == "" goto :eof

call :trim taskname "%~3"
if "!taskname!" == "" goto :eof

@REM input start time
call :scheduletime starttime

@REM create
schtasks /create /tn "!taskname!" /tr "!exename!" /sc daily /mo 1 /ri 480 /st !starttime! /du 0012:00 /f >nul 2>nul
if "!errorlevel!" == "0" set "%~1=1"
goto :eof


@REM prompt user input task start time 
:scheduletime <time>
set "%~1="
set "usertime="
set "defaulttime=09:15"

@REM choose
set "tips=[%ESC%[!warncolor!m提示%ESC%[0m] 正在设置更新时间，默认为 %ESC%[!warncolor!m09:15%ESC%[0m，是否需要修改？(%ESC%[!warncolor!mY%ESC%[0m/%ESC%[!warncolor!mN%ESC%[0m) "
if "!msterminal!" == "1" (
    choice /c yn /n /d n /t 5 /m "!tips!"
) else (
    set /p "=!tips!" <nul
    choice /c yn /n /d n /t 5
)

if !errorlevel! == 2 (
    set "%~1=!defaulttime!"
    goto :eof
)

@REM prompt user input time
call :promptinput inputtime "!defaulttime!" 0
set "%~1=!inputtime!"
goto :eof


@REM input and validate
:promptinput <result> <default> <retry>
set "%~1="

set "tips=[%ESC%[!warncolor!m提示%ESC%[0m] 请输入一个格式为 %ESC%[!warncolor!mHH:MM%ESC%[0m 的 %ESC%[!warncolor!m24小时制%ESC%[0m 时间："

call :trim retryflag "%~3"
if "!retryflag!" == "1" (
    set "tips=[%ESC%[91m错误%ESC%[0m] 输入的时间%ESC%[91m无效%ESC%[0m或%ESC%[91m格式不正确%ESC%[0m，请重新输入："
    set "retryflag=0"
)

set /p "userinput=!tips!"
if not defined userinput (set "userinput=%~2")

@REM validate user input
call :validatetime "%~1" "%~2" "!userinput!"
goto :eof


@REM validate user input time
:validatetime <result> <default> <input>
set "%~1="

@REM trim user input
call :trim usertime "%~3"

set "validflag=0"
for /f "tokens=1-2 delims=:" %%a in ("!usertime!") do (
    set "hours=%%a" 2>nul
    set "minutes=%%b" 2>nul

    call :is_number hour_flag !hours!
    call :is_number minute_flag !minutes!

    if !hour_flag! == 1 if !minute_flag! == 1 if !hours! lss 24 if !minutes! lss 60 if !hours! geq 0 if !minutes! geq 0 (
        set "validflag=1"
    )
)

if "!validflag!" == "0" (call :promptinput "%~1" "%~2" 1) else (set "%~1=!usertime!")
goto :eof


@REM check if a variable is zero or a positive integer
:is_number <result> <variable>
set "%~1=0"
call :trim variable "%~2"

@echo !variable! | findstr /r /c:"^[0-9][0-9][ ]*$" >nul 2>nul && (set "%~1=1")

goto :eof


@REM query scheduled tasks
:taskstatus <status> <taskname>
set "%~1=0"
call :trim taskname "%~2"
if "!taskname!" == "" goto :eof

@REM query
schtasks /query /tn "!taskname!" >nul 2>nul
if "!errorlevel!" NEQ "0" goto :eof

@REM compare script path is same as current path
set "commandpath="
for /f "tokens=3 delims=<>" %%a in ('schtasks /query /tn "!taskname!" /xml ^| findstr "<Command>"') do set "commandpath=%%a"
call :trim commandpath "!commandpath!"

if "!commandpath!" NEQ "!updatevbs!" goto :eof

set "status="
for /f "usebackq skip=3 tokens=4" %%a in (`schtasks /query /tn "!taskname!"`) do set "status=%%a"
call :trim status "!status!"

if "!status!" == "Ready" set "%~1=1"

goto :eof


@REM delete update tasks
:deletetask <result> <taskname>
set "%~1=0"
call :trim taskname "%~2"
if "!taskname!" == "" goto :eof

schtasks /query /tn "!taskname!" >nul 2>nul
@REM not found
if "!errorlevel!" NEQ "0" (
    set "%~1=1"
    goto :eof
)

@REM remove
call :privilege "goto :cancelscheduled !taskname!" 0

@REM get delete status
for /l %%i in (1,1,5) do (
    schtasks /query /tn "!taskname!" >nul 2>nul
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
:cancelscheduled <taskname>
@REM delete
schtasks /delete /tn "%~1" /f  >nul 2>nul

@REM get administrator privileges
call :nopromptrunas result
goto :eof


@REM add to 
:registerexe <result> <path>
set "%~1=0"
call :trim exename "%~2"
if "!exename!" == "" goto :eof
if not exist "!exename!" goto :eof

@REM delete
reg delete "!autostartregpath!" /v "Clash" /f >nul 2>nul
@REM register
reg add "!autostartregpath!" /v "Clash" /t "REG_SZ" /d "!exename!" >nul 2>nul
if "!errorlevel!" NEQ "0" goto :eof

@REM approved
reg delete "!startupapproved!" /v "Clash" /f >nul 2>nul
@REM register
reg add "!startupapproved!" /v "Clash" /t "REG_BINARY" /d "02 00 00 00 00 00 00 00 00 00 00 00" >nul 2>nul

if "!errorlevel!" == "0" set "%~1=1"
goto :eof


@REM vbs for startup
:generatestartvbs <path> <operation>
call :trim startscript "%~1"
if "!startscript!" == "" goto :eof

call :trim operation "%~2"
if "!operation!" == "" goto :eof

@echo set ws = WScript.CreateObject^("WScript.Shell"^) > "!startscript!"
@echo ws.Run "%~dp0!batname! !operation! -w !dest! -c !configfile!", 0 >> "!startscript!"
@echo set ws = Nothing >> "!startscript!"
goto :eof


@REM judge os caption
:ishomeedition <result>
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
:enablerunas <result>
set "%~1=1"

call :ishomeedition edition
if "!edition!" == "0" goto :eof

set "packagesfile=!temp!\grouppolicypackages.txt"

@REM find all grouppolicy pakcages
dir /b "C:\Windows\servicing\Packages\Microsoft-Windows-GroupPolicy-ClientExtensions-Package~3*.mum" > "!packagesfile!"
dir /b "C:\Windows\servicing\Packages\Microsoft-Windows-GroupPolicy-ClientTools-Package~3*.mum" >> "!packagesfile!"

@REM install
for /f %%i in ('findstr /i . "!packagesfile!" 2^>nul') do dism /online /norestart /add-package:"C:\Windows\servicing\Packages\%%i" >nul 2>nul
if "!errorlevel!" NEQ "0" set "%~1=0"

del /f /q "!packagesfile!" >nul 2>nul
goto :eof


@REM no prompt when run as admin
:nopromptrunas <result>
set "%~1=0"

@REM regedit path and key
set "grouppolicy=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
set "gprkey=ConsentPromptBehaviorAdmin"

call :regquery code "!grouppolicy!" "!gprkey!" "REG_DWORD"
if "!code!" == "0x0" (
    set "%~1=1"
    exit /b  
)

call :enablerunas enable
if "!enable!" == "0" goto :eof

@REM change regedit
reg delete "!grouppolicy!" /v ConsentPromptBehaviorAdmin /f >nul 2>nul
reg add "!grouppolicy!" /v ConsentPromptBehaviorAdmin /t REG_DWORD /d 0 /f >nul 2>nul
if "!errorlevel!" == "0" set "%~1=1"
goto :eof


@REM clean data
:purge
set "tips=[%ESC%[!warncolor!m警告%ESC%[0m] 即将关闭系统代理并禁用开机自启，是否继续？(%ESC%[!warncolor!mY%ESC%[0m/%ESC%[!warncolor!mN%ESC%[0m) "
if "!msterminal!" == "1" (
    choice /t 6 /d n /n /m "!tips!"
) else (
    set /p "=!tips!" <nul
    choice /t 6 /d n /n
)
if !errorlevel! == 2 exit /b 1

@REM close system proxy
call :disableproxy

@REM disable auto start
call :disableautostart success
if "!success!" == "0" (
    @echo [%ESC%[91m错误%ESC%[0m] 开机自启%ESC%[91m禁用失败%ESC%[0m，可在%ESC%[!warncolor!m任务管理中心%ESC%[0m手动设置
)

@REM delete scheduled
call :deletetask success "ClashUpdater"
if "!success!" == "0" (
    @echo [%ESC%[91m错误%ESC%[0m] 自动检查跟新取消%ESC%[91m失败%ESC%[0m，可在%ESC%[!warncolor!m任务计划程序%ESC%[0m中手动删除 
)

@REM stop process
call :killprocesswrapper

@REM remote shortcut
call :deleteshortcut

@echo [%ESC%[!infocolor!m信息%ESC%[0m] 清理%ESC%[!infocolor!m完毕%ESC%[0m, bye~
goto :eof


@REM query value form register
:regquery <result> <path> <key> <type>
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
:downloadicon <result> <iconname>
set "%~1=0"

call :trim iconname "%~2"
if "!iconname!" == "" goto :eof

call :ghproxywrapper iconurl "https://raw.githubusercontent.com/wzdnzd/batches/main/icons/clash.ico"
set "statuscode=000"
for /f %%a in ('curl --retry 3 --retry-max-time 60 -m 60 --connect-timeout 30 -L -s -o "!dest!\!iconname!" -w "%%{http_code}" "!iconurl!"') do set "statuscode=%%a"

if "!statuscode!" == "200" set "%~1=1"
goto :eof


@REM create desktop shortcut
:createshortcut <result> <linkdest> <target> <iconname>
set "%~1=0"
call :trim linkdest "%~2"
call :trim target "%~3"
call :trim iconname "%~4"


if "!linkdest!" == "" goto :eof
if "!target!" == "" goto :eof
if "!iconname!" == "" set "iconname=clash.ico"
if exist "!linkdest!" del /f /q "!linkdest!" >nul

set "vbspath=!temp!\createshortcut.vbs"
((
    @echo set ows = WScript.CreateObject^("WScript.Shell"^) 
    @echo slinkfile = ows.ExpandEnvironmentStrings^("!linkdest!"^)
    @echo set olink = ows.CreateShortcut^(slinkfile^) 
    @echo olink.TargetPath = ows.ExpandEnvironmentStrings^("!target!"^)
    @echo olink.IconLocation = ows.ExpandEnvironmentStrings^("!dest!\!iconname!"^)
    @echo olink.WorkingDirectory = ows.ExpandEnvironmentStrings^("!dest!"^)
    @echo olink.Save
) 1>!vbspath!

cscript //nologo "!vbspath!"
if "!errorlevel!" == "0" set "%~1=1"

del /f /q "!vbspath!"
) >nul
goto :eof


@REM send to desktop
:adddesktop
if "!enableshortcut!" == "0" goto :eof

set "iconname=clash.ico"
set "linkdest=!HOMEDRIVE!!HOMEPATH!\Desktop\Clash.lnk"

set "exepath="
@REM parse target if link exists
if exist "!linkdest!" (
    for /f "delims=" %%a in ('wmic path win32_shortcutfile where "name='!linkdest:\=\\!'" get target /value') do (
        for /f "tokens=2 delims==" %%b in ("%%~a") do set "exepath=%%b"
    )
)

call :trim exepath "!exepath!"
if "!exepath!" == "!startupvbs!" goto :eof

set "tips=[%ESC%[!warncolor!m提示%ESC%[0m] 是否添加桌面快捷方式？(%ESC%[!warncolor!mY%ESC%[0m/%ESC%[!warncolor!mN%ESC%[0m) "
if "!msterminal!" == "1" (
    choice /t 5 /d y /n /m "!tips!"
) else (
    set /p "=!tips!" <nul
    choice /t 5 /d y /n
)
if !errorlevel! == 2 goto :eof

if not exist "!dest!\!iconname!" (
    call :downloadicon finished "!iconname!"
    if "!finished!" == "0" (
        @echo [%ESC%[91m错误%ESC%[0m] 应用图标文件下载%ESC%[91m失败%ESC%[0m，无法创建桌面快捷方式
        goto :eof
    )
)

call :createshortcut finished "!linkdest!" "!startupvbs!" "!iconname!"
if "!finished!" == "0" (
    @echo [%ESC%[91m错误%ESC%[0m] 桌面快捷方式添加%ESC%[91m失败%ESC%[0m，如有需要，请自行创建
) else (
    @echo [%ESC%[!infocolor!m信息%ESC%[0m] 桌面快捷方式添加%ESC%[!infocolor!m成功%ESC%[0m
)
goto :eof


@REM remove shortcut from desktop
:deleteshortcut
set "linkpath=!HOMEDRIVE!!HOMEPATH!\Desktop\Clash.lnk"
del /f /q "!linkpath!" >nul 2>nul
goto :eof


@REM determine whether it is a microsoft terminal
:ismsterminal <result>
set "%~1=0"

call :whatterminal output 3
call :trim output "!output!"

set "retry=0"
if /i "!output!" == "powershell" set "retry=1"
if /i "!output!" == "pwsh" set "retry=1"

if "!retry!" == "1" (
    call :whatterminal output 4
    call :trim output "!output!"
)

if /i "!output!" == "WindowsTerminal" (
    set "%~1=1"
    goto :eof
)
goto :eof


@REM get current terminal name
:whatterminal <result> <num>
set "%~1="
call :trim num "%~2"
if "!num!" == "" set "num=3"

@REM set "pscmd=$current = Get-CimInstance -ClassName win32_process -filter ('ProcessID='+$pid); $parent = Get-Process -id ($current.parentprocessID); if ($parent.ProcessName -eq 'WindowsTerminal') {echo 'true';} else {$cimgrandparent = Get-CimInstance -ClassName win32_process -filter ('Processid='+($($parent.id))); $grandparent = Get-Process -id ($cimgrandparent.parentProcessId); if (($grandparent.processname) -eq 'WindowsTerminal') {echo 'true';} else {echo 'false';}}"

@REM reference: https://stackoverflow.com/questions/53447286/in-a-cmd-batch-file-can-i-determine-if-it-was-run-from-powershell
set "pscmd=$ppid=$pid;while($i++ -lt !num! -and ($ppid=(Get-CimInstance Win32_Process -Filter ('ProcessID='+$ppid)).ParentProcessId)) {}; (Get-Process -EA Ignore -ID $ppid).Name"

for /f "tokens=*" %%a in ('powershell -noprofile -command "!pscmd!"') do set "%~1=%%a"
goto :eof


endlocal
