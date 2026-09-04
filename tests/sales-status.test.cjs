const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const html=fs.readFileSync(__dirname+'/../index.html','utf8');
const stamps=[];
function node(tag,cls='',text=''){return {tag,className:cls,textContent:text,children:[],append(...items){this.children.push(...items);for(const n of items)if(n.className?.includes('availability-stamp'))stamps.push(n)},setAttribute(){},addEventListener(){},scrollIntoView(){},remove(){stamps.splice(stamps.indexOf(this),1)},get firstChild(){return this.children[0]}};}
const DOM={unitTop:node('div'),summary:node('div'),sections:node('div'),empty:node('div'),details:node('div')};
const context=vm.createContext({STATE:{compareUnits:[]},DOM,element:node,document:{querySelectorAll:()=>[...stamps],createTextNode:t=>node('text','',t)},clearNode:n=>n.children=[],clearNotice(){},isBlank:v=>v==null,unitKey:u=>u.id,icon:()=>node('svg'),addCurrentUnitToCompare(){},copyUnitLink(){},visibleText:v=>String(v),LAND_SECTIONS:[],SECTION_DEFINITIONS:[],updateUrl(){},window:{setTimeout(){},print(){}}});
vm.runInContext(html.slice(html.indexOf('function renderUnit(unit)'),html.indexOf('function renderSkeleton()')),context);
for(const asset_kind of ['land','apartment'])for(const status of ['محجوزة','مباعة','متاحة',null]){
 context.unit={asset_kind,unit_status:status,unit_no:'1',building_no:'A',project_name:'اختبار'};vm.runInContext('renderUnit(unit)',context);
 assert.equal(stamps.length,['محجوزة','مباعة'].includes(status)?1:0);if(stamps.length){assert.equal(stamps[0].textContent,status);assert(stamps[0].className.includes(status==='مباعة'?'sold':'reserved'));}
}
const js=fs.readFileSync(__dirname+'/../efragh/sales/sales.js','utf8');new vm.Script(js);
// A missing session must redirect before any network/data access.
let redirected=false,requests=0;const nodes={};const sales=vm.createContext({document:{getElementById:id=>nodes[id]??={hidden:true,open:false,replaceChildren(){},addEventListener(){},disabled:false},addEventListener(){}},sessionStorage:{getItem:()=>null,removeItem(){}},location:{replace:u=>{assert.equal(u,'../?next=sales');redirected=true}},window:{addEventListener(){}},fetch:()=>{requests++;},setTimeout,clearTimeout,AbortController,Intl,Option:function(){}});
vm.runInContext(js,sales);assert(redirected);assert.equal(requests,0);
console.log('PASS: sold/reserved stamps, available removes stamp, both asset types, missing session blocks data access.');
// Preserve the sales destination after login without accepting arbitrary redirects.
const employee=fs.readFileSync(__dirname+'/../efragh/index.html','utf8');
const bootSource=employee.slice(employee.indexOf('async function boot()'),employee.indexOf('      const usageField='));
(async()=>{for(const authenticated of [false,true]){let target=null;const ctx=vm.createContext({trpc:async()=>({authenticated}),URLSearchParams,location:{search:'?next=sales',replace:url=>target=url},$:()=>{throw Error('Document composer should not open');}});vm.runInContext(bootSource,ctx);await vm.runInContext('boot()',ctx);assert.equal(target,authenticated?'sales/':null);}console.log('PASS: sales login return requires authenticated session.');})().catch(error=>{console.error(error);process.exitCode=1;});
