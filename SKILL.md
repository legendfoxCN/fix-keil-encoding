---
name: fix-keil-encoding
description: "⚠ ASK FIRST — Convert source file encoding between UTF-8 and GB2312 when editing Keil uVision projects. Keil on Chinese Windows defaults to GB2312, but Write/Edit tools output UTF-8. Trigger when the user edits .c/.h files in STM32/8051 Keil projects, or mentions Keil, garbled text, encoding, or GB2312."
---

## ⚠ READ THIS FIRST — DO NOT SKIP

**Your first action after loading this skill: check whether the user's Keil encoding is already stored in project memory.**

If it is NOT stored, immediately ask the user — use their language:

> "What encoding does your Keil uVision use? GB2312 (default) or UTF-8?"

Save the answer to project memory. **Do NOT run --prep, --commit, or any other command until you have this answer.** If you skip this step, Chinese comments will silently garble in Keil and the user will blame the tool.

**Use the user's language when asking questions.**

---

# Fix Keil Encoding

Keil uVision on Chinese Windows defaults to GB2312. Write/Edit tools output UTF-8. Editing directly corrupts Chinese comments.

## Workflow

Before each edit: check project memory for the user's encoding. If missing → scroll up and follow the FIRST instruction at the top of this file.

1. **Scan** — Run `--check` on target files. Compare detected encoding against the user's config; flag any mismatch (non-blocking).
2. **Prep** — `bash ${CLAUDE_SKILL_DIR}/to_gb2312.sh --prep <file>` -> saves `.bak` + creates `.utf8` work copy
3. **Edit** — Use Write/Edit tools on the `.utf8` file
4. **Commit** — `bash ${CLAUDE_SKILL_DIR}/to_gb2312.sh --commit <file>` -> UTF-8 -> GB2312, overwrite original, delete `.utf8`
5. **Verify** — Remind the user to check in Keil. If garbled, `--undo` rolls back.

## Encoding Detection

`--prep` and `--check` detect the file's actual encoding using a two-pass algorithm:

1. Validate as **UTF-8** (`iconv -f UTF-8 -t UTF-8`)
2. Validate as **GB2312** (`iconv -f GB2312 -t UTF-8`)

If only one passes -> that's the encoding.

If **both** pass (rare — certain GB2312 byte sequences coincidentally form valid UTF-8), a **length comparison** breaks the tie: converting a GB2312 Chinese file GB2312->UTF-8 makes it **longer** (Chinese characters go from 2 bytes to 3 bytes). If the converted output is longer than the original, the file is GB2312; otherwise UTF-8.

| Detected | Action |
|----------|--------|
| GB2312   | Convert to UTF-8 `.utf8` work copy |
| ASCII    | Copy as-is |
| UTF-8    | Copy as-is + note: if garbled in Keil, use `--undo` |
| Unknown  | Try GB2312->UTF-8 conversion; if that fails, copy as-is + note: if garbled, use `--undo` |

**The `.bak` backup is always saved before any conversion.** If Keil shows garbled text after `--commit`, run `--undo` to restore the original file. No risk of data loss.

Use `--check <file>` to inspect encoding without modifying any files.

## Temp Files

All temp files live in `<project>/.keil-tmp/`, mirroring the source tree. Add `.keil-tmp/` to `.gitignore`.

| Command | Purpose |
|---------|---------|
| `--check <file>` | Detect encoding of file(s) without any modification |
| `--prep <file>` | Save `.bak` + create `.utf8` for editing |
| `--commit <file>` | Convert `.utf8` -> GB2312, overwrite original, delete `.utf8` |
| `--undo <file>` | Restore original from `.bak`, delete `.utf8` and `.bak` |
| `--status` | List all `.keil-tmp/` contents |
| `--cleanup` | Remove all `.keil-tmp/` directories |

---

> **Before running any command — did you ask the user about their Keil encoding yet? If not, scroll to the top.**
