@~/.config/agents/AGENTS.md

# Claude Code specific

## Report Writing
- When the user asks for a **レポート (report)**, read `~/.claude/skills/cognitive-rhythm-writing/SKILL.md` (via the Skill tool: `cognitive-rhythm-writing`) BEFORE starting the writing work, and follow its guidance.

## Daily Log (sava)
- 文脈が混ざりそうなときの一行メモには、`$CLAUDE_CODE_SESSION_ID` を使った
  `claude --resume <session-id>` をcontentに含める（会話そのものに戻れるように）
