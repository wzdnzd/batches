@REM author: wzdnzd
@REM date: 2024-05-17
@REM describe: Github Copilot Proxy Agent Controller

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
set "msterminal=1"

@REM info color
set "infocolor=92"
set "warncolor=93"

if "!msterminal!" == "1" (
    set "infocolor=95"
    set "warncolor=97"
)

@REM enable replace max tokens
set "enable_replace_max_token=1"

@REM enable set auto start
set "enable_auto_start=1"

@REM enable set auto update
set "enable_auto_update=1"

@REM enable set environment for JetBrains IDE
set "enable_set_env=1"

@REM start flag
set "startflag=0"

@REM restart clash.exe
set "restartflag=0"

@REM quit flag
set "quitflag=0"

@REM exit flag
set "shouldexit=0"

@REM update
set "updateflag=0"

@REM purge
set "purgeflag=0"

@REM project address on github
set "printflag=0"
set "address=https://github.com/linux-do/override"

@REM run on background
set "asdaemon=1"
set "show=0"

@REM setting workspace
set "dest="

@REM config file name
set "config=config.json"

@REM customize
set "customize=0"

@REM default executable file name
if "!customize!" == "1" (set "defaultname=copilot-agent.exe") else (set "defaultname=override.exe")

@REM last executable file name
set "software=!defaultname!"

@REM reg key name
set "application=GithubCopilotAgent"

@REM schedule name
set "scheduledname=GithubCopilotAgentUpdate"

@REM autostart registry configuration path
set "autostartregpath=HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
set "startupapproved=HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"
set "envpath=HKCU\Environment"

@REM parse arguments
call :argsparse %*

@REM invalid arguments
if "!shouldexit!" == "1" exit /b 1

@REM print project address
if "!printflag!" == "1" (
    @echo [%ESC%[!infocolor!m信息%ESC%[0m] 项目地址：%ESC%[!infocolor!m!address!%ESC%[0m
    goto :eof
)

@REM regular file path
if "!dest!" == "" set "dest=%~dp0"
call :pathregular dest "!dest!"

@REM executable file not exist
if not exist "!dest!" (
    @echo [%ESC%[91m错误%ESC%[0m] 文件夹 "!dest!" 不存在
    goto :eof
)

@REM auto start vb script
set "startupvbs=!dest!\copilot-startup.vbs"

@REM auto update vb script
set "updatevbs=!dest!\update.vbs"

@REM quit service
if "!quitflag!" == "1" goto :quit

@REM clean all setting
if "!purgeflag!" == "1" goto :purge

@REM print usage if no action
if "!startflag!" == "0" if "!restartflag!" == "0" if "!updateflag!" == "0" (
    if "!shouldexit!" == "0" goto :usage
    exit /b
)

@REM start service
if "!startflag!" == "1" goto :start

@REM restart service
if "!restartflag!" == "1" goto :restart

@REM update program
if "!updateflag!" == "1" goto :upgrade

exit /b


@REM parse and validate arguments
:argsparse
set result=false

if "%1" == "-a" set result=true
if "%1" == "--address" set result=true
if "!result!" == "true" (
    set "printflag=1"
    set result=false
    shift & goto :argsparse
)

if "%1" == "-d" set result=true
if "%1" == "--display" set result=true
if "!result!" == "true" (
    set "asdaemon=0"
    set result=false
    shift & goto :argsparse
)

if "%1" == "-f" set result=true
if "%1" == "--filename" set result=true
if "!result!" == "true" (
    @REM validate argument
    call :trim filename "%~2"

    if "!filename!" == "" set result=false
    if "!filename:~0,2!" == "--" set result=false
    if "!filename:~0,1!" == "-" set result=false

    if "!result!" == "false" (
        @echo [%ESC%[91m错误%ESC%[0m] 如果指定参数 "%ESC%[!warncolor!m--filename%ESC%[0m" 或者 "%ESC%[!warncolor!m-f%ESC%[0m" 则必须提供有效的%ESC%[!warncolor!m可执行文件名%ESC%[0m
        @echo.
        goto :usage
    )

    set "software=!filename!"
    set result=false
    shift & shift & goto :argsparse
)

if "%1" == "-h" set result=true
if "%1" == "--help" set result=true
if "!result!" == "true" (
    goto :usage
)

if "%1" == "-i" set result=true
if "%1" == "--interactive" set result=true
if "!result!" == "true" (
    set "show=1"
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
if "%1" == "--quit" set result=true
if "!result!" == "true" (
    set "quitflag=1"
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
if "%1" == "--start" set result=true
if "!result!" == "true" (
    set "startflag=1"
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
    if not exist "!directory!" (set "shouldexit=1")

    if "!shouldexit!" == "1" (
        @echo [%ESC%[91m错误%ESC%[0m] 参数 "%ESC%[!warncolor!m--workspace%ESC%[0m" 指定的文件夹路径 "%ESC%[!warncolor!m!directory!%ESC%[0m" %ESC%[91m无效%ESC%[0m
        @echo.
        goto :eof
    )

    set "dest=!directory!"
    set result=false
    shift & shift & goto :argsparse
)

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
@REM @echo. if this line contains Chinese output, it will be garbled
@echo -a, --address         打印 %ESC%[!warncolor!moverride%ESC%[0m 项目对应的 Github 地址
@REM @echo. if this line contains Chinese output, it will be garbled
@echo -h, --help            打印帮助信息
@echo -p, --purge           禁止服务开机自启、自动更新及环境变量设置等
@REM @echo. if this line contains Chinese output, it will be garbled
@echo -q, --quit            退出服务
@REM @echo. if this line contains Chinese output, it will be garbled
@echo -r, --restart         重启服务
@echo -s, --start           启动服务
@echo -u, --update          检查并更新 %ESC%[!warncolor!m!software!%ESC%[0m 可执行程序
echo.
@echo 其他参数：
@REM @echo. if this line contains Chinese output, it will be garbled
@echo -d, --display         前台运行，默认启动守护进程静默执行
@REM @echo. if this line contains Chinese output, it will be garbled
@echo -f, --filename        可执行程序文件名，默认为 %ESC%[!warncolor!m!defaultname!%ESC%[0m
@echo -i, --interactive     新窗口中执行窗口，不隐藏窗口
@echo -w, --workspace       服务工作路径，默认为当前脚本所在目录
@echo.

set "shouldexit=1"
goto :eof


@REM start program
:start
call :execute

@REM check
for /l %%i in (1,1,3) do (
    @REM check running status
    call :isrunning status
    if "!status!" == "1" (
        @echo [%ESC%[!infocolor!m信息%ESC%[0m] 服务启动%ESC%[!infocolor!m成功%ESC%[0m

        call :postprocess
        exit /b
    ) else (
        @REM waiting
        timeout /t 1 /nobreak >nul 2>nul
    )
)

@echo [%ESC%[91m错误%ESC%[0m] 服务启动%ESC%[91m失败%ESC%[0m，请检查配置 %ESC%[91m!config!%ESC%[0m 是否正确
goto :eof


@REM execute program
:execute
if not exist "!dest!\!software!" (
    @echo [%ESC%[91m错误%ESC%[0m] 可执行文件 %ESC%[91m!software!%ESC%[0m 不存在，无法启动服务
    goto :eof
)

if not exist "!dest!\!config!" (
    @echo [%ESC%[91m错误%ESC%[0m] 配置文件 %ESC%[91m!config!%ESC%[0m 不存在，无法启动服务
    goto :eof
)

cd /d "!dest!"

if "!asdaemon!" == "1" (
    @REM run on backend
    if "!show!" == "1" (
        start "" "!software!" >nul 2>&1
    ) else (
        start /min /b "" "!software!" >nul 2>&1
    )
) else (
    @REM executing !software! directly will block and the postprocess method cannot be called
    start "" "!software!"
)

goto :eof


@REM delect running status
:isrunning <result>
tasklist | findstr /i "!software!" >nul 2>nul && set "%~1=1" || set "%~1=0"
goto :eof


@REM restart program
:restart
call :isrunning status

if "!status!" == "0" (
    goto :start
) else (
    @REM kill process
    call :privilege "goto :killprocess !software!" !show!

    @REM check
    for /l %%i in (1,1,5) do (
        call :isrunning status
        if "!status!" == "0" (
            call :start
            exit /b
        ) else (
            @REM wait a moment
            timeout /t 1 /nobreak >nul 2>nul
        )
    )
)

@echo [%ESC%[91m错误%ESC%[0m] 无法关闭进程，服务重启%ESC%[91m失败%ESC%[0m，请到%ESC%[91m任务管理中心%ESC%[0m手动退出 %ESC%[!warncolor!m!software!%ESC%[0m
goto :eof


@REM quit program
:quit
call :isrunning status
if "!status!" == "0" (
    @echo [%ESC%[!infocolor!m信息%ESC%[0m] 服务%ESC%[!warncolor!m未启动%ESC%[0m，无须关闭
    goto :eof
)

set "tips=[%ESC%[!warncolor!m警告%ESC%[0m] 即将退出程序，是否继续？(%ESC%[!warncolor!mY%ESC%[0m/%ESC%[!warncolor!mN%ESC%[0m) "
if "!msterminal!" == "1" (
    choice /t 6 /d y /n /m "!tips!"
) else (
    set /p "=!tips!" <nul
    choice /t 6 /d y /n
)

if !errorlevel! == 2 exit /b 1

@REM kill process with admin 
call :privilege "goto :killprocess !software!" 0
goto :eof


@REM privilege escalation
:privilege <args> <show>
set "hidewindow=0"
set "operation=%~1"
if "!operation!" == "" (
    @echo [%ESC%[91m错误%ESC%[0m] 非法操作，必须指定函数名
    exit /b 1
)

@REM parse window parameter
call :trim param "%~2"
set "display=" & for /f "delims=0123456789" %%i in ("!param!") do set "display=%%i"
if defined display (set "hidewindow=0") else (set "hidewindow=!param!")
if "!hidewindow!" NEQ "0" set "hidewindow=1"

cacls "%SystemDrive%\System Volume Information" >nul 2>&1 && (
    if "!hidewindow!" == "1" (
        !operation!
        exit /b
    ) else (
        start "" mshta vbscript:CreateObject^("Shell.Application"^).ShellExecute^("%~snx0","%~1","","runas",0^)^(window.close^)&exit /b
    )
) || (start "" mshta vbscript:CreateObject^("Shell.Application"^).ShellExecute^("%~snx0","%~1","","runas",!hidewindow!^)^(window.close^)&exit /b)
goto :eof


@REM stop
:killprocess <name>
call :trim name "%~1"
if "!name!" == "" (set "name=!software!")

tasklist | findstr /i "!name!" >nul 2>nul && taskkill /im "!name!" /f >nul 2>nul
set "exitcode=!errorlevel!"

@REM no prompt
call :nopromptrunas success

@REM detect
for /l %%i in (1,1,3) do (
    @REM detect running status
    call :isrunning status
    if "!status!" == "0" (
        @echo [%ESC%[!infocolor!m信息%ESC%[0m] 服务已关闭，可使用 "%ESC%[!warncolor!m!batname! -r%ESC%[0m" 命令重启
        goto :eof
    ) else (
        @REM waiting for release
        timeout /t 1 /nobreak >nul 2>nul
    )
)

@echo [%ESC%[91m错误%ESC%[0m] 服务关闭失败，请到%ESC%[91m任务管理中心%ESC%[0m手动结束 %ESC%[!warncolor!m!software!%ESC%[0m 进程
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


@REM update program
:upgrade
if "!asdaemon!" == "1" (
    cacls "%SystemDrive%\System Volume Information" >nul 2>&1 || (start "" mshta vbscript:CreateObject^("Shell.Application"^).ShellExecute^("%~snx0"," %*","","runas",!show!^)^(window.close^)&exit /b)
)

@REM downlaod binary if necessary
call :download binary
if "!binary!" NEQ "" if exist "!binary!" (
    @REM stop process
    call :privilege "goto :killprocess !software!" 0

    @REM copy and replace old file
    del /f /q "!dest!\!software!" >nul 2>nul
    move "!binary!" "!dest!\!software!" >nul 2>nul

    @echo [%ESC%[!infocolor!m信息%ESC%[0m] 检查到较新版本程序并下载完毕，即将重启服务

    @REM start
    call :restart

    @echo [%ESC%[!infocolor!m信息%ESC%[0m] 程序更新完毕，服务已重启
) else (
    @echo [%ESC%[!infocolor!m信息%ESC%[0m] 当前已是最新版本，无需更新
)

if "!show!" == "1" pause
goto :eof


@REM wintun
:download <target>
set "%~1="
set "release="

@REM amd64 or 386
call :get_arch version
if "!version!" == "" (
    @echo [%ESC%[91m错误%ESC%[0m] 下载失败，无法获取 操作系统 及 CPU 架构信息
    goto :eof
)

@REM extract download url
for /f "tokens=1* delims=:" %%a in ('curl --retry 5 -s -L "https://api.github.com/repos/linux-do/override/releases/latest?per_page=1" ^| findstr /i /r "https://github.com/linux-do/override/releases/download/.*/override-windows-amd64-.*.zip"') do set "release=%%b"

call :trim rawurl "!release!"
if !rawurl! == "" (
    @echo [%ESC%[91m错误%ESC%[0m] 获取 !software! 下载链接失败
    goto :eof
)

set "rawurl=!rawurl:~1,-1!"
call :ghproxywrapper downloadurl !rawurl!

@echo [%ESC%[!infocolor!m信息%ESC%[0m] 开始下载 !software!，下载链接："!downloadurl!"

set "savedpath=!temp!\override.zip"
call :retrydownload "!downloadurl!" "!savedpath!"
if exist "!savedpath!" (
    set "filepath=!temp!\copilot-override"
    mkdir "!filepath!"

    @REM unzip
    tar -xzf "!savedpath!" -C !filepath! >nul 2>nul

    @REM clean workspace
    del /f /q "!savedpath!" >nul 2>nul

    set "program=!temp!\override.exe"
    del /f /q "!program!" >nul 2>nul

    for /f "delims=" %%i in ('dir /ad/b/s "!filepath!"') do (
        if exist "%%i\override.exe" (
            move "%%i\override.exe" "!temp!" >nul 2>nul
        )
    )

    @REM delete tmep diretory
    rd "!filepath!" /s /q >nul 2>nul

    if exist "!program!" (
        @REM compare and update
        call :md5compare diff "!program!" "!dest!\!software!"
        if "!diff!" == "1" (set "%~1=!program!")
    ) else (
        @echo [%ESC%[!warncolor!m警告%ESC%[0m] 下载 override 成功，但未找到 override.exe 文件
    )
) else (
    @echo [%ESC%[!warncolor!m警告%ESC%[0m] override 下载失败，请确认下载链接是否正确
)
goto :eof


@REM download with retry
:retrydownload <url> <filename>
set maxretries=3
call :trim downloadurl "%~1"
call :trim savepath "%~2"

set "valid=0"
if "!downloadurl:~0,7!" == "http://" set "valid=1"
if "!downloadurl:~0,8!" == "https://" set "valid=1"
if "!valid!" == "0" (
    @echo [%ESC%[!warncolor!m警告%ESC%[0m] 下载失败，无效的下载链接："!downloadurl!"
    goto :eof
)

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


@REM get cpu and os version, see: https://github.com/linux-do/override/releases
:get_arch <version>
set "%~1="
if "!PROCESSOR_ARCHITECTURE!" == "AMD64" (
    set "%~1=amd64"
) else if "!PROCESSOR_ARCHITECTURE!" == "X86" (
    set "%~1=386"
)

goto :eof


@REM config autostart and auto update
:postprocess
@REM allow change max tokens
if "!enable_replace_max_token!" == "1" call :replace_max_tokens 0

call :privilege "goto :nopromptrunas" 0

@REM allow auto start when user login
if "!enable_auto_start!" == "1" call :autostart

@REM allow auto check update
if "!enable_auto_update!" == "1" call :autoupdate

@REM set environment
if "!enable_set_env!" == "1" call :add_environment

goto :eof


@REM change max tokens to 2048
:replace_max_tokens <force>
call :trim force "%~1"
if "!force!" == "" set "force=0"

@REM subpath of the file to be replaced
set "subpath=dist\extension.js"

set "pattern=\.maxPromptCompletionTokens\(([a-zA-Z0-9_]+),([0-9]+)\)"
set "replacement=.maxPromptCompletionTokens($1,2048)"

@REM iterate over all github copilot directories
for /d %%d in (%USERPROFILE%\.vscode\extensions\github.copilot-*) do (
    set "extension_path=%%d\!subpath!"
    if exist "!extension_path!" (
        set "backupfile=!extension_path!.bak"

        @REM delete if exist backup file
        if exist "!backupfile!" (
            if "!force!" == "0" goto :eof

            del /f /q "!backupfile!" >nul 2>nul
        )

        @REM backup
        copy /y "!extension_path!" "!backupfile!" >nul 2>nul

        @REM do search and replace with pattern
        powershell -Command "(Get-Content '!extension_path!') -replace '!pattern!', '!replacement!' | Set-Content '!extension_path!'"
    )
)

@echo [%ESC%[!infocolor!m信息%ESC%[0m] 最大 tokens 数值设置%ESC%[!infocolor!m完成%ESC%[0m
goto :eof


@REM recovery max tokens
:recovery_max_tokens
@REM subpath of the file to be recovery
set "subpath=dist\extension.js"

@REM iterate over all github copilot directories
for /d %%d in (%USERPROFILE%\.vscode\extensions\github.copilot-*) do (
    set "extension_path=%%d\!subpath!"
    set "backupfile=!extension_path!.bak"

    if exist "!backupfile!" (
        @REM delete if exist extension file
        if exist "!extension_path!" (
            del /f /q "!extension_path!" >nul 2>nul
        )

        @REM replace
        move "!backupfile!" "!extension_path!" >nul 2>nul
    )
)

@echo [%ESC%[!infocolor!m信息%ESC%[0m] 最大 tokens 数值恢复%ESC%[!infocolor!m成功%ESC%[0m
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

set proxy_urls[0]=https://mirror.ghproxy.com
set proxy_urls[1]=https://gh.ddlc.top
set proxy_urls[2]=https://hub.gitmirror.com
set proxy_urls[3]=https://proxy.api.030101.xyz

@REM random [0, 2]
set /a num=!random! %% 4
set "ghproxy=!proxy_urls[%num%]!"

@REM github proxy
if "!rawurl:~0,18!" == "https://github.com" set "rawurl=!ghproxy!/!rawurl!"
if "!rawurl:~0,33!" == "https://raw.githubusercontent.com" set "rawurl=!ghproxy!/!rawurl!"
if "!rawurl:~0,34!" == "https://gist.githubusercontent.com" set "rawurl=!ghproxy!/!rawurl!"

set "%~1=!rawurl!"
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


@REM output with color
:setESC
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do (
  set ESC=%%b
  exit /b 0
)
exit /b 0


@REM auto start when user login
:autostart
call :regquery program "!autostartregpath!" "!application!" "REG_SZ"
if "!startupvbs!" NEQ "!program!" (
    set "tips=[%ESC%[!warncolor!m提示%ESC%[0m] 是否允许服务开机自启？(%ESC%[!warncolor!mY%ESC%[0m/%ESC%[!warncolor!mN%ESC%[0m) "
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

    call :generatevbs "!startupvbs!" "-r"
    call :register success "!startupvbs!"
    if "!success!" == "1" (
        @echo [%ESC%[!infocolor!m信息%ESC%[0m] 服务开机自启设置%ESC%[!infocolor!m完成%ESC%[0m
    ) else (
        @echo [%ESC%[91m错误%ESC%[0m] 服务开机自启设置%ESC%[91m失败%ESC%[0m
    )
)
goto :eof


@REM disable auto start
:disableautostart <result>
set "%~1=0"
call :regquery program "!autostartregpath!" "!application!" "REG_SZ"

if "!program!" == "" (
    set "%~1=1"
) else (
    set "shoulddelete=1"
    if "!startupvbs!" NEQ "!program!" (
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
        reg delete "!autostartregpath!" /v "!application!" /f >nul 2>nul
        if "!errorlevel!" == "0" set "%~1=1"

        @REM disable
        reg delete "!startupapproved!" /v "!application!" /f >nul 2>nul
    )
)
goto :eof


@REM add scheduled tasks
:autoupdate <refresh>
call :trim refresh "%~1"
if "!refresh!" == "" set "refresh=0"

call :taskstatus ready "!scheduledname!"
if "!refresh!" == "1" set "ready=0"

if "!ready!" == "0" (
    set "tips=[%ESC%[!warncolor!m提示%ESC%[0m] 是否设置自动检查更新应用 !software!？(%ESC%[!warncolor!mY%ESC%[0m/%ESC%[!warncolor!mN%ESC%[0m) "
    if "!msterminal!" == "1" (
        choice /t 5 /d n /n /m "!tips!"
    ) else (
        set /p "=!tips!" <nul
        choice /t 5 /d y /n
    )
    if !errorlevel! == 2 exit /b 1

    @REM generate vbs for update
    call :generatevbs "!updatevbs!" "-u"

    @REM delete old task
    call :deletetask success "!scheduledname!"

    @REM create new task
    call :createtask success "!updatevbs!" "!scheduledname!"
    if "!success!" == "1" (
        @echo [%ESC%[!infocolor!m信息%ESC%[0m] 自动检查更新设置%ESC%[!infocolor!m成功%ESC%[0m
    ) else (
        @echo [%ESC%[91m错误%ESC%[0m] 自动检查更新设置%ESC%[91m失败%ESC%[0m
    )
)
goto :eof


@REM set environment
:add_environment
set "configfile=!dest!\!config!"

@REM extract server address
set "content="
for /f "tokens=*" %%a in ('findstr /i /r /c:"\"bind\":.*:[0-9][0-9]*.*" config.json') do set "content=%%a"
if "!content!" == "" (
    @echo [%ESC%[91m错误%ESC%[0m] 配置 "%ESC%[!warncolor!m!configfile!%ESC%[0m" 无效，请检查确认
    exit /b 1
)

set "bindinfo="
for /f "tokens=1,* delims=:" %%a in ("!content!") do (set "bindinfo=%%b")
call :trim bindinfo !bindinfo!

@REM remove trailing comma
if "!bindinfo:~-1!"=="," set "bindinfo=!bindinfo:~0,-1!"

@REM remove leading and trailing quotes 
if !bindinfo:~0^,1!!bindinfo:~-1! equ "" set "bindinfo=!bindinfo:~1,-1!"
if "!bindinfo:~0,1!!bindinfo:~0,1!" == "''" set "bindinfo=!bindinfo:~1!"
if "!bindinfo:~-1!!bindinfo:~-1!" == "''" set "bindinfo=!bindinfo:~0,-1!"

if "!bindinfo!" == "" (
    @echo [%ESC%[91m错误%ESC%[0m] 配置 "%ESC%[!warncolor!m!configfile!%ESC%[0m" 无效，请检查确认
    exit /b 1
)

@REM base proxy url 
set "baseurl=http://!bindinfo!"

@REM check
call :check_env missing "!baseurl!"
if "!missing!" == "0" goto :eof

set "tips=[%ESC%[!warncolor!m提示%ESC%[0m] 是否为 JetBrains 系开发软件添加环境变量？(%ESC%[!warncolor!mY%ESC%[0m/%ESC%[!warncolor!mN%ESC%[0m) "
if "!msterminal!" == "1" (
    choice /t 5 /d n /n /m "!tips!"
) else (
    set /p "=!tips!" <nul
    choice /t 5 /d y /n
)
if !errorlevel! == 2 exit /b 1

@REM add to environment
call :privilege "goto :do_set_env !baseurl!" 0

goto :eof


@REM check all environment is ready
:check_env <result> <bindinfo>
set "%~1=0"
call :trim bindinfo "%~2"

call :regquery value "!envpath!" "AGENT_DEBUG_OVERRIDE_PROXY_URL" "REG_SZ"
if "!value!" NEQ "!bindinfo!" set "%~1=1"

call :regquery value "!envpath!" "GITHUB_COPILOT_OVERRIDE_PROXY_URL" "REG_SZ"
if "!value!" NEQ "!bindinfo!" set "%~1=1"

call :regquery value "!envpath!" "AGENT_DEBUG_OVERRIDE_CAPI_URL" "REG_SZ"
if "!value!" NEQ "!bindinfo!/v1" set "%~1=1"

call :regquery value "!envpath!" "GITHUB_COPILOT_OVERRIDE_CAPI_URL" "REG_SZ"
if "!value!" NEQ "!bindinfo!/v1" set "%~1=1"

goto :eof


@REM do set environment
:do_set_env <bindinfo>
call :trim bindinfo "%~1"
if "!bindinfo!" == "" (
    @echo [%ESC%[91m错误%ESC%[0m] 配置 "%ESC%[!warncolor!m!configfile!%ESC%[0m" 无效，请检查确认
    goto :eof
)

reg delete "!envpath!" /v "AGENT_DEBUG_OVERRIDE_PROXY_URL" /f >nul 2>nul
reg add "!envpath!" /v "AGENT_DEBUG_OVERRIDE_PROXY_URL" /t "REG_SZ" /d "!bindinfo!" >nul 2>nul

reg delete "!envpath!" /v "GITHUB_COPILOT_OVERRIDE_PROXY_URL" /f >nul 2>nul
reg add "!envpath!" /v "GITHUB_COPILOT_OVERRIDE_PROXY_URL" /t "REG_SZ" /d "!bindinfo!" >nul 2>nul

reg delete "!envpath!" /v "AGENT_DEBUG_OVERRIDE_CAPI_URL" /f >nul 2>nul
reg add "!envpath!" /v "AGENT_DEBUG_OVERRIDE_CAPI_URL" /t "REG_SZ" /d "!bindinfo!/v1" >nul 2>nul

reg delete "!envpath!" /v "GITHUB_COPILOT_OVERRIDE_CAPI_URL" /f >nul 2>nul
reg add "!envpath!" /v "GITHUB_COPILOT_OVERRIDE_CAPI_URL" /t "REG_SZ" /d "!bindinfo!/v1" >nul 2>nul

goto :eof


@REM remove environment
:remove_env
reg delete "!envpath!" /v "AGENT_DEBUG_OVERRIDE_PROXY_URL" /f >nul 2>nul
reg delete "!envpath!" /v "GITHUB_COPILOT_OVERRIDE_PROXY_URL" /f >nul 2>nul
reg delete "!envpath!" /v "AGENT_DEBUG_OVERRIDE_CAPI_URL" /f >nul 2>nul
reg delete "!envpath!" /v "GITHUB_COPILOT_OVERRIDE_CAPI_URL" /f >nul 2>nul
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


@REM remove scheduled task
:cancelscheduled <taskname>
@REM delete
schtasks /delete /tn "%~1" /f  >nul 2>nul

@REM get administrator privileges
call :nopromptrunas result
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


@REM vbs for startup
:generatevbs <path> <operation>
call :trim script "%~1"
if "!script!" == "" goto :eof

call :trim operation "%~2"
if "!operation!" == "" goto :eof

@echo set ws = WScript.CreateObject^("WScript.Shell"^) > "!script!"
@echo ws.Run "%~dp0!batname! !operation! -w !dest! -f !software!", 0 >> "!script!"
@echo set ws = Nothing >> "!script!"
goto :eof


@REM add to 
:register <result> <path>
set "%~1=0"
call :trim program "%~2"
if "!program!" == "" goto :eof
if not exist "!program!" goto :eof

@REM delete
reg delete "!autostartregpath!" /v "!application!" /f >nul 2>nul
@REM register
reg add "!autostartregpath!" /v "!application!" /t "REG_SZ" /d "!program!" >nul 2>nul
if "!errorlevel!" NEQ "0" goto :eof

@REM approved
reg delete "!startupapproved!" /v "!application!" /f >nul 2>nul
@REM register
reg add "!startupapproved!" /v "!application!" /t "REG_BINARY" /d "02 00 00 00 00 00 00 00 00 00 00 00" >nul 2>nul

if "!errorlevel!" == "0" set "%~1=1"
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
set "tips=[%ESC%[!warncolor!m警告%ESC%[0m] 即将关闭服务并禁用开机自启，是否继续？(%ESC%[!warncolor!mY%ESC%[0m/%ESC%[!warncolor!mN%ESC%[0m) "
if "!msterminal!" == "1" (
    choice /t 6 /d n /n /m "!tips!"
) else (
    set /p "=!tips!" <nul
    choice /t 6 /d n /n
)
if !errorlevel! == 2 exit /b 1

@REM reset max tokens to default
call :recovery_max_tokens

@REM kill process
call :privilege "goto :killprocess !software!" 0

@REM disable auto start
call :disableautostart success
if "!success!" == "0" (
    @echo [%ESC%[91m错误%ESC%[0m] 开机自启%ESC%[91m禁用失败%ESC%[0m，可在%ESC%[!warncolor!m任务管理中心%ESC%[0m手动设置
)

@REM delete scheduled
call :deletetask success "!scheduledname!"
if "!success!" == "0" (
    @echo [%ESC%[91m错误%ESC%[0m] 自动检查跟新取消%ESC%[91m失败%ESC%[0m，可在%ESC%[!warncolor!m任务计划程序%ESC%[0m中手动删除 
)

@REM remove environment
call :privilege "goto :remove_env" 0

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


endlocal
