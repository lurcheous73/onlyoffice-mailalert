#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
UA='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/124 Safari/537.36'
REFERER='https://www.myinstants.com/'

mkdir -p "$ROOT/sounds"

declare -A URLS=(
  [1]='https://www.myinstants.com/media/sounds/bong.mp3'
  [2]='https://www.myinstants.com/media/sounds/fears-to-fathom-notification-sound.mp3'
  [3]='https://www.myinstants.com/media/sounds/ding-sound-effect_2.mp3'
  [4]='https://www.myinstants.com/media/sounds/yahoo-email-sound.mp3'
  [5]='https://www.myinstants.com/media/sounds/windows-10-notify-email.mp3'
  [6]='https://www.myinstants.com/media/sounds/windows-longhorn-new-email.mp3'
  [7]='https://www.myinstants.com/media/sounds/crazy-frog-bros-audiotrimmer.mp3'
)

for num in 1 2 3 4 5 6 7; do
    url="${URLS[$num]}"
    tmp="$(mktemp)"

    echo "=== $num ==="
    echo "$url"

    curl -fsSL -A "$UA" -e "$REFERER" "$url" -o "$tmp"

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
done

(
    cd "$ROOT/sounds"
    sha256sum 1.mp3 2.mp3 3.mp3 4.mp3 5.mp3 6.mp3 7.mp3 > SHA256SUMS
)

echo
echo "Vendored sound files:"
ls -lh "$ROOT"/sounds/{1,2,3,4,5,6,7}.mp3
