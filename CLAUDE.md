# Seedling

A keyboard-driven client for `transmission-daemon` that looks and feels like the user's Quickshell menus (`~/Projects/quickbar`), with tremc's key bindings. Primary target: Arch Linux + Hyprland.

App ID: `io.github.anisthdev.Seedling` (set with `//@ pragma AppId` in `shell.qml`).

History: this started as a GTK 4 / libadwaita app in Rust, now in `~/Projects/seedling-gtk`. It moved to Quickshell so it can share the shell's look and motion (QML components, matugen colours) instead of imitating them in GTK. That project's `trpc` crate and its notes on the RPC are still a good reference.

## How it runs

Seedling is a Quickshell config that opens one normal app window (`FloatingWindow`), not a bar or panel:

```
qs -p ~/Projects/seedling
```

No build step. Quickshell reloads the running app when a file changes; restart it if a change doesn't show. Logs go to stdout and `/run/user/1000/quickshell/by-id/*/log.qslog`.

Seedling is only a **client**: all BitTorrent work is done by `transmission-daemon` over its RPC. The daemon is always local (`localhost:9091`); no remote-connection UI.

## Layout

```
shell.qml           # entry: pragmas, ShellRoot { AppWindow {} }
AppWindow.qml       # the window; key dispatch (overlays first, then the current view)
Theme.qml           # singleton: matugen palette, fonts, radii, motion (copied from quickbar)
Transmission.qml    # singleton: RPC, polling, torrents/byId, commands
Format.qml          # singleton: what a torrent shows (sizes, status text, progress, colours)
components/         # generic widgets; Label, Icon, IconButton, LinearProgress, ListKeys copied from quickbar
views/              # app screens: TorrentList, TorrentRow, StatusPage
icons/              # Material Symbols SVGs (white), copied from quickbar/icons as needed
```

Copied quickbar files say so in their header (with the quickbar commit). They are ours now: change them freely, but keep them recognisably the same as the shell's so the two look alike. Don't import from `~/Projects/quickbar`.

## Keyboard (tremc)

Everything must be doable from the keyboard, with tremc's bindings (`/usr/bin/tremc`, `self.actions` near line 380, lists every action, its keys and where it applies). Mouse use works too but is secondary.

- Keys are handled in one place per view (`AppWindow.handleKey` → overlay or view). Match letters on `event.text` (so `p` and `P` differ), special keys on `event.key`.
- An open dialog or overlay takes every key until it closes. Dialogs answer tremc style: `y`/Enter yes, `n`/`q`/Esc no.
- `?`/F1 shows every key of the current view; keep `AppWindow.bindings` in sync when adding keys.
- No focus rings (user's choice): the keyboard's current row is shown by its fill (`secondary_container`, all corners rounded).

Implemented: list movement (`j k`, arrows, `gg G`, Home/End, Ctrl+f/b, PgUp/PgDn, Ctrl+d/u, Ctrl+n/p), `p` `P` `N` `v`/`y` `r`/Del `R`/Shift+Del, `?`/F1, `q`, Ctrl+w.

## Design

Look like the shell's menus; check its components (`components/ListItem.qml`, `LinearProgress.qml`, `Dropdown.qml`, `modules/DownloadsCard.qml`) before designing something new.

- Colours: `Theme` properties named after Material roles, loaded from `~/.config/waybar/colors.css` (matugen) like the shell. Never hard-code hues. Theme colours are see-through (`Theme.alpha`, 85%) like the shell's menus. The window is the card (like the launcher's panel): `surface_container` at 97%. The menus are 85% but open over (dark) windows; Seedling sits over the bright blurred wallpaper, which at 85% washes it out. 97% measured the same as the control panel over a terminal (screenshot pixel samples). A rule in `~/.config/hypr/windows.lua` for Seedling's class stops Hyprland dimming it further (`opacity = "1.0 override 1.0 override"`) and gives it the menus' round 16px corners. Cards over the window's own content (dialogs, help) use `Qt.alpha(colour, 1)`.
- Layout like the launcher menu (`quickbar/components/LauncherWindow.qml`): padding 20 sides, 26 top, 20 bottom; title 26px `Theme.titleWeight` in `primary`; grouped list 2px apart, radius 10 outside / 3 between, rows `surface_container_high` on a layer under a sliding `secondary_container` fill (220 ms); row text inset 18px, title 14px, detail 12px `on_surface_variant`.
- Progress: `LinearProgress` (M3: 4px, gap, stop dot; no wavy animation, by choice). Download `primary`, seeding `tertiary` (filling toward the seed ratio limit), paused `outline`, error `error`.
- Type: `Label` (Google Sans Flex with the shell's weight axis); titles 24px, `Font.Normal`, `roundness: Theme.titleRoundness`; row title 14px, detail 12px `on_surface_variant`.
- Motion: the shell's curves and durations (`Theme.emphasizedDecel`, `animFast`, `animNormal`).

## Transmission RPC notes

Reference: Transmission's `docs/rpc-spec.md`. Check it when unsure of a field name — don't guess.

- `POST http://127.0.0.1:9091/transmission/rpc`, body `{ "method", "arguments" }`; reply `result` is `"success"` or an error string.
- Session-id handshake: a 409 carries `X-Transmission-Session-Id`; store it and retry once. Qt's XMLHttpRequest hides error replies' headers, but the daemon repeats the id in the body (see `Transmission.rpc`).
- Commands take `ids`. **Never send an empty or missing `ids`** — the daemon applies it to every torrent. Likewise an empty `files-wanted`/`priority-*` list means "all files".
- The daemon applies stop/remove on its own ~1 s timer, after answering. `Transmission.assume` shows the expected state at once and polls sent within `settleTime` of a local change are dropped.
- `status`: 0 stopped, 1 queued to verify, 2 verifying, 3 queued to download, 4 downloading, 5 queued to seed, 6 seeding. `eta` and `uploadRatio` are negative when unknown (-2 = infinite ratio).
- `seedRatioMode`: 0 global (`session-get` `seedRatioLimit` if `seedRatioLimited`), 1 own `seedRatioLimit`, 2 unlimited.
- Files by index into `files`; `fileStats[i].priority` -1/0/1, `wanted` bool.

## Testing

No automated UI tests. Test against a real daemon:

- The user's own daemon only for **looking** (opening the app, moving the cursor). Never pause, verify, remove or change their torrents.
- Actions in a throwaway daemon in a private network namespace (`unshare -rn`), with small locally created torrents (`transmission-create`); there `localhost:9091` is the sandbox's daemon.
- Run the app visibly on the user's screen (they like to watch). Send keys only to Seedling's window: `hyprctl dispatch 'hl.dsp.send_shortcut({ mods = "", key = "j", window = "class:io.github.anisthdev.Seedling" })'`. `?` is `key = "slash"` with `SHIFT`. Popups need real focus; if you give Seedling focus with `hl.dsp.focus`, hand it back afterwards.

## Plan

1. **Torrent list** with tremc's list keys, pause/resume, start now, verify, remove (with confirm and delete-data), unreachable/empty states, key help. *(done)*
2. **Details view** (Enter/`l`/Right, back with `q`/Backspace/Esc): tabs by `o` overview, `f` files, Tab/Shift+Tab. Files: `j k`, `h`/`l` lower/raise priority (off < low < normal < high, where off = skip), Space select, `a` select all, `L` seed ratio limit.
3. **Find, filter, sort, select**: `/`, `f`, `s`, Space/`A`/`i` on the list, commands on selections.
4. **Add and move**: `a` add (magnet, `.torrent` file, download dir), `m` move data.
5. **Polish**: `.desktop` file and launcher, `magnet:`/`.torrent` handler, notifications, queue order (`J`/`K`), speed limits.

Later maybe: peers and trackers tabs (`e`, `t`), labels, profiles.

Current stage: **2**.
