# 本番ビルド。公開リポジトリに置けない値（広告ユニット ID・開発者モードの合言葉）を
# git 管理外のファイルから読み、--dart-define で渡す。
#   android/admob.properties  : appId= / bannerUnitId=（無ければ Google のテスト ID）
#   tools/release.env         : DEV_PASSPHRASE=（無ければ開発者モードは開かない）
# 使い方:  powershell -File tools/build-release.ps1            → AAB
#          powershell -File tools/build-release.ps1 -Apk       → APK
param([switch]$Apk)

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

function Read-Props($path) {
  $h = @{}
  if (Test-Path $path) {
    Get-Content $path -Encoding UTF8 | ForEach-Object {
      if ($_ -match '^\s*([^#=]+?)\s*=\s*(.*)$') { $h[$matches[1]] = $matches[2].Trim() }
    }
  }
  return $h
}

$admob = Read-Props "android/admob.properties"
$env1  = Read-Props "tools/release.env"

$defines = @()
if ($admob.ContainsKey('bannerUnitId')) { $defines += "--dart-define=ADMOB_BANNER_UNIT_ID=$($admob['bannerUnitId'])" }
if ($env1.ContainsKey('DEV_PASSPHRASE')) { $defines += "--dart-define=DEV_PASSPHRASE=$($env1['DEV_PASSPHRASE'])" }

if ($defines.Count -eq 0) {
  Write-Host "注意: admob.properties / release.env が無いので、広告はテスト ID・開発者モードは無効でビルドします。"
}

$target = if ($Apk) { "apk" } else { "appbundle" }
& flutter build $target --release @defines
