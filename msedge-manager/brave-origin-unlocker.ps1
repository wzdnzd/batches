Write-Host "======================================================="
Write-Host "           Brave Origin Unlocker 一键解锁脚本           "       
Write-Host "======================================================="
Write-Host ""

$ErrorActionPreference = "Stop"

# 定义符号
$checkMark = [char]0x2714   # ✔
$crossMark = [char]0x274C   # ❌

# 1. 根据操作系统确定 Local State 文件路径模式
$os = [System.Environment]::OSVersion.Platform
$localStatePathPattern = $null

if ($os -eq [System.PlatformID]::Win32NT) {
    $localAppData = [System.Environment]::GetEnvironmentVariable("LOCALAPPDATA")
    if (-not $localAppData) {
        Write-Error "错误：找不到 LOCALAPPDATA 环境变量"
        exit 1
    }
    $localStatePathPattern = { param($version) "$localAppData\BraveSoftware\$version\User Data\Local State" }
}
elseif ($os -eq [System.PlatformID]::Unix) {
    $homeDir = [System.Environment]::GetEnvironmentVariable("HOME")
    if (-not $homeDir) {
        Write-Error "错误：找不到 HOME 环境变量"
        exit 1
    }
    $localStatePathPattern = { param($version) "$homeDir/Library/Application Support/BraveSoftware/$version/Local State" }
}
else {
    Write-Error "错误：不支持的操作系统：$os"
    exit 1
}

# 2. 要尝试的版本列表
$versions = @("Brave-Origin", "Brave-Origin-Beta", "Brave-Origin-Nightly")
$foundAny = $false

# 3. 遍历版本，尝试修改
foreach ($version in $versions) {
    $localStatePath = & $localStatePathPattern $version
    $displayName = $version -replace '-',' '

    # 检查文件是否存在，不存在则跳过
    if (-not (Test-Path -Path $localStatePath)) {
        continue
    }

    # 打印即将操作的信息
    Write-Host "浏览器版本: $displayName"
    Write-Host "待修改文件路径: $localStatePath"

    try {
        # 读取 JSON 文件
        $localState = Get-Content -Path $localStatePath -Raw | ConvertFrom-Json

        # 确保 brave.origin 字段存在并设置购买验证状态
        if (-not $localState.brave) {
            $localState | Add-Member -MemberType NoteProperty -Name "brave" -Value @{}
        }
        if (-not $localState.brave.origin) {
            $localState.brave | Add-Member -MemberType NoteProperty -Name "origin" -Value @{}
        }
        $localState.brave.origin | Add-Member -MemberType NoteProperty -Name "purchase_validated" -Value $true -Force

        # 确保 skus.state 存在
        if (-not $localState.skus) {
            $localState | Add-Member -MemberType NoteProperty -Name "skus" -Value @{ state = @{} }
        }
        if (-not $localState.skus.state) {
            $localState.skus | Add-Member -MemberType NoteProperty -Name "state" -Value @{}
        }

        # 构建 skus 凭证 JSON 字符串
        $skusState = @{
            credentials = @{
                items = @{
                    "6" = "7"
                }
            }
        }
        $skusStateJson = $skusState | ConvertTo-Json -Compress

        # 使用 Add-Member 添加/覆盖键 "67"
        $localState.skus.state | Add-Member -MemberType NoteProperty -Name "67" -Value $skusStateJson -Force

        # 写回文件
        $localState | ConvertTo-Json -Depth 10 | Set-Content -Path $localStatePath -Encoding UTF8

        # 成功
        Write-Host "$checkMark  $displayName 已成功解锁" -ForegroundColor Green
        $foundAny = $true
    }
    catch {
        # 失败
        Write-Host "$crossMark  处理 $displayName 时发生异常：$_" -ForegroundColor Red
        throw
    }
}

if (-not $foundAny) {
    Write-Host "未找到任何已安装的 Brave Origin 版本"
}

Write-Host ""