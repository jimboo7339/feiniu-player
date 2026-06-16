# 将本地 release.keystore 上传到 GitHub Actions Secrets（仅需运行一次）
# 用法: powershell -ExecutionPolicy Bypass -File tools/setup_github_signing.ps1

$ErrorActionPreference = "Stop"
Set-Location (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)

$keystore = "android/app/release.keystore"
if (-not (Test-Path $keystore)) {
    Write-Error "找不到 $keystore，请先运行 keytool 生成密钥库"
}

$gh = "$env:TEMP/gh-cli/bin/gh.exe"
if (-not (Test-Path $gh)) {
    Write-Error "未找到 gh CLI，请先安装 GitHub CLI 并 gh auth login"
}

$props = Get-Content "android/key.properties" | Where-Object { $_ -match '=' }
$config = @{}
foreach ($line in $props) {
    $k, $v = $line -split '=', 2
    $config[$k.Trim()] = $v.Trim()
}

$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path $keystore)))
$b64 | & $gh secret set ANDROID_KEYSTORE_BASE64
$config['storePassword'] | & $gh secret set ANDROID_KEYSTORE_PASSWORD
$config['keyAlias'] | & $gh secret set ANDROID_KEY_ALIAS
$config['keyPassword'] | & $gh secret set ANDROID_KEY_PASSWORD

Write-Host "GitHub Secrets 已更新: ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD"
