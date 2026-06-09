# Claude Session Usage — KDE Plasma 6 widget

A horizontal-panel plasmoid that shows how much of your current **Claude Code
usage window** you've used, as a single configurable bar.

- Shows the **real** per-plan utilisation for either the 5-hour session window
  or the rolling 7-day window — no guessing, no calibration.
- Width and colour are adjustable.
- Optional warning/critical recolouring as the bar fills.
- Reads usage via a small bundled **Rust binary** that wraps the
  [`claude-usage`](https://docs.rs/claude-usage) crate. It authenticates with
  your existing Claude Code OAuth token and asks Anthropic for the same numbers
  Claude Code's own `/usage` shows.
- Targets **Plasma 6 only** (versionless QML imports, `X-Plasma-API-Minimum-Version 6.0`).

> Verified target here: Plasma **6.6.5**, Rust **1.96**.

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
variable) and makes one HTTPS request per refresh. It never writes to
`~/.claude` and needs no Admin/API key — just the token Claude Code already
created when you logged in.

---

## Project layout

```
plasma-claude-usage/
├── install.sh                 # cargo build + kpackagetool6 install/upgrade
├── uninstall.sh               # kpackagetool6 remove (clean)
├── README.md
├── collector/                 # Rust collector (built at install time)
│   ├── Cargo.toml
│   └── src/main.rs            # get_usage() → one JSON line on stdout
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
                     claude-usage crate ─▶ Anthropic usage endpoint
                            │
                            ▼
                     {"active":true,"utilization":42.0,"fraction":0.42,
                      "minutes_remaining":…, "resets_at":…}   (one JSON line)
                            │
                     main.qml parses it ─▶ bar width = fraction ─▶ width/colour
```

---

## Status

**Complete and runnable:**
- [x] Plasmoid package skeleton (metadata, config, ui).
- [x] Bundled Rust collector using the `claude-usage` crate — real 5-hour and
      7-day utilisation, with reset timing.
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

## Build / install

Needs the **Rust toolchain** (https://rustup.rs); `install.sh` runs
`cargo build --release` and bundles the binary into the package.

```bash
cd ~/Projects/plasma-claude-usage
./install.sh
```

Then right-click the panel → **Add Widgets** → search **“Claude Session Usage”**
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

## Cleanup (it's meant to be easy)

```bash
cd ~/Projects/plasma-claude-usage
./uninstall.sh          # removes ~/.local/share/plasma/plasmoids/org.marko.claudeusage/
cd .. && rm -rf plasma-claude-usage   # delete the source too
```

That's everything. The widget writes no other files: its settings live in
`~/.config/plasma-org.kde.plasma.desktop-appletsrc` and disappear when you
remove the widget from the panel. It only ever reads your Claude credentials —
it never modifies anything under `~/.claude`.
