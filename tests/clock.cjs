const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const source = fs.readFileSync(require('node:path').join(__dirname, '../app/Home.qml'), 'utf8');
const start = source.indexOf('    function formatClock('), end = source.indexOf('\n    // ---- webOS', start);
const locale = {}; vm.createContext(locale); vm.runInContext(fs.readFileSync(require('node:path').join(__dirname, '../app/Locale.js'), 'utf8').replace(/^\.pragma library\s*/, ''), locale);
const context = {prefs: {}, Locale: locale, tvTimeFormat: 'HH24'};
vm.createContext(context); vm.runInContext(source.slice(start, end), context);
for (const [h, m, expected24, expected12] of [[0,0,'00:00','12:00 AM'],[9,5,'09:05','9:05 AM'],[12,0,'12:00','12:00 PM'],[19,7,'19:07','7:07 PM'],[23,59,'23:59','11:59 PM']]) {
    const date = {getHours:()=>h, getMinutes:()=>m};
    context.prefs.clock12h = false; assert.equal(context.formatClock(date),expected24);
    context.prefs.clock12h = true; assert.equal(context.formatClock(date),expected12);
}
assert(source.includes('visible: home.prefs.showAvatar !== false'));
console.log('PASS: 12/24-hour clock including midnight, noon and leading zeros; avatar visibility binding');
