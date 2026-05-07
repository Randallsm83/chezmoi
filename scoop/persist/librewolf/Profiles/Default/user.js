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

// ============================================================================
// Recovered from active prefs.js on 2026-05-06
// These are user_pref() entries that survived the noise filter (build IDs,
// telemetry timestamps, region updates, sessionstore versions, etc.). Some may
// match LibreWolf defaults already; review and prune as you have time. The
// browser will keep applying everything below on every startup until removed.
// ============================================================================
user_pref("beacon.enabled", false);
user_pref("browser.contentblocking.category", "strict");
user_pref("browser.ctrlTab.sortByRecentlyUsed", true);
user_pref("browser.dom.window.dump.enabled", false);
user_pref("browser.launcherProcess.enabled", true);
user_pref("browser.newtabpage.activity-stream.showSponsoredCheckboxes", false);
user_pref("browser.safebrowsing.downloads.remote.block_potentially_unwanted", false);
user_pref("browser.safebrowsing.downloads.remote.block_uncommon", false);
user_pref("browser.safebrowsing.downloads.remote.enabled", false);
user_pref("browser.safebrowsing.downloads.remote.url", "");
user_pref("browser.startup.page", 3);
user_pref("browser.theme.toolbar-theme", 0);
user_pref("browser.toolbars.bookmarks.visibility", "never");
user_pref("browser.uiCustomization.horizontalTabsBackup", "{\"placements\":{\"widget-overflow-fixed-list\":[],\"unified-extensions-area\":[\"_testpilot-containers-browser-action\",\"sponsorblocker_ajay_app-browser-action\",\"ublock0_raymondhill_net-browser-action\",\"addon_darkreader_org-browser-action\",\"_74145f27-f039-47ce-a470-a662b129930a_-browser-action\",\"_446900e4-71c2-419f-a6a7-df9c091e268b_-browser-action\",\"_b86e4813-687a-43e6-ab65-0bde4ab75758_-browser-action\"],\"nav-bar\":[\"sidebar-button\",\"home-button\",\"back-button\",\"forward-button\",\"stop-reload-button\",\"customizableui-special-spring15\",\"zoom-controls\",\"vertical-spacer\",\"urlbar-container\",\"customizableui-special-spring2\",\"new-window-button\",\"privatebrowsing-button\",\"share-tab-button\",\"downloads-button\",\"fxa-toolbar-menu-button\",\"panic-button\",\"developer-button\",\"preferences-button\",\"unified-extensions-button\"],\"toolbar-menubar\":[\"menubar-items\"],\"TabsToolbar\":[\"tabbrowser-tabs\",\"new-tab-button\",\"alltabs-button\"],\"vertical-tabs\":[],\"PersonalToolbar\":[\"personal-bookmarks\"]},\"seen\":[\"developer-button\",\"ublock0_raymondhill_net-browser-action\",\"screenshot-button\",\"_testpilot-containers-browser-action\",\"addon_darkreader_org-browser-action\",\"sponsorblocker_ajay_app-browser-action\",\"_74145f27-f039-47ce-a470-a662b129930a_-browser-action\",\"_446900e4-71c2-419f-a6a7-df9c091e268b_-browser-action\",\"_b86e4813-687a-43e6-ab65-0bde4ab75758_-browser-action\"],\"dirtyAreaCache\":[\"nav-bar\",\"vertical-tabs\",\"widget-overflow-fixed-list\",\"unified-extensions-area\",\"toolbar-menubar\",\"TabsToolbar\",\"PersonalToolbar\"],\"currentVersion\":23,\"newElementCount\":17}");
user_pref("browser.uiCustomization.horizontalTabstrip", "[\"tabbrowser-tabs\",\"new-tab-button\"]");
user_pref("browser.uiCustomization.navBarWhenVerticalTabs", "[\"sidebar-button\",\"home-button\",\"back-button\",\"forward-button\",\"stop-reload-button\",\"customizableui-special-spring15\",\"zoom-controls\",\"vertical-spacer\",\"urlbar-container\",\"customizableui-special-spring2\",\"new-window-button\",\"privatebrowsing-button\",\"share-tab-button\",\"downloads-button\",\"fxa-toolbar-menu-button\",\"panic-button\",\"developer-button\",\"preferences-button\",\"unified-extensions-button\"]");
user_pref("browser.uiCustomization.state", "{\"placements\":{\"widget-overflow-fixed-list\":[],\"unified-extensions-area\":[\"_testpilot-containers-browser-action\",\"sponsorblocker_ajay_app-browser-action\",\"ublock0_raymondhill_net-browser-action\",\"addon_darkreader_org-browser-action\",\"_74145f27-f039-47ce-a470-a662b129930a_-browser-action\",\"_446900e4-71c2-419f-a6a7-df9c091e268b_-browser-action\",\"_b86e4813-687a-43e6-ab65-0bde4ab75758_-browser-action\"],\"nav-bar\":[\"sidebar-button\",\"home-button\",\"back-button\",\"forward-button\",\"stop-reload-button\",\"customizableui-special-spring15\",\"zoom-controls\",\"vertical-spacer\",\"urlbar-container\",\"customizableui-special-spring2\",\"new-window-button\",\"privatebrowsing-button\",\"share-tab-button\",\"downloads-button\",\"fxa-toolbar-menu-button\",\"panic-button\",\"developer-button\",\"preferences-button\",\"unified-extensions-button\"],\"toolbar-menubar\":[\"menubar-items\"],\"TabsToolbar\":[],\"vertical-tabs\":[\"tabbrowser-tabs\"],\"PersonalToolbar\":[\"personal-bookmarks\"]},\"seen\":[\"developer-button\",\"ublock0_raymondhill_net-browser-action\",\"screenshot-button\",\"_testpilot-containers-browser-action\",\"addon_darkreader_org-browser-action\",\"sponsorblocker_ajay_app-browser-action\",\"_74145f27-f039-47ce-a470-a662b129930a_-browser-action\",\"_446900e4-71c2-419f-a6a7-df9c091e268b_-browser-action\",\"_b86e4813-687a-43e6-ab65-0bde4ab75758_-browser-action\"],\"dirtyAreaCache\":[\"nav-bar\",\"vertical-tabs\",\"widget-overflow-fixed-list\",\"unified-extensions-area\",\"toolbar-menubar\",\"TabsToolbar\",\"PersonalToolbar\"],\"currentVersion\":23,\"newElementCount\":18}");
user_pref("captivedetect.canonicalURL", "");
user_pref("devtools.console.stdout.chrome", false);
user_pref("devtools.debugger.remote-enabled", false);
user_pref("dom.battery.enabled", false);
user_pref("dom.forms.autocomplete.formautofill", true);
user_pref("dom.push.userAgentID", "59e49e2efd3344a6a113a0248f0996d7");
user_pref("dom.security.https_only_mode_ever_enabled", true);
user_pref("dom.security.https_only_mode_ever_enabled_pbm", true);
user_pref("dom.security.https_only_mode_pbm", true);
user_pref("extensions.activeThemeID", "default-theme@mozilla.org");
user_pref("extensions.colorway-builtin-themes-cleanup", 1);
user_pref("extensions.getAddons.cache.lastUpdate", 1778105860);
user_pref("extensions.getAddons.databaseSchema", 6);
user_pref("extensions.pictureinpicture.enable_picture_in_picture_overrides", true);
user_pref("extensions.quarantinedDomains.list", "autoatendimento.bb.com.br,ibpf.sicredi.com.br,ibpj.sicredi.com.br,internetbanking.caixa.gov.br,www.ib12.bradesco.com.br,www2.bancobrasil.com.br");
user_pref("extensions.signatureCheckpoint", 1);
user_pref("extensions.ui.dictionary.hidden", true);
user_pref("extensions.ui.lastCategory", "addons://list/plugin");
user_pref("extensions.ui.locale.hidden", true);
user_pref("extensions.ui.sitepermission.hidden", true);
user_pref("extensions.ui.theme.hidden", false);
user_pref("extensions.webextensions.ExtensionStorageIDB.migrated.@testpilot-containers", true);
user_pref("extensions.webextensions.ExtensionStorageIDB.migrated.addon@darkreader.org", true);
user_pref("extensions.webextensions.ExtensionStorageIDB.migrated.sponsorBlocker@ajay.app", true);
user_pref("extensions.webextensions.ExtensionStorageIDB.migrated.uBlock0@raymondhill.net", true);
user_pref("extensions.webextensions.ExtensionStorageIDB.migrated.{446900e4-71c2-419f-a6a7-df9c091e268b}", true);
user_pref("extensions.webextensions.ExtensionStorageIDB.migrated.{74145f27-f039-47ce-a470-a662b129930a}", true);
user_pref("extensions.webextensions.ExtensionStorageIDB.migrated.{b86e4813-687a-43e6-ab65-0bde4ab75758}", true);
user_pref("font.name.monospace.x-western", "Hack Nerd Font");
user_pref("font.name.serif.x-western", "Segoe UI");
user_pref("font.size.variable.x-western", 14);
user_pref("geo.enabled", false);
user_pref("geo.provider.network.url", "");
user_pref("gfx-shader-check.build-version", "20260428230144");
user_pref("gfx-shader-check.device-id", "0x2c02");
user_pref("gfx-shader-check.driver-version", "32.0.15.9636");
user_pref("gfx-shader-check.ptr-size", 8);
user_pref("layout.spellcheckDefault", 0);
user_pref("media.autoplay.blocking_policy", 2);
user_pref("media.gmp-manager.lastCheck", 1778106034);
user_pref("media.gmp.storage.version.observed", 1);
user_pref("media.hardware-video-decoding.failed", false);
user_pref("media.peerconnection.enabled", false);
user_pref("network.captive-portal-service.enabled", false);
user_pref("network.connectivity-service.enabled", false);
user_pref("network.cookie.CHIPS.lastMigrateDatabase", 2);
user_pref("network.early-hints.preconnect.max_connections", 0);
user_pref("network.http.http3.enable_0rtt", false);
user_pref("network.http.referer.XOriginPolicy", 2);
user_pref("network.http.referer.disallowCrossSiteRelaxingDefault.top_navigation", true);
user_pref("network.http.speculative-parallel-limit", 0);
user_pref("network.predictor.enabled", false);
user_pref("network.prefetch-next", false);
user_pref("pdfjs.enabledCache.state", false);
user_pref("pdfjs.migrationVersion", 2);
user_pref("permissions.manager.defaultsUrl", "");
user_pref("privacy.annotate_channels.strict_list.enabled", true);
user_pref("privacy.bounceTrackingProtection.hasMigratedUserActivationData", true);
user_pref("privacy.bounceTrackingProtection.mode", 1);
user_pref("privacy.clearOnShutdown.history", false);
user_pref("privacy.fingerprintingProtection", true);
user_pref("privacy.firstparty.isolate", true);
user_pref("privacy.globalprivacycontrol.was_ever_enabled", true);
user_pref("privacy.history.custom", true);
user_pref("privacy.purge_trackers.date_in_cookie_database", "0");
user_pref("privacy.query_stripping.enabled", true);
user_pref("privacy.query_stripping.enabled.pbmode", true);
user_pref("privacy.sanitize.pending", "[{\"id\":\"shutdown\",\"itemsToClear\":[\"cache\",\"cookiesAndStorage\"],\"options\":{}},{\"id\":\"newtab-container\",\"itemsToClear\":[],\"options\":{}}]");
user_pref("privacy.trackingprotection.allow_list.baseline.enabled", false);
user_pref("privacy.trackingprotection.allow_list.convenience.enabled", false);
user_pref("privacy.trackingprotection.allow_list.hasMigratedCategoryPrefs", true);
user_pref("privacy.trackingprotection.consentmanager.skip.pbmode.enabled", false);
user_pref("privacy.trackingprotection.emailtracking.enabled", true);
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.trackingprotection.socialtracking.enabled", true);
user_pref("privacy.userContext.extension", "@testpilot-containers");
user_pref("sanity-test.device-id", "0x2c02");
user_pref("sanity-test.driver-version", "32.0.15.9636");
user_pref("sanity-test.running", false);
user_pref("sanity-test.version", "20260428230144");
user_pref("security.tls.enable_0rtt_data", false);
user_pref("services.sync.engine.addresses.available", true);
user_pref("sidebar.backupState", "{\"command\":\"\",\"panelOpen\":false,\"launcherWidth\":243,\"launcherExpanded\":true,\"launcherVisible\":true}");
user_pref("sidebar.installed.extensions", "{446900e4-71c2-419f-a6a7-df9c091e268b}");
user_pref("sidebar.main.tools", "history,{446900e4-71c2-419f-a6a7-df9c091e268b}");
user_pref("sidebar.revamp", true);
user_pref("sidebar.verticalTabs", true);
user_pref("sidebar.verticalTabs.dragToPinPromo.dismissed", true);
user_pref("storage.vacuum.last.index", 0);
user_pref("storage.vacuum.last.places.sqlite", 1778006708);
user_pref("toolkit.profiles.storeID", "f5156e3a");
user_pref("toolkit.winRegisterApplicationRestart", false);
user_pref("ui.osk.debug.keyboardDisplayReason", "IKPOS: Touch screen not found.");
