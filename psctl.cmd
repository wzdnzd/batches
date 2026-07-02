@echo off & pushd "%~dp0"
chcp 65001 >nul 2>nul
setlocal EnableExtensions EnableDelayedExpansion

set "ACTION=%~1"
set "SELF_FULL=%~f0"
set "SELF_DIR=%~dp0"
set "SELF_NAME=%~nx0"
set "SELF_BASE=%~n0"
set "SELF_ID=%SELF_BASE: =_%"

set "BASE=%ProgramData%\PowerShellPolicy"
set "ALIAS_DIR=%BASE%\Aliases"
set "LOGDIR=%BASE%\Logs"
set "LOG=%LOGDIR%\%SELF_ID%.log"
set "TASK_VBS=%SELF_DIR%powershell-replace.vbs"

set "TASK_NAME=PowerShellAutoReplace"
set "DEFAULT_INTERVAL_HOURS=8"
set "INTERVAL_HOURS=%DEFAULT_INTERVAL_HOURS%"

set "SRP=HKLM\SOFTWARE\Policies\Microsoft\Windows\Safer\CodeIdentifiers"

set "GUID_PS64={A51C5F10-5100-4E51-9001-000000000001}"
set "GUID_PS32={A51C5F10-5100-4E51-9001-000000000002}"
set "GUID_ISE64={A51C5F10-5100-4E51-9001-000000000003}"
set "GUID_ISE32={A51C5F10-5100-4E51-9001-000000000004}"

set "SHOW_ADMIN=0"
set "ELEVATED=0"
set "SCHEDULED=0"
set "NO_PROMPT=0"
set "AUTO_CHECK=0"
set "OPTION_ERROR=0"

call :ParseOptions %*
if "%OPTION_ERROR%"=="1" exit /b 1

if "%ACTION%"=="" goto Usage
if /i "%ACTION%"=="help" goto Usage
if /i "%ACTION%"=="-h" goto Usage
if /i "%ACTION%"=="--help" goto Usage
if /i "%ACTION%"=="/?" goto Usage

if not "%ELEVATED%"=="1" (
    call :ValidateArgs %*
    if "%OPTION_ERROR%"=="1" goto Usage
)

if /i "%ACTION%"=="replace" goto ActionReplace
if /i "%ACTION%"=="restore" goto ActionRestore
if /i "%ACTION%"=="status" goto ActionStatus

rem Internal compatibility. Not listed in help
if /i "%ACTION%"=="check" (
    set "ACTION=replace"
    set "SCHEDULED=1"
    set "NO_PROMPT=1"
    set "AUTO_CHECK=0"
    goto ActionReplace
)

if /i "%ACTION%"=="auto" (
    set "ACTION=replace"
    set "AUTO_CHECK=1"
    goto ActionReplace
)

call :Msg "错误：未知操作：%ACTION%"
@echo.
goto Usage


:ActionReplace
call :EnsureDirs

call :IsAdmin
if errorlevel 1 (
    set "ELEVATE_ARGS=replace --elevated --no-prompt %INTERVAL_HOURS%"

    if "%SCHEDULED%"=="1" (
        set "ELEVATE_ARGS=replace --elevated --scheduled --no-prompt %INTERVAL_HOURS%"
    )

    if "%AUTO_CHECK%"=="1" (
        set "ELEVATE_ARGS=replace --elevated --no-prompt --auto-check %INTERVAL_HOURS%"
    )

    call :ElevateAndProxy
    exit /b %ERRORLEVEL%
)

call :DoReplace
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" exit /b %RC%

if "%SCHEDULED%"=="1" exit /b 0
if not "%AUTO_CHECK%"=="1" goto ReplaceDone

call :EnsureAutoTask "%INTERVAL_HOURS%"
set "RC=%ERRORLEVEL%"
call :StepLine "8/8" "%RC%" "检查并安装或更新自动检查修复定时任务"
if not "%RC%"=="0" exit /b %RC%

@echo.
call :PrintAutoTaskConfirmed
call :Msg "执行间隔：每 %INTERVAL_HOURS% 小时"
call :Msg "任务名称：%TASK_NAME%"
call :Msg "任务脚本：%TASK_VBS%"
call :Msg "日志位置：%LOG%"

:ReplaceDone
@echo.
call :Msg "替换完成，你可以运行以下命令查看状态：%SELF_NAME% status"
exit /b 0


:ActionRestore
call :EnsureDirs

call :IsAdmin
if errorlevel 1 (
    set "ELEVATE_ARGS=restore --elevated"
    call :ElevateAndProxy
    exit /b %ERRORLEVEL%
)

call :Restore
exit /b %ERRORLEVEL%


:ActionStatus
call :Status
exit /b 0


:Usage
call :Msg "用法："
call :Msg "  %SELF_NAME% replace [hours] [options]"
call :Msg "  %SELF_NAME% restore [options]"
call :Msg "  %SELF_NAME% status"
@echo.
call :Msg "示例："
call :Msg "  %SELF_NAME% replace"
call :Msg "  %SELF_NAME% replace 8"
call :Msg "  %SELF_NAME% replace /hours:4"
call :Msg "  %SELF_NAME% replace --hours=12"
call :Msg "  %SELF_NAME% replace --auto-check"
call :Msg "  %SELF_NAME% replace --auto-check --hours=4"
call :Msg "  %SELF_NAME% replace --show"
call :Msg "  %SELF_NAME% replace --no-prompt"
call :Msg "  %SELF_NAME% restore"
call :Msg "  %SELF_NAME% status"
@echo.
call :Msg "功能："
call :Msg "  replace [hours]  隐藏并禁用 Windows PowerShell 5.1，创建 powershell.exe 到 pwsh.exe 的别名映射"
call :Msg "  restore          移除本脚本创建的 SRP 规则、别名和定时任务，并恢复旧有入口"
call :Msg "  status           输出当前配置状态报告"
@echo.
call :Msg "选项："
call :Msg "  --auto-check     执行 replace 成功后检查并安装或更新自动修复定时任务"
call :Msg "  --show           非管理员运行时显示提升后的管理员窗口；默认隐藏并将结果回显到当前窗口"
call :Msg "  --no-prompt      非交互模式；当前主要供内部提升或定时任务调用"
@echo.
call :Msg "定时任务间隔："
call :Msg "  默认值：%DEFAULT_INTERVAL_HOURS% 小时"
call :Msg "  合法范围：1-23 小时"
exit /b 1


:ValidateArgs
setlocal EnableDelayedExpansion
set "MAIN=%~1"
set "BAD_ARG="
set "EXPECT_HOURS_VALUE=0"

if /i not "!MAIN!"=="replace" (
    if /i not "!MAIN!"=="restore" (
        if /i not "!MAIN!"=="status" (
            if /i not "!MAIN!"=="check" (
                if /i not "!MAIN!"=="auto" (
                    set "BAD_ARG=!MAIN!"
                    goto ValidateArgsInvalid
                )
            )
        )
    )
)

shift

:ValidateArgsLoop
if "%~1"=="" goto ValidateArgsDone
set "A=%~1"

if "!EXPECT_HOURS_VALUE!"=="1" (
    echo(!A! | findstr /r "^[1-9][0-9]*$" >nul
    if errorlevel 1 (
        set "BAD_ARG=!A!"
        goto ValidateArgsInvalid
    )
    set "EXPECT_HOURS_VALUE=0"
    goto ValidateArgsNext
)

if /i "!A!"=="--show" goto ValidateArgsNext
if /i "!A!"=="--show-admin" goto ValidateArgsNext
if /i "!A!"=="--visible" goto ValidateArgsNext
if /i "!A!"=="--elevated" goto ValidateArgsNext

if /i "!MAIN!"=="replace" (
    if /i "!A!"=="--scheduled" goto ValidateArgsNext
    if /i "!A!"=="--no-prompt" goto ValidateArgsNext
    if /i "!A!"=="--auto-check" goto ValidateArgsNext
    if /i "!A!"=="--hours" (
        set "EXPECT_HOURS_VALUE=1"
        goto ValidateArgsNext
    )
    if /i "!A:~0,7!"=="/hours:" goto ValidateArgsNext
    if /i "!A:~0,8!"=="--hours=" goto ValidateArgsNext
    echo(!A! | findstr /r "^[1-9][0-9]*$" >nul
    if not errorlevel 1 goto ValidateArgsNext
)

set "BAD_ARG=!A!"
goto ValidateArgsInvalid

:ValidateArgsNext
shift
goto ValidateArgsLoop

:ValidateArgsDone
if "!EXPECT_HOURS_VALUE!"=="1" (
    set "BAD_ARG=--hours"
    goto ValidateArgsInvalid
)
endlocal
exit /b 0

:ValidateArgsInvalid
call :Msg "错误：非法参数或命令组合：!BAD_ARG!"
endlocal & set "OPTION_ERROR=1"
exit /b 1


:ParseOptions
set "EXPECT_HOURS_VALUE=0"

:ParseOptionsLoop
if "%~1"=="" exit /b 0

set "ARG=%~1"

if "!EXPECT_HOURS_VALUE!"=="1" (
    call :SetInterval "!ARG!"
    set "EXPECT_HOURS_VALUE=0"
    shift
    goto ParseOptionsLoop
)

if /i "!ARG!"=="--show" set "SHOW_ADMIN=1"
if /i "!ARG!"=="--show-admin" set "SHOW_ADMIN=1"
if /i "!ARG!"=="--visible" set "SHOW_ADMIN=1"
if /i "!ARG!"=="--elevated" set "ELEVATED=1"
if /i "!ARG!"=="--scheduled" set "SCHEDULED=1"
if /i "!ARG!"=="--no-prompt" set "NO_PROMPT=1"
if /i "!ARG!"=="--auto-check" set "AUTO_CHECK=1"
if /i "!ARG!"=="--hours" set "EXPECT_HOURS_VALUE=1"

if /i "!ARG:~0,7!"=="/hours:" (
    call :SetInterval "!ARG:~7!"
)

if /i "!ARG:~0,8!"=="--hours=" (
    call :SetInterval "!ARG:~8!"
)

echo(!ARG! | findstr /r "^[1-9][0-9]*$" >nul
if not errorlevel 1 (
    if /i not "!ARG!"=="replace" (
        if /i not "!ARG!"=="restore" (
            if /i not "!ARG!"=="status" (
                if /i not "!ARG!"=="auto" (
                    if /i not "!ARG!"=="check" (
                        call :SetInterval "!ARG!"
                    )
                )
            )
        )
    )
)

shift
goto ParseOptionsLoop


:SetInterval
set "N=%~1"

echo(%N% | findstr /r "^[1-9][0-9]*$" >nul
if errorlevel 1 (
    call :Msg "错误：无效的定时任务间隔：%N%"
    call :Msg "合法范围：1-23 小时"
    set "OPTION_ERROR=1"
    exit /b 1
)

set /a CHECK_N=%N%

if %CHECK_N% LSS 1 (
    call :Msg "错误：定时任务间隔必须在 1 到 23 小时之间。"
    set "OPTION_ERROR=1"
    exit /b 1
)

if %CHECK_N% GTR 23 (
    call :Msg "错误：定时任务间隔必须在 1 到 23 小时之间。"
    set "OPTION_ERROR=1"
    exit /b 1
)

set "INTERVAL_HOURS=%CHECK_N%"
exit /b 0


:IsAdmin
fltmc >nul 2>&1
exit /b %ERRORLEVEL%


:ElevateAndProxy
if "%SHOW_ADMIN%"=="1" goto ElevateVisible

set "RUN_ID=%RANDOM%%RANDOM%"
set "OUT_LOG=%TEMP%\psctl_%RUN_ID%.out"
set "DONE_FILE=%TEMP%\psctl_%RUN_ID%.done"
set "WRAP=%TEMP%\psctl_%RUN_ID%.cmd"
set "VBS=%TEMP%\psctl_%RUN_ID%.vbs"

del /f /q "%OUT_LOG%" "%DONE_FILE%" "%WRAP%" "%VBS%" >nul 2>&1

> "%WRAP%" echo @echo off
>> "%WRAP%" echo chcp 65001 ^>nul 2^>nul
>> "%WRAP%" echo call "%SELF_FULL%" %ELEVATE_ARGS% ^> "%OUT_LOG%" 2^>^&1
>> "%WRAP%" echo echo %%ERRORLEVEL%%^>"%DONE_FILE%"

> "%VBS%" echo Set UAC = CreateObject("Shell.Application")
>> "%VBS%" echo UAC.ShellExecute "cmd.exe", "/d /q /c ""%WRAP%""", "%CD%", "runas", 0

call :Msg "[权限] ⚠️ 当前权限不足，正在请求 UAC 授权"
cscript //nologo "%VBS%" >nul 2>&1
set "VBS_RC=%ERRORLEVEL%"
del /f /q "%VBS%" >nul 2>&1

if not "%VBS_RC%"=="0" (
    call :Msg "[权限] ❌ 无法请求管理员授权。"
    del /f /q "%WRAP%" >nul 2>&1
    exit /b 1
)

call :Msg "[权限] ⚠️ 已启动隐藏管理员进程，正在等待完成"

set /a WAIT_COUNT=0

:WaitElevatedHidden
if exist "%DONE_FILE%" goto ElevatedHiddenDone
timeout /t 1 /nobreak >nul 2>nul
set /a WAIT_COUNT+=1

if %WAIT_COUNT% GEQ 600 (
    call :Msg "[权限] ❌ 等待管理员进程超时。"
    call :Msg "日志文件：%OUT_LOG%"
    del /f /q "%WRAP%" >nul 2>&1
    exit /b 1
)

goto WaitElevatedHidden


:ElevatedHiddenDone
@echo.

@REM 使用 type "%OUT_LOG%" 命令会导致部分中文输出乱码，必须使用 findstr 命令
findstr /R "^" "%OUT_LOG%"

set /p ELEVATED_RC=<"%DONE_FILE%"

del /f /q "%OUT_LOG%" "%DONE_FILE%" "%WRAP%" >nul 2>&1

exit /b %ELEVATED_RC%


:ElevateVisible
set "RUN_ID=%RANDOM%%RANDOM%"
set "WRAP=%TEMP%\psctl_visible_%RUN_ID%.cmd"
set "VBS=%TEMP%\psctl_visible_%RUN_ID%.vbs"

del /f /q "%WRAP%" "%VBS%" >nul 2>&1

> "%WRAP%" echo @echo off
>> "%WRAP%" echo chcp 65001 ^>nul 2^>nul
>> "%WRAP%" echo call "%SELF_FULL%" %ELEVATE_ARGS%
>> "%WRAP%" echo @echo.
>> "%WRAP%" echo @echo 管理员窗口执行结束，可手动关闭此窗口。
>> "%WRAP%" echo pause ^>nul

> "%VBS%" echo Set UAC = CreateObject("Shell.Application")
>> "%VBS%" echo UAC.ShellExecute "cmd.exe", "/k ""%WRAP%""", "%CD%", "runas", 1

call :Msg "[权限] 当前权限不足，正在请求 UAC 授权..."
cscript //nologo "%VBS%" >nul 2>&1
set "VBS_RC=%ERRORLEVEL%"
del /f /q "%VBS%" >nul 2>&1

if not "%VBS_RC%"=="0" (
    call :Msg "[权限] ❌ 无法请求管理员授权。"
    del /f /q "%WRAP%" >nul 2>&1
    exit /b 1
)

exit /b 0


:EnsureDirs
if not exist "%BASE%" md "%BASE%" >nul 2>&1
if not exist "%ALIAS_DIR%" md "%ALIAS_DIR%" >nul 2>&1
if not exist "%LOGDIR%" md "%LOGDIR%" >nul 2>&1
exit /b 0


:Log
>> "%LOG%" echo [%date% %time%] %~1
exit /b 0


:Msg
@echo(%~1
exit /b 0


:StepLine
if "%~2"=="0" (
    call :Msg "[%~1] ✅ %~3"
) else (
    call :Msg "[%~1] ❌ %~3，错误码：%~2"
)

exit /b 0


:PrintAutoTaskConfirmed
call :Msg "自动检查修复定时任务已确认"
exit /b 0


:StepCleanProgramData
if "%~1"=="0" goto StepCleanProgramDataOk
call :Msg "[8/8] ❌ 清理由本脚本生成的 ProgramData/PowerShellPolicy 目录，错误码：%~1"
exit /b 0

:StepCleanProgramDataOk
call :Msg "[8/8] ✅ 清理由本脚本生成的 ProgramData/PowerShellPolicy 目录"
exit /b 0


:DoReplace
@echo.
call :Msg "正在执行替换及隐藏配置"
call :Log "开始执行隐藏或检查操作"

call :EnsureSrpBlacklist
set "RC=%ERRORLEVEL%"
call :StepLine "1/7" "%RC%" "配置 SRP 禁用规则"
if not "%RC%"=="0" exit /b %RC%

call :RemoveOldAppPaths
set "RC=%ERRORLEVEL%"
call :StepLine "2/7" "%RC%" "清理旧版 powershell.exe 路径相关注册表配置项"
if not "%RC%"=="0" exit /b %RC%

call :CleanLoadedUsers
set "RC=%ERRORLEVEL%"
call :StepLine "3/7" "%RC%" "清理已加载用户的 PATH 和 powershell.exe 注册表项"
if not "%RC%"=="0" exit /b %RC%

call :CleanMachineAndCurrentUserPath
set "RC=%ERRORLEVEL%"
call :StepLine "4/7" "%RC%" "清理系统和当前用户 PATH 并加入别名目录"
if not "%RC%"=="0" exit /b %RC%

call :RemoveStartMenuLinks
set "RC=%ERRORLEVEL%"
call :StepLine "5/7" "%RC%" "移除开始菜单中的旧有 PowerShell 入口"
if not "%RC%"=="0" exit /b %RC%

call :EnsurePwshAlias
set "RC=%ERRORLEVEL%"
call :StepLine "6/7" "%RC%" "创建 powershell.exe 到 pwsh.exe 的别名映射"
if not "%RC%"=="0" exit /b %RC%

gpupdate /target:computer /force >nul 2>&1
set "RC=%ERRORLEVEL%"
call :StepLine "7/7" "%RC%" "刷新计算机策略"

call :Log "替换或检查操作完成"
exit /b %RC%


:CleanMachineAndCurrentUserPath
call :CleanPathKey "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" 1
if errorlevel 1 exit /b %ERRORLEVEL%

call :CleanPathKey "HKCU\Environment" 1
if errorlevel 1 exit /b %ERRORLEVEL%

call :Log "已清理系统和当前用户 PATH 并加入别名目录"
exit /b 0


:CleanLoadedUsers
for /f "delims=" %%S in ('reg query HKU 2^>nul ^| findstr /r /c:"^HKEY_USERS\\S-1-5-21-" ^| findstr /v /i "_Classes"') do (
    call :CleanPathKey "%%S\Environment" 0
    call :DeleteAppPathIfOld "%%S\Software\Microsoft\Windows\CurrentVersion\App Paths\powershell.exe"
    call :DeleteAppPathIfOld "%%S\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\powershell.exe"
)
exit /b 0


:EnsureSrpBlacklist
reg add "%SRP%" /v DefaultLevel /t REG_DWORD /d 0x00040000 /f >nul || exit /b 1
reg add "%SRP%" /v TransparentEnabled /t REG_DWORD /d 1 /f >nul || exit /b 1
reg add "%SRP%" /v PolicyScope /t REG_DWORD /d 0 /f >nul || exit /b 1
reg add "%SRP%" /v AuthenticodeEnabled /t REG_DWORD /d 0 /f >nul || exit /b 1

reg add "%SRP%\0" /f >nul 2>&1 || exit /b 1
reg add "%SRP%\0\Paths" /f >nul 2>&1 || exit /b 1

call :AddSrpRule "%GUID_PS64%" "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" "禁用 Windows PowerShell 5.1 x64" || exit /b 1
call :AddSrpRule "%GUID_PS32%" "%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe" "禁用 Windows PowerShell 5.1 x86" || exit /b 1
call :AddSrpRule "%GUID_ISE64%" "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell_ise.exe" "禁用 Windows PowerShell ISE x64" || exit /b 1
call :AddSrpRule "%GUID_ISE32%" "%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell_ise.exe" "禁用 Windows PowerShell ISE x86" || exit /b 1

call :Log "已确保 SRP 禁用规则存在"
exit /b 0


:AddSrpRule
set "RULEKEY=%SRP%\0\Paths\%~1"
reg add "%RULEKEY%" /v ItemData /t REG_SZ /d "%~2" /f >nul || exit /b 1
reg add "%RULEKEY%" /v SaferFlags /t REG_DWORD /d 0 /f >nul || exit /b 1
reg add "%RULEKEY%" /v Description /t REG_SZ /d "%~3" /f >nul || exit /b 1
exit /b 0


:RemoveOldAppPaths
call :DeleteAppPathIfOld "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\powershell.exe"
call :DeleteAppPathIfOld "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\powershell.exe"
exit /b 0


:DeleteAppPathIfOld
reg query "%~1" /ve 2>nul | findstr /i /c:"WindowsPowerShell\v1.0\powershell.exe" >nul
if not errorlevel 1 (
    reg delete "%~1" /f >nul 2>&1
    call :Log "已删除旧版 App Paths：%~1"
)
exit /b 0


:CleanPathKey
setlocal DisableDelayedExpansion
set "KEY=%~1"
set "ADDALIAS=%~2"
set "VBS=%TEMP%\psctl_path_%RANDOM%_%RANDOM%.vbs"

> "%VBS%" echo Set sh = CreateObject("WScript.Shell")
>> "%VBS%" echo key = WScript.Arguments(0)
>> "%VBS%" echo addAlias = WScript.Arguments(1)
>> "%VBS%" echo aliasDir = WScript.Arguments(2)
>> "%VBS%" echo sysroot = WScript.Arguments(3)
>> "%VBS%" echo remove1 = Norm(sysroot ^& "\System32\WindowsPowerShell\v1.0")
>> "%VBS%" echo remove2 = Norm(sysroot ^& "\SysWOW64\WindowsPowerShell\v1.0")
>> "%VBS%" echo aliasNorm = Norm(aliasDir)
>> "%VBS%" echo On Error Resume Next
>> "%VBS%" echo oldPath = sh.RegRead(key ^& "\Path")
>> "%VBS%" echo If Err.Number ^<^> 0 Then
>> "%VBS%" echo     Err.Clear
>> "%VBS%" echo     If addAlias = "1" Then
>> "%VBS%" echo         sh.RegWrite key ^& "\Path", aliasDir, "REG_EXPAND_SZ"
>> "%VBS%" echo     End If
>> "%VBS%" echo     WScript.Quit 0
>> "%VBS%" echo End If
>> "%VBS%" echo On Error GoTo 0
>> "%VBS%" echo parts = Split(oldPath, ";")
>> "%VBS%" echo newPath = ""
>> "%VBS%" echo For Each item In parts
>> "%VBS%" echo     item = Trim(item)
>> "%VBS%" echo     If Not item = "" Then
>> "%VBS%" echo         n = Norm(item)
>> "%VBS%" echo         keep = True
>> "%VBS%" echo         If LCase(n) = LCase(remove1) Then keep = False
>> "%VBS%" echo         If LCase(n) = LCase(remove2) Then keep = False
>> "%VBS%" echo         If LCase(n) = LCase(aliasNorm) Then keep = False
>> "%VBS%" echo         If keep Then
>> "%VBS%" echo             If newPath = "" Then
>> "%VBS%" echo                 newPath = item
>> "%VBS%" echo             Else
>> "%VBS%" echo                 newPath = newPath ^& ";" ^& item
>> "%VBS%" echo             End If
>> "%VBS%" echo         End If
>> "%VBS%" echo     End If
>> "%VBS%" echo Next
>> "%VBS%" echo If addAlias = "1" Then
>> "%VBS%" echo     If newPath = "" Then
>> "%VBS%" echo         newPath = aliasDir
>> "%VBS%" echo     Else
>> "%VBS%" echo         newPath = aliasDir ^& ";" ^& newPath
>> "%VBS%" echo     End If
>> "%VBS%" echo End If
>> "%VBS%" echo If Not newPath = oldPath Then
>> "%VBS%" echo     sh.RegWrite key ^& "\Path", newPath, "REG_EXPAND_SZ"
>> "%VBS%" echo End If
>> "%VBS%" echo WScript.Quit 0
>> "%VBS%" echo Function Norm(x)
>> "%VBS%" echo     y = sh.ExpandEnvironmentStrings(x)
>> "%VBS%" echo     Do While Len(y) ^> 0 And Right(y, 1) = "\"
>> "%VBS%" echo         y = Left(y, Len(y) - 1)
>> "%VBS%" echo     Loop
>> "%VBS%" echo     Norm = y
>> "%VBS%" echo End Function

cscript //nologo "%VBS%" "%KEY%" "%ADDALIAS%" "%ALIAS_DIR%" "%SystemRoot%" >nul 2>&1
set "RC=%ERRORLEVEL%"
del /f /q "%VBS%" >nul 2>&1

endlocal & exit /b %RC%


:RemoveStartMenuLinks
rmdir /s /q "%ProgramData%\Microsoft\Windows\Start Menu\Programs\Windows PowerShell" >nul 2>&1

for /d %%U in ("C:\Users\*") do (
    rmdir /s /q "%%~fU\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Windows PowerShell" >nul 2>&1
)

for /r "%ProgramData%\Microsoft\Windows\Start Menu\Programs" %%F in (*Windows PowerShell*.lnk) do (
    del /f /q "%%~fF" >nul 2>&1
)

call :Log "已移除开始菜单中的 Windows PowerShell 旧入口"
exit /b 0


:EnsurePwshAlias
call :FindPwshTarget

if not defined PWSH_TARGET (
    call :Log "未找到 pwsh.exe，无法创建 powershell.exe 别名"
    exit /b 1
)

if not exist "%ALIAS_DIR%" md "%ALIAS_DIR%" >nul 2>&1

> "%ALIAS_DIR%\powershell.cmd" echo @echo off
>> "%ALIAS_DIR%\powershell.cmd" echo "%PWSH_TARGET%" %%*

copy /y "%ALIAS_DIR%\powershell.cmd" "%ALIAS_DIR%\powershell.bat" >nul 2>&1

del /f /q "%ALIAS_DIR%\powershell.exe" >nul 2>&1
mklink "%ALIAS_DIR%\powershell.exe" "%PWSH_TARGET%" >nul 2>&1

if not exist "%ALIAS_DIR%\powershell.exe" (
    call :Log "powershell.exe 符号链接创建失败"
    exit /b 1
)

reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\powershell.exe" /ve /t REG_SZ /d "%ALIAS_DIR%\powershell.exe" /f >nul || exit /b 1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\powershell.exe" /v Path /t REG_SZ /d "%ALIAS_DIR%" /f >nul || exit /b 1

reg add "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\powershell.exe" /ve /t REG_SZ /d "%ALIAS_DIR%\powershell.exe" /f >nul || exit /b 1
reg add "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\powershell.exe" /v Path /t REG_SZ /d "%ALIAS_DIR%" /f >nul || exit /b 1

call :Log "已注册 powershell.exe 别名：%ALIAS_DIR%\powershell.exe"
exit /b 0


:FindPwshTarget
set "PWSH_TARGET="

if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" (
    set "PWSH_TARGET=%ProgramFiles%\PowerShell\7\pwsh.exe"
    exit /b 0
)

for /f "delims=" %%D in ('dir /b /ad /o-n "%ProgramFiles%\WindowsApps\Microsoft.PowerShell_*_x64__8wekyb3d8bbwe" 2^>nul') do (
    if not defined PWSH_TARGET if exist "%ProgramFiles%\WindowsApps\%%D\pwsh.exe" (
        set "PWSH_TARGET=%ProgramFiles%\WindowsApps\%%D\pwsh.exe"
    )
)

if defined PWSH_TARGET exit /b 0

if exist "%LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe" (
    set "PWSH_TARGET=%LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe"
    exit /b 0
)

for /f "delims=" %%P in ('where pwsh.exe 2^>nul') do (
    if not defined PWSH_TARGET set "PWSH_TARGET=%%P"
)

exit /b 0


:EnsureAutoTask
set "INTERVAL=%~1"

call :WriteTaskVbs "%INTERVAL%"
if errorlevel 1 exit /b 1

set "EXPECTED_INTERVAL=PT%INTERVAL%H"
set "TASK_XML=%TEMP%\psctl_task_%RANDOM%_%RANDOM%.xml"
set "NEED_RECREATE=0"

schtasks /query /tn "%TASK_NAME%" /xml > "%TASK_XML%" 2>nul

if errorlevel 1 (
    set "NEED_RECREATE=1"
) else (
    findstr /i /c:"<Enabled>true</Enabled>" "%TASK_XML%" >nul || set "NEED_RECREATE=1"
    findstr /i /c:"<RunLevel>HighestAvailable</RunLevel>" "%TASK_XML%" >nul || set "NEED_RECREATE=1"
    findstr /i /c:"wscript.exe" "%TASK_XML%" >nul || set "NEED_RECREATE=1"
    findstr /i /c:"%TASK_VBS%" "%TASK_XML%" >nul || set "NEED_RECREATE=1"
    findstr /i /c:"%EXPECTED_INTERVAL%" "%TASK_XML%" >nul || set "NEED_RECREATE=1"
)

del /f /q "%TASK_XML%" >nul 2>&1

if "%NEED_RECREATE%"=="0" (
    schtasks /change /tn "%TASK_NAME%" /enable >nul 2>&1
    call :Log "自动检查修复定时任务已存在且配置一致"
    exit /b 0
)

schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1

set "TASK_TR="%SystemRoot%\System32\wscript.exe" //B //Nologo "%TASK_VBS%""

schtasks /create ^
    /tn "%TASK_NAME%" ^
    /sc hourly ^
    /mo %INTERVAL% ^
    /st 00:00 ^
    /rl HIGHEST ^
    /tr "%TASK_TR%" ^
    /f >nul 2>&1

if errorlevel 1 (
    call :Log "创建定时任务失败"
    exit /b 1
)

schtasks /change /tn "%TASK_NAME%" /enable >nul 2>&1
schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if errorlevel 1 (
    call :Log "创建后未能查询到定时任务"
    exit /b 1
)

call :Log "已安装自动检查任务：每 %INTERVAL% 小时执行一次"
exit /b 0


:WriteTaskVbs
setlocal DisableDelayedExpansion
set "INTERVAL=%~1"
set "SCRIPT_PATH=%SELF_FULL%"
set "LOG_PATH=%LOG%"

set "SCRIPT_ESC=%SCRIPT_PATH:&=^&%"
set "LOG_ESC=%LOG_PATH:&=^&%"

> "%TASK_VBS%" echo Set sh = CreateObject("WScript.Shell")
>> "%TASK_VBS%" echo Set fso = CreateObject("Scripting.FileSystemObject")
>> "%TASK_VBS%" echo scriptPath = "%SCRIPT_ESC%"
>> "%TASK_VBS%" echo logPath = "%LOG_ESC%"
>> "%TASK_VBS%" echo logDir = fso.GetParentFolderName(logPath)
>> "%TASK_VBS%" echo baseDir = fso.GetParentFolderName(logDir)
>> "%TASK_VBS%" echo On Error Resume Next
>> "%TASK_VBS%" echo If Not fso.FolderExists(baseDir) Then fso.CreateFolder(baseDir)
>> "%TASK_VBS%" echo If Not fso.FolderExists(logDir) Then fso.CreateFolder(logDir)
>> "%TASK_VBS%" echo If fso.FileExists(logPath) Then fso.DeleteFile logPath, True
>> "%TASK_VBS%" echo On Error GoTo 0
>> "%TASK_VBS%" echo cmd = "cmd.exe /d /q /c chcp 65001 ^>nul 2^>nul ^& " ^& Chr(34) ^& scriptPath ^& Chr(34) ^& " replace --scheduled --no-prompt %INTERVAL% ^>^> " ^& Chr(34) ^& logPath ^& Chr(34) ^& " 2^>^&1"
>> "%TASK_VBS%" echo sh.Run cmd, 0, True

if not exist "%TASK_VBS%" (
    endlocal
    exit /b 1
)

endlocal
exit /b 0


:Restore
@echo.
call :Msg "正在执行 PowerShell 5.1 恢复操作"
call :Log "开始执行恢复操作"
set "RESTORE_FAILED=0"

call :RemoveAutoTask
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" set "RESTORE_FAILED=1"
call :StepLine "1/8" "%RC%" "移除自动检查并隐藏定时任务"

call :RemoveSrpRules
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" set "RESTORE_FAILED=1"
call :StepLine "2/8" "%RC%" "移除本脚本创建的 SRP 应用禁用规则"

call :RemoveAliasAndAliasPaths
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" set "RESTORE_FAILED=1"
call :StepLine "3/8" "%RC%" "移除 PowerShell 7 别名映射和应用路径相关注册表配置项"

call :RestoreOldAppPaths
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" set "RESTORE_FAILED=1"
call :StepLine "4/8" "%RC%" "恢复旧版 Windows PowerShell 应用路径相关注册表配置项"

call :RestoreOldMachinePath
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" set "RESTORE_FAILED=1"
call :StepLine "5/8" "%RC%" "添加旧版 Windows PowerShell 到系统和当前用户 PATH 变量"

call :RestoreStartMenuLinks
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" set "RESTORE_FAILED=1"
call :StepLine "6/8" "%RC%" "恢复开始菜单中的 Windows PowerShell 入口"

gpupdate /target:computer /force >nul 2>&1
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" set "RESTORE_FAILED=1"
call :StepLine "7/8" "%RC%" "刷新计算机软件限制策略"

if "%RESTORE_FAILED%"=="0" (
    call :CleanupProgramData
    set "RC=%ERRORLEVEL%"
    call :StepCleanProgramData "%RC%"
    exit /b %RC%
) else (
    call :StepLine "8/8" "1" "跳过 ProgramData/PowerShellPolicy 清理，因为前面的恢复步骤存在失败"
    exit /b 1
)


:RemoveAutoTask
schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if not errorlevel 1 (
    schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1
)
if exist "%TASK_VBS%" del /f /q "%TASK_VBS%" >nul 2>&1
call :Log "已移除自动检查任务"
exit /b 0


:CleanupProgramData
if exist "%ALIAS_DIR%" rmdir /s /q "%ALIAS_DIR%" >nul 2>&1
if exist "%LOGDIR%" rmdir /s /q "%LOGDIR%" >nul 2>&1

if exist "%BASE%" (
    dir /a /b "%BASE%" 2>nul | findstr . >nul
    if errorlevel 1 (
        rmdir /q "%BASE%" >nul 2>&1
    )
)

exit /b 0


:RemoveSrpRules
reg delete "%SRP%\0\Paths\%GUID_PS64%" /f >nul 2>&1
reg delete "%SRP%\0\Paths\%GUID_PS32%" /f >nul 2>&1
reg delete "%SRP%\0\Paths\%GUID_ISE64%" /f >nul 2>&1
reg delete "%SRP%\0\Paths\%GUID_ISE32%" /f >nul 2>&1
call :Log "已移除本脚本创建的 SRP 规则"
exit /b 0


:RemoveAliasAndAliasPaths
call :DeleteAppPathIfAlias "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\powershell.exe"
call :DeleteAppPathIfAlias "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\powershell.exe"

call :DeleteAppPathIfAlias "HKCU\Software\Microsoft\Windows\CurrentVersion\App Paths\powershell.exe"
call :DeleteAppPathIfAlias "HKCU\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\powershell.exe"
call :RemoveAliasFromPathKey "HKCU\Environment"

for /f "delims=" %%S in ('reg query HKU 2^>nul ^| findstr /r /c:"^HKEY_USERS\\S-1-5-21-" ^| findstr /v /i "_Classes"') do (
    call :DeleteAppPathIfAlias "%%S\Software\Microsoft\Windows\CurrentVersion\App Paths\powershell.exe"
    call :DeleteAppPathIfAlias "%%S\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\powershell.exe"
    call :RemoveAliasFromPathKey "%%S\Environment"
)

call :RemoveAliasFromPathKey "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"

rmdir /s /q "%ALIAS_DIR%" >nul 2>&1

call :Log "已移除 powershell.exe 到 pwsh.exe 的别名映射"
exit /b 0


:DeleteAppPathIfAlias
reg query "%~1" /ve 2>nul | findstr /i /c:"PowerShellPolicy\Aliases\powershell.exe" >nul
if not errorlevel 1 (
    reg delete "%~1" /f >nul 2>&1
)
exit /b 0


:RemoveAliasFromPathKey
setlocal DisableDelayedExpansion
set "KEY=%~1"
set "VBS=%TEMP%\psctl_remove_alias_%RANDOM%_%RANDOM%.vbs"

> "%VBS%" echo Set sh = CreateObject("WScript.Shell")
>> "%VBS%" echo key = WScript.Arguments(0)
>> "%VBS%" echo aliasDir = WScript.Arguments(1)
>> "%VBS%" echo aliasNorm = Norm(aliasDir)
>> "%VBS%" echo On Error Resume Next
>> "%VBS%" echo oldPath = sh.RegRead(key ^& "\Path")
>> "%VBS%" echo If Err.Number ^<^> 0 Then WScript.Quit 0
>> "%VBS%" echo On Error GoTo 0
>> "%VBS%" echo parts = Split(oldPath, ";")
>> "%VBS%" echo newPath = ""
>> "%VBS%" echo For Each item In parts
>> "%VBS%" echo     item = Trim(item)
>> "%VBS%" echo     If Not item = "" Then
>> "%VBS%" echo         If Not LCase(Norm(item)) = LCase(aliasNorm) Then
>> "%VBS%" echo             If newPath = "" Then
>> "%VBS%" echo                 newPath = item
>> "%VBS%" echo             Else
>> "%VBS%" echo                 newPath = newPath ^& ";" ^& item
>> "%VBS%" echo             End If
>> "%VBS%" echo         End If
>> "%VBS%" echo     End If
>> "%VBS%" echo Next
>> "%VBS%" echo If Not newPath = oldPath Then sh.RegWrite key ^& "\Path", newPath, "REG_EXPAND_SZ"
>> "%VBS%" echo WScript.Quit 0
>> "%VBS%" echo Function Norm(x)
>> "%VBS%" echo     y = sh.ExpandEnvironmentStrings(x)
>> "%VBS%" echo     Do While Len(y) ^> 0 And Right(y, 1) = "\"
>> "%VBS%" echo         y = Left(y, Len(y) - 1)
>> "%VBS%" echo     Loop
>> "%VBS%" echo     Norm = y
>> "%VBS%" echo End Function

cscript //nologo "%VBS%" "%KEY%" "%ALIAS_DIR%" >nul 2>&1
set "RC=%ERRORLEVEL%"
del /f /q "%VBS%" >nul 2>&1

endlocal & exit /b %RC%


:RestoreOldAppPaths
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\powershell.exe" /ve /t REG_SZ /d "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" /f >nul || exit /b 1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\powershell.exe" /v Path /t REG_SZ /d "%SystemRoot%\System32\WindowsPowerShell\v1.0" /f >nul || exit /b 1

if exist "%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe" (
    reg add "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\powershell.exe" /ve /t REG_SZ /d "%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe" /f >nul
    reg add "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\powershell.exe" /v Path /t REG_SZ /d "%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0" /f >nul
)

call :Log "已恢复旧版 Windows PowerShell 的应用路径相关注册表配置项"
exit /b 0


:RestoreOldMachinePath
call :RestoreOldPathKey "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
if errorlevel 1 exit /b %ERRORLEVEL%

call :RestoreOldPathKey "HKCU\Environment"
exit /b %ERRORLEVEL%


:RestoreOldPathKey
setlocal DisableDelayedExpansion
set "KEY=%~1"
set "VBS=%TEMP%\psctl_restore_path_%RANDOM%_%RANDOM%.vbs"

> "%VBS%" echo Set sh = CreateObject("WScript.Shell")
>> "%VBS%" echo key = WScript.Arguments(0)
>> "%VBS%" echo sysroot = WScript.Arguments(1)
>> "%VBS%" echo oldItem = "%%SystemRoot%%\System32\WindowsPowerShell\v1.0"
>> "%VBS%" echo oldNorm = Norm(sysroot ^& "\System32\WindowsPowerShell\v1.0")
>> "%VBS%" echo On Error Resume Next
>> "%VBS%" echo oldPath = sh.RegRead(key ^& "\Path")
>> "%VBS%" echo If Err.Number ^<^> 0 Then
>> "%VBS%" echo     Err.Clear
>> "%VBS%" echo     sh.RegWrite key ^& "\Path", oldItem, "REG_EXPAND_SZ"
>> "%VBS%" echo     WScript.Quit 0
>> "%VBS%" echo End If
>> "%VBS%" echo On Error GoTo 0
>> "%VBS%" echo hasOld = False
>> "%VBS%" echo parts = Split(oldPath, ";")
>> "%VBS%" echo For Each item In parts
>> "%VBS%" echo     If LCase(Norm(item)) = LCase(oldNorm) Then hasOld = True
>> "%VBS%" echo Next
>> "%VBS%" echo If Not hasOld Then
>> "%VBS%" echo     If oldPath = "" Then
>> "%VBS%" echo         newPath = oldItem
>> "%VBS%" echo     Else
>> "%VBS%" echo         newPath = oldPath ^& ";" ^& oldItem
>> "%VBS%" echo     End If
>> "%VBS%" echo     sh.RegWrite key ^& "\Path", newPath, "REG_EXPAND_SZ"
>> "%VBS%" echo End If
>> "%VBS%" echo WScript.Quit 0
>> "%VBS%" echo Function Norm(x)
>> "%VBS%" echo     y = sh.ExpandEnvironmentStrings(Trim(x))
>> "%VBS%" echo     Do While Len(y) ^> 0 And Right(y, 1) = "\"
>> "%VBS%" echo         y = Left(y, Len(y) - 1)
>> "%VBS%" echo     Loop
>> "%VBS%" echo     Norm = y
>> "%VBS%" echo End Function

cscript //nologo "%VBS%" "%KEY%" "%SystemRoot%" >nul 2>&1
set "RC=%ERRORLEVEL%"
del /f /q "%VBS%" >nul 2>&1

endlocal & exit /b %RC%

:RestoreStartMenuLinks
set "VBS=%TEMP%\ps51_links_%RANDOM%.vbs"

> "%VBS%" echo Set W = CreateObject("WScript.Shell")
>> "%VBS%" echo Set F = CreateObject("Scripting.FileSystemObject")
>> "%VBS%" echo D = W.ExpandEnvironmentStrings("%%ProgramData%%") ^& "\Microsoft\Windows\Start Menu\Programs\Windows PowerShell"
>> "%VBS%" echo If Not F.FolderExists(D) Then F.CreateFolder(D)
>> "%VBS%" echo Sub L(N,T)
>> "%VBS%" echo Set S = W.CreateShortcut(D ^& "\" ^& N)
>> "%VBS%" echo S.TargetPath = T
>> "%VBS%" echo S.WorkingDirectory = W.ExpandEnvironmentStrings("%%USERPROFILE%%")
>> "%VBS%" echo S.Save
>> "%VBS%" echo End Sub

if exist "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" (
    >> "%VBS%" echo L "Windows PowerShell.lnk", "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
)

if exist "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell_ise.exe" (
    >> "%VBS%" echo L "Windows PowerShell ISE.lnk", "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell_ise.exe"
)

if exist "%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe" (
    >> "%VBS%" echo L "Windows PowerShell (x86).lnk", "%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
)

if exist "%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell_ise.exe" (
    >> "%VBS%" echo L "Windows PowerShell ISE (x86).lnk", "%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell_ise.exe"
)

cscript //nologo "%VBS%" >nul 2>&1
set "RC=%ERRORLEVEL%"
del /f /q "%VBS%" >nul 2>&1

if not "%RC%"=="0" exit /b %RC%

call :Log "已恢复开始菜单中的 Windows PowerShell 旧有入口"
exit /b 0


:StatusAppPath
setlocal DisableDelayedExpansion
set "APP_REG=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\powershell.exe"
set "APP_PATH="

reg query "%APP_REG%" /ve >nul 2>&1
if errorlevel 1 goto StatusAppPathMissing

for /f "tokens=1,2,*" %%A in ('reg query "%APP_REG%" /ve 2^>nul ^| findstr /i "REG_"') do (
    set "APP_PATH=%%C"
)

if not defined APP_PATH goto StatusAppPathEmpty

call :Msg "  ✅ 已配置：注册表中 powershell.exe 路径为 %APP_PATH%"
endlocal
exit /b 0

:StatusAppPathEmpty
call :Msg "  ❌ 已配置但未读取到 powershell.exe 注册表路径"
endlocal
exit /b 1

:StatusAppPathMissing
call :Msg "  ❌ 未配置：powershell.exe 相关注册表路径不存在"
endlocal
exit /b 1


:StatusTaskDetail
setlocal DisableDelayedExpansion
set "TASK_OUT=%TEMP%\psctl_task_status_%RANDOM%_%RANDOM%.txt"

schtasks /query /tn "%TASK_NAME%" /fo LIST /v > "%TASK_OUT%" 2>nul

for /f "usebackq delims=" %%L in ("%TASK_OUT%") do (
    echo(  %%L
)

del /f /q "%TASK_OUT%" >nul 2>&1
endlocal
exit /b 0


:StatusPathLookup
setlocal DisableDelayedExpansion
set "EXE_NAME=%~1"
set "FOUND="
set "OUT=%TEMP%\psctl_where_%RANDOM%_%RANDOM%.out"

where.exe "%EXE_NAME%" > "%OUT%" 2>nul

for /f "usebackq delims=" %%P in ("%OUT%") do (
    if not defined FOUND set "FOUND=%%P"
)

del /f /q "%OUT%" >nul 2>&1

if defined FOUND goto StatusPathLookupFound
goto StatusPathLookupMissing


:StatusPathLookupFound
setlocal EnableDelayedExpansion
echo(  !EXE_NAME! -^> !FOUND!
endlocal
endlocal
exit /b 0


:StatusPathLookupMissing
setlocal EnableDelayedExpansion
echo(  !EXE_NAME! -^> 未找到（基于当前终端 PATH）
endlocal
endlocal
exit /b 1


:Status
@echo.
call :Msg "PowerShell 状态报告"
@echo.

call :Msg "[脚本信息]"
@echo   当前脚本：%SELF_FULL%
@echo   别名目录：%ALIAS_DIR%
@echo   日志位置：%LOG%

@echo.
call :Msg "[SRP 默认级别]"
reg query "%SRP%" /v DefaultLevel 2>nul | findstr /i "0x40000" >nul
if errorlevel 1 (
    call :Msg "  ❌ 异常：未确认 SRP 默认级别为 “不受限”"
) else (
    call :Msg "  ✅ 正常：SRP 默认级别为 “不受限”"
)

@echo.
call :Msg "[SRP 禁用规则]"
call :StatusRule "%GUID_PS64%" "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
call :StatusRule "%GUID_PS32%" "%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
call :StatusRule "%GUID_ISE64%" "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell_ise.exe"
call :StatusRule "%GUID_ISE32%" "%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell_ise.exe"

@echo.
call :Msg "[系统环境变量]"
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2>nul | findstr /i /c:"PowerShellPolicy\Aliases" >nul
if errorlevel 1 (
    call :Msg "  ❌ 未配置：别名目录不在系统 PATH 中"
) else (
    call :Msg "  ✅ 正常：别名目录已加入系统 PATH"
)

reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2>nul | findstr /i /c:"WindowsPowerShell\v1.0" >nul
if errorlevel 1 (
    call :Msg "  ✅ 正常：旧版 Windows PowerShell 路径不在系统 PATH 中"
) else (
    call :Msg "  ❌ 警告：旧版 Windows PowerShell 路径仍在系统 PATH 中"
)

@echo.
call :Msg "[当前用户环境变量]"
reg query "HKCU\Environment" /v Path 2>nul | findstr /i /c:"PowerShellPolicy\Aliases" >nul
if errorlevel 1 (
    call :Msg "  ❌ 未配置：别名目录不在当前用户 PATH 中"
) else (
    call :Msg "  ✅ 正常：别名目录已加入当前用户 PATH"
)

reg query "HKCU\Environment" /v Path 2>nul | findstr /i /c:"WindowsPowerShell\v1.0" >nul
if errorlevel 1 (
    call :Msg "  ✅ 正常：旧版 Windows PowerShell 路径不在当前用户 PATH 中"
) else (
    call :Msg "  ❌ 警告：旧版 Windows PowerShell 路径仍在当前用户 PATH 中"
)

@echo.
call :Msg "[别名文件]"
if exist "%ALIAS_DIR%\powershell.cmd" (
    call :Msg "  ✅ 正常：%ALIAS_DIR%\powershell.cmd"
) else (
    call :Msg "  ❌ 未配置：%ALIAS_DIR%\powershell.cmd"
)

if exist "%ALIAS_DIR%\powershell.exe" (
    call :Msg "  ✅ 正常：%ALIAS_DIR%\powershell.exe"
) else (
    call :Msg "  ❌ 未配置：%ALIAS_DIR%\powershell.exe"
)

@echo.
call :Msg "[注册表项]"
call :StatusAppPath

@echo.
call :Msg "[定时任务]"
schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if errorlevel 1 (
    call :Msg "  ❌ 未配置：%TASK_NAME%"
) else (
    call :Msg "  ✅ 已存在：%TASK_NAME%"
    @echo.
    call :StatusTaskDetail
)

@echo.
call :Msg "[应用路径检测结果] 提示：检测基于当前进程的 PATH，执行 replace 或 restore 后请新开一个终端再次检测"
call :StatusPathLookup "powershell.exe"
call :StatusPathLookup "pwsh.exe"

@echo.
exit /b 0


:StatusRule
reg query "%SRP%\0\Paths\%~1" /v ItemData 2>nul | findstr /i /c:"%~2" >nul
if errorlevel 1 (
    call :Msg "  ❌ 未配置：%~2"
) else (
    call :Msg "  ✅ 正常：%~2"
)
exit /b 0