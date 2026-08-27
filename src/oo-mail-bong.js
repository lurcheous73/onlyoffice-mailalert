(function () {
    "use strict";

    if (!/^\/addons\/mail(?:\/|$)/i.test(window.location.pathname)) {
        return;
    }

    const VERSION = "0.003";
    const SOUND_KEY = "oo-mail-bong-sound";
    const CUSTOM_SOUND_KEY = "oo-mail-alert-custom-sound";
    const ACCOUNT_SOUNDS = {
        "deborah.sherwood@the-grange.uk": "/addons/mail/sounds/debs.mp3"
    };

    let previousUnread = null;
    let hooked = false;

    function log() {
        console.log("[OO Mail Alert]", ...arguments);
    }

    function selectedSound() {
        let n = parseInt(localStorage.getItem(SOUND_KEY) || "1", 10);
        if (!Number.isInteger(n) || n < 1 || n > 6) n = 1;
        return n;
    }

    function customSound() {
        const value = localStorage.getItem(CUSTOM_SOUND_KEY);
        return value && value.trim() ? value.trim() : null;
    }

    function accountSound() {
        try {
            if (!window.accountsManager || typeof window.accountsManager.getAccountList !== "function") {
                return null;
            }
            const accounts = window.accountsManager.getAccountList() || [];
            for (let i = 0; i < accounts.length; i++) {
                const email = String(accounts[i].email || "").toLowerCase();
                if (ACCOUNT_SOUNDS[email]) return ACCOUNT_SOUNDS[email];
            }
        } catch (_) {}
        return null;
    }

    function aprilFoolsSound() {
        const now = new Date();
        if (now.getMonth() === 3 && now.getDate() === 1 && now.getHours() === 11) {
            const key = "oo-mail-alert-april-" + now.getFullYear();
            if (localStorage.getItem(key) !== "1") {
                localStorage.setItem(key, "1");
                return 7;
            }
        }
        return null;
    }

    function soundUrl(number) {
        return "/addons/mail/sounds/" + number + ".mp3";
    }

    function normalSoundUrl() {
        return accountSound() || customSound() || soundUrl(selectedSound());
    }

    function playUrl(url) {
        const audio = new Audio(url);
        audio.volume = 0.85;
        audio.play().catch(function (err) {
            console.warn("[OO Mail Alert] audio blocked:", err);
        });
    }

    function findInbox(folders) {
        if (!Array.isArray(folders)) return null;
        let inboxId = 1;
        try {
            if (window.TMMail && TMMail.sysfolders && TMMail.sysfolders.inbox) {
                inboxId = TMMail.sysfolders.inbox.id;
            }
        } catch (_) {}
        return folders.find(function (folder) {
            return Number(folder.id) === Number(inboxId);
        }) || null;
    }

    function processFolders(folders) {
        const inbox = findInbox(folders);
        if (!inbox) return;

        const unread = Number(inbox.unread_messages !== undefined ? inbox.unread_messages : inbox.unread);
        if (!Number.isFinite(unread)) return;

        if (previousUnread === null) {
            previousUnread = unread;
            log("baseline unread:", unread);
            return;
        }

        if (unread > previousUnread) {
            const april = aprilFoolsSound();
            const url = april ? soundUrl(april) : normalSoundUrl();
            log("new mail:", unread - previousUnread, "unread:", previousUnread, "->", unread, "sound:", url);
            playUrl(url);
        }
        previousUnread = unread;
    }

    function hookMailFolders() {
        if (hooked) return;
        if (!window.Teamlab || typeof window.Teamlab.getMailFolders !== "function") {
            setTimeout(hookMailFolders, 250);
            return;
        }

        const original = window.Teamlab.getMailFolders;
        window.Teamlab.getMailFolders = function (params, options) {
            options = options || {};
            const originalSuccess = options.success;
            const wrappedOptions = Object.assign({}, options, {
                success: function () {
                    try { processFolders(arguments[1]); }
                    catch (err) { console.error("[OO Mail Alert]", err); }
                    if (typeof originalSuccess === "function") {
                        return originalSuccess.apply(this, arguments);
                    }
                }
            });
            return original.call(this, params, wrappedOptions);
        };

        hooked = true;
        log("loaded v" + VERSION);
        log("selected sound:", normalSoundUrl());
    }

    window.OOMailBong = {
        setSound: function (number) {
            number = Number(number);
            if (!Number.isInteger(number) || number < 1 || number > 6) {
                throw new Error("Sound must be between 1 and 6");
            }
            localStorage.removeItem(CUSTOM_SOUND_KEY);
            localStorage.setItem(SOUND_KEY, String(number));
            log("sound set to", number);
        },
        getSound: function () { return normalSoundUrl(); },
        setCustomSound: function (url) {
            if (typeof url !== "string" || !url.trim()) throw new Error("Custom sound URL is required");
            localStorage.setItem(CUSTOM_SOUND_KEY, url.trim());
            log("custom sound set to", url.trim());
        },
        clearCustomSound: function () {
            localStorage.removeItem(CUSTOM_SOUND_KEY);
            log("custom sound cleared; selected sound:", normalSoundUrl());
        },
        test: function () { playUrl(normalSoundUrl()); }
    };

    hookMailFolders();
})();
