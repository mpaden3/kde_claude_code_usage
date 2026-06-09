# Claude Session Usage — KDE Plasma 6 widget

A horizontal-panel plasmoid that shows how much of your current **Claude Code
5-hour session window** you've used, as a single configurable bar.

- Width and colour are adjustable.
- Optional warning/critical recolouring as the bar fills.
- Reads usage locally from `~/.claude/projects/**/*.jsonl` via a small bundled
  Python script — **no network, no external dependencies, no root.**
- Targets **Plasma 6 only** (versionless QML imports, `X-Plasma-API-Minimum-Version 6.0`).

> Verified target here: Plasma **6.6.5**, Python **3.14**.

---

## What the bar means

Claude usage resets on a rolling **5-hour window** ("session"). The bundled
script groups your recent assistant-message token usage into 5-hour blocks the
same way [`ccusage`](https://github.com/ryoppippi/ccusage) does, finds the block
that covers *now*, and reports its token totals. The widget draws
`tokens / limit` as a fraction.

Because Claude doesn't expose your real per-plan ceiling locally, **the "full
bar" token budget is a number you set** (Configure → *Full bar at*). See
[Calibrating the limit](#calibrating-the-limit).

**Billable vs all tokens:** by default the bar counts *billable* tokens
(`input + output + cache-creation`) and ignores `cache_read`, which otherwise
dominates and is mostly free. Switch to *All tokens* in config if you prefer the
raw `ccusage`-style total.

---

## Project layout

```
plasma-claude-usage/
├── install.sh                 # kpackagetool6 install/upgrade
├── uninstall.sh               # kpackagetool6 remove (clean)
├── README.md
└── package/
    ├── metadata.json          # plasmoid manifest (id: org.marko.claudeusage)
    └── contents/
        ├── code/
        │   └── claude_usage.py   # reads ~/.claude logs → one JSON line
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
                     runs:  python3 .../code/claude_usage.py
                            │
                            ▼
                     {"active":true,"total_tokens":…,"input_tokens":…,
                      "minutes_remaining":…, …}   (one JSON line on stdout)
                            │
                     main.qml parses it ─▶ fraction = tokens / limit ─▶ bar width/colour
```

---

## Implementation plan / status

**v0.1 (this scaffold — complete and runnable):**
- [x] Plasmoid package skeleton (metadata, config, ui).
- [x] Bundled dependency-free Python collector with 5-hour block logic,
      file-mtime prefiltering, and message de-duplication.
- [x] Bar rendering pinned to a configurable width, fills the panel height.
- [x] Configurable base colour + optional warn/critical thresholds.
- [x] Configurable token budget, metric (billable/all), label, refresh interval.
- [x] Tooltip with raw token count and minutes left in the window.
- [x] Click the bar to force an immediate refresh.
- [x] One-command install/uninstall.

**Possible v0.2+ (not built yet):**
- [ ] Cost (€/$) readout — needs a per-model price table; pricing drifts, so left out of v1.
- [ ] Weekly-limit secondary bar.
- [ ] Auto-calibrate the limit from observed session peaks.
- [ ] Vertical-panel layout (today it's tuned for horizontal panels).

---

## Build / install

```bash
cd ~/Projects/plasma-claude-usage
./install.sh
```

Then right-click the panel → **Add Widgets** → search **“Claude Session Usage”**
→ drag it onto a horizontal panel. Right-click the widget → **Configure** to set
width, colour, and the token budget.

If it doesn't appear right away, reload the shell once:

```bash
kquitapp6 plasmashell && (kstart plasmashell >/dev/null 2>&1 &)
```

---

## Development & testing

### 1. Test the collector alone (no Plasma needed)

Run it against your real data:

```bash
python3 package/contents/code/claude_usage.py
```

Or against **fake** data so you can see all the states without touching
`~/.claude` (the script honours `CLAUDE_CONFIG_DIR`):

```bash
TMP=$(mktemp -d)
mkdir -p "$TMP/projects/demo"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf '%s\n' \
  "{\"timestamp\":\"$NOW\",\"requestId\":\"r1\",\"message\":{\"id\":\"m1\",\"usage\":{\"input_tokens\":1000,\"output_tokens\":2000,\"cache_creation_input_tokens\":500,\"cache_read_input_tokens\":40000}}}" \
  > "$TMP/projects/demo/session.jsonl"
CLAUDE_CONFIG_DIR="$TMP" python3 package/contents/code/claude_usage.py
rm -rf "$TMP"
```

You should get a single JSON line with `"active": true` and the summed tokens.

### 2. Test the widget in isolation

After `./install.sh`, run it in a standalone window (no panel surgery):

```bash
plasmawindowed org.marko.claudeusage
```

> `plasmawindowed` ships with Plasma. For hot-reloading during UI work, install
> the Plasma SDK (`plasma-sdk`) and use `plasmoidviewer -a ./package` instead —
> it re-renders on file save.

### 3. Iterate on the live panel widget

`kpackagetool6 --upgrade` updates the installed files; the quickest way to see
QML changes is to re-run install then reload the shell:

```bash
./install.sh && kquitapp6 plasmashell && (kstart plasmashell >/dev/null 2>&1 &)
```

Watch for QML/script errors while developing:

```bash
journalctl --user -f -t plasmashell
```

### Calibrating the limit

The default *Full bar at* is **2,000,000 billable tokens**, which is just a
starting guess. To tune it: open a heavy work session, hover the widget to read
the live **raw token count** in the tooltip near the point where you actually
hit your Claude limit, then set *Full bar at* to that number.

---

## Cleanup (it's meant to be easy)

```bash
cd ~/Projects/plasma-claude-usage
./uninstall.sh          # removes ~/.local/share/plasma/plasmoids/org.marko.claudeusage/
cd .. && rm -rf plasma-claude-usage   # delete the source too
```

That's everything. The widget writes no other files: its settings live in
`~/.config/plasma-org.kde.plasma.desktop-appletsrc` and disappear when you
remove the widget from the panel. It never modifies anything under `~/.claude`
(read-only access).
