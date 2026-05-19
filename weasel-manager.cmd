@echo off
setlocal EnableExtensions DisableDelayedExpansion

rem ============================================================
rem Weasel Manager - Scoop-style installer
rem Pure Batch version. No JScript.
rem PowerShell is only used for RunAs elevation.
rem ============================================================

set "API_URL=https://api.github.com/repos/rime/weasel/releases?per_page=10"
set "DOWNLOAD_BASE=https://github.com/rime/weasel/releases/download"
set "UA=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36"

set "MANAGER_NAME=%~nx0"
set "MANAGER_BASE=%~n0"
set "MANAGER_SELF=%~f0"
set "STATE_NAME=%MANAGER_BASE%.state"

set "REG_WEASEL=HKLM\Software\Rime\Weasel"
set "REG_MANAGER=HKLM\Software\Rime\WeaselManager"
set "REG_UNINSTALL=HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\Weasel"
set "REG_RUN=HKLM\Software\Microsoft\Windows\CurrentVersion\Run"

set "ACTION=%~1"
if "%ACTION%"=="" goto usage
shift

set "APP_DIR="
set "INSTALLER="
set "REQUEST_VERSION="
set "CHANNEL=stable"
set "CHANNEL_SPECIFIED=0"
set "YES=0"
set "FORCE=0"
set "NO_START=0"
set "PURGE=0"
set "SEVENZIP="
set "RIME_USER_DIR="
set "SYNC_REPO_DIR="
set "CONTEXT_FILE="
set "INSTALL_MODE="
set "ADMIN_WINDOW=hide"
set "GIT_UPDATED=0"

goto parse_args


rem ============================================================
rem argument parser
rem ============================================================

:parse_args
if "%~1"=="" goto args_done

if /I "%~1"=="--dir" goto opt_dir
if /I "%~1"=="--installer" goto opt_installer
if /I "%~1"=="--version" goto opt_version
if /I "%~1"=="--channel" goto opt_channel
if /I "%~1"=="--stable" goto opt_stable
if /I "%~1"=="--beta" goto opt_beta
if /I "%~1"=="--7z" goto opt_7z
if /I "%~1"=="--data-dir" goto opt_data_dir
if /I "%~1"=="--rime-dir" goto opt_data_dir
if /I "%~1"=="--context" goto opt_context
if /I "%~1"=="--admin-window" goto opt_admin_window
if /I "%~1"=="--show-admin-window" goto opt_show_admin_window
if /I "%~1"=="--hide-admin-window" goto opt_hide_admin_window
if /I "%~1"=="--yes" goto opt_yes
if /I "%~1"=="--force" goto opt_force
if /I "%~1"=="--nostart" goto opt_nostart
if /I "%~1"=="--purge" goto opt_purge

echo ERROR: unknown option: %~1
exit /b 1

:opt_dir
if "%~2"=="" goto arg_error
set "APP_DIR=%~2"
shift
shift
goto parse_args

:opt_installer
if "%~2"=="" goto arg_error
set "INSTALLER=%~2"
shift
shift
goto parse_args

:opt_version
if "%~2"=="" goto arg_error
set "REQUEST_VERSION=%~2"
shift
shift
goto parse_args

:opt_channel
if "%~2"=="" goto arg_error
set "CHANNEL=%~2"
set "CHANNEL_SPECIFIED=1"
shift
shift
goto parse_args

:opt_stable
set "CHANNEL=stable"
set "CHANNEL_SPECIFIED=1"
shift
goto parse_args

:opt_beta
set "CHANNEL=beta"
set "CHANNEL_SPECIFIED=1"
shift
goto parse_args

:opt_7z
if "%~2"=="" goto arg_error
set "SEVENZIP=%~2"
shift
shift
goto parse_args

:opt_data_dir
if "%~2"=="" goto arg_error
set "RIME_USER_DIR=%~2"
shift
shift
goto parse_args

:opt_context
if "%~2"=="" goto arg_error
set "CONTEXT_FILE=%~2"
shift
shift
goto parse_args

:opt_admin_window
if "%~2"=="" goto arg_error
if /I "%~2"=="show" (
    set "ADMIN_WINDOW=show"
    shift
    shift
    goto parse_args
)
if /I "%~2"=="hide" (
    set "ADMIN_WINDOW=hide"
    shift
    shift
    goto parse_args
)
echo ERROR: --admin-window must be show or hide.
exit /b 1

:opt_show_admin_window
set "ADMIN_WINDOW=show"
shift
goto parse_args

:opt_hide_admin_window
set "ADMIN_WINDOW=hide"
shift
goto parse_args

:opt_yes
set "YES=1"
shift
goto parse_args

:opt_force
set "FORCE=1"
shift
goto parse_args

:opt_nostart
set "NO_START=1"
shift
goto parse_args

:opt_purge
set "PURGE=1"
shift
goto parse_args

:args_done

if /I "%CHANNEL%"=="stable" goto channel_ok
if /I "%CHANNEL%"=="beta" goto channel_ok
echo ERROR: --channel must be stable or beta.
exit /b 1

:channel_ok

if not "%INSTALLER%"=="" if not "%REQUEST_VERSION%"=="" (
    echo ERROR: --installer and --version cannot be used together.
    exit /b 1
)

if /I "%ACTION%"=="install" goto do_install
if /I "%ACTION%"=="update" goto do_update
if /I "%ACTION%"=="uninstall" goto do_uninstall
if /I "%ACTION%"=="sync" goto do_sync

if /I "%ACTION%"=="__admin_install" goto do_admin_install
if /I "%ACTION%"=="__admin_uninstall" goto do_admin_uninstall

echo ERROR: unknown action: %ACTION%
goto usage


rem ============================================================
rem install - normal privilege orchestration
rem ============================================================

:do_install
call :ResolveInstallDirForInstall
if errorlevel 1 exit /b 1

call :ResolveTools
if errorlevel 1 exit /b 1

if not "%INSTALLER%"=="" goto install_from_local
if not "%REQUEST_VERSION%"=="" goto install_from_version
goto install_from_latest

:install_from_local
if not exist "%INSTALLER%" (
    echo ERROR: installer not found:
    echo %INSTALLER%
    exit /b 1
)

for %%I in ("%INSTALLER%") do set "INSTALLER=%%~fI"

call :ParseVersionFromFileName "%INSTALLER%"
if errorlevel 1 exit /b 1

set "PKG_VERSION=%PARSED_VERSION%"
set "PKG_CHANNEL=%PARSED_CHANNEL%"
set "SOURCE_URL=local:%INSTALLER%"
goto install_ready

:install_from_version
call :ResolveDownloadByVersion "%REQUEST_VERSION%"
if errorlevel 1 exit /b 1

call :DownloadLatest
if errorlevel 1 exit /b 1

set "INSTALLER=%DOWNLOADED_FILE%"
set "PKG_VERSION=%LATEST_VERSION%"
set "PKG_CHANNEL=%LATEST_CHANNEL%"
set "SOURCE_URL=%LATEST_URL%"
goto install_ready

:install_from_latest
call :GetLatestRelease "%CHANNEL%"
if errorlevel 1 exit /b 1

call :DownloadLatest
if errorlevel 1 exit /b 1

set "INSTALLER=%DOWNLOADED_FILE%"
set "PKG_VERSION=%LATEST_VERSION%"
set "PKG_CHANNEL=%LATEST_CHANNEL%"
set "SOURCE_URL=%LATEST_URL%"

:install_ready
echo.
echo Installing Weasel...
echo   Version : %PKG_VERSION%
echo   Channel : %PKG_CHANNEL%
echo   Target  : %APP_DIR%
echo.

call :WriteInstallContext "install"
if errorlevel 1 exit /b 1

call :RunAsSelf __admin_install --context "%CONTEXT_FILE%"
set "ADMIN_RC=%ERRORLEVEL%"
if not "%ADMIN_RC%"=="0" exit /b %ADMIN_RC%

call :StartWeaselServerNormal
exit /b %ERRORLEVEL%


rem ============================================================
rem update - normal privilege orchestration
rem ============================================================

:do_update
call :ResolveTools
if errorlevel 1 exit /b 1

if "%APP_DIR%"=="" (
    call :LoadInstallDirFromRegistry
    if errorlevel 1 exit /b 1
)

call :NormalizeAppDir
if errorlevel 1 exit /b 1

call :LoadLocalState
if errorlevel 1 exit /b 1

if "%LOCAL_VERSION%"=="" (
    echo ERROR: cannot determine local Weasel version.
    echo Please specify --dir or reinstall first.
    exit /b 1
)

if "%LOCAL_CHANNEL%"=="" (
    call :DetectChannelFromVersion "%LOCAL_VERSION%"
    set "LOCAL_CHANNEL=%VERSION_CHANNEL%"
)

echo Local version : %LOCAL_VERSION%
echo Local channel : %LOCAL_CHANNEL%
echo Install dir   : %APP_DIR%
echo.

if not "%REQUEST_VERSION%"=="" goto update_to_version

if "%CHANNEL_SPECIFIED%"=="1" (
    set "UPDATE_CHANNEL=%CHANNEL%"
) else (
    set "UPDATE_CHANNEL=%LOCAL_CHANNEL%"
)

call :GetLatestRelease "%UPDATE_CHANNEL%"
if errorlevel 1 exit /b 1
goto update_compare

:update_to_version
call :ResolveDownloadByVersion "%REQUEST_VERSION%"
if errorlevel 1 exit /b 1

:update_compare
echo Target version: %LATEST_VERSION%
echo Target channel: %LATEST_CHANNEL%
echo.

if /I "%LOCAL_VERSION%"=="%LATEST_VERSION%" if /I "%LOCAL_CHANNEL%"=="%LATEST_CHANNEL%" (
    echo Already up to date.
    exit /b 0
)

echo Updating: %LOCAL_VERSION% -^> %LATEST_VERSION%
echo Channel : %LOCAL_CHANNEL% -^> %LATEST_CHANNEL%
echo.

call :DownloadLatest
if errorlevel 1 exit /b 1

set "INSTALLER=%DOWNLOADED_FILE%"
set "PKG_VERSION=%LATEST_VERSION%"
set "PKG_CHANNEL=%LATEST_CHANNEL%"
set "SOURCE_URL=%LATEST_URL%"
set "FORCE=1"

call :WriteInstallContext "update"
if errorlevel 1 exit /b 1

call :RunAsSelf __admin_install --context "%CONTEXT_FILE%"
set "ADMIN_RC=%ERRORLEVEL%"
if not "%ADMIN_RC%"=="0" exit /b %ADMIN_RC%

call :StartWeaselServerNormal
exit /b %ERRORLEVEL%


rem ============================================================
rem uninstall - normal privilege orchestration
rem ============================================================

:do_uninstall
if "%APP_DIR%"=="" (
    call :LoadInstallDirFromRegistry
    if errorlevel 1 exit /b 1
)

call :NormalizeAppDir
if errorlevel 1 exit /b 1

if not exist "%APP_DIR%\" (
    echo ERROR: install dir does not exist:
    echo %APP_DIR%
    exit /b 1
)

if "%YES%"=="1" goto uninstall_confirmed

echo This will uninstall Weasel from:
echo %APP_DIR%
echo.
choice /M "Continue"
if errorlevel 2 exit /b 1

:uninstall_confirmed
call :WriteUninstallContext
if errorlevel 1 exit /b 1

call :RunAsSelf __admin_uninstall --context "%CONTEXT_FILE%"
exit /b %ERRORLEVEL%


rem ============================================================
rem internal elevated actions
rem ============================================================

:do_admin_install
call :RequireAdmin
if errorlevel 1 exit /b 1

call :LoadContext
if errorlevel 1 exit /b 1

if "%INSTALL_MODE%"=="" (
    echo ERROR: missing install mode in context.
    exit /b 1
)

call :InstallCore "%INSTALL_MODE%"
exit /b %ERRORLEVEL%


:do_admin_uninstall
call :RequireAdmin
if errorlevel 1 exit /b 1

call :LoadContext
if errorlevel 1 exit /b 1

call :UninstallCore
exit /b %ERRORLEVEL%


rem ============================================================
rem sync - normal privilege
rem ============================================================

:do_sync
call :ResolveGit
if errorlevel 1 exit /b 1

if "%RIME_USER_DIR%"=="" (
    call :LoadRimeUserDirFromRegistry
    if errorlevel 1 (
        echo ERROR: cannot find Rime user data directory.
        echo Please pass --data-dir.
        exit /b 1
    )
)

call :NormalizeRimeUserDir
if errorlevel 1 exit /b 1

call :ResolveOhMyRimeRepoDir
if errorlevel 1 exit /b 1

echo.
echo Syncing Rime config repository...
echo Data dir : %RIME_USER_DIR%
echo Repo dir : %SYNC_REPO_DIR%
echo.

call :GitPullFastForwardOnly
if errorlevel 1 exit /b 1

if "%GIT_UPDATED%"=="1" (
    echo.
    echo Git sync completed with updates.
    echo Triggering Rime redeployment...
    echo.

    call :RunRimeRedeploy
    if errorlevel 1 (
        echo ERROR: sync succeeded, but redeployment failed.
        exit /b 1
    )
) else (
    echo.
    echo Git sync completed. No upstream changes detected.
    echo Redeployment skipped.
)

echo.
echo Sync completed.
exit /b 0


rem ============================================================
rem elevated install/update core
rem ============================================================

:InstallCore
set "INSTALL_MODE=%~1"

call :NormalizeAppDir
if errorlevel 1 exit /b 1

call :CheckSafeTarget
if errorlevel 1 exit /b 1

call :StopWeasel
call :UnregisterOldWeasel

if not exist "%APP_DIR%\" mkdir "%APP_DIR%"
if errorlevel 1 (
    echo ERROR: failed to create install dir:
    echo %APP_DIR%
    exit /b 1
)

call :CleanInstallDirForExtract
if errorlevel 1 exit /b 1

echo Extracting installer...
"%SEVENZIP%" x "%INSTALLER%" "-o%APP_DIR%" -y
if errorlevel 1 (
    echo ERROR: 7-Zip extraction failed.
    exit /b 1
)

if exist "%APP_DIR%\$PLUGINSDIR\" (
    rmdir /s /q "%APP_DIR%\$PLUGINSDIR"
)

if not exist "%APP_DIR%\Rime\" (
    mkdir "%APP_DIR%\Rime"
)

if not exist "%APP_DIR%\WeaselSetup.exe" (
    echo ERROR: WeaselSetup.exe not found after extraction.
    exit /b 1
)

if not exist "%APP_DIR%\WeaselDeployer.exe" (
    echo ERROR: WeaselDeployer.exe not found after extraction.
    exit /b 1
)

if not exist "%APP_DIR%\WeaselServer.exe" (
    echo ERROR: WeaselServer.exe not found after extraction.
    exit /b 1
)

echo Registering input method...
pushd "%APP_DIR%"
start "" /wait "%APP_DIR%\WeaselSetup.exe" /i
set "SETUP_RC=%ERRORLEVEL%"
popd

if not "%SETUP_RC%"=="0" (
    echo ERROR: WeaselSetup.exe /i failed.
    exit /b 1
)

call :RunWeaselDeployment "%INSTALL_MODE%"

call :CopyManagerToInstallDir
call :WriteState
call :WriteRegistry

echo.
echo Done.
echo Weasel is installed in: %APP_DIR%
exit /b 0


rem ============================================================
rem elevated uninstall core
rem ============================================================

:UninstallCore
call :StopWeasel

if exist "%APP_DIR%\WeaselSetup.exe" (
    echo Unregistering Weasel input method...
    start "" /wait "%APP_DIR%\WeaselSetup.exe" /u
)

call :DeleteRegistry

echo Removing files...
call :RemoveInstallFiles
if errorlevel 1 exit /b 1

echo.
echo Uninstall completed.
exit /b 0


rem ============================================================
rem RunAs and context
rem ============================================================

:RunAsSelf
set "RUNAS_ARGS=%*"
set "RUNAS_RC=%TEMP%\%MANAGER_BASE%_runas_%RANDOM%%RANDOM%.rc"
set "RUNAS_LOG=%TEMP%\%MANAGER_BASE%_runas_%RANDOM%%RANDOM%.log"
set "RUNAS_WRAPPER=%TEMP%\%MANAGER_BASE%_runas_%RANDOM%%RANDOM%.cmd"

if exist "%RUNAS_RC%" del /f /q "%RUNAS_RC%" >nul 2>&1
if exist "%RUNAS_LOG%" del /f /q "%RUNAS_LOG%" >nul 2>&1
if exist "%RUNAS_WRAPPER%" del /f /q "%RUNAS_WRAPPER%" >nul 2>&1

call :IsAdmin
if "%IS_ADMIN%"=="1" (
    call "%MANAGER_SELF%" %RUNAS_ARGS%
    exit /b %ERRORLEVEL%
)

(
    echo @echo off
    echo call "%MANAGER_SELF%" %RUNAS_ARGS% ^> "%RUNAS_LOG%" 2^>^&1
    echo echo %%ERRORLEVEL%%^>"%RUNAS_RC%"
    echo exit /b %%ERRORLEVEL%%
) > "%RUNAS_WRAPPER%"

echo Requesting administrator privileges...

if /I "%ADMIN_WINDOW%"=="show" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process -FilePath $env:ComSpec -ArgumentList '/d /c ""%RUNAS_WRAPPER%""' -Verb RunAs; exit 0 } catch { exit 1 }"
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process -FilePath $env:ComSpec -ArgumentList '/d /c ""%RUNAS_WRAPPER%""' -Verb RunAs -WindowStyle Hidden; exit 0 } catch { exit 1 }"
)

if errorlevel 1 (
    echo ERROR: failed to start elevated process or UAC was cancelled.
    del "%RUNAS_WRAPPER%" >nul 2>&1
    exit /b 1
)

echo Waiting for elevated operation to finish...

for /L %%T in (1,1,1800) do (
    if exist "%RUNAS_RC%" goto runas_done
    ping -n 2 127.0.0.1 >nul 2>&1
)

echo ERROR: elevated operation timed out.
echo Log file:
echo %RUNAS_LOG%

if exist "%RUNAS_LOG%" (
    echo.
    type "%RUNAS_LOG%"
)

del "%RUNAS_WRAPPER%" >nul 2>&1
exit /b 1

:runas_done
set "ELEVATED_RC=1"
set /p ELEVATED_RC=<"%RUNAS_RC%"

if exist "%RUNAS_LOG%" (
    echo.
    type "%RUNAS_LOG%"
)

del "%RUNAS_RC%" >nul 2>&1
del "%RUNAS_LOG%" >nul 2>&1
del "%RUNAS_WRAPPER%" >nul 2>&1

exit /b %ELEVATED_RC%


:WriteInstallContext
set "INSTALL_MODE=%~1"
set "CONTEXT_FILE=%TEMP%\%MANAGER_BASE%_context_%RANDOM%%RANDOM%.txt"

(
    echo INSTALL_MODE=%INSTALL_MODE%
    echo APP_DIR=%APP_DIR%
    echo INSTALLER=%INSTALLER%
    echo PKG_VERSION=%PKG_VERSION%
    echo PKG_CHANNEL=%PKG_CHANNEL%
    echo SOURCE_URL=%SOURCE_URL%
    echo SEVENZIP=%SEVENZIP%
    echo FORCE=%FORCE%
    echo NO_START=%NO_START%
) > "%CONTEXT_FILE%"

if not exist "%CONTEXT_FILE%" (
    echo ERROR: failed to create context file.
    exit /b 1
)

exit /b 0


:WriteUninstallContext
set "CONTEXT_FILE=%TEMP%\%MANAGER_BASE%_context_%RANDOM%%RANDOM%.txt"

(
    echo APP_DIR=%APP_DIR%
    echo PURGE=%PURGE%
    echo YES=%YES%
) > "%CONTEXT_FILE%"

if not exist "%CONTEXT_FILE%" (
    echo ERROR: failed to create context file.
    exit /b 1
)

exit /b 0


:LoadContext
if "%CONTEXT_FILE%"=="" (
    echo ERROR: missing --context.
    exit /b 1
)

if not exist "%CONTEXT_FILE%" (
    echo ERROR: context file not found:
    echo %CONTEXT_FILE%
    exit /b 1
)

for /f "usebackq tokens=1,* delims==" %%A in ("%CONTEXT_FILE%") do (
    set "%%A=%%B"
)

del "%CONTEXT_FILE%" >nul 2>&1

exit /b 0


:IsAdmin
set "IS_ADMIN=0"
fltmc >nul 2>&1
if not errorlevel 1 set "IS_ADMIN=1"
exit /b 0


:RequireAdmin
call :IsAdmin
if not "%IS_ADMIN%"=="1" (
    echo ERROR: this internal operation requires administrator privileges.
    exit /b 1
)

exit /b 0


rem ============================================================
rem GitHub release discovery
rem ============================================================

:GetLatestRelease
set "WANTED_CHANNEL=%~1"
set "LATEST_URL="
set "LATEST_VERSION="
set "LATEST_CHANNEL="
set "LATEST_FILE="
set "REL_TAG="
set "REL_CHANNEL="

set "JSON_FILE=%TEMP%\%MANAGER_BASE%_releases_%RANDOM%%RANDOM%.json"
set "FILTERED_FILE=%TEMP%\%MANAGER_BASE%_filtered_%RANDOM%%RANDOM%.txt"

echo Fetching GitHub releases...
curl.exe -fL --retry 3 ^
  -A "%UA%" ^
  -H "Accept: application/vnd.github+json" ^
  -H "X-GitHub-Api-Version: 2022-11-28" ^
  -o "%JSON_FILE%" ^
  "%API_URL%"

if errorlevel 1 (
    echo ERROR: failed to fetch GitHub releases.
    del "%JSON_FILE%" >nul 2>&1
    del "%FILTERED_FILE%" >nul 2>&1
    exit /b 1
)

findstr /N /I /C:"tag_name" /C:"prerelease" /C:"browser_download_url" "%JSON_FILE%" > "%FILTERED_FILE%"

for /f "usebackq delims=" %%L in ("%FILTERED_FILE%") do (
    set "JSON_LINE=%%L"
    call :ProcessFilteredReleaseLine
    if defined LATEST_URL goto latest_found
)

:latest_found
del "%JSON_FILE%" >nul 2>&1
del "%FILTERED_FILE%" >nul 2>&1

if "%LATEST_URL%"=="" (
    echo ERROR: no %WANTED_CHANNEL% Weasel installer was found in GitHub releases.
    exit /b 1
)

echo Found latest %WANTED_CHANNEL%:
echo   Version : %LATEST_VERSION%
echo   URL     : %LATEST_URL%
exit /b 0


:ProcessFilteredReleaseLine
set "LINE=%JSON_LINE%"

echo(%LINE% | findstr /I /C:"tag_name" >nul
if not errorlevel 1 goto pfl_tag

echo(%LINE% | findstr /I /C:"prerelease" >nul
if not errorlevel 1 goto pfl_prerelease

echo(%LINE% | findstr /I /C:"browser_download_url" >nul
if not errorlevel 1 goto pfl_url

exit /b 0

:pfl_tag
call :ExtractQuotedJsonValueFromLine
set "REL_TAG=%JSON_VAL%"
if "%REL_TAG:~0,1%"=="v" set "REL_TAG=%REL_TAG:~1%"
set "REL_CHANNEL="
exit /b 0

:pfl_prerelease
echo(%LINE% | findstr /I /C:"true" >nul
if errorlevel 1 (
    set "REL_CHANNEL=stable"
) else (
    set "REL_CHANNEL=beta"
)
exit /b 0

:pfl_url
if /I not "%REL_CHANNEL%"=="%WANTED_CHANNEL%" exit /b 0

call :ExtractQuotedJsonValueFromLine
if "%JSON_VAL%"=="" exit /b 0

call :UrlToFileName "%JSON_VAL%"
call :TryParseVersionFromFileName "%URL_FILE%"
if errorlevel 1 exit /b 0

set "LATEST_URL=%JSON_VAL%"
set "LATEST_FILE=%URL_FILE%"
set "LATEST_VERSION=%PARSED_VERSION%"
set "LATEST_CHANNEL=%PARSED_CHANNEL%"
exit /b 0


:ExtractQuotedJsonValueFromLine
set "JSON_VAL="
for /f tokens^=4^ delims^=^" %%A in ('echo(%LINE%') do set "JSON_VAL=%%A"
exit /b 0


:UrlToFileName
set "URL_FILE="
set "U=%~1"
set "U=%U:/=\%"
for %%F in ("%U%") do set "URL_FILE=%%~nxF"
exit /b 0


:ResolveDownloadByVersion
set "REQ_VERSION=%~1"
set "REQ_VERSION=%REQ_VERSION: =%"

if "%REQ_VERSION%"=="" (
    echo ERROR: empty version.
    exit /b 1
)

if /I "%REQ_VERSION:~0,1%"=="v" set "REQ_VERSION=%REQ_VERSION:~1%"

call :NormalizeRequestedVersion "%REQ_VERSION%"
if errorlevel 1 exit /b 1

set "LATEST_VERSION=%NORM_ASSET_VERSION%"
set "LATEST_CHANNEL=%NORM_CHANNEL%"
set "LATEST_FILE=weasel-%NORM_ASSET_VERSION%-installer.exe"
set "LATEST_URL=%DOWNLOAD_BASE%/%NORM_TAG%/%LATEST_FILE%"

echo Resolving requested version...
echo   Version : %LATEST_VERSION%
echo   Channel : %LATEST_CHANNEL%
echo   URL     : %LATEST_URL%

curl.exe -fsIL --retry 2 -A "%UA%" -o nul "%LATEST_URL%"
if errorlevel 1 (
    echo ERROR: corresponding release asset does not exist or cannot be accessed.
    echo Version: %REQ_VERSION%
    exit /b 1
)

exit /b 0


:NormalizeRequestedVersion
set "NORM_INPUT=%~1"
set "NORM_TAG="
set "NORM_ASSET_VERSION="
set "NORM_CHANNEL="
set "VP1="
set "VP2="
set "VP3="
set "VP4="
set "VP5="
set "VP6="

for /f "tokens=1-6 delims=." %%A in ("%NORM_INPUT%") do (
    set "VP1=%%A"
    set "VP2=%%B"
    set "VP3=%%C"
    set "VP4=%%D"
    set "VP5=%%E"
    set "VP6=%%F"
)

if "%VP1%"=="" goto norm_bad
if "%VP2%"=="" goto norm_bad
if "%VP3%"=="" goto norm_bad

if "%VP4%"=="" (
    set "NORM_TAG=%VP1%.%VP2%.%VP3%"
    set "NORM_ASSET_VERSION=%VP1%.%VP2%.%VP3%.0"
    set "NORM_CHANNEL=stable"
    exit /b 0
)

if "%VP4%"=="0" if "%VP5%"=="" (
    set "NORM_TAG=%VP1%.%VP2%.%VP3%"
    set "NORM_ASSET_VERSION=%VP1%.%VP2%.%VP3%.0"
    set "NORM_CHANNEL=stable"
    exit /b 0
)

set "NORM_TAG=%NORM_INPUT%"
set "NORM_ASSET_VERSION=%NORM_INPUT%"
set "NORM_CHANNEL=beta"
exit /b 0

:norm_bad
echo ERROR: invalid version format.
exit /b 1


:DownloadLatest
set "DOWNLOAD_DIR=%TEMP%\%MANAGER_BASE%_downloads"

if not exist "%DOWNLOAD_DIR%\" mkdir "%DOWNLOAD_DIR%"

set "DOWNLOADED_FILE=%DOWNLOAD_DIR%\%LATEST_FILE%"

echo Downloading installer...
echo %LATEST_URL%
curl.exe -fL --retry 3 -A "%UA%" -o "%DOWNLOADED_FILE%" "%LATEST_URL%"
if errorlevel 1 (
    echo ERROR: download failed.
    exit /b 1
)

if not exist "%DOWNLOADED_FILE%" (
    echo ERROR: downloaded file not found.
    exit /b 1
)

echo Downloaded:
echo %DOWNLOADED_FILE%
exit /b 0


rem ============================================================
rem version parsing
rem ============================================================

:ParseVersionFromFileName
call :TryParseVersionFromFileName "%~1"
if errorlevel 1 (
    echo ERROR: invalid installer filename.
    echo Actual:
    echo   %~1
    exit /b 1
)
exit /b 0


:TryParseVersionFromFileName
set "PARSED_VERSION="
set "PARSED_CHANNEL="
set "BASE="
set "V="

for %%I in ("%~1") do set "BASE=%%~nI"

if /I not "%BASE:~0,7%"=="weasel-" exit /b 1

set "V=%BASE:~7%"

if /I not "%V:~-10%"=="-installer" exit /b 1

set "V=%V:~0,-10%"

if "%V%"=="" exit /b 1

set "PARSED_VERSION=%V%"

call :DetectChannelFromVersion "%PARSED_VERSION%"
set "PARSED_CHANNEL=%VERSION_CHANNEL%"

exit /b 0


:DetectChannelFromVersion
set "VERSION_CHANNEL=beta"
set "DP1="
set "DP2="
set "DP3="
set "DP4="
set "DP5="

for /f "tokens=1-6 delims=." %%A in ("%~1") do (
    set "DP1=%%A"
    set "DP2=%%B"
    set "DP3=%%C"
    set "DP4=%%D"
    set "DP5=%%E"
)

if "%DP4%"=="0" if "%DP5%"=="" set "VERSION_CHANNEL=stable"

exit /b 0


rem ============================================================
rem install dir / local state
rem ============================================================

:ResolveInstallDirForInstall
if "%APP_DIR%"=="" (
    set "APP_DIR=%ProgramFiles%\Rime\Weasel"
)

call :NormalizeAppDir
exit /b %ERRORLEVEL%


:NormalizeAppDir
if "%APP_DIR%"=="" (
    echo ERROR: install dir is empty.
    exit /b 1
)

for %%I in ("%APP_DIR%") do set "APP_DIR=%%~fI"

if "%APP_DIR:~-1%"=="\" (
    if /I not "%APP_DIR:~1%"==":\" set "APP_DIR=%APP_DIR:~0,-1%"
)

exit /b 0


:LoadInstallDirFromRegistry
set "APP_DIR="

for %%R in (64 32) do (
    if not defined APP_DIR (
        for /f "tokens=1,2,*" %%A in ('reg query "%REG_MANAGER%" /v InstallDir /reg:%%R 2^>nul') do (
            if /I "%%A"=="InstallDir" set "APP_DIR=%%C"
        )
    )
)

for %%R in (64 32) do (
    if not defined APP_DIR (
        for /f "tokens=1,2,*" %%A in ('reg query "%REG_WEASEL%" /v WeaselRoot /reg:%%R 2^>nul') do (
            if /I "%%A"=="WeaselRoot" set "APP_DIR=%%C"
        )
    )
)

if not defined APP_DIR (
    echo ERROR: cannot find install dir from registry.
    echo Please pass --dir.
    exit /b 1
)

exit /b 0


:LoadLocalState
set "LOCAL_VERSION="
set "LOCAL_CHANNEL="

for %%R in (64 32) do (
    if not defined LOCAL_VERSION (
        for /f "tokens=1,2,*" %%A in ('reg query "%REG_MANAGER%" /v Version /reg:%%R 2^>nul') do (
            if /I "%%A"=="Version" set "LOCAL_VERSION=%%C"
        )
    )

    if not defined LOCAL_CHANNEL (
        for /f "tokens=1,2,*" %%A in ('reg query "%REG_MANAGER%" /v Channel /reg:%%R 2^>nul') do (
            if /I "%%A"=="Channel" set "LOCAL_CHANNEL=%%C"
        )
    )
)

for %%R in (64 32) do (
    if not defined LOCAL_VERSION (
        for /f "tokens=1,2,*" %%A in ('reg query "%REG_UNINSTALL%" /v DisplayVersion /reg:%%R 2^>nul') do (
            if /I "%%A"=="DisplayVersion" set "LOCAL_VERSION=%%C"
        )
    )
)

if not exist "%APP_DIR%\%STATE_NAME%" exit /b 0

for /f "usebackq tokens=1,* delims==" %%A in ("%APP_DIR%\%STATE_NAME%") do (
    if /I "%%A"=="VERSION" if not defined LOCAL_VERSION set "LOCAL_VERSION=%%B"
    if /I "%%A"=="CHANNEL" if not defined LOCAL_CHANNEL set "LOCAL_CHANNEL=%%B"
)

exit /b 0


:WriteState
(
    echo VERSION=%PKG_VERSION%
    echo CHANNEL=%PKG_CHANNEL%
    echo INSTALL_DIR=%APP_DIR%
    echo SOURCE_URL=%SOURCE_URL%
) > "%APP_DIR%\%STATE_NAME%"

exit /b 0


rem ============================================================
rem sync helpers
rem ============================================================

:ResolveGit
where git.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: git.exe not found.
    echo Please install Git and make sure git.exe is in PATH.
    exit /b 1
)

exit /b 0


:LoadRimeUserDirFromRegistry
set "RIME_USER_DIR="

for /f "tokens=1,2,*" %%A in ('reg query "HKCU\Software\Rime\Weasel" /v RimeUserDir 2^>nul') do (
    if /I "%%A"=="RimeUserDir" set "RIME_USER_DIR=%%C"
)

if "%RIME_USER_DIR%"=="" exit /b 1

exit /b 0


:NormalizeRimeUserDir
if "%RIME_USER_DIR%"=="" (
    echo ERROR: Rime user data directory is empty.
    exit /b 1
)

call set "RIME_USER_DIR=%RIME_USER_DIR%"

for %%I in ("%RIME_USER_DIR%") do set "RIME_USER_DIR=%%~fI"

if "%RIME_USER_DIR:~-1%"=="\" (
    if /I not "%RIME_USER_DIR:~1%"==":\" set "RIME_USER_DIR=%RIME_USER_DIR:~0,-1%"
)

if not exist "%RIME_USER_DIR%\" (
    echo ERROR: Rime user data directory does not exist:
    echo %RIME_USER_DIR%
    exit /b 1
)

exit /b 0


:ResolveOhMyRimeRepoDir
set "SYNC_REPO_DIR="

if exist "%RIME_USER_DIR%\.git\" (
    set "SYNC_REPO_DIR=%RIME_USER_DIR%"
    exit /b 0
)

if exist "%RIME_USER_DIR%\oh-my-rime\.git\" (
    set "SYNC_REPO_DIR=%RIME_USER_DIR%\oh-my-rime"
    exit /b 0
)

echo ERROR: Rime user data directory is not a Git repository.
echo Expected a .git directory under the data dir.
echo If the repository is elsewhere, pass --data-dir with the repository root.
exit /b 1


:GitPullFastForwardOnly
set "OLD_HEAD="
set "NEW_HEAD="
set "GIT_UPDATED=0"

for /f "delims=" %%H in ('git -C "%SYNC_REPO_DIR%" rev-parse --short HEAD 2^>nul') do set "OLD_HEAD=%%H"

echo Current revision: %OLD_HEAD%
echo Running: git pull --ff-only
echo.

git -C "%SYNC_REPO_DIR%" pull --ff-only
if errorlevel 1 (
    echo.
    echo ERROR: git pull --ff-only failed.
    echo Possible causes:
    echo   - local changes not committed
    echo   - local branch diverged from remote
    echo   - network or authentication failure
    exit /b 1
)

for /f "delims=" %%H in ('git -C "%SYNC_REPO_DIR%" rev-parse --short HEAD 2^>nul') do set "NEW_HEAD=%%H"

echo.
echo Previous revision: %OLD_HEAD%
echo Current revision : %NEW_HEAD%

if not "%OLD_HEAD%"=="%NEW_HEAD%" set "GIT_UPDATED=1"

exit /b 0


:ResolveAppDirForRedeploy
if not "%APP_DIR%"=="" (
    call :NormalizeAppDir
    if errorlevel 1 exit /b 1
    goto check_deployer_for_sync
)

call :LoadInstallDirFromRegistry
if errorlevel 1 (
    echo ERROR: cannot find Weasel install dir from registry.
    echo Please pass --dir so the script can find WeaselDeployer.exe.
    exit /b 1
)

call :NormalizeAppDir
if errorlevel 1 exit /b 1

:check_deployer_for_sync
if not exist "%APP_DIR%\WeaselDeployer.exe" (
    echo ERROR: WeaselDeployer.exe not found in install dir:
    echo %APP_DIR%
    exit /b 1
)

exit /b 0


:RunRimeRedeploy
call :ResolveAppDirForRedeploy
if errorlevel 1 exit /b 1

if exist "%APP_DIR%\WeaselServer.exe" (
    start "" "%APP_DIR%\WeaselServer.exe"
    ping -n 2 127.0.0.1 >nul 2>&1
)

pushd "%APP_DIR%"
if errorlevel 1 (
    echo ERROR: failed to enter install dir.
    exit /b 1
)

echo Running WeaselDeployer.exe /deploy...
start "" /wait "%APP_DIR%\WeaselDeployer.exe" /deploy
if not errorlevel 1 (
    popd
    echo Redeployment completed.
    exit /b 0
)

popd

echo WARNING: redeploy failed. Starting server and retrying...

if exist "%APP_DIR%\WeaselServer.exe" (
    start "" "%APP_DIR%\WeaselServer.exe"
    ping -n 3 127.0.0.1 >nul 2>&1
)

pushd "%APP_DIR%"
if errorlevel 1 exit /b 1

start "" /wait "%APP_DIR%\WeaselDeployer.exe" /deploy
if not errorlevel 1 (
    popd
    echo Redeployment completed.
    exit /b 0
)

popd

echo ERROR: WeaselDeployer.exe /deploy failed.
exit /b 1


rem ============================================================
rem tool resolving
rem ============================================================

:ResolveTools
where curl.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: curl.exe not found.
    exit /b 1
)

if "%SEVENZIP%"=="" goto resolve_7z_auto

for %%Z in ("%SEVENZIP%") do set "SEVENZIP=%%~fZ"

if exist "%SEVENZIP%" exit /b 0

echo ERROR: 7z.exe not found:
echo %SEVENZIP%
exit /b 1

:resolve_7z_auto
for /f "delims=" %%Z in ('where 7z.exe 2^>nul') do (
    set "SEVENZIP=%%Z"
    exit /b 0
)

if exist "%ProgramFiles%\7-Zip\7z.exe" (
    set "SEVENZIP=%ProgramFiles%\7-Zip\7z.exe"
    exit /b 0
)

if exist "%ProgramFiles(x86)%\7-Zip\7z.exe" (
    set "SEVENZIP=%ProgramFiles(x86)%\7-Zip\7z.exe"
    exit /b 0
)

if exist "%USERPROFILE%\scoop\apps\7zip\current\7z.exe" (
    set "SEVENZIP=%USERPROFILE%\scoop\apps\7zip\current\7z.exe"
    exit /b 0
)

echo ERROR: 7z.exe not found.
echo Please pass --7z.
exit /b 1


rem ============================================================
rem file operations
rem ============================================================

:CheckSafeTarget
call :RejectDangerousDir
if errorlevel 1 exit /b 1

if not exist "%APP_DIR%\" exit /b 0

set "DIR_EMPTY=1"

for /f "delims=" %%A in ('dir /a /b "%APP_DIR%" 2^>nul') do (
    set "DIR_EMPTY=0"
    goto target_nonempty_checked
)

:target_nonempty_checked
if "%DIR_EMPTY%"=="1" exit /b 0

set "LOOKS_WEASEL=0"

if exist "%APP_DIR%\WeaselSetup.exe" set "LOOKS_WEASEL=1"
if exist "%APP_DIR%\WeaselServer.exe" set "LOOKS_WEASEL=1"
if exist "%APP_DIR%\WeaselDeployer.exe" set "LOOKS_WEASEL=1"
if exist "%APP_DIR%\%STATE_NAME%" set "LOOKS_WEASEL=1"
if exist "%APP_DIR%\Rime\" set "LOOKS_WEASEL=1"

if "%LOOKS_WEASEL%"=="1" exit /b 0
if "%FORCE%"=="1" exit /b 0

echo ERROR: target directory is not empty and does not look like a Weasel directory.
echo Use --force only if you are sure.
exit /b 1


:RejectDangerousDir
if "%APP_DIR%"=="" exit /b 1

if /I "%APP_DIR%"=="%SystemDrive%\" (
    echo ERROR: refusing to operate on drive root.
    exit /b 1
)

if /I "%APP_DIR%"=="%SystemRoot%" (
    echo ERROR: refusing to operate on Windows directory.
    exit /b 1
)

if /I "%APP_DIR%"=="%ProgramFiles%" (
    echo ERROR: refusing to operate on Program Files root.
    exit /b 1
)

if not "%ProgramFiles(x86)%"=="" (
    if /I "%APP_DIR%"=="%ProgramFiles(x86)%" (
        echo ERROR: refusing to operate on Program Files root.
        exit /b 1
    )
)

exit /b 0


:CleanInstallDirForExtract
if not exist "%APP_DIR%\" exit /b 0

echo Cleaning old program files while preserving user data and manager state...

for /f "delims=" %%A in ('dir /a /b "%APP_DIR%" 2^>nul') do (
    if /I not "%%A"=="Rime" if /I not "%%A"=="%MANAGER_NAME%" if /I not "%%A"=="%STATE_NAME%" (
        call :DeletePath "%APP_DIR%\%%A"
    )
)

exit /b 0


:DeletePath
if exist "%~1\" (
    attrib -r -s -h "%~1" /s /d >nul 2>&1
    rmdir /s /q "%~1"
) else (
    attrib -r -s -h "%~1" >nul 2>&1
    del /f /q "%~1" >nul 2>&1
)

exit /b 0


:CopyManagerToInstallDir
if /I "%MANAGER_SELF%"=="%APP_DIR%\%MANAGER_NAME%" exit /b 0

copy /y "%MANAGER_SELF%" "%APP_DIR%\%MANAGER_NAME%" >nul
exit /b 0


:RemoveInstallFiles
call :RejectDangerousDir
if errorlevel 1 exit /b 1

if "%PURGE%"=="1" (
    rmdir /s /q "%APP_DIR%"
    exit /b 0
)

echo Preserving user data directory if it exists.

for /f "delims=" %%A in ('dir /a /b "%APP_DIR%" 2^>nul') do (
    if /I not "%%A"=="Rime" (
        call :DeletePath "%APP_DIR%\%%A"
    )
)

set "LEFT=0"
for /f "delims=" %%A in ('dir /a /b "%APP_DIR%" 2^>nul') do set "LEFT=1"

if "%LEFT%"=="0" (
    rmdir "%APP_DIR%" >nul 2>&1
) else (
    echo Install dir was kept because it still contains preserved files.
)

exit /b 0


rem ============================================================
rem Weasel process / deployment
rem ============================================================

:StopWeasel
echo Stopping WeaselServer...

if exist "%APP_DIR%\WeaselServer.exe" (
    start "" /min "%APP_DIR%\WeaselServer.exe" /quit
)

ping -n 2 127.0.0.1 >nul 2>&1

taskkill /IM WeaselServer.exe /T /F >nul 2>&1

exit /b 0


:UnregisterOldWeasel
if exist "%APP_DIR%\WeaselSetup.exe" (
    echo Unregistering old Weasel input method...
    start "" /wait "%APP_DIR%\WeaselSetup.exe" /u
    if errorlevel 1 (
        echo WARNING: old WeaselSetup.exe /u returned a non-zero exit code.
    )
)

exit /b 0


:RunWeaselDeployment
set "DEPLOY_MODE=%~1"

if not exist "%APP_DIR%\WeaselDeployer.exe" (
    echo WARNING: WeaselDeployer.exe not found. Deployment skipped.
    exit /b 0
)

pushd "%APP_DIR%"
if errorlevel 1 (
    echo WARNING: failed to enter install directory. Deployment skipped.
    exit /b 0
)

echo Running deployment with /install...
start "" /wait "%APP_DIR%\WeaselDeployer.exe" /install
if not errorlevel 1 goto deploy_success

echo WARNING: /install failed. Trying /deploy...
start "" /wait "%APP_DIR%\WeaselDeployer.exe" /deploy
if not errorlevel 1 goto deploy_success

echo WARNING: deployment failed. Starting server and retrying /deploy...
if exist "%APP_DIR%\WeaselServer.exe" (
    start "" "%APP_DIR%\WeaselServer.exe"
    ping -n 3 127.0.0.1 >nul 2>&1
)

start "" /wait "%APP_DIR%\WeaselDeployer.exe" /deploy
if not errorlevel 1 goto deploy_success

popd

echo WARNING: WeaselDeployer failed, but installation files and registry were updated.
echo WARNING: If needed, run redeploy manually.
exit /b 0

:deploy_success
popd
echo Deployment completed.
exit /b 0


:StartWeaselServerNormal
if "%NO_START%"=="1" exit /b 0

if not exist "%APP_DIR%\WeaselServer.exe" exit /b 0

echo Starting WeaselServer...
start "" "%APP_DIR%\WeaselServer.exe"

exit /b 0


rem ============================================================
rem registry
rem ============================================================

:WriteRegistry
set "MANAGER_PATH=%APP_DIR%\%MANAGER_NAME%"
set "SERVER_PATH=%APP_DIR%\WeaselServer.exe"

call :WriteRegistryForView 64
call :WriteRegistryForView 32

reg add "HKCU\Software\Rime\Weasel\Updates" /v CheckForUpdates /t REG_SZ /d 0 /f >nul 2>&1

exit /b 0


:WriteRegistryForView
set "REG_VIEW=%~1"

reg add "%REG_WEASEL%" /v InstallDir /t REG_SZ /d "%APP_DIR%" /f /reg:%REG_VIEW% >nul 2>&1
reg add "%REG_WEASEL%" /v WeaselRoot /t REG_SZ /d "%APP_DIR%" /f /reg:%REG_VIEW% >nul 2>&1

reg add "%REG_MANAGER%" /v InstallDir /t REG_SZ /d "%APP_DIR%" /f /reg:%REG_VIEW% >nul 2>&1
reg add "%REG_MANAGER%" /v Version /t REG_SZ /d "%PKG_VERSION%" /f /reg:%REG_VIEW% >nul 2>&1
reg add "%REG_MANAGER%" /v Channel /t REG_SZ /d "%PKG_CHANNEL%" /f /reg:%REG_VIEW% >nul 2>&1
reg add "%REG_MANAGER%" /v SourceUrl /t REG_SZ /d "%SOURCE_URL%" /f /reg:%REG_VIEW% >nul 2>&1
reg add "%REG_MANAGER%" /v ManagerPath /t REG_SZ /d "%MANAGER_PATH%" /f /reg:%REG_VIEW% >nul 2>&1

reg add "%REG_UNINSTALL%" /v DisplayName /t REG_SZ /d "Weasel" /f /reg:%REG_VIEW% >nul 2>&1
reg add "%REG_UNINSTALL%" /v DisplayVersion /t REG_SZ /d "%PKG_VERSION%" /f /reg:%REG_VIEW% >nul 2>&1
reg add "%REG_UNINSTALL%" /v InstallLocation /t REG_SZ /d "%APP_DIR%" /f /reg:%REG_VIEW% >nul 2>&1
reg add "%REG_UNINSTALL%" /v Publisher /t REG_SZ /d "RIME Developers" /f /reg:%REG_VIEW% >nul 2>&1
reg add "%REG_UNINSTALL%" /v URLInfoAbout /t REG_SZ /d "https://rime.im/" /f /reg:%REG_VIEW% >nul 2>&1
reg add "%REG_UNINSTALL%" /v HelpLink /t REG_SZ /d "https://rime.im/docs/" /f /reg:%REG_VIEW% >nul 2>&1
reg add "%REG_UNINSTALL%" /v NoModify /t REG_DWORD /d 1 /f /reg:%REG_VIEW% >nul 2>&1
reg add "%REG_UNINSTALL%" /v NoRepair /t REG_DWORD /d 1 /f /reg:%REG_VIEW% >nul 2>&1

reg add "%REG_UNINSTALL%" /v DisplayIcon /t REG_SZ /d "\"%SERVER_PATH%\"" /f /reg:%REG_VIEW% >nul 2>&1
reg add "%REG_UNINSTALL%" /v UninstallString /t REG_SZ /d "\"%MANAGER_PATH%\" uninstall --dir \"%APP_DIR%\" --yes" /f /reg:%REG_VIEW% >nul 2>&1
reg add "%REG_UNINSTALL%" /v QuietUninstallString /t REG_SZ /d "\"%MANAGER_PATH%\" uninstall --dir \"%APP_DIR%\" --yes" /f /reg:%REG_VIEW% >nul 2>&1

reg add "%REG_RUN%" /v WeaselServer /t REG_SZ /d "\"%SERVER_PATH%\"" /f /reg:%REG_VIEW% >nul 2>&1

exit /b 0


:DeleteRegistry
for %%R in (64 32) do (
    reg delete "%REG_UNINSTALL%" /f /reg:%%R >nul 2>&1
    reg delete "%REG_MANAGER%" /f /reg:%%R >nul 2>&1
    reg delete "%REG_WEASEL%" /f /reg:%%R >nul 2>&1
    reg delete "%REG_RUN%" /v WeaselServer /f /reg:%%R >nul 2>&1
)

reg delete "HKCU\Software\Rime\Weasel\Updates" /f >nul 2>&1

exit /b 0


rem ============================================================
rem usage
rem ============================================================

:arg_error
echo ERROR: missing argument value.
exit /b 1


:usage
echo Usage:
echo.
echo   %MANAGER_NAME% install --dir ^<install-dir^> --stable
echo   %MANAGER_NAME% install --dir ^<install-dir^> --beta
echo   %MANAGER_NAME% install --dir ^<install-dir^> --version ^<version^>
echo   %MANAGER_NAME% install --dir ^<install-dir^> --installer ^<installer.exe^>
echo   %MANAGER_NAME% update
echo   %MANAGER_NAME% update --stable
echo   %MANAGER_NAME% update --beta
echo   %MANAGER_NAME% update --version ^<version^>
echo   %MANAGER_NAME% uninstall
echo   %MANAGER_NAME% sync
echo   %MANAGER_NAME% sync --data-dir ^<rime-user-dir^>
echo   %MANAGER_NAME% sync --dir ^<install-dir^> --data-dir ^<rime-user-dir^>
echo.
echo Options:
echo   --dir PATH              Application install directory
echo   --installer PATH        Local installer package
echo   --version VALUE         Install or update to an explicit version
echo   --stable                Use stable channel
echo   --beta                  Use beta channel
echo   --channel VALUE         stable or beta
echo   --7z PATH               Path to 7z.exe
echo   --data-dir PATH         Rime user data directory or repository root
echo   --rime-dir PATH         Alias of --data-dir
echo   --force                 Allow non-empty non-Weasel-like target directory
echo   --nostart               Do not start server after install/update
echo   --yes                   Do not ask confirmation on uninstall
echo   --purge                 Remove preserved user data directory on uninstall
echo   --admin-window VALUE    show or hide elevated cmd window
echo   --show-admin-window     Show elevated cmd window
echo   --hide-admin-window     Hide elevated cmd window
exit /b 1