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

    // When the model last changed here rather than in the daemon. The
    // daemon applies some commands (stop, remove) on its own ~1 s timer,
    // so a poll sent shortly after may still show the old state.
    property double changedAt: 0
    readonly property int settleTime: 2000

    property int polls: 0
    // Daemon settings change rarely: fetched every this many polls
    readonly property int sessionEvery: 15

    // A command failed; the window shows it in a snackbar
    signal failed(string message)
    signal removed(string message)

    readonly property var fields: ["id", "name", "status", "error", "errorString", "percentDone", "recheckProgress", "rateDownload", "rateUpload", "eta", "uploadRatio", "sizeWhenDone", "leftUntilDone", "uploadedEver", "seedRatioMode", "seedRatioLimit", "trackerStats"]

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
        if (polls % sessionEvery === 0)
            rpc("session-get", {
                fields: ["seedRatioLimit", "seedRatioLimited"]
            }, args => globalRatioLimit = args.seedRatioLimited ? args.seedRatioLimit : -1);
        polls++;
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

    // Pause a running torrent, resume a paused one
    function toggle(t) {
        if (t.status === 0)
            start([t.id]);
        else
            stop([t.id]);
    }

    // As tremc's P: pause everything if anything runs, else resume all
    function toggleAll() {
        if (torrents.some(t => t.status !== 0))
            stop(torrents.filter(t => t.status !== 0).map(t => t.id));
        else
            start(torrents.map(t => t.id));
    }

    function remove(id, deleteData) {
        const t = byId[id];
        if (!t)
            return;
        rpc("torrent-remove", {
            ids: [id],
            "delete-local-data": deleteData
        }, () => {
            changedAt = Date.now();
            setTorrents(torrents.filter(other => other.id !== id));
            removed(deleteData ? `Removed “${t.name}” and deleted its files` : `Removed “${t.name}”`);
        }, message => failed(`Couldn’t remove “${t.name}”: ${message}`));
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
