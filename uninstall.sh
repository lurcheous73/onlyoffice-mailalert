#!/usr/bin/env bash
set -Eeuo pipefail

CTID="${CTID:-400}"
OO_CONTAINER="${OO_CONTAINER:-onlyoffice-community-server}"
WEB=/var/www/onlyoffice/WebStudio
JS="$WEB/addons/mail/js/oo-mail-bong.js"
SOUNDS="$WEB/addons/mail/sounds"
NGINX=/etc/nginx/includes/onlyoffice-communityserver-common.conf

run() {
    pct exec "$CTID" -- "$@"
}

LATEST="$(pct exec "$CTID" -- sh -lc 'ls -dt /root/onlyoffice-mailalert-backup-* 2>/dev/null | head -1' || true)"

if [[ -z "$LATEST" ]]; then
    echo "FAIL: no ONLYOFFICE Mail Alert backup found in CT $CTID" >&2
    exit 1
fi

echo "Using backup: $LATEST"
run docker cp "$LATEST/original/onlyoffice-communityserver-common.conf" "$OO_CONTAINER:$NGINX"
run docker exec "$OO_CONTAINER" rm -f "$JS"
run docker exec "$OO_CONTAINER" rm -rf "$SOUNDS"
run docker exec "$OO_CONTAINER" nginx -t
run docker exec "$OO_CONTAINER" nginx -s reload

echo "ONLYOFFICE Mail Alert removed."
