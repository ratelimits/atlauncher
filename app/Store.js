.pragma library
/* Saved state (arrangement, hidden apps, preferences, TMDB cache): JSON values in one SQLite table through
   QtQuick.LocalStorage. Values are kept in memory and written through. */
.import QtQuick.LocalStorage 2.0 as Sql

var db = null, cache = {};

function open() {
    if (db) return;
    try {
        db = Sql.LocalStorage.openDatabaseSync('atlauncher', '1.0', 'ATLauncher', 2000000);
        db.transaction(function (tx) {
            tx.executeSql('CREATE TABLE IF NOT EXISTS kv (k TEXT PRIMARY KEY, v TEXT)');
            var rs = tx.executeSql('SELECT k, v FROM kv');
            for (var i = 0; i < rs.rows.length; i++) {
                try { cache[rs.rows.item(i).k] = JSON.parse(rs.rows.item(i).v); } catch (e) {}
            }
        });
    } catch (e) { db = null; }
}

function get(key, fallback) {
    open();
    return cache.hasOwnProperty(key) ? cache[key] : fallback;
}

function set(key, value) {
    open();
    cache[key] = value;
    if (!db) return;
    try {
        db.transaction(function (tx) { tx.executeSql('INSERT OR REPLACE INTO kv (k, v) VALUES (?, ?)', [key, JSON.stringify(value)]); });
    } catch (e) {}
}
