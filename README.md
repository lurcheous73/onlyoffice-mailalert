# ONLYOFFICE Mail Alert

Tiny notification-sound add-on for ONLYOFFICE CommunityServer / Workspace Mail.

It does **not** add another mail poller. It hooks ONLYOFFICE's existing `Teamlab.getMailFolders()` refresh and plays one sound when the Inbox unread count increases.

## Behaviour

- Sounds `1.mp3` to `6.mp3` are selectable.
- `7.mp3` is deliberately hidden from normal configuration.
- No sound on initial page load; the initial unread count is only used as a baseline.
- One sound per refresh batch, even if several messages arrive together.
- On **1 April, between 11:00:00 and 11:59:59 local browser time**, the first new-mail event plays hidden `7.mp3` once, then normal behaviour resumes for the rest of the year.
- Normal sound selection is stored per browser profile in `localStorage`.

## Current sound map

The repository expects these vendored files under `sounds/`:

| File | Sound |
|---|---|
| `1.mp3` | Bong |
| `2.mp3` | Fears to Fathom notification |
| `3.mp3` | Ding |
| `4.mp3` | Yahoo email |
| `5.mp3` | Windows 10 Notify Email |
| `6.mp3` | Windows Longhorn New Email |
| `7.mp3` | hidden April-Fools sound |

The source-page manifest is in `sounds/SOURCES.tsv`.

## Install from a Proxmox host

The default deployment model is the same as the Brimstone installation: an LXC containing Docker, with the ONLYOFFICE CommunityServer container inside it.

```bash
CTID=400 ./install.sh
```

Optional variables:

```bash
CTID=400 \
OO_CONTAINER=onlyoffice-community-server \
./install.sh
```

The installer:

1. validates the target CommunityServer container;
2. backs up the nginx include it patches;
3. copies `src/oo-mail-bong.js` and `sounds/1.mp3` through `sounds/7.mp3` into CommunityServer;
4. injects the script using nginx `sub_filter`;
5. runs `nginx -t` before reloading nginx;
6. installs an uninstall/restore helper.

## Browser console

After opening ONLYOFFICE Mail and doing a hard refresh:

```javascript
OOMailBong.getSound()
OOMailBong.setSound(4)
OOMailBong.test()
```

Only `1` through `6` are accepted by `setSound()`.

## Uninstall

From the same Proxmox host:

```bash
CTID=400 ./uninstall.sh
```

## Vendoring the sounds

`tools/vendor-sounds.sh` resolves the sound pages, downloads each MP3, renames them to `1.mp3` through `7.mp3`, verifies that they are audio files, and writes SHA-256 hashes.

Once the MP3s have been vendored and committed, production installs do **not** contact the sound source websites.

## Compatibility

Initially built and tested against:

- ONLYOFFICE CommunityServer `12.8.0.1971`
- nginx `1.18.0` with `http_sub_module`
- CommunityServer running under Docker inside Proxmox LXC

The installer deliberately validates paths and nginx capabilities rather than assuming every ONLYOFFICE image has the same layout.
