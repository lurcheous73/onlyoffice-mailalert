#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT/sounds/SOURCES.tsv"
UA='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/124 Safari/537.36'

mkdir -p "$ROOT/sounds"

while IFS=$'\t' read -r num name page; do
    [[ -n "$num" && -n "$page" ]] || continue

    echo "=== $num: $name ==="
    html="$(curl -fsSL -A "$UA" "$page")"

    mp3="$(printf '%s' "$html" \
        | grep -oE '/media/sounds/[^"'"'"'?#]+\.mp3' \
        | head -1 || true)"

    if [[ -z "$mp3" ]]; then
        echo "FAIL: could not resolve MP3 from $page" >&2
        exit 1
    fi

    url="https://www.myinstants.com${mp3}"
    tmp="$(mktemp)"

    curl -fsSL -A "$UA" "$url" -o "$tmp"

    mime="$(file -b --mime-type "$tmp")"
    case "$mime" in
        audio/mpeg|audio/mp3|application/octet-stream) ;;
        *)
            echo "FAIL: $url returned unexpected MIME $mime" >&2
            rm -f "$tmp"
            exit 1
            ;;
    esac

    mv "$tmp" "$ROOT/sounds/$num.mp3"
    echo "saved sounds/$num.mp3"
done < "$MANIFEST"

(
    cd "$ROOT/sounds"
    sha256sum 1.mp3 2.mp3 3.mp3 4.mp3 5.mp3 6.mp3 7.mp3 > SHA256SUMS
)

echo
echo "Vendored sound files:"
ls -lh "$ROOT"/sounds/{1,2,3,4,5,6,7}.mp3
