// bento · Unit-01 (userChrome.css); раньше — WinBox 4
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("browser.compactmode.show", true);
user_pref("browser.uidensity", 1);

// Clean Firefox Home: hide site tiles and recommendations.
user_pref("browser.newtabpage.activity-stream.feeds.topsites", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.highlights", false);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);

// bento: без полосы значков новой боковой панели (классическая панель — Ctrl+B / Ctrl+H)
user_pref("sidebar.revamp", false);
user_pref("sidebar.verticalTabs", false);

// HDR-видео (YouTube и т.п.) на Wayland с HDR-режимом Hyprland
user_pref("gfx.wayland.hdr", true);
user_pref("gfx.webrender.all", true);
