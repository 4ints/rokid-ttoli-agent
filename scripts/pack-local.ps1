<#
.SYNOPSIS
  토큰을 주입한 임시 복사본으로 똘똘이 에이전트를 패키징/설치한다 (Windows).
  저장소의 config.js 에는 토큰을 넣지 않는다 (공개 저장소).

.DESCRIPTION
  토큰 파일: %USERPROFILE%\.rokid-hermes\env  (KEY=VALUE 줄)
    ROKID_PROXY_TOKEN=...          (필수, 서버 ~/.config/rokid-hermes-proxy/env 와 같은 값)
    CF_ACCESS_CLIENT_ID=...        (선택, Cloudflare Access 사용 시)
    CF_ACCESS_CLIENT_SECRET=...    (선택)

.EXAMPLE
  .\scripts\pack-local.ps1                 # ttoli-agent.aix 생성 (저장소 폴더, git 제외)
  .\scripts\pack-local.ps1 -Install        # ADB로 안경에 설치
  .\scripts\pack-local.ps1 -Install -Launch
  .\scripts\pack-local.ps1 -Out C:\rokid-studio\ttoli-agent   # Studio "로컬 폴더 가져오기"용 폴더
#>
param(
  [switch]$Install,
  [switch]$Launch,
  [string]$Serial,
  [string]$Out
)
$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $env:USERPROFILE '.rokid-hermes\env'
if (-not (Test-Path $envFile)) { throw "토큰 파일이 없습니다: $envFile (ROKID_PROXY_TOKEN=... 한 줄을 넣으세요)" }

$vars = @{}
foreach ($line in Get-Content $envFile) {
  if ($line -match '^\s*([A-Z_]+)\s*=\s*(.*?)\s*$') { $vars[$Matches[1]] = $Matches[2] }
}
if (-not $vars['ROKID_PROXY_TOKEN']) { throw "ROKID_PROXY_TOKEN 이 비어 있습니다: $envFile" }

if (-not (Get-Command aix -ErrorAction SilentlyContinue)) {
  throw "aix CLI가 없습니다. 먼저: npm install -g @yodaos-pkg/aix-cli"
}

function Write-Injected([string]$dir) {
  $cfg = Join-Path $dir 'config.js'
  $text = [IO.File]::ReadAllText($cfg)
  foreach ($key in 'PROXY_TOKEN', 'CF_ACCESS_CLIENT_ID', 'CF_ACCESS_CLIENT_SECRET') {
    $src = if ($key -eq 'PROXY_TOKEN') { 'ROKID_PROXY_TOKEN' } else { $key }
    $value = [string]$vars[$src]
    $text = [regex]::Replace($text, "(?<=$key`: ')[^']*", [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $value })
  }
  [IO.File]::WriteAllText($cfg, $text, [Text.UTF8Encoding]::new($false))
}

function Copy-Project([string]$dest) {
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  # .aix\agent-id(로컬 에이전트 ID)는 함께 복사해 매번 같은 ID로 설치되게 한다.
  Get-ChildItem -Force $root |
    Where-Object { $_.Name -notin '.git', 'node_modules', 'scripts' -and -not (-not $_.PSIsContainer -and $_.Extension -eq '.aix') } |
    Copy-Item -Destination $dest -Recurse -Force
}

if ($Out) {
  # Studio 로컬 가져오기용: 저장소 밖 폴더에 토큰이 들어간 사본을 만든다.
  $resolved = [IO.Path]::GetFullPath($Out)
  if ($resolved.StartsWith([IO.Path]::GetFullPath($root))) { throw "-Out 은 저장소 밖 경로여야 합니다 (토큰 유출 방지)" }
  if (Test-Path $resolved) { Remove-Item -Recurse -Force $resolved }
  Copy-Project $resolved
  Write-Injected $resolved
  Write-Host "Studio 가져오기용 폴더 준비: $resolved"
  return
}

# 로컬 에이전트 ID(.aix\agent-id, git 제외)를 한 번 만들어 두면 매번 같은 ID로 설치된다.
if (-not (Test-Path (Join-Path $root '.aix\agent-id'))) { aix show $root | Out-Null }

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("ttoli-agent-" + [guid]::NewGuid().ToString('N'))
try {
  Copy-Project $tmp
  Write-Injected $tmp
  $serialArgs = @(); if ($Serial) { $serialArgs = @('--serial', $Serial) }
  if ($Install) {
    aix install $tmp @serialArgs
    if ($Launch) { aix launch-page $tmp @serialArgs }
  } else {
    aix pack $tmp -o (Join-Path $root 'ttoli-agent.aix')
  }
} finally {
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
