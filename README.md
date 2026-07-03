# Claude Code Statusline

<p align="center">
  <img src="https://img.shields.io/badge/Claude%20Code-Statusline-6B3FA0?style=flat-square" alt="Claude Code Statusline">
  <img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="MIT License">
  <img src="https://img.shields.io/badge/PRs-welcome-brightgreen?style=flat-square" alt="PRs Welcome">
</p>

> A powerful, customizable status line hook for [Claude Code](https://claude.ai/code) — showing model info, context usage, cost, session duration, code changes, Git branch, and sub-agent status in your terminal.
>
> 为 [Claude Code](https://claude.ai/code) 打造的功能丰富的状态行钩子脚本——在终端中显示模型信息、上下文用量、费用估算、会话时长、代码变更、Git 分支和 Sub-agent 状态。

---

## ✨ Features / 功能

| Item | Description |
|------|-------------|
| 📁 **Working Directory** | Current project path (auto-truncated when too long) |
| 🤖 **Model Name** | Shortened model display name |
| 📊 **Context Bar** | Visual progress bar (█░) with color-coded usage: green <50%, yellow <80%, red ≥80% |
| 💰 **Cost Estimate** | Real-time token cost calculation with multi-model pricing |
| 🔥 **Peak Hours** | Auto-detect Beijing peak hours (8:00-22:00) with doubled-rate marker |
| ⏱ **Session Duration** | Elapsed session time (XhXmXs) |
| 📝 **Code Changes** | Lines added/removed since session start |
| 🌿 **Git Branch** | Current Git branch display |
| 👤 **Sub-agent** | Active sub-agent name badge |

---

## 📸 Preview / 效果预览

```
[deepseek-v4-flash] 🔥  ████████░░░░░░░░░░░░ 40.0% | ¥0.12 | 1h23m45s | +156/-23 |  main
```

---

## 🚀 Installation / 安装

### Prerequisites / 前置要求

- [Claude Code](https://claude.ai/code) installed
- `jq` and `bc` command-line tools

```bash
# macOS
brew install jq bc

# Ubuntu / Debian
sudo apt install jq bc

# CentOS / Fedora / RHEL
sudo yum install jq bc
```

### Quick Install / 快速安装

```bash
# Clone the repo / 克隆仓库
git clone https://github.com/WITstudio86/claude-code-statusline.git
cd claude-code-statusline

# Make script executable / 赋予执行权限
chmod +x statusline.sh

# Get absolute path / 获取绝对路径
SCRIPT_PATH="$(pwd)/statusline.sh"
```

### Configure Claude Code / 配置 Claude Code

Add the following to your Claude Code `~/.claude/settings.json`:

```json
{
  "statusLine.type": "command",
  "statusLine.command": "bash /path/to/your/statusline.sh"
}
```

Replace `/path/to/your/statusline.sh` with the actual absolute path.

**Example / 示例:**

```json
{
  "statusLine.type": "command",
  "statusLine.command": "bash $HOME/.claude/statusline.sh"
}
```

> **💡 Tip:** Put the script in `~/.claude/statusline.sh` for a clean, centralized configuration.
>
> **💡 提示：** 将脚本放在 `~/.claude/statusline.sh` 可以获得更整洁的配置。

---

## ⚙️ Configuration / 配置

### Model Pricing / 模型定价

Edit the `case` block in `statusline.sh` to add or update models:

```bash
case "$model_id" in
    *deepseek*flash*)  PI=1;   PO=2;   PCR="0.02";  PCW=1   ;;  # Input/Output/CacheRead/CacheWrite per 1M tokens
    your*model*)       PI=X;   PO=Y;   PCR=Z;       PCW=W   ;;
    *)                 PI=0;   PO=0;   PCR=0;       PCW=0   ;;  # Unknown → free display
esac
```

- `PI` — Input price (¥/1M tokens)
- `PO` — Output price (¥/1M tokens)
- `PCR` — Cache read price (¥/1M tokens)
- `PCW` — Cache write price (¥/1M tokens)
- Prices are automatically doubled during peak hours (08:00-22:00 Beijing time)

### Peak Hours / 高峰时段

The script uses Beijing time (Asia/Shanghai) for peak detection. To adjust the peak window, modify these lines:

```bash
if [ "$hour_bj" -ge 8 ] && [ "$hour_bj" -lt 22 ]; then
```

Or disable peak pricing entirely by setting `multiplier=1` unconditionally.

### Customization / 自定义

Feel free to fork and modify the script to:
- Add more model pricing entries
- Change the progress bar style
- Add new information fields
- Adjust color thresholds
- Localize for different currencies/timezones

---

## 📁 File Structure / 文件结构

```
claude-code-statusline/
├── statusline.sh          # Main script / 主脚本
├── settings.example.json  # Example Claude Code config / 配置示例
├── LICENSE                # MIT License
└── README.md              # This file / 本文件
```

---

## 🧩 How It Works / 工作原理

Claude Code provides a JSON payload via stdin to the configured status line command. The script:

1. **Parses** the JSON with `jq` to extract model, context, cost, and other fields
2. **Calculates** costs using built-in pricing tables and session duration
3. **Detects** Beijing peak hours for dynamic pricing display
4. **Builds** a color-coded progress bar for context window usage
5. **Outputs** a formatted string that Claude Code renders as the status line

---

## 🤝 Contributing / 贡献

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/WITstudio86/claude-code-statusline/issues).

PRs 和 Issue 欢迎提交！

---

## 📄 License / 许可

[MIT](LICENSE) © WITstudio86

---

<p align="center"><b>Happy Coding with Claude Code! 🚀</b></p>
