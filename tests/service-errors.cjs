const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = fs.readFileSync(require('node:path').join(__dirname, '../app/main.qml'), 'utf8');
function extract(name, from) {
    const start = source.indexOf('function ' + name + '(', from || 0);
    const open = source.indexOf('{', start);
    let depth = 1, end = open + 1;
    for (; depth; end++) {
        if (source[end] === '{') depth++;
        if (source[end] === '}') depth--;
    }
    return source.slice(start, end);
}
for (const [result, text] of [[0, 'token 0'], [new Error('denied'), 'denied']]) {
    let response;
    const context = { service: { pending: {}, call() { if (result instanceof Error) throw result; return result; } } };
    vm.createContext(context);
    vm.runInContext(extract('call', source.indexOf('id: lunaClient')), context);
    context.call('luna://com.webos.applicationManager/launch', {id: 'netflix'}, r => { response = r; });
    assert.equal(response.returnValue, false);
    assert(response.errorText.includes(text));
    assert.equal(Object.keys(context.service.pending).length, 0);
}
const context = { pending: {} };
vm.createContext(context);
vm.runInContext(extract('finish'), context);
let replies = 0;
context.pending[10] = r => { replies++; assert.equal(r.returnValue, false); };
context.finish(10, {returnValue: false});
context.finish(10, {returnValue: false});
assert.equal(replies, 1, 'error and response signals must complete the request only once');
console.log('PASS: token-zero errors, thrown service errors, duplicate response/error signals');
