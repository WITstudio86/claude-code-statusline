[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$raw = @($input) -join "`n"
$data = $raw | ConvertFrom-Json

$model = if ($data.model.display_name) { $data.model.display_name } else { "?" }
$pct   = if ($data.context_window.used_percentage) { $data.context_window.used_percentage } else { 0 }
$cwd   = if ($data.cwd) { $data.cwd } else { "" }

$cu = $data.context_window.current_usage
$it = if ($cu -and $cu.input_tokens)                { $cu.input_tokens }                else { 0 }
$ot = if ($cu -and $cu.output_tokens)               { $cu.output_tokens }               else { 0 }
$cr = if ($cu -and $cu.cache_read_input_tokens)     { $cu.cache_read_input_tokens }     else { 0 }
$cw = if ($cu -and $cu.cache_creation_input_tokens) { $cu.cache_creation_input_tokens } else { 0 }

# ── 高峰时段检测（北京时间 9:00-12:00 和 14:00-18:00 翻倍）──
$beijingNow = [DateTime]::UtcNow.AddHours(8)
$isPeak = ($beijingNow.Hour -ge 9 -and $beijingNow.Hour -lt 12) -or ($beijingNow.Hour -ge 14 -and $beijingNow.Hour -lt 18)
$multiplier = if ($isPeak) { 2 } else { 1 }

# ── 定价匹配 —— 格式：输入 输出 缓存命中 缓存写入（DeepSeek 为 元/1M tokens 平时价格，高峰自动翻倍）──
$modelId = if ($data.model.id) { $data.model.id } else { "" }

switch -Wildcard ($modelId) {
    # DeepSeek
    "*deepseek*flash*" { $PI = 1;    $PO = 2;   $PCR = 0.02;  $PCW = 1    }  # V4-Flash
    "*deepseek*pro*"   { $PI = 3;    $PO = 6;   $PCR = 0.025; $PCW = 3    }  # V4-Pro
    # 其他供应商
    "*kimi*k2*"        { $PI = 2;    $PO = 8;   $PCR = 0;     $PCW = 2    }
    "*glm*4*"          { $PI = 1;    $PO = 4;   $PCR = 0;     $PCW = 1    }
    "*qwen*plus*"      { $PI = 3.5;  $PO = 7;   $PCR = 0;     $PCW = 3.5  }
    "*MiniMax*M2*"     { $PI = 8;    $PO = 32;  $PCR = 0;     $PCW = 8    }
    # Anthropic 官方（⚠ 以下为美元定价，切回时需将输出中的 ¥ 改为 $）
    "*claude*sonnet*"  { $PI = 3;    $PO = 15;  $PCR = 0.30;  $PCW = 3.75 }
    "*claude*opus*"    { $PI = 15;   $PO = 75;  $PCR = 1.50;  $PCW = 18.75 }
    # 未识别：不显示费用
    default            { $PI = 0;    $PO = 0;   $PCR = 0;     $PCW = 0    }
}

if ($PI -ne 0) {
    $cost = [math]::Round(($it * $PI + $ot * $PO + $cr * $PCR + $cw * $PCW) * $multiplier / 1000000, 4)
    $costStr = " | ¥$cost"
} else {
    $costStr = ""
}

# ── 会话时长 ──
$durationMs = if ($data.cost.total_duration_ms) { $data.cost.total_duration_ms } else { 0 }
$totalSecs  = [math]::Floor($durationMs / 1000)
$h = [math]::Floor($totalSecs / 3600)
$m = [math]::Floor(($totalSecs % 3600) / 60)
$s = $totalSecs % 60

if ($h -gt 0) {
    $timeStr = " | ${h}h${m}m${s}s"
} elseif ($m -gt 0) {
    $timeStr = " | ${m}m${s}s"
} elseif ($totalSecs -gt 0) {
    $timeStr = " | ${s}s"
} else {
    $timeStr = ""
}

# ── 代码变更 ──
$added   = if ($data.cost.total_lines_added)   { $data.cost.total_lines_added }   else { 0 }
$removed = if ($data.cost.total_lines_removed) { $data.cost.total_lines_removed } else { 0 }
$codeStr = if ($added -gt 0 -or $removed -gt 0) { " | +${added}/-${removed}" } else { "" }

# ── Git 分支 ──
$branch = ""
if ($cwd) {
    try { $branch = & git -C $cwd branch --show-current 2>$null } catch { }
}
$gitStr = if ($branch) { " |  $branch" } else { "" }

# ── Sub-agent ──
$agentStr = ""
if ($data.agent -and $data.agent.name) {
    $agentStr = " | [" + $data.agent.name + "]"
}

# ── 进度条 ──
$filled = [math]::Floor($pct / 5)
$bar = ("█" * $filled) + ("░" * (20 - $filled))

# ── 颜色 ──
$esc      = [char]27
$color    = if ($pct -lt 50) { 32 } elseif ($pct -lt 80) { 33 } else { 31 }
$pctRound = [math]::Round($pct, 1)

# ── 模型名缩短 ──
$modelShort = ($model -replace '.*/', '') -replace ' .*', ''

# ── 高峰标记 ──
$peakTag = if ($isPeak) { " 🔥" } else { "" }

[Console]::WriteLine("[$modelShort]$peakTag  $esc[${color}m${bar} ${pctRound}%$esc[0m${costStr}${timeStr}${codeStr}${gitStr}${agentStr}")
