const fs=require('fs'),vm=require('vm'),assert=require('assert');
const s=fs.readFileSync(require('path').join(__dirname, '../app/Home.qml'),'utf8');
function fn(n){let a=s.indexOf('function '+n+'('),b=s.indexOf('{',a),d=1,i=b+1;for(;d;i++){if(s[i]==='{')d++;if(s[i]==='}')d--;}return s.slice(a,i);}
const Qt={Key_Left:1,Key_Right:2,Key_Up:3,Key_Down:4,Key_Return:5,Key_Back:6};
const c={Qt,apps:[{id:'a'},{id:'b'},{id:'c'},{id:'hdmi',fixed:true}],selected:0,cols:6,editing:false,visualEdit:false,settings:{open:true},appMenu:{shown:false},Cat:{movable:a=>a&&!a.fixed},closeSettings(){c.settings.open=false},pressTimer:{stop(){}},holdTimer:{stop(){}},setMode(m){c.mode=m},render(){},tileAt:()=>null,bumpTile(){},appModel:{move(){}},saveOrder(){c.saved=c.apps.map(a=>a.id).join(',')},row:i=>Math.floor(i/6),move(dx,dy){c.selected=Math.max(0,Math.min(c.apps.length-1,c.selected+dx+dy*6))},isBack:k=>k===6,isOk:k=>k===5,okSuppress:false,lastMove:0};
vm.createContext(c);for(const n of ['startVisualEdit','chooseEditApp','startEditing','finishEditing','editKey','keyDown','pageFor'])vm.runInContext(fn(n),c);
c.candidates=[];c.isHidden=()=>false;
c.pageFor('apps').rows[0].act();assert(c.visualEdit&&!c.settings.open&&!c.editing);
function key(k){c.okSuppress=false;c.keyDown(k,false)}
key(2);assert.equal(c.selected,1);key(5);assert(c.editing);key(1);assert.equal(c.apps[0].id,'b');key(5);assert(!c.editing&&c.visualEdit);
key(2);key(2);key(5);assert(c.editing);key(1);key(5);assert.equal(c.saved,'b,c,a,hdmi');assert(c.visualEdit);
key(6);assert(!c.visualEdit&&!c.editing);
c.startVisualEdit();key(5);key(6);assert(!c.visualEdit&&!c.editing);
assert(!s.includes('editButtonFocused'));assert(!s.includes('toggleVisualEdit'));
console.log('PASS: Settings entry, app selection, two consecutive moves, saving, Back while selecting/moving, removed permanent button');
