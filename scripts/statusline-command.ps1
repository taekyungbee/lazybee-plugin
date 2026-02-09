# lazybee-plugin statusline (Windows PowerShell)
$input = $input | ConvertFrom-Json

# 필드 추출
$Model = if ($input.model.display_name) { $input.model.display_name } else { "?" }
$Dir = if ($input.workspace.current_dir) { $input.workspace.current_dir } elseif ($input.cwd) { $input.cwd } else { "" }
$Cost = [double]($input.cost.total_cost_usd ?? 0)
$Pct = [int]($input.context_window.used_percentage ?? 0)
$DurationMs = [long]($input.cost.total_duration_ms ?? 0)
$InputTokens = [long]($input.cost.total_input_tokens ?? 0)
$CacheRead = [long]($input.cost.total_cache_read_tokens ?? 0)

# === 주간 사용 한도 (API 호출 + 60초 캐시) ===
$UsageCache = "$env:TEMP\.claude-usage-cache.json"
$UsageCacheTTL = 60
$FiveHrPct = 0; $SevenDayPct = 0

function Fetch-Usage {
    try {
        $credPath = "$env:USERPROFILE\.claude\.credentials.json"
        if (-not (Test-Path $credPath)) { return }
        $creds = Get-Content $credPath -Raw | ConvertFrom-Json
        $token = $creds.claudeAiOauth.accessToken
        if (-not $token) { return }
        $headers = @{
            "Accept"          = "application/json"
            "Content-Type"    = "application/json"
            "User-Agent"      = "claude-code/2.0.32"
            "Authorization"   = "Bearer $token"
            "anthropic-beta"  = "oauth-2025-04-20"
        }
        $resp = Invoke-RestMethod -Uri "https://api.anthropic.com/api/oauth/usage" -Headers $headers -TimeoutSec 3 -ErrorAction Stop
        $resp | ConvertTo-Json -Depth 5 | Set-Content $UsageCache -Encoding UTF8
    } catch {}
}

if (Test-Path $UsageCache) {
    $cacheAge = ((Get-Date) - (Get-Item $UsageCache).LastWriteTime).TotalSeconds
    if ($cacheAge -gt $UsageCacheTTL) {
        Start-Job -ScriptBlock { param($fn) & $fn } -ArgumentList ${function:Fetch-Usage} | Out-Null
    }
} else {
    Fetch-Usage
}

if (Test-Path $UsageCache) {
    $usage = Get-Content $UsageCache -Raw | ConvertFrom-Json
    $FiveHrPct = [int]($usage.five_hour.utilization ?? 0)
    $SevenDayPct = [int]($usage.seven_day.utilization ?? 0)
}

# 색상 (ANSI escape)
$Cyan = "`e[36m"; $Green = "`e[32m"; $Yellow = "`e[33m"; $Red = "`e[31m"
$Magenta = "`e[35m"; $White = "`e[1;37m"; $Dim = "`e[2m"; $Reset = "`e[0m"

# 컨텍스트 프로그레스 바
$BarColor = if ($Pct -ge 90) { $Red } elseif ($Pct -ge 50) { $Yellow } else { $Green }

$BarWidth = 20
$Filled = [math]::Floor($Pct * $BarWidth / 100)
$Empty = $BarWidth - $Filled
$Bar = ("█" * $Filled) + ("░" * $Empty)

# 토큰 수 + 캐시 히트율
$TokenK = [math]::Floor($InputTokens / 1000)
$CachePct = 0
$TotalInput = $InputTokens + $CacheRead
if ($TotalInput -gt 0) { $CachePct = [math]::Floor($CacheRead * 100 / $TotalInput) }

$TokenLabel = if ($CachePct -gt 0) { "${Dim}${TokenK}k(${CachePct}%↑)${Reset}" } else { "${Dim}${TokenK}k${Reset}" }

# 컨텍스트 임계값
$CtxLabel = ""
if ($Pct -ge 90) { $CtxLabel = " ${Red}CRITICAL${Reset}" }
elseif ($Pct -ge 80) { $CtxLabel = " ${Yellow}COMPRESS?${Reset}" }

# 사용 한도 라벨
$LimitLabel = ""
if ($FiveHrPct -gt 0 -or $SevenDayPct -gt 0) {
    $LimitColor = if ($FiveHrPct -ge 80 -or $SevenDayPct -ge 80) { $Red }
                  elseif ($FiveHrPct -ge 50 -or $SevenDayPct -ge 50) { $Yellow }
                  else { $Green }
    $LimitLabel = " ${Dim}|${Reset} ${LimitColor}5h:${FiveHrPct}% 7d:${SevenDayPct}%${Reset}"
}

# 시간
$Mins = [math]::Floor($DurationMs / 60000)
$Secs = [math]::Floor(($DurationMs % 60000) / 1000)

# 비용 색상
$CostFmt = $Cost.ToString("F2")
$CostColor = if ($Cost -ge 10) { $Red } elseif ($Cost -ge 5) { $Yellow } else { $Green }

# Git 브랜치
$Branch = ""
if ($Dir) { try { $Branch = git -C $Dir symbolic-ref --short HEAD 2>$null } catch {} }

# 한 줄 출력
$Out = "${White} ${Model}${Reset}"
if ($Dir) { $DirName = Split-Path $Dir -Leaf; $Out += " ${Cyan} ${DirName}${Reset}" }
if ($Branch) { $Out += " ${Magenta} ${Branch}${Reset}" }
$Out += " ${Dim}|${Reset} ${BarColor}${Bar}${Reset} ${Pct}% ${TokenLabel}${CtxLabel}"
$Out += $LimitLabel
$Out += " ${Dim}|${Reset} ${CostColor}`$${CostFmt}${Reset}"
$Out += " ${Dim}|${Reset} ${Dim}${Mins}m ${Secs}s${Reset}"

Write-Host -NoNewline $Out
