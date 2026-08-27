#!/usr/bin/env bash
set -Eeuo pipefail

CTID="${CTID:-400}"
OO_CONTAINER="${OO_CONTAINER:-onlyoffice-community-server}"
WEB=/var/www/onlyoffice/WebStudio
JS="$WEB/addons/mail/js/oo-mail-bong.js"
SOUNDS="$WEB/addons/mail/sounds"
NGINX=/etc/nginx/includes/onlyoffice-communityserver-common.conf
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="/root/onlyoffice-mailalert-backup-$STAMP"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

run() {
    pct exec "$CTID" -- "$@"
}

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

command -v pct >/dev/null 2>&1 || fail "pct not found; run this from the Proxmox host"

for f in "$SCRIPT_DIR/src/oo-mail-bong.js"; do
    [[ -f "$f" ]] || fail "missing $f"
done

for n in 1 2 3 4 5 6 7; do
    [[ -f "$SCRIPT_DIR/sounds/$n.mp3" ]] || fail "missing sounds/$n.mp3"
done

echo "============================================================"
echo " ONLYOFFICE MAIL ALERT INSTALL"
echo " CTID: $CTID"
echo " Container: $OO_CONTAINER"
echo "============================================================"

run docker inspect "$OO_CONTAINER" >/dev/null

if ! run docker exec "$OO_CONTAINER" nginx -V 2>&1 | grep -q -- '--with-http_sub_module'; then
    fail "nginx http_sub_module is not available"
fi

run docker exec "$OO_CONTAINER" test -f "$NGINX"
run mkdir -p "$BACKUP/original"
run docker cp "$OO_CONTAINER:$NGINX" "$BACKUP/original/onlyoffice-communityserver-common.conf"

run docker exec "$OO_CONTAINER" mkdir -p "$SOUNDS"

pct push "$CTID" "$SCRIPT_DIR/src/oo-mail-bong.js" /tmp/oo-mail-bong.js
run docker cp /tmp/oo-mail-bong.js "$OO_CONTAINER:$JS"
run rm -f /tmp/oo-mail-bong.js

for n in 1 2 3 4 5 6 7; do
    pct push "$CTID" "$SCRIPT_DIR/sounds/$n.mp3" "/tmp/$n.mp3"
    run docker cp "/tmp/$n.mp3" "$OO_CONTAINER:$SOUNDS/$n.mp3"
    run rm -f "/tmp/$n.mp3"
done

run docker exec "$OO_CONTAINER" chown onlyoffice:onlyoffice "$JS"
run docker exec "$OO_CONTAINER" chmod 0644 "$JS"
run docker exec "$OO_CONTAINER" sh -lc "chown onlyoffice:onlyoffice '$SOUNDS'/*.mp3 && chmod 0644 '$SOUNDS'/*.mp3"

pct exec "$CTID" -- docker exec -i "$OO_CONTAINER" python3 - <<'PY'
from pathlib import Path

path = Path('/etc/nginx/includes/onlyoffice-communityserver-common.conf')
text = path.read_text()
marker = '# OO-MAIL-ALERT'

if marker not in text:
    needle = 'location / {\n'
    replacement = '''location / {
        # OO-MAIL-ALERT
        sub_filter_once on;
        sub_filter '</body>' '<script src="/addons/mail/js/oo-mail-bong.js?v=0001"></script></body>';
'''
    if needle not in text:
        raise SystemExit('FAIL: location / block not found')
    text = text.replace(needle, replacement, 1)
    path.write_text(text)

print('OO Mail Alert nginx injection present')
PY

run docker exec "$OO_CONTAINER" nginx -t
run docker exec "$OO_CONTAINER" nginx -s reload

cat > /tmp/onlyoffice-mailalert-restore.sh <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
C='$OO_CONTAINER'
NGINX='$NGINX'
BACKUP='$BACKUP'
docker cp "\$BACKUP/original/onlyoffice-communityserver-common.conf" "\$C:\$NGINX"
docker exec "\$C" rm -f '$JS'
docker exec "\$C" rm -rf '$SOUNDS'
docker exec "\$C" nginx -t
docker exec "\$C" nginx -s reload
echo 'ONLYOFFICE Mail Alert restored to pre-install nginx config.'
EOF

pct push "$CTID" /tmp/onlyoffice-mailalert-restore.sh "$BACKUP/restore.sh"
run chmod 700 "$BACKUP/restore.sh"
rm -f /tmp/onlyoffice-mailalert-restore.sh

echo
echo "INSTALL COMPLETE"
echo "Rollback: pct exec $CTID -- $BACKUP/restore.sh"
