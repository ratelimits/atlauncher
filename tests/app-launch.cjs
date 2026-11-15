const fs=require('fs'),vm=require('vm'),assert=require('assert');
const s=fs.readFileSync(require('path').join(__dirname, '../app/Home.qml'),'utf8');
function fn(n){let a=s.indexOf('function '+n+'('),b=s.indexOf('{',a),d=1,i=b+1;for(;d;i++){if(s[i]==='{')d++;if(s[i]==='}')d--;}return s.slice(a,i);}
const c={Cat:{SETTINGS_ID:"settings",ESCAPE_ID:"escape"},lgHomeId:"escape"}; vm.createContext(c);
const main=fs.readFileSync(require('path').join(__dirname,'../app/main.qml'),'utf8');
assert(!/luna:\s*luna\s*(?:\n|$)/.test(main),'Home.luna must not bind to itself');
assert(/id:\s*lunaClient/.test(main)&&/luna:\s*lunaClient/.test(main));
let launched;
c.luna={call(uri,payload,done){launched={uri,payload};if(done)done({returnValue:true});}};
c.Store={set(){}};c.toast=()=>{};
vm.runInContext(fn('call'),c);vm.runInContext(fn('launch'),c);
c.launch({id:'netflix',name:'Netflix'});
assert.equal(launched.uri,'luna://com.webos.applicationManager/launch');
assert.equal(launched.payload.id,'netflix');
console.log('PASS: unambiguous QML service binding and launch dispatch');
