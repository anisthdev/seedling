pragma Singleton

import Quickshell
import QtQuick

// Turns a torrent from the daemon into what a row shows. Sizes and speeds
// are bytes; seconds for times.
Singleton {
    // Daemon status codes
    readonly property int stopped: 0
    readonly property int queuedToVerify: 1
    readonly property int verifying: 2
    readonly property int queuedToDownload: 3
    readonly property int downloading: 4
    readonly property int queuedToSeed: 5
    readonly property int seeding: 6

    function size(bytes) {
        const units = ["B", "KB", "MB", "GB", "TB"];
        let value = bytes, unit = 0;
        while (value >= 1000 && unit < units.length - 1) {
            value /= 1000;
            unit++;
        }
        return unit === 0 ? `${value} B` : `${value.toFixed(value < 10 ? 1 : 0)} ${units[unit]}`;
    }

    function speed(bytes) {
        return `${size(bytes)}/s`;
    }

    function eta(seconds) {
        if (seconds < 0)
            return "";
        if (seconds < 60)
            return "less than a minute left";
        const minutes = Math.ceil(seconds / 60);
        if (minutes < 60)
            return `${minutes} min left`;
        const hours = Math.floor(minutes / 60);
        if (hours >= 24)
            return `${Math.floor(hours / 24)} d left`;
        return minutes % 60 ? `${hours} h ${minutes % 60} min left` : `${hours} h left`;
    }

    // -2 is the daemon's "infinite", -1 "not applicable"
    function ratio(value) {
        if (value === -2)
            return "∞";
        return value < 0 ? "–" : value.toFixed(2);
    }

    function status(t) {
        return ["Paused", "Queued to verify", "Verifying", "Queued", "Downloading", "Queued to seed", "Seeding"][t.status] ?? "Unknown";
    }

    // Tracker warnings (1) are common and harmless; 2 and 3 are errors
    function hasError(t) {
        return t.error >= 2 && t.errorString !== "";
    }

    function complete(t) {
        return t.percentDone >= 1;
    }

    // The seed ratio the torrent stops at, or -1 for none
    function ratioTarget(t) {
        switch (t.seedRatioMode) {
        case 0:
            return Transmission.globalRatioLimit;
        case 1:
            return t.seedRatioLimit > 0 ? t.seedRatioLimit : -1;
        }
        return -1;
    }

    // Seeding toward the ratio target, rather than downloading or checking
    function uploadPhase(t) {
        return complete(t) && t.status !== queuedToVerify && t.status !== verifying;
    }

    function progress(t) {
        if (t.status === verifying)
            return t.recheckProgress;
        if (!uploadPhase(t))
            return t.percentDone;
        const target = ratioTarget(t);
        if (t.uploadRatio === -2 || target <= 0)
            return 1;
        return Math.max(0, Math.min(1, t.uploadRatio / target));
    }

    // download, upload, paused or error: see TorrentRow's colours
    function kind(t) {
        if (hasError(t))
            return "error";
        if (t.status === stopped)
            return "paused";
        return uploadPhase(t) ? "upload" : "download";
    }

    // A progress bar's colours, by kind
    function barColor(kind) {
        return ({
                download: Theme.primary,
                upload: Theme.tertiary,
                paused: Theme.outline,
                error: Theme.error
            })[kind];
    }

    function trackColor(kind) {
        return ({
                download: Theme.primary_container,
                upload: Theme.tertiary_container,
                paused: Theme.surface_container_highest,
                error: Qt.alpha(Theme.error, 0.24)
            })[kind];
    }

    // What it's doing: "Downloading · 1.2 GB of 4.0 GB · ↓ 1.2 MB/s · 2 min left"
    function statusText(t) {
        if (hasError(t))
            return t.errorString;
        const parts = [status(t)];
        if (t.status === verifying)
            parts.push(`${Math.floor(t.recheckProgress * 100)}%`);
        if (complete(t))
            parts.push(`${size(t.uploadedEver)} uploaded`);
        else
            parts.push(`${size(t.sizeWhenDone - t.leftUntilDone)} of ${size(t.sizeWhenDone)}`);
        if (t.rateDownload > 0)
            parts.push(`↓ ${speed(t.rateDownload)}`);
        if (t.rateUpload > 0)
            parts.push(`↑ ${speed(t.rateUpload)}`);
        if (t.status === downloading && eta(t.eta))
            parts.push(eta(t.eta));
        return parts.join(" · ");
    }

    function ratioText(t) {
        const target = ratioTarget(t);
        return target > 0 ? `Ratio ${ratio(t.uploadRatio)} / ${ratio(target)}` : `Ratio ${ratio(t.uploadRatio)}`;
    }

    // Swarm size from the trackers, -1 when none has said. Trackers mostly
    // see the same peers, so take the largest count rather than a sum.
    function seeders(t) {
        return Math.max(-1, ...(t.trackerStats ?? []).map(s => s.seederCount));
    }

    function leechers(t) {
        return Math.max(-1, ...(t.trackerStats ?? []).map(s => s.leecherCount));
    }

    // A date from the daemon (seconds since 1970), or "–" for none
    function date(seconds) {
        return seconds > 0 ? Qt.formatDateTime(new Date(seconds * 1000), "d MMM yyyy, HH:mm") : "–";
    }

    // A long span, to the two largest units: "3 d 4 h", "12 min"
    function duration(seconds) {
        if (seconds < 60)
            return seconds > 0 ? "less than a minute" : "–";
        const units = [[86400, "d"], [3600, "h"], [60, "min"]];
        const parts = [];
        let left = seconds;
        for (const [length, name] of units) {
            if (left >= length || parts.length > 0) {
                parts.push(`${Math.floor(left / length)} ${name}`);
                left %= length;
            }
            if (parts.length === 2)
                break;
        }
        return parts.filter(p => !p.startsWith("0 ")).join(" ");
    }

    function percent(fraction) {
        return `${Math.floor(fraction * 1000) / 10}%`;
    }

    // What seedRatioMode means for this torrent: "3.00 (default)", "2.50",
    // "no limit"
    function ratioLimitText(t) {
        switch (t.seedRatioMode) {
        case 0:
            return Transmission.globalRatioLimit > 0 ? `${ratio(Transmission.globalRatioLimit)} (default)` : "no limit (default)";
        case 1:
            return ratio(t.seedRatioLimit);
        }
        return "no limit";
    }

    // A file's priority level (see Transmission.fileLevel)
    function priority(level) {
        return ({
                "-2": "Skip",
                "-1": "Low",
                "0": "Normal",
                "1": "High"
            })[level] ?? "";
    }
}
