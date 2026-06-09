#!/usr/bin/env python3
"""Report current Claude Code usage as a single JSON line.

No third-party dependencies. Scans ~/.claude/projects/**/*.jsonl and reports token
totals for either:

  * session  – the current ccusage-style 5-hour block that covers "now"
  * weekly   – a rolling 7-day window (sum of everything in the last 7 days)

Usage: claude_usage.py [session|weekly]   (defaults to session)

Designed to be invoked by the Plasma widget.
"""

import glob
import json
import os
import sys
from datetime import datetime, timedelta, timezone

SESSION_HOURS = 5
WEEK_HOURS = 7 * 24
# Margin on the lookback so we never miss the active block / week boundary because
# of clock skew or hour-floored block starts. Files older than this are skipped so
# we never re-read months of history on every tick.
MARGIN_HOURS = 1


def claude_dir():
    return os.environ.get("CLAUDE_CONFIG_DIR", os.path.expanduser("~/.claude"))


def parse_ts(value):
    if not isinstance(value, str) or not value:
        return None
    try:
        if value.endswith("Z"):
            value = value[:-1] + "+00:00"
        return datetime.fromisoformat(value).astimezone(timezone.utc)
    except ValueError:
        return None


def iter_entries(lookback_hours):
    """Yield (timestamp, usage_dict) for recent assistant messages, de-duplicated."""
    base = os.path.join(claude_dir(), "projects")
    if not os.path.isdir(base):
        return
    cutoff = datetime.now(timezone.utc) - timedelta(hours=lookback_hours)
    seen = set()
    for path in glob.glob(os.path.join(base, "**", "*.jsonl"), recursive=True):
        try:
            mtime = datetime.fromtimestamp(os.path.getmtime(path), timezone.utc)
        except OSError:
            continue
        if mtime < cutoff:
            continue
        try:
            with open(path, "r", encoding="utf-8") as handle:
                for line in handle:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        obj = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    message = obj.get("message")
                    if not isinstance(message, dict):
                        continue
                    usage = message.get("usage")
                    if not isinstance(usage, dict):
                        continue
                    ts = parse_ts(obj.get("timestamp"))
                    if ts is None or ts < cutoff:
                        continue
                    # Claude logs the same assistant turn in multiple files; de-dup
                    # on (message id, request id) when present.
                    key = (message.get("id"), obj.get("requestId"))
                    if key != (None, None):
                        if key in seen:
                            continue
                        seen.add(key)
                    yield ts, usage
        except OSError:
            continue


def build_blocks(entries):
    """Split time-sorted entries into 5-hour blocks (ccusage-style)."""
    blocks = []
    block_start = None
    block_usages = []
    last_ts = None
    for ts, usage in entries:
        floored = ts.replace(minute=0, second=0, microsecond=0)
        if block_start is None:
            block_start = floored
        elif (ts - block_start >= timedelta(hours=SESSION_HOURS)
              or ts - last_ts >= timedelta(hours=SESSION_HOURS)):
            blocks.append((block_start, block_usages))
            block_start = floored
            block_usages = []
        block_usages.append(usage)
        last_ts = ts
    if block_start is not None:
        blocks.append((block_start, block_usages))
    return blocks


def collect_session(now):
    """Return (active, usages, start, end) for the current 5-hour block."""
    entries = sorted(iter_entries(SESSION_HOURS + MARGIN_HOURS), key=lambda i: i[0])
    if not entries:
        return False, [], None, None
    start, usages = build_blocks(entries)[-1]
    end = start + timedelta(hours=SESSION_HOURS)
    return now < end, usages, start, end


def collect_weekly(now):
    """Return (active, usages, start, end) for a rolling 7-day window.

    Claude doesn't expose the real weekly reset locally, so we approximate with a
    rolling window: everything in the last 7 days counts, and `end` is when the
    oldest counted message rolls off (i.e. when the total first starts to drop).
    """
    entries = sorted(iter_entries(WEEK_HOURS + MARGIN_HOURS), key=lambda i: i[0])
    if not entries:
        return False, [], None, None
    start = entries[0][0]
    end = start + timedelta(hours=WEEK_HOURS)
    return True, [u for _, u in entries], start, end


def main():
    window = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] in ("session", "weekly") else "session"

    result = {
        "window": window,
        "active": False,
        "input_tokens": 0,
        "output_tokens": 0,
        "cache_creation_tokens": 0,
        "cache_read_tokens": 0,
        "total_tokens": 0,
        "block_start": None,
        "block_end": None,
        "minutes_remaining": 0,
        "minutes_elapsed": 0,
        "error": None,
    }

    now = datetime.now(timezone.utc)
    if window == "weekly":
        active, usages, start, end = collect_weekly(now)
    else:
        active, usages, start, end = collect_session(now)

    if not usages:
        print(json.dumps(result))
        return

    def total(field):
        return sum(int(u.get(field) or 0) for u in usages)

    inp = total("input_tokens")
    out = total("output_tokens")
    cache_create = total("cache_creation_input_tokens")
    cache_read = total("cache_read_input_tokens")

    result.update({
        "active": active,
        "input_tokens": inp,
        "output_tokens": out,
        "cache_creation_tokens": cache_create,
        "cache_read_tokens": cache_read,
        "total_tokens": inp + out + cache_create + cache_read,
        "block_start": start.isoformat(),
        "block_end": end.isoformat(),
        "minutes_remaining": max(0, int((end - now).total_seconds() // 60)) if active else 0,
        "minutes_elapsed": max(0, int((now - start).total_seconds() // 60)),
    })
    print(json.dumps(result))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # never crash the widget; report the error instead
        print(json.dumps({"error": str(exc), "active": False, "total_tokens": 0}))
        sys.exit(0)
