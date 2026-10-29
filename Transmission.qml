pragma Singleton

import Quickshell
import QtQuick

// transmission-daemon over its RPC (the classic API; see docs/rpc-spec.md
// in the transmission repository). Polls every 2 s and keeps `torrents` in
// the daemon's order, `byId` for rows keyed by id so they stay put across
// polls. The request code started out as quickbar's Transmission.qml.
Singleton {
    id: root

    readonly property string url: "http://127.0.0.1:9091/transmission/rpc"
    property string session

    property var torrents: []
    // id → torrent
    property var byId: ({})
    readonly property var ids: torrents.map(t => t.id)

    // null until the daemon first answers, then whether it does
    property var reachable: null
    // Why it doesn't, for the status page
    property string problem

    // The daemon's own seed ratio limit, or -1 when it has none on
    property real globalRatioLimit: -1
    // Where the daemon puts new torrents
    property string downloadDir

    // When the model last changed here rather than in the daemon. The
    // daemon applies some commands (stop, remove) on its own ~1 s timer,
    // so a poll sent shortly after may still show the old state.
    property double changedAt: 0
    readonly property int settleTime: 2000

    // Polling on; the menu turns it off while closed
    property bool active: true

    property int polls: 0
    // Daemon settings change rarely: fetched every this many polls
    readonly property int sessionEvery: 15

    // A command failed; the window shows it in a snackbar
    signal failed(string message)
    signal removed(string message)

    readonly property var fields: ["id", "name", "status", "error", "errorString", "percentDone", "recheckProgress", "rateDownload", "rateUpload", "eta", "uploadRatio", "sizeWhenDone", "leftUntilDone", "uploadedEver", "seedRatioMode", "seedRatioLimit", "trackerStats", "addedDate", "activityDate", "doneDate", "queuePosition", "downloadDir", "totalSize", "peersConnected", "peersGettingFromUs", "peersSendingToUs", "isPrivate"]

    // The torrent the details view shows (-1 for none), and everything
    // about it: the list's fields, these, its files and theirs
    property int detailsId: -1
    property var details: null
    readonly property var detailFields: fields.concat(["hashString", "haveValid", "downloadedEver", "corruptEver", "pieceCount", "pieceSize", "dateCreated", "secondsSeeding", "secondsDownloading", "comment", "creator", "files", "fileStats"])

    onDetailsIdChanged: {
        details = null;
        if (detailsId >= 0)
            refreshDetails();
    }

    // One request. `done` gets the reply's arguments, `fail` a message.
    function rpc(method, args, done, fail, retried) {
        const xhr = new XMLHttpRequest();
        xhr.open("POST", url);
        xhr.timeout = 10000;
        if (session)
            xhr.setRequestHeader("X-Transmission-Session-Id", session);
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            // The daemon hands out a session id on the first request, and
            // may change it later. Qt's XMLHttpRequest hides an error
            // reply's headers, but the daemon repeats the id in the page.
            if (xhr.status === 409 && !retried) {
                session = xhr.getResponseHeader("X-Transmission-Session-Id") || (xhr.responseText.match(/X-Transmission-Session-Id: (\w+)/)?.[1] ?? "");
                rpc(method, args, done, fail, true);
                return;
            }
            if (xhr.status !== 200) {
                fail?.(xhr.status === 0 ? "Connection refused" : xhr.status === 401 ? "The daemon wants a username and password" : `HTTP ${xhr.status}`);
                return;
            }
            let reply;
            try {
                reply = JSON.parse(xhr.responseText);
            } catch (e) {
                fail?.("Unreadable reply from the daemon");
                return;
            }
            if (reply.result === "success")
                done?.(reply.arguments ?? {});
            else
                fail?.(reply.result);
        };
        xhr.send(JSON.stringify({
            method: method,
            arguments: args
        }));
    }

    function refresh() {
        const sent = Date.now();
        rpc("torrent-get", {
            fields: fields
        }, args => {
            reachable = true;
            problem = "";
            // Possibly older than what the model now assumes
            if (sent >= changedAt + settleTime)
                setTorrents(args.torrents);
        }, message => {
            reachable = false;
            problem = message;
        });
        refreshDetails();
        if (polls % sessionEvery === 0)
            rpc("session-get", {
                fields: ["seedRatioLimit", "seedRatioLimited", "download-dir"]
            }, args => {
                globalRatioLimit = args.seedRatioLimited ? args.seedRatioLimit : -1;
                downloadDir = args["download-dir"];
            });
        polls++;
    }

    function refreshDetails() {
        if (detailsId < 0)
            return;
        const id = detailsId;
        const sent = Date.now();
        rpc("torrent-get", {
            ids: [id],
            fields: detailFields
        }, args => {
            if (id === detailsId && (!details || sent >= changedAt + settleTime))
                details = args.torrents[0] ?? null;
        });
    }

    function setTorrents(list) {
        const map = {};
        for (const t of list)
            map[t.id] = t;
        byId = map;
        torrents = list.slice().sort((a, b) => a.id - b.id);
    }

    // Shows the state a command leads to before the daemon reports it
    function assume(id, changes) {
        const t = byId[id];
        if (!t)
            return;
        const updated = Object.assign({}, t, changes);
        setTorrents(torrents.map(other => other.id === id ? updated : other));
        if (details?.id === id)
            details = Object.assign({}, details, changes);
        changedAt = Date.now();
    }

    // Commands that take only ids. An empty list is never sent: without
    // ids the daemon would apply the command to every torrent.
    function command(method, ids, failure, assumed) {
        if (ids.length === 0)
            return;
        rpc(method, {
            ids: ids
        }, null, message => failed(`${failure}: ${message}`));
        for (const id of ids)
            assume(id, assumed(byId[id]));
    }

    function start(ids) {
        command("torrent-start", ids, "Couldn’t resume", t => ({
                    status: t.percentDone >= 1 ? 5 : 3
                }));
    }

    function startNow(ids) {
        command("torrent-start-now", ids, "Couldn’t start", t => ({
                    status: t.percentDone >= 1 ? 5 : 3
                }));
    }

    function stop(ids) {
        command("torrent-stop", ids, "Couldn’t pause", () => ({
                    status: 0,
                    rateDownload: 0,
                    rateUpload: 0,
                    eta: -1
                }));
    }

    function verify(ids) {
        command("torrent-verify", ids, "Couldn’t verify", () => ({
                    status: 1
                }));
    }

    // As tremc's p: resume them if any is paused, else pause them all
    function toggle(list) {
        if (list.some(t => t.status === 0))
            start(list.filter(t => t.status === 0).map(t => t.id));
        else
            stop(list.map(t => t.id));
    }

    // As tremc's P, for the torrents shown: pause them if any runs, else
    // resume them all
    function toggleAll(list) {
        if (list.some(t => t.status !== 0))
            stop(list.filter(t => t.status !== 0).map(t => t.id));
        else
            start(list.map(t => t.id));
    }

    // Priority levels of a file: -2 skipped (not wanted), else the
    // daemon's -1 low, 0 normal, 1 high
    function fileLevel(stats) {
        return stats.wanted ? stats.priority : -2;
    }

    // Sets files of the details' torrent (indexes into `files`) to a level.
    // An empty list is never sent: it would mean every file.
    function setFileLevel(indexes, level) {
        const t = details;
        if (!t || indexes.length === 0)
            return;
        const args = {
            ids: [t.id]
        };
        if (level === -2)
            args["files-unwanted"] = indexes;
        else {
            args["files-wanted"] = indexes;
            args[["priority-low", "priority-normal", "priority-high"][level + 1]] = indexes;
        }
        rpc("torrent-set", args, null, message => failed(`Couldn’t change the files’ priority: ${message}`));
        const stats = t.fileStats.slice();
        for (const i of indexes)
            stats[i] = Object.assign({}, stats[i], level === -2 ? {
                wanted: false
            } : {
                wanted: true,
                priority: level
            });
        details = Object.assign({}, t, {
            fileStats: stats
        });
        changedAt = Date.now();
    }

    // As tremc's h and l: one step from the lowest of the files up, or from
    // the highest down, for all of them (skip < low < normal < high)
    function stepFiles(indexes, by) {
        if (!details || indexes.length === 0)
            return;
        const levels = indexes.map(i => fileLevel(details.fileStats[i]));
        const from = by > 0 ? Math.min(...levels) : Math.max(...levels);
        const to = Math.max(-2, Math.min(1, from + by));
        if (to !== from)
            setFileLevel(indexes, to);
    }

    // The seed ratio limit: a number >= 0 stops seeding there, "unlimited"
    // never stops, "default" follows the daemon's own limit
    function setSeedRatio(ids, limit) {
        if (ids.length === 0)
            return;
        const args = {
            ids: ids
        };
        let changes;
        if (limit === "default")
            changes = {
                seedRatioMode: 0
            };
        else if (limit === "unlimited")
            changes = {
                seedRatioMode: 2
            };
        else
            changes = {
                seedRatioMode: 1,
                seedRatioLimit: limit
            };
        Object.assign(args, changes);
        rpc("torrent-set", args, null, message => failed(`Couldn’t set the seed ratio limit: ${message}`));
        for (const id of ids)
            assume(id, changes);
    }

    // A magnet link, URL or .torrent file (a path the daemon can read: it
    // runs as the user); `done` gets the torrent and whether it was already
    // there
    function add(link, dir, paused, done) {
        const args = {
            filename: link,
            paused: paused
        };
        if (dir)
            args["download-dir"] = dir;
        rpc("torrent-add", args, reply => {
            const added = reply["torrent-added"];
            done?.(added ?? reply["torrent-duplicate"], !added);
            refresh();
        }, message => failed(`Couldn’t add the torrent: ${message === "unrecognized info" ? "it isn’t a torrent, or the file can’t be read" : message}`));
    }

    // Moves the torrents' data to `dir`, as tremc's m
    function move(ids, dir) {
        if (ids.length === 0)
            return;
        rpc("torrent-set-location", {
            ids: ids,
            location: dir,
            move: true
        }, () => refresh(), message => failed(`Couldn’t move: ${message}`));
        for (const id of ids)
            assume(id, {
                downloadDir: dir
            });
    }

    // Free space where `path` is, in bytes, to `done`
    function freeSpace(path, done) {
        rpc("free-space", {
            path: path
        }, args => done(args["size-bytes"]), () => done(-1));
    }

    // Never with no ids: the daemon would remove every torrent
    function remove(ids, deleteData) {
        const gone = ids.map(id => byId[id]).filter(t => t);
        if (gone.length === 0)
            return;
        const what = gone.length === 1 ? `“${gone[0].name}”` : `${gone.length} torrents`;
        rpc("torrent-remove", {
            ids: gone.map(t => t.id),
            "delete-local-data": deleteData
        }, () => {
            changedAt = Date.now();
            setTorrents(torrents.filter(other => !gone.includes(other)));
            removed(deleteData ? `Removed ${what} and deleted the files` : `Removed ${what}`);
        }, message => failed(`Couldn’t remove ${what}: ${message}`));
    }

    Timer {
        interval: 2000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
