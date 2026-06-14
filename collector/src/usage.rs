//! In-house replacement for the `claude-usage` crate.
//!
//! Reads the Claude Code OAuth token (`~/.claude/.credentials.json`, or the
//! `CLAUDE_CODE_OAUTH_TOKEN` env var) and asks Anthropic for the *real* 5-hour
//! and 7-day usage windows. Only the slice the collector actually uses is kept:
//! credential lookup, one blocking GET, and the two timing helpers.
//!
//! Security: the token is read, used for a single request, and never logged or
//! interpolated into an error string.

use chrono::{DateTime, TimeDelta, Utc};
use serde::Deserialize;

/// Anthropic OAuth usage endpoint and the beta header it requires.
const USAGE_API_URL: &str = "https://api.anthropic.com/api/oauth/usage";
const BETA_HEADER: &str = "oauth-2025-04-20";

/// Path to the Claude Code credentials file, relative to `$HOME`.
const CREDENTIALS_PATH: &str = ".claude/.credentials.json";

/// Environment variable that overrides the credentials file when set.
const ENV_VAR_TOKEN: &str = "CLAUDE_CODE_OAUTH_TOKEN";

/// Overall request timeout; the endpoint rate-limits but should never hang.
const REQUEST_TIMEOUT_SECS: u64 = 10;

#[derive(Deserialize)]
pub struct UsageData {
    pub five_hour: UsagePeriod,
    pub seven_day: UsagePeriod,
    #[serde(default)]
    pub seven_day_sonnet: Option<UsagePeriod>,
}

#[derive(Deserialize)]
pub struct UsagePeriod {
    /// Percentage of quota used (0.0 – 100.0+; over 100 means quota exceeded).
    pub utilization: f64,
    /// When this window resets; `None` if the API doesn't report it.
    #[serde(default)]
    pub resets_at: Option<DateTime<Utc>>,
}

impl UsagePeriod {
    /// Time remaining until reset (negative if already past); `None` if unknown.
    pub fn time_until_reset(&self) -> Option<TimeDelta> {
        self.resets_at.map(|reset| reset - Utc::now())
    }

    /// `true` when utilisation is at or below the share of the window elapsed,
    /// i.e. usage is sustainable. `None` if the reset time is unknown.
    pub fn is_on_pace(&self, period_hours: u32) -> Option<bool> {
        self.time_until_reset().map(|remaining| {
            let total = f64::from(period_hours) * 3600.0;
            let elapsed_pct = ((total - remaining.num_seconds() as f64) / total * 100.0).clamp(0.0, 100.0);
            self.utilization <= elapsed_pct
        })
    }
}

/// Retrieve the OAuth access token: env var first, then the credentials file.
fn read_token() -> Result<String, String> {
    if let Ok(token) = std::env::var(ENV_VAR_TOKEN)
        && !token.is_empty()
    {
        return Ok(token);
    }

    let home = std::env::var("HOME").map_err(|_| "HOME not set".to_string())?;
    let path = std::path::Path::new(&home).join(CREDENTIALS_PATH);
    let raw = std::fs::read_to_string(&path)
        .map_err(|_| "credentials not found (run `claude` to log in)".to_string())?;

    let json: serde_json::Value =
        serde_json::from_str(&raw).map_err(|e| format!("failed to parse credentials: {e}"))?;
    let oauth = json
        .get("claudeAiOauth")
        .ok_or("missing claudeAiOauth in credentials")?;

    // expiresAt is milliseconds since epoch; a past value means a stale token.
    if let Some(expires_at_ms) = oauth.get("expiresAt").and_then(|v| v.as_i64())
        && Utc::now().timestamp_millis() > expires_at_ms
    {
        return Err("token expired (run `claude` to re-login)".into());
    }

    oauth
        .get("accessToken")
        .and_then(|v| v.as_str())
        .map(String::from)
        .ok_or_else(|| "missing accessToken in credentials".into())
}

/// Fetch current Claude Code usage. Error strings are kept generic so the token
/// can never leak through them.
pub fn get_usage() -> Result<UsageData, String> {
    let token = read_token()?;

    let body = ureq::get(USAGE_API_URL)
        .timeout(std::time::Duration::from_secs(REQUEST_TIMEOUT_SECS))
        .set("Authorization", &format!("Bearer {token}"))
        .set("anthropic-beta", BETA_HEADER)
        .call()
        .map_err(|e| match e {
            ureq::Error::Status(401, _) => "unauthorized (run `claude` to re-login)".to_string(),
            ureq::Error::Status(429, _) => "rate limited".to_string(),
            ureq::Error::Status(code, _) => format!("server returned HTTP {code}"),
            ureq::Error::Transport(_) => "failed to connect to Anthropic API".to_string(),
        })?
        .into_string()
        .map_err(|_| "failed to read response body".to_string())?;

    serde_json::from_str(&body).map_err(|e| format!("failed to parse API response: {e}"))
}
