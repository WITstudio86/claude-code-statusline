#!/bin/bash
# ── Claude Code Status Line Hook ──
# 项目地址、模型、上下文、费用、时长、代码变更、Git 分支

input=$(cat)

# ── 基础字段提取 ──
dir=$(echo "$input" | jq -r '.workspace.current_dir // ""')
model=$(echo "$input" | jq -r '.model.display_name // "?"')
model_id=$(echo "$input" | jq -r '.model.id // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
cu=$(echo "$input" | jq -r '.context_window.current_usage // {}')

it=$(echo "$cu" | jq -r '.input_tokens // 0')
ot=$(echo "$cu" | jq -r '.output_tokens // 0')
cr=$(echo "$cu" | jq -r '.cache_read_input_tokens // 0')
cw=$(echo "$cu" | jq -r '.cache_creation_input_tokens // 0')

# ── 高峰时段检测（北京时间 9:00-12:00 和 14:00-18:00 翻倍）──
hour_bj=$(TZ='Asia/Shanghai' date +%H)
hour_bj=$((10#$hour_bj))  # 去掉前导零，避免被当作八进制
if { [ "$hour_bj" -ge 9 ] && [ "$hour_bj" -lt 12 ]; } || { [ "$hour_bj" -ge 14 ] && [ "$hour_bj" -lt 18 ]; }; then
    is_peak=1
    multiplier=2
else
    is_peak=0
    multiplier=1
fi

# ── 定价匹配（DeepSeek 为 元/1M tokens 平时价格）──
# PI=输入 PO=输出 PCR=缓存读 PCW=缓存写
case "$model_id" in
    *deepseek*flash*)  PI=1;   PO=2;   PCR="0.02";  PCW=1   ;;  # V4-Flash
    *deepseek*pro*)    PI=3;   PO=6;   PCR="0.025"; PCW=3   ;;  # V4-Pro
    *kimi*k2*)         PI=2;   PO=8;   PCR=0;       PCW=2   ;;
    *glm*4*)           PI=1;   PO=4;   PCR=0;       PCW=1   ;;
    *qwen*plus*)       PI=3.5; PO=7;   PCR=0;       PCW=3.5 ;;
    *MiniMax*M2*)      PI=8;   PO=32;  PCR=0;       PCW=8   ;;
    *claude*sonnet*)   PI=3;   PO=15;  PCR="0.30";  PCW="3.75" ;;
    *claude*opus*)     PI=15;  PO=75;  PCR="1.50";  PCW="18.75" ;;
    *)                 PI=0;   PO=0;   PCR=0;       PCW=0   ;;
esac

# ── 费用计算 ──
if [ "$PI" != "0" ] || [ "$PO" != "0" ]; then
    cost=$(echo "scale=4; ($it * $PI + $ot * $PO + $cr * $PCR + $cw * $PCW) * $multiplier / 1000000" | bc)
    cost_str=" | ¥$cost"
else
    cost_str=""
fi

# ── 会话时长 ──
duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
total_secs=$(( duration_ms / 1000 ))
h=$(( total_secs / 3600 ))
m=$(( (total_secs % 3600) / 60 ))
s=$(( total_secs % 60 ))

if [ "$h" -gt 0 ]; then
    time_str=" | ${h}h${m}m${s}s"
elif [ "$m" -gt 0 ]; then
    time_str=" | ${m}m${s}s"
elif [ "$total_secs" -gt 0 ]; then
    time_str=" | ${s}s"
else
    time_str=""
fi

# ── 代码变更 ──
added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
if [ "$added" -gt 0 ] || [ "$removed" -gt 0 ]; then
    code_str=" | +${added}/-${removed}"
else
    code_str=""
fi

# ── Git 分支 ──
branch=""
if [ -n "$dir" ] && [ -d "$dir" ]; then
    branch=$(git -C "$dir" branch --show-current 2>/dev/null)
fi
if [ -n "$branch" ]; then
    git_str=" |  $branch"
else
    git_str=""
fi

# ── Sub-agent ──
agent=$(echo "$input" | jq -r '.agent.name // ""')
if [ -n "$agent" ]; then
    agent_str=" | [$agent]"
else
    agent_str=""
fi

# ── 进度条 ──
pct_int=${used_pct%.*}
filled=$(( pct_int / 5 ))
bar=""
for ((i=0; i<20; i++)); do
    if [ "$i" -lt "$filled" ]; then bar="${bar}█"; else bar="${bar}░"; fi
done

# ── 颜色 ──
esc=$'\033'
if   [ "$pct_int" -lt 50 ]; then color=32
elif [ "$pct_int" -lt 80 ]; then color=33
else color=31
fi
pct_round=$(printf "%.1f" "$used_pct")

# ── 模型名缩短 ──
model_short="${model##*/}"
model_short="${model_short%% *}"
# 去掉 [1M] / [200K] 等上下文窗口标注
model_short="${model_short%%[*}"

# ── 高峰标记 ──
peak_tag=""
[ "$is_peak" -eq 1 ] && peak_tag=" 🔥"

# ── 目录显示（缩短）──
dir_display="$dir"
[ -n "${HOME:-}" ] && [[ "$dir_display" == "$HOME"* ]] && dir_display="~${dir_display#$HOME}"
[ ${#dir_display} -gt 25 ] && dir_display="...${dir_display: -22}"

# ── 输出 ──
printf "[${model_short}]${peak_tag}  ${esc}[${color}m${bar} %.1f%%${esc}[0m${cost_str}${time_str}${code_str}${git_str}${agent_str}" "$used_pct"
