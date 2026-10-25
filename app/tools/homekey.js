/* ATLauncher's key filter, loaded by LG's surface-manager from /var/lib/atlauncher/homekey.js through the
   com.webos.surfacemanager.keyFilters config (runtime only; atlauncher.sh enable/disable). The Home key opens ATLauncher
   (the Home app, through atlauncher.sh's overlay); the Input key opens ATLauncher on HDMI 1 (the inputs row); the Settings key
   opens ATLauncher's Settings (its "TV Settings" row opens LG's quick settings).
   Anything unexpected passes the key on to LG's own handling (KeyPolicy.NextPolicy), so a failure here can never
   swallow the remote.
   Pointer: LG shows the Magic Remote pointer for Home and Settings (StarfishKeyFilter getMRCUCursorVisibiltyByKey,
   run before this filter), and for Input the remote itself sends CursorShow right after. ATLauncher is driven by the
   arrows after these keys, so the pointer is hidden again, and a CursorShow within a second of Input is dropped
   (moving the remote still shows it). */
var ATLAUNCHER_HOME = "com.webos.app.home";
var CURSOR_GRACE_MS = 1000;
var atlauncherInputAt = 0;

function atlauncherHideCursor(deviceId) {
    try { if (global && global.setMRCUCursorVisibility) global.setMRCUCursorVisibility(0, deviceId, true, false); }
    catch (e) { console.warn("ATLAUNCHER_KEY cursor:", e); }
}

function atlauncherLaunch(params) {
    // A fresh timestamp each time: the native TV Home sees a relaunch as its launch parameters changing, so two
    // identical Home presses in a row must still differ.
    params.t = Date.now();
    applicationManager.launch(ATLAUNCHER_HOME, JSON.stringify(params));
    pmLog.info("ATLAUNCHER_KEY", {"launched": ATLAUNCHER_HOME, "params": params});
}

function handleATLauncherKey(key, pressed, autoRepeat, deviceId) {
    try {
        var home = key === Qt.Key_Super_L || key === Qt.Key_Meta;
        var input = key === WebOS.Key_webOS_InputSource || key === WebOS.Key_webOS_LocalInputSource;
        var settings = key === WebOS.Key_webOS_Settings || key === WebOS.Key_webOS_LocalSettings;
        if (key === WebOS.Key_webOS_CursorShow && Date.now() - atlauncherInputAt < CURSOR_GRACE_MS)
            return KeyPolicy.Accepted;
        if (!home && !input && !settings)
            return KeyPolicy.NextPolicy;
        // Leave first-use setup and blocking system dialogs to LG.
        if ((bootManager && bootManager.bootFirstUse) || (modalAlert && modalAlert.visible))
            return KeyPolicy.NextPolicy;
        if (input) atlauncherInputAt = Date.now();
        atlauncherHideCursor(deviceId);
        if (!pressed && !autoRepeat)
            atlauncherLaunch(input ? {"activateType": "input", "focus": "com.webos.app.hdmi1"}
                         : settings ? {"activateType": "settings"}
                         : {"activateType": "home", "launchType": "homeKey"});
        return KeyPolicy.Accepted;
    } catch (e) {
        console.warn("ATLAUNCHER_KEY failed, passing the key to LG:", e);
        return KeyPolicy.NextPolicy;
    }
}
