//! Report current Claude Code usage as a single JSON line.
//!
//! Reads the Claude Code OAuth token (`~/.claude/.credentials.json`, or the
//! `CLAUDE_CODE_OAUTH_TOKEN` env var) and asks Anthropic for the *real* 5-hour
//! and 7-day usage windows (see the `usage` module). Unlike the previous
//! local-log estimator, the percentages here are the actual per-plan
//! utilisation, so the widget no longer needs a guessed token limit.
//!
//! Usage: claude-usage-collector [session|weekly]   (defaults to session)
//!
//! The endpoint rate-limits aggressively, so each successful reading is cached
//! to disk. On any failure (rate limit, network) we serve that last good reading
//! instead of a blank, aged forward and flagged `"stale": true`, so the widget
//! keeps showing a number. It never exits non-zero: failures are reported in the
//! JSON `error` field.

mod usage;

use serde_json::json;
use usage::{get_usage, UsagePeriod};
use std::fs;
use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};

/// Hours covered by each window, used to derive elapsed time.
const SESSION_HOURS: u32 = 5;
const WEEK_HOURS: u32 = 7 * 24;

fn now_epoch() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}

fn period_json(p: &UsagePeriod, period_hours: u32) -> serde_json::Value {
    // resets_at present => there is a live window to report.
    let active = p.resets_at.is_some();
    let minutes_remaining = p
        .time_until_reset()
        .map(|d| d.num_minutes().max(0))
        .unwrap_or(0);
    let total_minutes = i64::from(period_hours) * 60;
    let minutes_elapsed = (total_minutes - minutes_remaining).clamp(0, total_minutes);

    json!({
        "active": active,
        "utilization": p.utilization,
        "fraction": (p.utilization / 100.0).clamp(0.0, 1.0),
        "resets_at": p.resets_at.map(|t| t.to_rfc3339()),
        "minutes_remaining": minutes_remaining,
        "minutes_elapsed": minutes_elapsed,
        "on_pace": p.is_on_pace(period_hours),
    })
}

fn cache_path(window: &str) -> Option<PathBuf> {
    let base = std::env::var_os("XDG_CACHE_HOME")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|h| PathBuf::from(h).join(".cache")))?;
    let dir = base.join("claude-usage-collector");
    fs::create_dir_all(&dir).ok()?;
    Some(dir.join(format!("{window}.json")))
}

fn write_cache(window: &str, value: &serde_json::Value) {
    if let Some(path) = cache_path(window)
        && let Ok(s) = serde_json::to_string(value)
    {
        let _ = fs::write(path, s);
    }
}

/// On failure, serve the last good reading (if any), aged forward so the
/// countdown keeps ticking, and flagged stale with the error attached.
fn stale_from_cache(window: &str, period_hours: u32, err: &str) -> Option<serde_json::Value> {
    let raw = fs::read_to_string(cache_path(window)?).ok()?;
    let mut value: serde_json::Value = serde_json::from_str(&raw).ok()?;
    let obj = value.as_object_mut()?;

    let cached_at = obj.get("cached_at").and_then(|x| x.as_i64()).unwrap_or_else(now_epoch);
    let delta_min = (now_epoch() - cached_at).max(0) / 60;
    let total = i64::from(period_hours) * 60;
    let old_rem = obj.get("minutes_remaining").and_then(|x| x.as_i64()).unwrap_or(0);
    let old_el = obj.get("minutes_elapsed").and_then(|x| x.as_i64()).unwrap_or(0);

    obj.insert("minutes_remaining".into(), json!((old_rem - delta_min).clamp(0, total)));
    obj.insert("minutes_elapsed".into(), json!((old_el + delta_min).clamp(0, total)));
    obj.insert("stale".into(), json!(true));
    obj.insert("error".into(), json!(err));
    Some(value)
}

fn run(window: &str) -> serde_json::Value {
    let hours = if window == "weekly" { WEEK_HOURS } else { SESSION_HOURS };

    match get_usage() {
        Ok(usage) => {
            let period = if window == "weekly" { &usage.seven_day } else { &usage.five_hour };
            let mut out = period_json(period, hours);
            let obj = out.as_object_mut().expect("period_json returns an object");
            obj.insert("window".into(), json!(window));
            obj.insert("error".into(), serde_json::Value::Null);
            obj.insert("stale".into(), json!(false));
            obj.insert("cached_at".into(), json!(now_epoch()));
            obj.insert(
                "seven_day_sonnet".into(),
                usage
                    .seven_day_sonnet
                    .as_ref()
                    .map(|p| json!(p.utilization))
                    .unwrap_or(serde_json::Value::Null),
            );
            write_cache(window, &out);
            out
        }
        Err(e) => {
            let err = e.to_string();
            // Fall back to the last good reading; only blank if we never had one.
            stale_from_cache(window, hours, &err).unwrap_or_else(|| {
                json!({
                    "window": window,
                    "active": false,
                    "fraction": 0.0,
                    "utilization": 0.0,
                    "stale": false,
                    "error": err,
                })
            })
        }
    }
}

fn main() {
    let window = match std::env::args().nth(1).as_deref() {
        Some("weekly") => "weekly",
        _ => "session",
    };
    println!("{}", run(window));
}
