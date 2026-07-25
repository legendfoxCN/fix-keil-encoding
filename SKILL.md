---
name: fix-keil-encoding
description: "Convert source file encoding between UTF-8 and GB2312 when editing Keil uVision projects. Keil on Chinese Windows defaults to GB2312, but Write/Edit tools output UTF-8 — without conversion Chinese comments appear garbled. Trigger when the user edits .c/.h files in STM32/8051 Keil projects, or mentions Keil, garbled text, encoding, or GB2312."
---

# Fix Keil Encoding

Keil uVision on Chinese Windows uses GB2312. Write/Edit tools output UTF-8. Editing directly corrupts Chinese comments.

## Workflow

1. `bash ${CLAUDE_SKILL_DIR}/to_gb2312.sh --prep <file>` → saves `.bak` + creates `.utf8` under `<project>/.keil-tmp/`
2. Edit the `.utf8` path printed by the script
3. `bash ${CLAUDE_SKILL_DIR}/to_gb2312.sh --commit <file>` → converts `.utf8` back to GB2312, overwrites original, deletes `.utf8`

## Verify Your Changes

- Read the `.utf8` file directly to confirm edits — it is UTF-8, readable in the terminal
- **Never** read the original `.c`/`.h` to verify — it is GB2312, garbled in the terminal
- **Never** run `--prep` again after `--commit` — that recreates `.utf8` from the committed GB2312 file

## Temp Files

All temp files live in `<project>/.keil-tmp/`, mirroring the source tree. Add `.keil-tmp/` to `.gitignore`.

| Command | Purpose |
|---------|---------|
| `--prep <file>` | Save `.bak` + create `.utf8` for editing |
| `--commit <file>` | Convert `.utf8` → GB2312, overwrite original, delete `.utf8` |
| `--undo <file>` | Restore from `.bak` (ensures GB2312), delete all temp files |
| `--status` | List all `.keil-tmp/` contents |
| `--cleanup` | Remove all `.keil-tmp/` directories |
