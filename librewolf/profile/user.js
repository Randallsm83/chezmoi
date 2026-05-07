// LibreWolf user-overlay preferences
// LibreWolf already hardens many of these via librewolf.cfg.
// This file applies additional tweaks on top of those defaults.
// Lines starting with // are comments. Edit and remove as desired.

// === Network leak / fingerprinting hardening ===

// Disable WebGL (kills a fingerprinting vector; may break 3D web apps)
user_pref("webgl.disabled", true);

// Disable battery status API
user_pref("dom.battery.enabled", false);

// Disable geolocation
user_pref("geo.enabled", false);
user_pref("geo.provider.network.url", "");

// Disable speculative connections / prefetching (less data leakage)
user_pref("network.predictor.enabled", false);
user_pref("network.prefetch-next", false);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.dns.disablePrefetchFromHTTPS", true);
user_pref("network.http.speculative-parallel-limit", 0);

// Stricter Referer policy: send only when origins match, trim to origin
user_pref("network.http.referer.XOriginPolicy", 2);
user_pref("network.http.referer.XOriginTrimmingPolicy", 2);

// === Cookie & storage hygiene ===

// First-party isolation (already on via RFP, but reinforced)
user_pref("privacy.firstparty.isolate", true);

// Clear cookies and site data on shutdown (LibreWolf default; reaffirmed)
user_pref("privacy.sanitize.sanitizeOnShutdown", true);
user_pref("privacy.clearOnShutdown.cookies", true);
user_pref("privacy.clearOnShutdown.cache", true);
user_pref("privacy.clearOnShutdown.history", false);
user_pref("privacy.clearOnShutdown.formdata", true);
user_pref("privacy.clearOnShutdown.sessions", true);

// === Search & UX ===

// Use HTTPS-only mode in all windows (private + normal)
user_pref("dom.security.https_only_mode", true);
user_pref("dom.security.https_only_mode_pbm", true);

// Disable search suggestions in URL bar (reduces data sent to search engine)
// Comment out if you prefer suggestions
user_pref("browser.urlbar.suggest.searches", false);
user_pref("browser.search.suggest.enabled", false);

// === Misc privacy ===

// Disable sending of the Beacon API (used for tracking pings)
user_pref("beacon.enabled", false);

// Disable WebRTC peer connection (already covered by LibreWolf, reinforced)
user_pref("media.peerconnection.enabled", false);

// Disable autoplay of media (audio + video) by default
user_pref("media.autoplay.default", 5);
user_pref("media.autoplay.blocking_policy", 2);

// === Theming ===

// Enable userChrome.css / userContent.css loading from <profile>/chrome/
// Required for the Spaceduck UI theme deployed by chezmoi.
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
