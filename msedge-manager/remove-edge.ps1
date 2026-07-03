<#
Remove-Edge-Keep-WebView2.ps1 v1.6
Removes Microsoft Edge browser, Edge AppX packages, Edge Update services/tasks/files/registry,
while preserving Microsoft Edge WebView2 Runtime files and detection registry entries.

Default mode is dry-run. Use -Apply to make changes.
Uses only built-in Windows PowerShell/cmdlets and Windows built-in tools.

Backup/config improvements in v1.3-v1.6:
- Use -BackupRoot to choose the parent backup directory.
- Use -BackupDir to choose an exact backup session directory.
- Or create remove-edge-keep-webview2.config.psd1 next to this script with: @{ BackupRoot = 'D:\Backups\EdgeRemoval'; BackupEnabled = $true }
- Backups are enabled by default. Use -NoBackup or BackupEnabled = $false to disable registry/task backups.
- Use -Mode Restore [-RestoreFrom <folder>] -Apply to restore registry exports and scheduled task XML exports.
- Use -MaxBackups <N> or MaxBackups = N to keep only the newest N backup folders. 0 means no retention cleanup.
- Use SkipUserData = $true in the config file to preserve per-user Edge profiles/data by default.
#>

[CmdletBinding()]
param(
    [ValidateSet('Remove','Restore')]
    [string]$Mode = 'Remove',
    [switch]$Apply,
    [string]$BackupRoot,
    [string]$BackupDir,
    [switch]$NoBackup,
    [ValidateRange(0, 9999)]
    [int]$MaxBackups = 0,
    [string]$RestoreFrom,
    [switch]$NoSelfElevate,
    [switch]$SkipAppx,
    [switch]$SkipUserData,
    [switch]$SkipFileRemoval,
    [switch]$SkipRegistryCleanup,
    [switch]$SkipInstalledEdgeUninstaller
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$Script:Changed = 0
$Script:Matched = 0
$Script:Warnings = New-Object System.Collections.Generic.List[string]
$Script:BackedUp = @{}
$Script:BackupInitialized = $false

$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Script:ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$Script:ConfigPath = Join-Path $Script:ScriptDir 'remove-edge.config.psd1'

function Resolve-FullPath([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return $Path }
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return (Join-Path (Get-Location).Path $Path)
}

function Get-ConfiguredBackupRoot {
    function Resolve-BackupRootPath {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Path,

            [Parameter(Mandatory = $true)]
            [string]$BaseDir
        )

        if ([System.IO.Path]::IsPathRooted($Path)) {
            return (Resolve-FullPath $Path)
        }

        return (Resolve-FullPath (Join-Path $BaseDir $Path))
    }

    # Command-line -BackupRoot keeps the old behavior: relative paths are resolved against the caller's current directory.
    if (-not [string]::IsNullOrWhiteSpace($BackupRoot)) {
        return (Resolve-BackupRootPath -Path $BackupRoot -BaseDir (Get-Location).Path)
    }

    # Config file BackupRoot: relative paths are resolved against the .ps1 script directory.
    if (Test-Path -LiteralPath $Script:ConfigPath) {
        try {
            $cfg = Import-PowerShellDataFile -LiteralPath $Script:ConfigPath -ErrorAction Stop
            if ($cfg.ContainsKey('BackupRoot') -and -not [string]::IsNullOrWhiteSpace([string]$cfg.BackupRoot)) {
                return (Resolve-BackupRootPath -Path ([string]$cfg.BackupRoot) -BaseDir $Script:ScriptDir)
            }
        } catch {
            Write-Warning "Failed to read config file: $Script:ConfigPath -- $($_.Exception.Message)"
        }
    }

    return (Join-Path $Script:ScriptDir 'EdgeRemovalBackups')
}

function Get-ConfiguredBackupEnabled {
    if ($NoBackup) {
        return $false
    }

    if (Test-Path -LiteralPath $Script:ConfigPath) {
        try {
            $cfg = Import-PowerShellDataFile -LiteralPath $Script:ConfigPath -ErrorAction Stop
            if ($cfg.ContainsKey('BackupEnabled')) {
                return [bool]$cfg.BackupEnabled
            }
        } catch {
            Write-Warning "Failed to read config file: $Script:ConfigPath -- $($_.Exception.Message)"
        }
    }

    return $true
}

function Get-ConfiguredMaxBackups {
    if ($PSBoundParameters.ContainsKey('MaxBackups')) {
        return [int]$MaxBackups
    }

    if (Test-Path -LiteralPath $Script:ConfigPath) {
        try {
            $cfg = Import-PowerShellDataFile -LiteralPath $Script:ConfigPath -ErrorAction Stop
            if ($cfg.ContainsKey('MaxBackups')) {
                $value = [int]$cfg.MaxBackups
                if ($value -lt 0) { return 0 }
                if ($value -gt 9999) { return 9999 }
                return $value
            }
        } catch {
            Write-Warning "Failed to read config file: $Script:ConfigPath -- $($_.Exception.Message)"
        }
    }

    return 0
}

function Get-ConfiguredSkipUserData {
    if ($PSBoundParameters.ContainsKey('SkipUserData')) {
        return [bool]$SkipUserData
    }

    if (Test-Path -LiteralPath $Script:ConfigPath) {
        try {
            $cfg = Import-PowerShellDataFile -LiteralPath $Script:ConfigPath -ErrorAction Stop
            if ($cfg.ContainsKey('SkipUserData')) {
                return [bool]$cfg.SkipUserData
            }
        } catch {
            Write-Warning "Failed to read config file: $Script:ConfigPath -- $($_.Exception.Message)"
        }
    }

    return $false
}

if (-not [string]::IsNullOrWhiteSpace($RestoreFrom)) {
    $Mode = 'Restore'
    $RestoreFrom = Resolve-FullPath $RestoreFrom
}

$Script:BackupRoot = Get-ConfiguredBackupRoot
$Script:BackupEnabled = Get-ConfiguredBackupEnabled
$Script:MaxBackups = Get-ConfiguredMaxBackups
$Script:SkipUserData = Get-ConfiguredSkipUserData
if (-not [string]::IsNullOrWhiteSpace($BackupDir)) {
    $Script:BackupDir = Resolve-FullPath $BackupDir
} else {
    $Script:BackupDir = Join-Path $Script:BackupRoot ("EdgeRemovalBackup-{0}" -f $Timestamp)
}

if ((-not $Script:BackupEnabled) -and ($Mode -eq 'Remove') -and ((-not [string]::IsNullOrWhiteSpace($BackupRoot)) -or (-not [string]::IsNullOrWhiteSpace($BackupDir)))) {
    Write-Warning 'Backup is disabled; -BackupRoot and -BackupDir will be ignored during removal.'
}

$WebViewGuid = '{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}'
$EdgeGuids = @(
    '{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}', # Edge Stable
    '{2CD8A007-E189-409D-A2C8-9AF4EF3C72AA}', # Edge Beta
    '{65C35B14-6C1D-4122-AC46-7148CC9D6497}', # Edge Canary
    '{0D50BFEC-CD6A-4F9A-964C-C7416E3ACB10}'  # Edge Dev
)

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Quote-Argument([string]$Value) {
    return ('"' + ($Value -replace '"','`"') + '"')
}

function Get-CurrentArgumentList {
    $args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Quote-Argument $PSCommandPath), '-Mode', $Mode)
    if ($Apply) { $args += '-Apply' }
    if (-not [string]::IsNullOrWhiteSpace($BackupRoot)) { $args += '-BackupRoot'; $args += (Quote-Argument $BackupRoot) }
    if (-not [string]::IsNullOrWhiteSpace($BackupDir)) { $args += '-BackupDir'; $args += (Quote-Argument $BackupDir) }
    if ($NoBackup) { $args += '-NoBackup' }
    if ($PSBoundParameters.ContainsKey('MaxBackups')) { $args += '-MaxBackups'; $args += $MaxBackups }
    if (-not [string]::IsNullOrWhiteSpace($RestoreFrom)) { $args += '-RestoreFrom'; $args += (Quote-Argument $RestoreFrom) }
    if ($NoSelfElevate) { $args += '-NoSelfElevate' }
    if ($SkipAppx) { $args += '-SkipAppx' }
    if ($PSBoundParameters.ContainsKey('SkipUserData')) { $args += ('-SkipUserData:{0}' -f ($(if ($SkipUserData) { '$true' } else { '$false' }))) }
    if ($SkipFileRemoval) { $args += '-SkipFileRemoval' }
    if ($SkipRegistryCleanup) { $args += '-SkipRegistryCleanup' }
    if ($SkipInstalledEdgeUninstaller) { $args += '-SkipInstalledEdgeUninstaller' }
    return ($args -join ' ')
}

if (-not (Test-IsAdmin)) {
    if ($NoSelfElevate) {
        throw 'Administrator privileges are required.'
    }
    Write-Host 'Requesting administrator privileges...'
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList (Get-CurrentArgumentList)
    exit
}

function Add-Warn([string]$Message) {
    $Script:Warnings.Add($Message) | Out-Null
    Write-Warning $Message
}

function Write-Plan([string]$Kind, [string]$Target, [string]$Reason) {
    $mode = if ($Apply) { 'APPLY' } else { 'DRYRUN' }
    Write-Host ("[{0}][{1}] {2} -- {3}" -f $mode, $Kind, $Target, $Reason)
    $Script:Matched++
}

function Invoke-Change([string]$Kind, [string]$Target, [string]$Reason, [scriptblock]$Action) {
    Write-Plan -Kind $Kind -Target $Target -Reason $Reason
    if ($Apply) {
        try {
            & $Action
            $Script:Changed++
        } catch {
            Add-Warn ("Failed: {0} -- {1}" -f $Target, $_.Exception.Message)
        }
    }
}

function Convert-ToRegExePath([string]$Path) {
    $p = $Path
    $p = $p -replace '^Microsoft\.PowerShell\.Core\\Registry::', ''
    $p = $p -replace '^Registry::', ''
    if ($p -like 'HKLM:\*') { return 'HKEY_LOCAL_MACHINE\' + $p.Substring(6) }
    if ($p -like 'HKCU:\*') { return 'HKEY_CURRENT_USER\' + $p.Substring(6) }
    if ($p -like 'HKCR:\*') { return 'HKEY_CLASSES_ROOT\' + $p.Substring(6) }
    return $p
}

function Initialize-BackupFolder {
    if ($Script:BackupInitialized) { return }
    if (-not $Apply) { return }
    if (-not $Script:BackupEnabled) { return }

    if (-not (Test-Path -LiteralPath $Script:BackupDir)) {
        New-Item -ItemType Directory -Path $Script:BackupDir -Force | Out-Null
    }

    $readme = Join-Path $Script:BackupDir 'README.txt'
    $registryManifest = Join-Path $Script:BackupDir 'registry-manifest.tsv'
    $taskManifest = Join-Path $Script:BackupDir 'scheduled-tasks.tsv'

    if (-not (Test-Path -LiteralPath $registryManifest)) {
        "SourceRegPath`tBackupFile" | Set-Content -LiteralPath $registryManifest -Encoding UTF8
    }
    if (-not (Test-Path -LiteralPath $taskManifest)) {
        "TaskPath`tTaskName`tXmlFile" | Set-Content -LiteralPath $taskManifest -Encoding UTF8
    }

    @"
Edge removal backup folder
Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

This folder contains registry exports and scheduled task XML exports created before removal.
It can restore registry keys/values and scheduled tasks only. It cannot restore deleted program files, AppX packages, or fully reinstall Edge Update binaries.

Restore options:
1. Run restore-registry.cmd as administrator.
2. Or run:
   powershell -NoProfile -ExecutionPolicy Bypass -File .\restore-registry.ps1 -Apply
3. Or run the main script:
   powershell -NoProfile -ExecutionPolicy Bypass -File <main script> -Mode Restore -RestoreFrom "$Script:BackupDir" -Apply
"@ | Set-Content -LiteralPath $readme -Encoding UTF8

    'edge-removal-backup' | Set-Content -LiteralPath (Join-Path $Script:BackupDir '.edge-removal-backup') -Encoding ASCII

    $restoreCmd = @'
@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0restore-registry.ps1" -Apply
pause
'@
    Set-Content -LiteralPath (Join-Path $Script:BackupDir 'restore-registry.cmd') -Value $restoreCmd -Encoding ASCII

    $restorePs1 = @'
[CmdletBinding()]
param([switch]$Apply)

$ErrorActionPreference = 'Continue'
$folder = $PSScriptRoot
Write-Host "Backup folder: $folder"

$regFiles = Get-ChildItem -LiteralPath $folder -Filter '*.reg' -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer } | Sort-Object Name
Write-Host "Registry files: $($regFiles.Count)"
foreach ($file in $regFiles) {
    if ($Apply) {
        Write-Host "[RESTORE][registry] $($file.Name)"
        & reg.exe import $file.FullName
    } else {
        Write-Host "[DRYRUN][registry] $($file.Name)"
    }
}

$taskManifest = Join-Path $folder 'scheduled-tasks.tsv'
if (Test-Path -LiteralPath $taskManifest) {
    $tasks = Import-Csv -LiteralPath $taskManifest -Delimiter "`t" | Where-Object { $_.XmlFile }
    Write-Host "Scheduled task exports: $($tasks.Count)"
    foreach ($task in $tasks) {
        $xml = Join-Path $folder $task.XmlFile
        $tn = ($task.TaskPath + $task.TaskName)
        if (-not $tn.StartsWith('\')) { $tn = '\' + $tn }
        if ($Apply) {
            if (Test-Path -LiteralPath $xml) {
                Write-Host "[RESTORE][task] $tn"
                & schtasks.exe /Create /TN $tn /XML $xml /F | Out-Null
            }
        } else {
            Write-Host "[DRYRUN][task] $tn"
        }
    }
}

if (-not $Apply) {
    Write-Host 'No changes were made. Re-run with -Apply to restore.'
} else {
    Write-Host 'Restore finished. Restart Windows if you restored service-related registry keys.'
}
'@
    Set-Content -LiteralPath (Join-Path $Script:BackupDir 'restore-registry.ps1') -Value $restorePs1 -Encoding UTF8

    try {
        if ($PSCommandPath) {
            Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $Script:BackupDir 'main-script-copy.ps1') -Force -ErrorAction SilentlyContinue
        }
    } catch {}

    $Script:BackupInitialized = $true
}

function Backup-RegKey([string]$Path) {
    if (-not $Apply) { return }
    if (-not $Script:BackupEnabled) { return }
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $regPath = Convert-ToRegExePath $Path
    if ($Script:BackedUp.ContainsKey($regPath)) { return }
    Initialize-BackupFolder
    $safe = $regPath -replace '[\\/:*?"<>|]', '_'
    $fileName = "{0}.reg" -f $safe
    $file = Join-Path $Script:BackupDir $fileName
    & reg.exe export $regPath $file /y > $null 2> $null
    if ($LASTEXITCODE -eq 0) {
        Add-Content -LiteralPath (Join-Path $Script:BackupDir 'registry-manifest.tsv') -Value ("{0}`t{1}" -f $regPath, $fileName) -Encoding UTF8
        $Script:BackedUp[$regPath] = $true
    } else {
        Add-Warn "Registry export failed: $regPath"
    }
}

function Backup-ScheduledTaskSafe([string]$TaskName, [string]$TaskPath) {
    if (-not $Apply) { return }
    if (-not $Script:BackupEnabled) { return }
    try {
        Initialize-BackupFolder
        $fullTaskName = $TaskPath + $TaskName
        $safe = $fullTaskName -replace '[\\/:*?"<>|]', '_'
        $fileName = "task-{0}.xml" -f $safe
        $file = Join-Path $Script:BackupDir $fileName
        Export-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction Stop | Out-File -LiteralPath $file -Encoding UTF8
        Add-Content -LiteralPath (Join-Path $Script:BackupDir 'scheduled-tasks.tsv') -Value ("{0}`t{1}`t{2}" -f $TaskPath, $TaskName, $fileName) -Encoding UTF8
    } catch {
        Add-Warn ("Scheduled task export failed: {0}{1} -- {2}" -f $TaskPath, $TaskName, $_.Exception.Message)
    }
}

function Invoke-BackupRetention {
    if (-not $Apply) { return }
    if (-not $Script:BackupEnabled) { return }
    if ($Script:MaxBackups -le 0) { return }
    if (-not $Script:BackupInitialized) { return }

    try {
        $retentionRoot = Split-Path -Parent $Script:BackupDir
        if ([string]::IsNullOrWhiteSpace($retentionRoot)) { return }
        if (-not (Test-Path -LiteralPath $retentionRoot)) { return }

        $currentPath = [System.IO.Path]::GetFullPath($Script:BackupDir).TrimEnd('\','/')
        $backupDirs = Get-ChildItem -LiteralPath $retentionRoot -Directory -ErrorAction SilentlyContinue | Where-Object {
            ($_.Name -like 'EdgeRemovalBackup-*') -or (Test-Path -LiteralPath (Join-Path $_.FullName '.edge-removal-backup'))
        } | Sort-Object CreationTimeUtc, Name

        if ($backupDirs.Count -le $Script:MaxBackups) {
            Write-Host "Backup retention: $($backupDirs.Count)/$Script:MaxBackups backup folders, nothing to delete."
            return
        }

        $victims = New-Object System.Collections.Generic.List[object]
        foreach ($dir in $backupDirs) {
            if (($backupDirs.Count - $victims.Count) -le $Script:MaxBackups) { break }
            $dirPath = [System.IO.Path]::GetFullPath($dir.FullName).TrimEnd('\','/')
            if ($dirPath -ieq $currentPath) { continue }
            $victims.Add($dir) | Out-Null
        }

        foreach ($dir in $victims) {
            Write-Host "[APPLY][backup-retention] remove old backup folder -- $($dir.FullName)"
            Remove-Item -LiteralPath $dir.FullName -Recurse -Force -ErrorAction Stop
        }

        if ($victims.Count -gt 0) {
            Write-Host "Backup retention: kept newest $Script:MaxBackups backup folders under $retentionRoot."
        }
    } catch {
        Add-Warn "Backup retention cleanup failed: $($_.Exception.Message)"
    }
}

function Test-WebViewText($Text) {
    if ($null -eq $Text) { return $false }
    $s = [string]$Text
    return ($s -match '(?i)webview|msedgewebview2|edgewebview|microsoft edge webview2|microsoft edgewebview|F3017226-FE2A-4295-8BDF-00C3A9A7E4C5')
}

function Test-EdgeBrowserText($Text) {
    if ($null -eq $Text) { return $false }
    $s = [string]$Text
    if (Test-WebViewText $s) { return $false }
    if ($s -match '(?i)msedge\.exe|microsoft edge|microsoftedge|microsoft\.microsoftedge|edgeupdate|edgecore|MSEdgeHTM|MSEdgePDF|MSEdgeBHTML|MicrosoftEdgeUpdate|MicrosoftEdgeElevationService') { return $true }
    foreach ($g in $EdgeGuids) {
        if ($s.IndexOf($g, [StringComparison]::OrdinalIgnoreCase) -ge 0) { return $true }
    }
    return $false
}

function Get-RegKeyText([string]$Path) {
    $text = $Path
    try {
        $props = Get-ItemProperty -LiteralPath $Path -ErrorAction SilentlyContinue
        if ($null -ne $props) {
            foreach ($p in $props.PSObject.Properties) {
                if ($p.Name -like 'PS*') { continue }
                $text += ' ' + $p.Name + ' ' + ([string]$p.Value)
            }
        }
    } catch {}
    return $text
}

function Remove-RegKeySafe([string]$Path, [string]$Reason) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    if (Test-WebViewText $Path) {
        Write-Host "[KEEP][registry-key] $Path -- WebView2 protected"
        return
    }
    Invoke-Change -Kind 'registry-key' -Target $Path -Reason $Reason -Action {
        Backup-RegKey $Path
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
    }
}

function Remove-RegValueSafe([string]$Path, [string]$Name, [string]$Reason) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    if (Test-WebViewText ($Path + '\' + $Name)) {
        Write-Host "[KEEP][registry-value] $Path\$Name -- WebView2 protected"
        return
    }
    Invoke-Change -Kind 'registry-value' -Target "$Path\$Name" -Reason $Reason -Action {
        Backup-RegKey $Path
        Remove-ItemProperty -LiteralPath $Path -Name $Name -Force -ErrorAction Stop
    }
}

function Remove-RegDefaultSafe([string]$Path, [string]$Reason) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    Invoke-Change -Kind 'registry-default' -Target $Path -Reason $Reason -Action {
        Backup-RegKey $Path
        $regPath = Convert-ToRegExePath $Path
        & reg.exe delete $regPath /ve /f > $null 2> $null
    }
}

function Stop-And-DeleteService([string]$Name, [string]$DisplayName) {
    if (Test-WebViewText ($Name + ' ' + $DisplayName)) { return }
    Invoke-Change -Kind 'service' -Target $Name -Reason 'remove Microsoft Edge service' -Action {
        Backup-RegKey ("HKLM:\SYSTEM\CurrentControlSet\Services\{0}" -f $Name)
        try { Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue } catch {}
        & sc.exe delete $Name > $null 2> $null
    }
}

function Stop-EdgeProcesses {
    $processNames = @(
        'msedge',
        'MicrosoftEdge',
        'MicrosoftEdgeCP',
        'MicrosoftEdgeSH',
        'MicrosoftEdgeBCHost',
        'MicrosoftEdgeUpdate',
        'MicrosoftEdgeUpdateCore',
        'MicrosoftEdgeUpdateBroker',
        'MicrosoftEdgeUpdateComRegisterShell64',
        'MicrosoftEdgeUpdateComRegisterShell32',
        'browser_broker',
        'identity_helper',
        'pwahelper'
    )

    foreach ($name in $processNames) {
        Get-Process -Name $name -ErrorAction SilentlyContinue | ForEach-Object {
            $proc = $_
            $path = $null
            try { $path = $proc.Path } catch {}
            if (Test-WebViewText ($proc.ProcessName + ' ' + $path)) { return }
            Invoke-Change -Kind 'process' -Target "$($proc.ProcessName) pid=$($proc.Id)" -Reason 'stop Edge before removal' -Action {
                Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Remove-EdgeServices {
    $services = Get-Service -ErrorAction SilentlyContinue | Where-Object {
        (($_.Name -match '^(edgeupdate|edgeupdatem)$') -or
         ($_.Name -eq 'MicrosoftEdgeElevationService') -or
         ($_.DisplayName -like '*Microsoft Edge*')) -and
        -not (Test-WebViewText ($_.Name + ' ' + $_.DisplayName))
    }
    foreach ($svc in $services) {
        Stop-And-DeleteService -Name $svc.Name -DisplayName $svc.DisplayName
    }
}

function Invoke-InstalledEdgeUninstaller {
    if ($SkipInstalledEdgeUninstaller) { return }

    $patterns = @()
    if (${env:ProgramFiles(x86)}) { $patterns += (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\*\Installer\setup.exe') }
    if ($env:ProgramFiles) { $patterns += (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\*\Installer\setup.exe') }

    foreach ($pat in $patterns) {
        Get-Item -Path $pat -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | ForEach-Object {
            $setup = $_.FullName
            if (Test-WebViewText $setup) { return }
            Invoke-Change -Kind 'uninstaller' -Target $setup -Reason 'run installed Edge browser uninstaller only' -Action {
                $p = Start-Process -FilePath $setup -ArgumentList '--uninstall --system-level --force-uninstall --verbose-logging' -Wait -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
                if ($null -ne $p -and $p.ExitCode -ne 0) {
                    Add-Warn "Edge uninstaller returned exit code $($p.ExitCode): $setup"
                }
            }
        }
    }
}

function Remove-EdgeScheduledTasks {
    try {
        $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
            (($_.TaskName -like 'MicrosoftEdge*') -or ($_.TaskPath -like '\Microsoft\EdgeUpdate\*')) -and
            -not (Test-WebViewText ($_.TaskPath + $_.TaskName))
        }
        foreach ($task in $tasks) {
            Invoke-Change -Kind 'scheduled-task' -Target ($task.TaskPath + $task.TaskName) -Reason 'remove Edge scheduled task' -Action {
                Backup-ScheduledTaskSafe -TaskName $task.TaskName -TaskPath $task.TaskPath
                Unregister-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -Confirm:$false -ErrorAction SilentlyContinue
            }
        }
    } catch {
        Add-Warn "Scheduled task cleanup failed: $($_.Exception.Message)"
    }
}

function Remove-EdgeAppxPackages {
    if ($SkipAppx) { return }

    $namePatterns = @('Microsoft.MicrosoftEdge*', 'Microsoft.MicrosoftEdgeDevToolsClient*')

    foreach ($pat in $namePatterns) {
        Get-AppxPackage -AllUsers -Name $pat -ErrorAction SilentlyContinue | Where-Object {
            -not (Test-WebViewText ($_.Name + ' ' + $_.PackageFullName))
        } | ForEach-Object {
            $pkg = $_
            Invoke-Change -Kind 'appx-package' -Target $pkg.PackageFullName -Reason 'remove installed Edge AppX package' -Action {
                try {
                    Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                } catch {
                    Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction SilentlyContinue
                }
            }
        }
    }

    Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object {
        (($_.DisplayName -like 'Microsoft.MicrosoftEdge*') -or ($_.DisplayName -like 'Microsoft.MicrosoftEdgeDevToolsClient*')) -and
        -not (Test-WebViewText ($_.DisplayName + ' ' + $_.PackageName))
    } | ForEach-Object {
        $prov = $_
        Invoke-Change -Kind 'appx-provisioned' -Target $prov.PackageName -Reason 'remove provisioned Edge AppX package' -Action {
            Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction SilentlyContinue | Out-Null
        }
    }
}

function Clean-OpenWithList([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $props = Get-ItemProperty -LiteralPath $Path -ErrorAction SilentlyContinue
    if ($null -eq $props) { return }
    $removed = New-Object System.Collections.Generic.List[string]

    foreach ($p in $props.PSObject.Properties) {
        if ($p.Name -like 'PS*' -or $p.Name -eq 'MRUList') { continue }
        if (Test-EdgeBrowserText $p.Value) {
            Remove-RegValueSafe -Path $Path -Name $p.Name -Reason 'OpenWithList points to Edge'
            $removed.Add($p.Name) | Out-Null
        }
    }

    $mru = $props.PSObject.Properties | Where-Object { $_.Name -eq 'MRUList' } | Select-Object -First 1
    if ($removed.Count -gt 0 -and $null -ne $mru -and $null -ne $mru.Value) {
        $old = [string]$mru.Value
        $new = $old
        foreach ($name in $removed) { $new = $new.Replace($name, '') }
        if ($new -ne $old) {
            Invoke-Change -Kind 'registry-value' -Target "$Path\MRUList" -Reason 'remove Edge from OpenWith MRUList' -Action {
                Backup-RegKey $Path
                if ($new.Length -gt 0) { Set-ItemProperty -LiteralPath $Path -Name 'MRUList' -Value $new -Force }
                else { Remove-ItemProperty -LiteralPath $Path -Name 'MRUList' -Force -ErrorAction SilentlyContinue }
            }
        }
    }
}

function Clean-OpenWithProgids([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $props = Get-ItemProperty -LiteralPath $Path -ErrorAction SilentlyContinue
    if ($null -eq $props) { return }
    foreach ($p in $props.PSObject.Properties) {
        if ($p.Name -like 'PS*') { continue }
        if ((Test-EdgeBrowserText $p.Name) -or (Test-EdgeBrowserText $p.Value)) {
            Remove-RegValueSafe -Path $Path -Name $p.Name -Reason 'OpenWithProgids contains Edge ProgID'
        }
    }
}

function Clean-UserChoice([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $props = Get-ItemProperty -LiteralPath $Path -ErrorAction SilentlyContinue
    if ($null -eq $props) { return }
    if (Test-EdgeBrowserText $props.ProgId) {
        Remove-RegKeySafe -Path $Path -Reason 'UserChoice points to Edge'
    }
}

function Clean-ExplorerFileExts {
    $root = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts'
    if (-not (Test-Path -LiteralPath $root)) { return }
    Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue | ForEach-Object {
        Clean-OpenWithList -Path (Join-Path $_.PSPath 'OpenWithList')
        Clean-OpenWithProgids -Path (Join-Path $_.PSPath 'OpenWithProgids')
        Clean-UserChoice -Path (Join-Path $_.PSPath 'UserChoice')
    }
}

function Clean-AssociationToasts {
    $paths = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\ApplicationAssociationToasts',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\ApplicationAssociationToasts'
    )
    foreach ($path in $paths) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $props = Get-ItemProperty -LiteralPath $path -ErrorAction SilentlyContinue
        if ($null -eq $props) { continue }
        foreach ($p in $props.PSObject.Properties) {
            if ($p.Name -like 'PS*') { continue }
            if ((Test-EdgeBrowserText $p.Name) -or (Test-EdgeBrowserText $p.Value)) {
                Remove-RegValueSafe -Path $path -Name $p.Name -Reason 'Edge association toast cache'
            }
        }
    }
}

function Clean-UrlAssociations {
    $root = 'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations'
    if (-not (Test-Path -LiteralPath $root)) { return }
    Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue | ForEach-Object {
        Clean-UserChoice -Path (Join-Path $_.PSPath 'UserChoice')
    }
}

function Clean-UninstallEntries {
    $roots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue | ForEach-Object {
            $key = $_.PSPath
            $props = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
            $text = ($_.PSChildName + ' ' + $props.DisplayName + ' ' + $props.Publisher + ' ' + $props.InstallLocation + ' ' + $props.UninstallString)
            if ((Test-EdgeBrowserText $text) -and -not (Test-WebViewText $text)) {
                Remove-RegKeySafe -Path $key -Reason 'Edge uninstall registration'
            }
        }
    }
}

function Clean-RunKeys {
    $roots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
    )
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $props = Get-ItemProperty -LiteralPath $root -ErrorAction SilentlyContinue
        if ($null -eq $props) { continue }
        foreach ($p in $props.PSObject.Properties) {
            if ($p.Name -like 'PS*') { continue }
            $text = $p.Name + ' ' + ([string]$p.Value)
            if ((Test-EdgeBrowserText $text) -and -not (Test-WebViewText $text)) {
                Remove-RegValueSafe -Path $root -Name $p.Name -Reason 'Edge autostart entry'
            }
        }
    }
}

function Clean-RegisteredApplications {
    $roots = @(
        'HKLM:\SOFTWARE\RegisteredApplications',
        'HKCU:\SOFTWARE\RegisteredApplications'
    )
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $props = Get-ItemProperty -LiteralPath $root -ErrorAction SilentlyContinue
        if ($null -eq $props) { continue }
        foreach ($p in $props.PSObject.Properties) {
            if ($p.Name -like 'PS*') { continue }
            $text = $p.Name + ' ' + ([string]$p.Value)
            if ((Test-EdgeBrowserText $text) -and -not (Test-WebViewText $text)) {
                Remove-RegValueSafe -Path $root -Name $p.Name -Reason 'Edge registered application entry'
            }
        }
    }
}

function Clean-EdgeUpdateRegistryPreserveWebView([string]$BasePath) {
    if (-not (Test-Path -LiteralPath $BasePath)) { return }
    Backup-RegKey $BasePath

    $containers = @('Clients', 'ClientState', 'ClientStateMedium')
    foreach ($container in $containers) {
        $containerPath = Join-Path $BasePath $container
        if (-not (Test-Path -LiteralPath $containerPath)) { continue }

        Get-ChildItem -LiteralPath $containerPath -ErrorAction SilentlyContinue | ForEach-Object {
            $childPath = $_.PSPath
            $name = $_.PSChildName
            if ($name -ieq $WebViewGuid) {
                Write-Host "[KEEP][registry-key] $childPath -- WebView2 runtime detection"
                return
            }

            $text = Get-RegKeyText $childPath
            $isKnownEdgeGuid = $false
            foreach ($g in $EdgeGuids) { if ($name -ieq $g) { $isKnownEdgeGuid = $true } }

            if ($isKnownEdgeGuid -or (Test-EdgeBrowserText $text)) {
                Remove-RegKeySafe -Path $childPath -Reason 'Edge Update client state for Edge browser/channel'
            }
        }
    }

    $props = Get-ItemProperty -LiteralPath $BasePath -ErrorAction SilentlyContinue
    if ($null -ne $props) {
        foreach ($p in $props.PSObject.Properties) {
            if ($p.Name -like 'PS*') { continue }
            $text = $p.Name + ' ' + ([string]$p.Value)
            if ((Test-EdgeBrowserText $text) -and -not (Test-WebViewText $text)) {
                Remove-RegValueSafe -Path $BasePath -Name $p.Name -Reason 'Edge Update value not related to WebView2'
            }
        }
    }

    Get-ChildItem -LiteralPath $BasePath -ErrorAction SilentlyContinue | ForEach-Object {
        if ($containers -contains $_.PSChildName) { return }
        $text = Get-RegKeyText $_.PSPath
        if (Test-WebViewText $text) {
            Write-Host "[KEEP][registry-key] $($_.PSPath) -- WebView2 protected"
            return
        }
        Remove-RegKeySafe -Path $_.PSPath -Reason 'Edge Update non-WebView2 component state'
    }
}

function Clean-EdgePolicyRegistryPreserveWebView([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    Backup-RegKey $Path
    $props = Get-ItemProperty -LiteralPath $Path -ErrorAction SilentlyContinue
    if ($null -ne $props) {
        foreach ($p in $props.PSObject.Properties) {
            if ($p.Name -like 'PS*') { continue }
            $text = $p.Name + ' ' + ([string]$p.Value)
            if (Test-WebViewText $text) {
                Write-Host "[KEEP][registry-value] $Path\$($p.Name) -- WebView2 policy"
                continue
            }
            if ((Test-EdgeBrowserText $text) -or ($p.Name -in @('InstallDefault','UpdateDefault','Allowsxs','CreateDesktopShortcutDefault','RemoveDesktopShortcutDefault','TargetChannel','UpdaterExperimentationAndConfigurationServiceControl','AutoUpdateCheckPeriodMinutes'))) {
                Remove-RegValueSafe -Path $Path -Name $p.Name -Reason 'Edge Update policy not related to WebView2'
            }
        }
    }
}

function Clean-ClassKeys {
    $classRoots = @(
        'HKCU:\Software\Classes',
        'HKLM:\SOFTWARE\Classes',
        'HKLM:\SOFTWARE\WOW6432Node\Classes',
        'Registry::HKEY_CLASSES_ROOT'
    )

    foreach ($root in $classRoots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        Remove-RegKeySafe -Path (Join-Path (Join-Path $root 'Applications') 'msedge.exe') -Reason 'Edge Open With application entry'
        Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue | Where-Object {
            $_.PSChildName -like 'MSEdge*' -and -not (Test-WebViewText $_.PSChildName)
        } | ForEach-Object {
            Remove-RegKeySafe -Path $_.PSPath -Reason 'Edge ProgID/class entry'
        }
    }
}

function Clean-KnownRegistryKeys {
    $knownKeys = @(
        'HKCU:\Software\Microsoft\Edge',
        'HKLM:\SOFTWARE\Microsoft\Edge',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Edge',
        'HKCU:\Software\Microsoft\Internet Explorer\EdgeIntegration',
        'HKLM:\SOFTWARE\Microsoft\Internet Explorer\EdgeIntegration',
        'HKCU:\Software\Clients\StartMenuInternet\Microsoft Edge',
        'HKLM:\SOFTWARE\Clients\StartMenuInternet\Microsoft Edge',
        'HKLM:\SOFTWARE\WOW6432Node\Clients\StartMenuInternet\Microsoft Edge',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe'
    )

    foreach ($k in $knownKeys) {
        Remove-RegKeySafe -Path $k -Reason 'known Edge browser registry key'
    }

    $packageRoots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Applications',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\InboxApplications',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\EndOfLife',
        'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\Repository\Packages'
    )

    foreach ($root in $packageRoots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue | Where-Object {
            ($_.PSChildName -like 'Microsoft.MicrosoftEdge*' -or $_.PSChildName -like 'Microsoft.MicrosoftEdgeDevToolsClient*') -and
            -not (Test-WebViewText $_.PSChildName)
        } | ForEach-Object {
            Remove-RegKeySafe -Path $_.PSPath -Reason 'Edge AppX registry state'
        }
    }
}

function Clean-Registry {
    if ($SkipRegistryCleanup) { return }

    Clean-ExplorerFileExts
    Clean-UrlAssociations
    Clean-AssociationToasts
    Clean-UninstallEntries
    Clean-RunKeys
    Clean-RegisteredApplications
    Clean-ClassKeys
    Clean-KnownRegistryKeys

    $edgeUpdateRoots = @(
        'HKCU:\Software\Microsoft\EdgeUpdate',
        'HKLM:\SOFTWARE\Microsoft\EdgeUpdate',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate'
    )
    foreach ($root in $edgeUpdateRoots) {
        Clean-EdgeUpdateRegistryPreserveWebView -BasePath $root
    }

    $policyRoot = 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate'
    Clean-EdgePolicyRegistryPreserveWebView -Path $policyRoot
    Remove-RegKeySafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Reason 'Edge browser policies'
    Remove-RegKeySafe -Path 'HKCU:\SOFTWARE\Policies\Microsoft\Edge' -Reason 'Edge browser policies'
}

function Invoke-TakeOwnership([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    & takeown.exe /F $Path /R /D Y > $null 2> $null
    & icacls.exe $Path /grant '*S-1-5-32-544:F' /T /C > $null 2> $null
}

function Remove-FileSystemPath([string]$Path, [string]$Reason) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    if (Test-WebViewText $Path) {
        Write-Host "[KEEP][file] $Path -- WebView2 protected"
        return
    }
    if (-not (Test-Path -LiteralPath $Path)) { return }

    Invoke-Change -Kind 'file' -Target $Path -Reason $Reason -Action {
        try {
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        } catch {
            Invoke-TakeOwnership -Path $Path
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        }
    }
}

function Remove-FileSystemWildcard([string]$Pattern, [string]$Reason) {
    if ([string]::IsNullOrWhiteSpace($Pattern)) { return }
    Get-Item -Path $Pattern -Force -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-FileSystemPath -Path $_.FullName -Reason $Reason
    }
}

function Remove-EdgeFiles {
    if ($SkipFileRemoval) { return }

    $paths = New-Object System.Collections.Generic.List[string]

    if (${env:ProgramFiles(x86)}) {
        $paths.Add((Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge')) | Out-Null
        $paths.Add((Join-Path ${env:ProgramFiles(x86)} 'Microsoft\EdgeCore')) | Out-Null
        $paths.Add((Join-Path ${env:ProgramFiles(x86)} 'Microsoft\EdgeUpdate')) | Out-Null
        $paths.Add((Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Temp')) | Out-Null
    }
    if ($env:ProgramFiles) {
        $paths.Add((Join-Path $env:ProgramFiles 'Microsoft\Edge')) | Out-Null
        $paths.Add((Join-Path $env:ProgramFiles 'Microsoft\EdgeCore')) | Out-Null
        $paths.Add((Join-Path $env:ProgramFiles 'Microsoft\EdgeUpdate')) | Out-Null
        $paths.Add((Join-Path $env:ProgramFiles 'Microsoft\Temp')) | Out-Null
    }

    $paths.Add((Join-Path $env:ProgramData 'Microsoft\EdgeUpdate')) | Out-Null
    $paths.Add((Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk')) | Out-Null
    $paths.Add((Join-Path $env:PUBLIC 'Desktop\Microsoft Edge.lnk')) | Out-Null
    $paths.Add((Join-Path $env:WINDIR 'System32\Tasks\Microsoft\EdgeUpdate')) | Out-Null

    foreach ($p in $paths) { Remove-FileSystemPath -Path $p -Reason 'remove Edge/EdgeUpdate files' }

    Remove-FileSystemWildcard -Pattern (Join-Path $env:WINDIR 'SystemApps\Microsoft.MicrosoftEdge*') -Reason 'remove legacy Edge system app files'
    Remove-FileSystemWildcard -Pattern (Join-Path $env:ProgramFiles 'WindowsApps\Microsoft.MicrosoftEdge*') -Reason 'remove Edge AppX package files'
    Remove-FileSystemWildcard -Pattern (Join-Path $env:ProgramFiles 'WindowsApps\Microsoft.MicrosoftEdgeDevToolsClient*') -Reason 'remove Edge DevTools AppX package files'

    if (-not $Script:SkipUserData) {
        Get-ChildItem -LiteralPath 'C:\Users' -Force -Directory -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -notin @('Default', 'Default User', 'All Users', 'Public')
        } | ForEach-Object {
            $profile = $_.FullName
            Remove-FileSystemPath -Path (Join-Path $profile 'AppData\Local\Microsoft\Edge') -Reason 'remove per-user Edge browser data'
            Remove-FileSystemPath -Path (Join-Path $profile 'AppData\Local\Microsoft\Edge SxS') -Reason 'remove per-user Edge Canary data'
            Remove-FileSystemWildcard -Pattern (Join-Path $profile 'AppData\Local\Packages\Microsoft.MicrosoftEdge*') -Reason 'remove per-user Edge AppX data'
            Remove-FileSystemWildcard -Pattern (Join-Path $profile 'AppData\Local\Packages\Microsoft.MicrosoftEdgeDevToolsClient*') -Reason 'remove per-user Edge AppX data'
            Remove-FileSystemPath -Path (Join-Path $profile 'Desktop\Microsoft Edge.lnk') -Reason 'remove per-user Edge shortcut'
            Remove-FileSystemPath -Path (Join-Path $profile 'AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk') -Reason 'remove per-user Edge shortcut'
        }
    }
}

function Show-WebView2Status {
    Write-Host ''
    Write-Host 'WebView2 preservation check:'

    $wvDirs = @()
    if (${env:ProgramFiles(x86)}) { $wvDirs += (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\EdgeWebView\Application') }
    if ($env:ProgramFiles) { $wvDirs += (Join-Path $env:ProgramFiles 'Microsoft\EdgeWebView\Application') }

    $foundFile = $false
    foreach ($d in $wvDirs) {
        Get-Item -Path (Join-Path $d '*\msedgewebview2.exe') -ErrorAction SilentlyContinue | Select-Object -First 1 | ForEach-Object {
            $foundFile = $true
            Write-Host "  Runtime file: $($_.FullName)"
        }
    }
    if (-not $foundFile) { Write-Host '  Runtime file: not found in the usual EdgeWebView folders' }

    $wvRegPaths = @(
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\$WebViewGuid",
        "HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\$WebViewGuid",
        "HKCU:\Software\Microsoft\EdgeUpdate\Clients\$WebViewGuid"
    )
    $foundReg = $false
    foreach ($rp in $wvRegPaths) {
        if (Test-Path -LiteralPath $rp) {
            $foundReg = $true
            $pv = $null
            try { $pv = (Get-ItemProperty -LiteralPath $rp -ErrorAction SilentlyContinue).pv } catch {}
            Write-Host "  Detection key: $rp  pv=$pv"
        }
    }
    if (-not $foundReg) { Write-Host '  Detection key: not found in common EdgeUpdate Clients locations' }
}

function Resolve-RestoreFolder {
    if (-not [string]::IsNullOrWhiteSpace($RestoreFrom)) {
        return $RestoreFrom
    }
    if (-not [string]::IsNullOrWhiteSpace($BackupDir)) {
        return $Script:BackupDir
    }

    $root = $Script:BackupRoot
    if (-not (Test-Path -LiteralPath $root)) {
        return $root
    }

    $latest = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'EdgeRemovalBackup-*' } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($null -ne $latest) {
        return $latest.FullName
    }

    return $root
}

function Restore-Backups {
    $folder = Resolve-RestoreFolder
    Write-Host ''
    Write-Host 'Restore Edge removal backups'
    Write-Host "Backup folder: $folder"
    Write-Host ("Mode: {0}" -f ($(if ($Apply) { 'APPLY - restore will be imported' } else { 'DRYRUN - no restore will be imported' })))
    Write-Host ''

    if (-not (Test-Path -LiteralPath $folder)) {
        throw "Backup folder not found: $folder"
    }

    $regFiles = Get-ChildItem -LiteralPath $folder -Filter '*.reg' -ErrorAction SilentlyContinue |
        Where-Object { -not $_.PSIsContainer } |
        Sort-Object Name

    Write-Host "Registry files: $($regFiles.Count)"
    foreach ($file in $regFiles) {
        if ($Apply) {
            Write-Host "[RESTORE][registry] $($file.Name)"
            & reg.exe import $file.FullName
            if ($LASTEXITCODE -ne 0) { Add-Warn "Registry import failed: $($file.FullName)" }
            else { $Script:Changed++ }
        } else {
            Write-Host "[DRYRUN][registry] $($file.Name)"
            $Script:Matched++
        }
    }

    $taskManifest = Join-Path $folder 'scheduled-tasks.tsv'
    if (Test-Path -LiteralPath $taskManifest) {
        $tasks = Import-Csv -LiteralPath $taskManifest -Delimiter "`t" | Where-Object { $_.XmlFile }
        Write-Host "Scheduled task exports: $($tasks.Count)"
        foreach ($task in $tasks) {
            $xml = Join-Path $folder $task.XmlFile
            $tn = ($task.TaskPath + $task.TaskName)
            if (-not $tn.StartsWith('\')) { $tn = '\' + $tn }
            if ($Apply) {
                if (Test-Path -LiteralPath $xml) {
                    Write-Host "[RESTORE][task] $tn"
                    & schtasks.exe /Create /TN $tn /XML $xml /F | Out-Null
                    if ($LASTEXITCODE -ne 0) { Add-Warn "Scheduled task restore failed: $tn" }
                    else { $Script:Changed++ }
                }
            } else {
                Write-Host "[DRYRUN][task] $tn"
                $Script:Matched++
            }
        }
    }

    Write-Host ''
    if ($Apply) {
        Write-Host "Restored items: $Script:Changed"
        Write-Host 'Restart Windows if service-related registry keys were restored.'
    } else {
        Write-Host 'No changes were made. Re-run with -Apply to restore.'
    }
}

if ($Mode -eq 'Restore') {
    Restore-Backups
} else {
    Write-Host ''
    Write-Host 'Remove Edge, keep WebView2'
    Write-Host ("Mode: {0}" -f ($(if ($Apply) { 'APPLY - changes will be made' } else { 'DRYRUN - no changes will be made' })))
    if ($Script:BackupEnabled) {
        Write-Host "Backup: enabled"
        Write-Host "Backup root: $Script:BackupRoot"
        Write-Host "Backup folder: $Script:BackupDir"
        if ($Script:MaxBackups -gt 0) { Write-Host "Max backups: $Script:MaxBackups" } else { Write-Host "Max backups: unlimited" }
    } else {
        Write-Host "Backup: disabled"
    }
    Write-Host ("User data cleanup: {0}" -f ($(if ($Script:SkipUserData) { 'skipped' } else { 'enabled' })))
    Write-Host ''

    Stop-EdgeProcesses
    Invoke-InstalledEdgeUninstaller
    Remove-EdgeServices
    Remove-EdgeScheduledTasks
    Remove-EdgeAppxPackages
    Clean-Registry
    Remove-EdgeFiles
    Show-WebView2Status
    Invoke-BackupRetention

    Write-Host ''
    Write-Host "Matched items: $Script:Matched"
    if ($Apply) {
        Write-Host "Changed items: $Script:Changed"
        if ($Script:BackupEnabled) {
            Write-Host "Registry/task backup folder: $Script:BackupDir"
        } else {
            Write-Host "Registry/task backup: disabled"
        }
        Write-Host 'Restart Windows after running this script.'
    } else {
        Write-Host 'No changes were made. Re-run with -Apply to actually remove items.'
    }
}

if ($Script:Warnings.Count -gt 0) {
    Write-Host ''
    Write-Host 'Warnings:'
    foreach ($w in $Script:Warnings) { Write-Host "  - $w" }
}
