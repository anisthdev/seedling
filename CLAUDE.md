# Seedling

A keyboard-driven client for `transmission-daemon` that looks and feels like the user's Quickshell menus (`~/Projects/quickbar`), with tremc's key bindings. Primary target: Arch Linux + Hyprland.

App ID: `io.github.anisthdev.Seedling` (set with `//@ pragma AppId` in `shell.qml`).

History: this started as a GTK 4 / libadwaita app in Rust, now in `~/Projects/seedling-gtk`. It moved to Quickshell so it can share the shell's look and motion (QML components, matugen colours) instead of imitating them in GTK. That project's `trpc` crate and its notes on the RPC are still a good reference.

## How it runs

Seedling is a Quickshell config, separate from quickbar, that shows itself as one of the shell's menus: like the movie search (`quickbar/modules/MediaSearch.qml`), a full-screen overlay `PanelWindow` with a panel at the bottom centre that springs open upwards and folds back down. It stays running while closed (not polling the daemon) and opens on starting.

```
./seedling            # open or close the menu, starting Seedling (opened) if it isn't running
./seedling show ID    # open it on that torrent's details (IPC `details`; qs keeps "show" for itself)
qs -p ~/Projects/seedling ipc call seedling toggle|open|close|details ID
```

SUPER+T (`~/.config/hypr/bindings/utilities.lua`) runs `./seedling`. The bar's downloads dropdown (quickbar's `DownloadHub`, `docs/downloads.md` there) shows unfinished torrents with Seedling's badge and opens `seedling show ID` on a click. `io.github.anisthdev.Seedling.desktop` (symlinked into `~/.local/share/applications`, icon `transmission`) gives that badge and the launcher entry. `q`/Esc on the list, Ctrl+w and a click outside close it.

It opens on starting, but a reload keeps the open/closed state it had (`PersistentProperties` in `Menu.qml`): an open menu takes the keyboard, so it must never pop up by itself.

No build step. Quickshell reloads the running app when a file changes; restart it if a change doesn't show (a failed load can leave it without keyboard focus). Logs go to stdout and `/run/user/1000/quickshell/by-id/*/log.qslog`.

Seedling is only a **client**: all BitTorrent work is done by `transmission-daemon` over its RPC. The daemon is always local (`localhost:9091`); no remote-connection UI.

## Layout

```
shell.qml           # entry: pragmas, ShellRoot { Menu {} }
Menu.qml            # the menu: layer surface, panel, open/close, IPC; key dispatch (overlays first, then the current view)
Theme.qml           # singleton: matugen palette, fonts, radii, motion (copied from quickbar)
Transmission.qml    # singleton: RPC, polling, torrents/byId, commands
Format.qml          # singleton: what a torrent shows (sizes, status text, progress, colours)
components/         # generic widgets (confirm, input, picker and add dialogs, path field, snackbar, key help); Label, Icon, IconButton, LinearProgress, ListKeys copied from quickbar
views/              # app screens: TorrentList/TorrentRow, DetailsView (Overview, FileList/FileRow), StatusPage
icons/              # Material Symbols SVGs (white), copied from quickbar/icons as needed
```

Copied quickbar files say so in their header (with the quickbar commit). They are ours now: change them freely, but keep them recognisably the same as the shell's so the two look alike. Don't import from `~/Projects/quickbar`.

## Keyboard (tremc)

Everything must be doable from the keyboard, with tremc's bindings (`/usr/bin/tremc`, `self.actions` near line 380, lists every action, its keys and where it applies). Mouse use works too but is secondary.

- Keys are handled in one place per view (`Menu.handleKey` → overlay or view). Match letters on `event.text` (so `p` and `P` differ), special keys on `event.key`.
- An open dialog or overlay takes every key until it closes. Dialogs answer tremc style: `y`/Enter yes, `n`/`q`/Esc no.
- `?`/F1 shows every key of the current view; keep `Menu.listBindings`/`detailsBindings` (and the shared `torrentBindings`) in sync when adding keys.
- No focus rings (user's choice): the keyboard's current row is shown by its fill (`secondary_container`, all corners rounded).

Implemented: list movement (`j k`, arrows, `gg G`, Home/End, Ctrl+f/b, PgUp/PgDn, Ctrl+d/u, Ctrl+n/p), `p` `P` `N` `v`/`y` `r`/Del `R`/Shift+Del `L`, `?`/F1, `q`, Ctrl+w. Find `/` (the launcher's field: narrows by name; Enter/Esc give the keys back, Down/Tab/Ctrl+j/n move), filter `f` and sort `s` (a `PickerDialog` with tremc's options and letters; the pick follows its torrent as the order changes), select Space (and move down) `A` `i`. `p` `N` `v` `L` `r` act on the selection (of what's shown) else the current torrent; `R` on the current one only, as tremc; `P` on all shown. Esc lets go of the selection, then the search, then closes. Add `a`/Ctrl+a (paused): `AddDialog`, link or `.torrent` path (clipboard link filled in, else `~/Downloads/`) and folder (the daemon's `download-dir` first, Up/Down through the folders in use, free space shown); the pick follows the new torrent. Move `m` (selection-aware, also in details): `InputDialog` with a `PathField`. Tab completes paths in both (`PathField`, listing with `sh`). Details (Enter/`l`/Right or double-click; back `q`/Esc/Backspace): `o` `f` Tab/Shift+Tab; overview (a summary, Space shows more details) scrolls with the list keys, `h`/`l` switch tabs; files: list movement, `h`/`l` priority (selection, else current; tremc's stepping from the lowest/highest), Space, `a`, Esc drops the selection; `p` `P` `N` `v` `L` `R` act on the open torrent.

## Design

Look like the shell's menus; check its components (`components/ListItem.qml`, `LinearProgress.qml`, `Dropdown.qml`, `modules/DownloadsCard.qml`) before designing something new.

- Colours: `Theme` properties named after Material roles, loaded from `~/.config/waybar/colors.css` (matugen) like the shell. Never hard-code hues. Theme colours are see-through (`Theme.alpha`, 85%) like the shell's menus. The panel is plain `Theme.surface_container`, radius `Theme.cardRadius`, exactly as the menus' panels. Its layer uses the menus' namespace `quickbar-overlay`, so Hyprland's layer rules (`looknfeel.lua`: blur, no layer slide) treat it as one of them; that's what makes it match. Cards over the panel's own content (dialogs, help) use `Qt.alpha(colour, 1)`; the panel grows to fit an open one (their `wanted`).
- Layout like the launcher menu (`quickbar/components/LauncherWindow.qml`): panel 820 wide (the grown movie search), 16px off the bottom, as tall as the page wants (views' `implicitHeight`, rows measured on a hidden probe row) up to most of the screen; padding 20 sides, 26 top, 20 bottom; title 26px `Theme.titleWeight` in `primary`; grouped list 2px apart, radius 10 outside / 3 between, rows `surface_container_high` on a layer under a sliding `secondary_container` fill (220 ms); row text inset 18px, title 14px, detail 12px `on_surface_variant`.
- Progress: `LinearProgress` (M3: 4px, gap, stop dot; no wavy animation, by choice). Download `primary`, seeding `tertiary` (filling toward the seed ratio limit), paused `outline`, error `error`.
- Type: `Label` (Google Sans Flex with the shell's weight axis); titles 24px, `Font.Normal`, `roundness: Theme.titleRoundness`; row title 14px, detail 12px `on_surface_variant`.
- Motion: the shell's curves and durations (`Theme.emphasizedDecel`, `animFast`, `animNormal`).

## Transmission RPC notes

Reference: Transmission's `docs/rpc-spec.md`. Check it when unsure of a field name — don't guess.

- `POST http://127.0.0.1:9091/transmission/rpc`, body `{ "method", "arguments" }`; reply `result` is `"success"` or an error string.
- `torrent-add` takes `filename` (a path the daemon reads — it runs as the user — a URL or a magnet link), `download-dir`, `paused`; the reply has `torrent-added` or `torrent-duplicate`. `torrent-set-location` with `move: true` moves the data. `free-space` `{ path }` answers `size-bytes`.
- Session-id handshake: a 409 carries `X-Transmission-Session-Id`; store it and retry once. Qt's XMLHttpRequest hides error replies' headers, but the daemon repeats the id in the body (see `Transmission.rpc`).
- Commands take `ids`. **Never send an empty or missing `ids`** — the daemon applies it to every torrent. Likewise an empty `files-wanted`/`priority-*` list means "all files".
- The daemon applies stop/remove on its own ~1 s timer, after answering. `Transmission.assume` shows the expected state at once and polls sent within `settleTime` of a local change are dropped.
- `status`: 0 stopped, 1 queued to verify, 2 verifying, 3 queued to download, 4 downloading, 5 queued to seed, 6 seeding. `eta` and `uploadRatio` are negative when unknown (-2 = infinite ratio).
- `seedRatioMode`: 0 global (`session-get` `seedRatioLimit` if `seedRatioLimited`), 1 own `seedRatioLimit`, 2 unlimited.
- Files by index into `files`; `fileStats[i].priority` -1/0/1, `wanted` bool.

## Testing

No automated UI tests. Test against a real daemon:

- The user's own daemon only for **looking** (opening the app, moving the cursor). Never pause, verify, remove or change their torrents.
- Actions in a throwaway daemon in a private network namespace, with small locally created torrents (`transmission-create`); there `localhost:9091` is the sandbox's daemon. What works: `unshare -rn sh -c 'ip link set lo up && exec unshare --map-user=1000 --map-group=1000 inner.sh'` (the nested map lets Qt reach the Wayland socket), where `inner.sh` starts `transmission-daemon -g <dir> -w <data>`, adds the torrents and `exec`s `qs -p`. Stop your own Seedling first (both would answer the same IPC). Check results with `nsenter -t <qs pid> -U -n --preserve-credentials transmission-remote 9091 …`. Clean up by pid: `pkill -f <pattern>` matches the shell running it.
- Run the app visibly on the user's screen (they like to watch). While open the menu takes the keyboard (exclusive focus), so send keys with `wtype` (`wtype j`, `wtype -k Return`, `wtype '?'`). Check first that it really is open (`hyprctl layers -j`: a `quickbar-overlay` layer whose pid is Seedling's `qs`), or the keys land in the user's terminal. Close it afterwards (`ipc call seedling close`) to give the keyboard back.

## Plan

1. **Torrent list** with tremc's list keys, pause/resume, start now, verify, remove (with confirm and delete-data), unreachable/empty states, key help. *(done)*
2. **Details view** (Enter/`l`/Right, back with `q`/Backspace/Esc): tabs by `o` overview, `f` files, Tab/Shift+Tab. Files: `j k`, `h`/`l` lower/raise priority (off < low < normal < high, where off = skip), Space select, `a` select all, `L` seed ratio limit. *(done)*
3. **Find, filter, sort, select**: `/`, `f`, `s`, Space/`A`/`i` on the list, commands on selections. *(done)*
4. **Add and move**: `a` add (magnet, `.torrent` file, download dir), `m` move data. *(done)*
5. **Polish**: `.desktop` file and launcher, `magnet:`/`.torrent` handler, notifications, queue order (`J`/`K`), speed limits.

Later maybe: peers and trackers tabs (`e`, `t`), labels, profiles.

Current stage: **5**.
