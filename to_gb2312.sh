#!/bin/bash
# to_gb2312.sh - Keil source encoding converter
# All temp files live in <project>/.keil-tmp/ mirroring the project structure.

set -e

# ── Helpers ──
is_utf8() { iconv -f UTF-8 -t UTF-8 "$1" > /dev/null 2>&1; }
has_non_ascii() { grep -qaP '[\x80-\xFF]' "$1" 2>/dev/null; }

# ── Encoding detection ──
# Returns: ascii | gb2312 | utf8 | unknown
#
# Key insight: GB2312 Chinese (2-byte pairs in 0xA1-0xFE) can coincidentally
# form valid UTF-8 sequences. When both encodings validate, a length comparison
# breaks the tie: GB2312 Chinese expands from 2 bytes to 3 bytes in UTF-8,
# so if the converted output is longer, the original was GB2312.
detect_encoding() {
    local f="$1"
    if ! has_non_ascii "$f"; then
        echo "ascii"; return 0
    fi

    local ok_utf8=false ok_gb2312=false
    is_utf8 "$f" && ok_utf8=true
    iconv -f GB2312 -t UTF-8 "$f" > /dev/null 2>&1 && ok_gb2312=true

    # Only UTF-8 valid -> definitely UTF-8
    if $ok_utf8 && ! $ok_gb2312; then
        echo "utf8"; return 0
    fi

    # Only GB2312 valid -> definitely GB2312
    if ! $ok_utf8 && $ok_gb2312; then
        echo "gb2312"; return 0
    fi

    # Both valid (rare) -> length comparison
    if $ok_utf8 && $ok_gb2312; then
        local orig_len converted_len
        orig_len=$(wc -c < "$f")
        converted_len=$(iconv -f GB2312 -t UTF-8 "$f" 2>/dev/null | wc -c)
        if [ "$converted_len" -gt "$orig_len" ]; then
            # Grew after conversion -> was GB2312 (2-byte -> 3-byte CJK)
            echo "gb2312"; return 0
        fi
        # Same or shorter -> was already UTF-8
        echo "utf8"; return 0
    fi

    echo "unknown"; return 0
}

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
    # e.g. User/main.c -> <root>/.keil-tmp/User/
    local f="$1" root
    root="$(find_root "$f")"
    local rel; rel="$(realpath --relative-to="$root" "$(dirname "$f")")"
    echo "$root/.keil-tmp/$rel"
}

bak_file() { echo "$(tmp_dir "$1")/$(basename "$1").bak"; }
utf8_file() { echo "$(tmp_dir "$1")/$(basename "$1").utf8"; }

usage() {
    echo "Usage:"
    echo "  to_gb2312.sh --prep    <file> [file2..]  Save .bak + create .utf8 work copy"
    echo "  to_gb2312.sh --commit  <file> [file2..]  Convert .utf8 -> GB2312, overwrite original"
    echo "  to_gb2312.sh --undo    <file> [file2..]  Restore original from .bak, remove temp files"
    echo "  to_gb2312.sh --status                   List .keil-tmp/ contents"
    echo "  to_gb2312.sh --cleanup                  Remove all .keil-tmp/ directories"
    echo "  to_gb2312.sh --check   <file> [file2..] Detect encoding (no file changes)"
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

# ── Check (encoding detection only, no file changes) ──
if [ "$1" = "--check" ]; then
    shift
    [ $# -eq 0 ] && { echo "Usage: to_gb2312.sh --check <file> [file2..]"; exit 1; }
    for f in "$@"; do
        f="$(realpath "$f")"
        [ -f "$f" ] || { echo "NOT FOUND: $f"; continue; }
        enc=$(detect_encoding "$f")
        case "$enc" in
            ascii)   echo "ASCII   $f" ;;
            gb2312)  echo "GB2312  $f" ;;
            utf8)    echo "UTF-8   $f  <- note: Keil default encoding is GB2312; if garbled, use --undo" ;;
            unknown) echo "UNKNOWN $f  <- cannot determine encoding; if garbled, use --undo" ;;
        esac
    done
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

        # ── Detect encoding + save .bak ──
        enc=$(detect_encoding "$f")
        [ -f "$bak" ] || cp "$f" "$bak"

        case "$enc" in

        ascii)
            cp "$f" "$utf8"
            echo "PREP  $(basename "$f")  (ASCII)"
            ;;

        gb2312)
            iconv -f GB2312 -t UTF-8 "$f" > "$utf8" 2>/dev/null || {
                rm -f "$utf8"
                echo "FAIL $(basename "$f") - GB2312 -> UTF-8 conversion failed"
                continue
            }
            echo "PREP  $(basename "$f")  (GB2312 -> UTF-8)"
            ;;

        utf8)
            cp "$f" "$utf8"
            echo "PREP  $(basename "$f")  (UTF-8, use --undo if garbled in Keil)"
            ;;

        *)
            # Unknown encoding — try GB2312 first, fall back to raw copy
            if iconv -f GB2312 -t UTF-8 "$f" > "$utf8" 2>/dev/null; then
                echo "PREP  $(basename "$f")  (UNKNOWN, attempted GB2312->UTF-8, use --undo if garbled)"
            else
                cp "$f" "$utf8"
                echo "PREP  $(basename "$f")  (UNKNOWN, copied as-is, use --undo if garbled)"
            fi
            ;;

        esac
        echo "      -> edit: $utf8"
        ;;

    --commit)
        [ -f "$utf8" ] || { echo "SKIP $(basename "$f") - no .utf8 file found"; continue; }
        iconv -f UTF-8 -t GB2312 "$utf8" > "${utf8}.tmp" 2>/dev/null
        if [ $? -eq 0 ] && [ -s "${utf8}.tmp" ]; then
            mv "${utf8}.tmp" "$f"
            rm -f "$utf8"
            echo "OK  $(basename "$f")  (UTF-8 -> GB2312)"
        else
            rm -f "${utf8}.tmp"
            echo "FAIL $(basename "$f")"
        fi
        ;;

    --undo)
        [ -f "$bak" ] || { echo "NO BAK: $f"; continue; }
        cp "$bak" "$f"
        rm -f "$utf8" "$bak"
        rmdir --ignore-fail-on-non-empty "$tdir" 2>/dev/null || true
        echo "UNDO $(basename "$f")  (restored from .bak)"
        ;;

    esac
done
