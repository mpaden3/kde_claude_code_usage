# Claude Session Usage — KDE Plasma 6 widget

A horizontal-panel plasmoid that shows how much of your current **Claude Code
usage window** you've used, as a single configurable bar.

- Shows the **real** per-plan utilisation for either the 5-hour session window
  or the rolling 7-day window — no guessing, no calibration.
- Width and colour are adjustable.
- Optional warning/critical recolouring as the bar fills.
- Reads usage via a small bundled **Rust binary** that talks directly to
  Anthropic's OAuth usage endpoint — the same numbers Claude Code's own
  `/usage` shows. It uses the login token Claude Code already created; there is
  no third-party usage SDK and no Admin/API key involved.
- Targets **Plasma 6 only** (versionless QML imports, `X-Plasma-API-Minimum-Version 6.0`).

> Requires the Rust toolchain (edition 2024, so **Rust ≥ 1.85**). Tested on
> Plasma **6.6.5** with Rust **1.96**.

> **Unofficial.** This is a community-made widget and is not affiliated with,
> sponsored by, or endorsed by Anthropic.

---

## What the bar means

Claude usage resets on a rolling **5-hour window** ("session") and a separate
**7-day window**. The bundled collector calls Anthropic's usage endpoint and
reports the actual utilisation percentage for whichever window you pick, plus
when it resets. The widget draws that percentage directly — `utilization / 100`
as a fraction — so the "full bar" is your real per-plan ceiling, not a number you
have to tune.

Pick which window to show in *Configure → Show*. There is nothing else to
calibrate.

### Credentials & network

The collector reads your Claude Code OAuth token from
`~/.claude/.credentials.json` (or the `CLAUDE_CODE_OAUTH_TOKEN` environment
variable) and makes one HTTPS request per refresh to `api.anthropic.com`. The
token is read, used for that single request, and never logged or written
anywhere. The widget never modifies anything under `~/.claude` and needs no
Admin/API key — just the token Claude Code already created when you logged in.

---

## Requirements

- KDE **Plasma 6** (Plasma 5 is not supported).
- The **Rust toolchain** (https://rustup.rs), **Rust ≥ 1.85** — `install.sh`
  builds the collector with `cargo`.
- `kpackagetool6` (ships with Plasma 6).
- A working Claude Code login (so `~/.claude/.credentials.json` exists).

---

## Build / install

```bash
git clone https://github.com/mpaden3/kde_claude_code_usage.git
cd kde_claude_code_usage
./install.sh
```

`install.sh` runs `cargo build --release`, bundles the binary into the package,
and installs the plasmoid into `~/.local/share/plasma/plasmoids/` (no root, no
system files).

Then right-click the panel → **Add Widgets** → search **"Claude Session Usage"**
→ drag it onto a horizontal panel. Right-click the widget → **Configure** to set
width, colour, and which window to show.

> **After upgrading, restart the shell.** plasmashell caches plasmoid QML for the
> whole session, so re-installing (or even removing and re-adding the widget) is
> *not* enough to load new code — you must restart the shell once:
>
> ```bash
> kquitapp6 plasmashell && (kstart plasmashell >/dev/null 2>&1 &)
> ```

---

## Project layout

```
kde_claude_code_usage/
├── install.sh                 # cargo build + kpackagetool6 install/upgrade
├── uninstall.sh               # kpackagetool6 remove (clean)
├── README.md
├── LICENSE                    # MIT
├── collector/                 # Rust collector (built at install time)
│   ├── Cargo.toml
│   └── src/
│       ├── main.rs            # CLI + disk caching → one JSON line on stdout
│       └── usage.rs           # token read + Anthropic usage request (ureq/rustls)
└── package/
    ├── metadata.json          # plasmoid manifest (id: org.marko.claudeusage)
    └── contents/
        ├── code/
        │   └── claude-usage-collector   # the built binary (bundled by install.sh)
        ├── config/
        │   ├── config.qml        # registers the "General" config page
        │   └── main.xml          # config keys + defaults (cfg_* properties)
        └── ui/
            ├── main.qml          # the bar + executable data source + timer
            └── configGeneral.qml # the settings form
```

### How the pieces talk

```
Timer (every N s) ─▶ Plasma5Support "executable" engine
                     runs:  .../code/claude-usage-collector [session|weekly]
                            │
                            ▼
                     reads ~/.claude/.credentials.json (OAuth token)
                     ─▶ HTTPS GET api.anthropic.com/api/oauth/usage
                            │
                            ▼
                     {"active":true,"utilization":42.0,"fraction":0.42,
                      "minutes_remaining":…, "resets_at":…}   (one JSON line)
                            │
                     main.qml parses it ─▶ bar width = fraction ─▶ width/colour
```

The endpoint rate-limits, so each successful reading is cached to
`~/.cache/claude-usage-collector/`. On a failed refresh the collector serves the
last good reading (aged forward and flagged `stale`) instead of blanking the bar.

---

## Development & testing

### 1. Test the collector alone (no Plasma needed)

```bash
cargo run --manifest-path collector/Cargo.toml -- session   # or: weekly
```

You should get a single JSON line with `"active": true` and the live
`utilization` percentage. To test against a specific token without touching
`~/.claude`:

```bash
CLAUDE_CODE_OAUTH_TOKEN="sk-ant-oat0..." \
  cargo run --manifest-path collector/Cargo.toml -- session
```

### 2. Test the widget in isolation

After `./install.sh`, run it in a standalone window (no panel surgery):

```bash
plasmawindowed org.marko.claudeusage
```

> `plasmawindowed` ships with Plasma. For hot-reloading during UI work, install
> the Plasma SDK (`plasma-sdk`) and use `plasmoidviewer -a ./package` instead —
> it re-renders on file save and is not subject to plasmashell's QML cache.

### 3. Iterate on the live panel widget

```bash
./install.sh && kquitapp6 plasmashell && (kstart plasmashell >/dev/null 2>&1 &)
```

Watch for QML/script errors while developing:

```bash
journalctl --user -f -t plasmashell
```

---

## Status

**Complete and runnable:**
- [x] Plasmoid package skeleton (metadata, config, ui).
- [x] Bundled Rust collector (in-house, `ureq` + rustls) — real 5-hour and 7-day
      utilisation with reset timing, disk-cached against rate limits.
- [x] Bar rendering pinned to a configurable width, fills the panel height.
- [x] Configurable base colour + optional warn/critical thresholds.
- [x] Configurable window (session/weekly), label, refresh interval.
- [x] Tooltip with utilisation % and time until the window resets.
- [x] Click the bar to force an immediate refresh.
- [x] One-command build + install/uninstall.

**Possible later (not built yet):**
- [ ] Cost (€/$) readout — the usage endpoint reports utilisation, not spend.
- [ ] Show both windows at once (two bars).
- [ ] Vertical-panel layout (today it's tuned for horizontal panels).

---

## Uninstall

```bash
./uninstall.sh          # removes ~/.local/share/plasma/plasmoids/org.marko.claudeusage/
```

The widget writes no other files of its own: its settings live in
`~/.config/plasma-org.kde.plasma.desktop-appletsrc` and disappear when you remove
the widget from the panel; cached readings live in
`~/.cache/claude-usage-collector/`. It only ever reads your Claude credentials —
it never modifies anything under `~/.claude`.

---

## Contributing

Issues and pull requests are welcome. For UI changes, please test with
`plasmoidviewer -a ./package` and confirm the collector still emits valid JSON
(`cargo run --manifest-path collector/Cargo.toml -- session`). Please run
`cargo clippy` before opening a PR.

## License

[MIT](LICENSE) © Marko Pađen
