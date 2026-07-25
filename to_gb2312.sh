#!/bin/bash
# to_gb2312.sh - Keil source encoding converter
# All temp files live in <project>/.keil-tmp/ mirroring the project structure.

set -e

# ── Helpers ──
is_utf8() { iconv -f UTF-8 -t UTF-8 "$1" > /dev/null 2>&1; }
has_non_ascii() { grep -qaP '[\x80-\xFF]' "$1" 2>/dev/null; }

find_root() {
    # Walk up from the source file to find the project root (has .uvprojx)
    local dir
    dir="$(realpath "$(dirname "$1")")"
    while [ "$dir" != "/" ] && [ "$dir" != "." ]; do
        if compgen -G "$dir"/*.uvprojx > /dev/null 2>&1; then
            echo "$dir"; return 0
        fi
        dir="$(dirname "$dir")"
    done
    # Fallback: source file's own directory
    realpath "$(dirname "$1")"
}

tmp_dir() {
    # e.g. User/main.c → <root>/.keil-tmp/User/
    local f="$1" root
    root="$(find_root "$f")"
    local rel; rel="$(realpath --relative-to="$root" "$(dirname "$f")")"
    echo "$root/.keil-tmp/$rel"
}

bak_file() { echo "$(tmp_dir "$1")/$(basename "$1").bak"; }
utf8_file() { echo "$(tmp_dir "$1")/$(basename "$1").utf8"; }

usage() {
    echo "Usage:"
    echo "  to_gb2312.sh --prep    <file> [file2..]  保存备份，生成 UTF-8 工作副本"
    echo "  to_gb2312.sh --commit  <file> [file2..]  提交 UTF-8 → GB2312，删 .utf8"
    echo "  to_gb2312.sh --undo    <file> [file2..]  从 .bak 恢复（确保 GB2312），删临时文件"
    echo "  to_gb2312.sh --status                   列出 .keil-tmp 状态"
    echo "  to_gb2312.sh --cleanup                  删除整个 .keil-tmp/"
    exit 1
}
[ $# -eq 0 ] && usage

# ── Status ──
if [ "$1" = "--status" ]; then
    script_dir="$(realpath "$(dirname "$0")")"
    echo "Keil temp files (from current directory down):"
    find . -type d -name ".keil-tmp" 2>/dev/null | while read d; do
        echo ""
        echo "  $d/"
        find "$d" -type f | sort | while read tf; do
            case "$tf" in
                *.bak)  echo "    [bak]  ${tf#$d/}" ;;
                *.utf8) echo "    [utf8] ${tf#$d/}" ;;
                *)      echo "           ${tf#$d/}" ;;
            esac
        done
    done
    exit 0
fi

# ── Cleanup ──
if [ "$1" = "--cleanup" ]; then
    find . -type d -name ".keil-tmp" 2>/dev/null | while read d; do
        echo "Removing $d"
        rm -rf "$d"
    done
    echo "Done."
    exit 0
fi

# ── Commands that take file arguments ──
cmd="$1"; shift
case "$cmd" in
    --prep|--commit|--undo) ;;
    *) usage ;;
esac
[ $# -eq 0 ] && usage

for f in "$@"; do
    f="$(realpath "$f")"
    [ -f "$f" ] || { echo "NOT FOUND: $f"; continue; }

    tdir="$(tmp_dir "$f")"
    bak="$(bak_file "$f")"
    utf8="$(utf8_file "$f")"

    case "$cmd" in

    --prep)
        mkdir -p "$tdir"
        [ -f "$bak" ] || cp "$f" "$bak"
        if ! has_non_ascii "$f"; then
            cp "$f" "$utf8"
            echo "COPY  $(basename "$f")  (ASCII)"
        elif is_utf8 "$f"; then
            cp "$f" "$utf8"
            echo "COPY  $(basename "$f")  (already UTF-8)"
        else
            iconv -f GB2312 -t UTF-8 "$f" > "$utf8" 2>/dev/null || { rm -f "$utf8"; echo "FAIL $f"; continue; }
            echo "PREP  $(basename "$f")  (GB2312 → UTF-8)"
        fi
        echo "      → 编辑: $utf8"
        ;;

    --commit)
        [ -f "$utf8" ] || { echo "SKIP $(basename "$f") — 没有 .utf8 文件"; continue; }
        iconv -f UTF-8 -t GB2312 "$utf8" > "${utf8}.tmp" 2>/dev/null
        if [ $? -eq 0 ] && [ -s "${utf8}.tmp" ]; then
            mv "${utf8}.tmp" "$f"
            rm -f "$utf8"
            echo "OK  $(basename "$f")  (UTF-8 → GB2312)"
        else
            rm -f "${utf8}.tmp"
            echo "FAIL $(basename "$f")"
        fi
        ;;

    --undo)
        [ -f "$bak" ] || { echo "NO BAK: $f"; continue; }
        if is_utf8 "$bak" && has_non_ascii "$bak"; then
            iconv -f UTF-8 -t GB2312 "$bak" > "$f" 2>/dev/null || { echo "FAIL $f"; continue; }
        else
            cp "$bak" "$f"
        fi
        rm -f "$utf8" "$bak"
        # Remove empty dirs up to .keil-tmp
        rmdir --ignore-fail-on-non-empty "$tdir" 2>/dev/null || true
        echo "UNDO $(basename "$f")"
        ;;

    esac
done
