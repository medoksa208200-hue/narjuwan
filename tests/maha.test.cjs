const fs=require('node:fs');
const vm=require('node:vm');
const assert=require('node:assert/strict');
const path=require('node:path');
const root=path.join(__dirname,'..');
const plots=JSON.parse(fs.readFileSync(path.join(root,'database/maha-plots.json')));
assert.equal(plots.length,967);
assert.equal(plots.filter(p=>p.usage_type==='سكني').length,930);
assert.equal(plots.filter(p=>p.usage_type==='تجاري').length,37);
assert.equal(new Set(plots.map(p=>p.building_no+'|'+p.unit_no)).size,967);
for(const p of plots){assert(Math.abs(p.total_area*p.price_per_sqm-p.final_price)<.02);assert.equal(p.street_count,['north','south','east','west'].filter(d=>p['street_'+d]>0).length)}
for(const file of ['index.html','efragh/index.html']){
 const html=fs.readFileSync(path.join(root,file),'utf8');
 for(const match of html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g))new vm.Script(match[1]);
}
// Exercise draft calculations and saved-snapshot rendering without a browser.
const html=fs.readFileSync(path.join(root,'efragh/index.html'),'utf8');
let code=[...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)].at(-1)[1];
code=code.slice(0,code.indexOf('      const usageField='));
const fields={};
const get=id=>fields[id]??=( {value:'',innerHTML:'',querySelector:()=>null} );
const context=vm.createContext({document:{getElementById:get},sessionStorage:{getItem:()=>null},window:{location:{href:"https://example.test/efragh/"}},URL,Intl,Date,console,setTimeout,clearTimeout});
vm.runInContext(code,context);
for(const [key,val] of Object.entries({documentType:'quote',buyerName:'اختبار',buyerIdentity:'123',buyerPhone:'0500000000',propertyType:'أرض',city:'الرياض',usage:'تجاري',issueDate:'2026-09-03',hijriDate:'اختبار',hasRealEstateTax:'yes',brokerageRatio:'0.5',totalArea:'1241.17',netArea:'1241.17'}))get(key).value=val;
vm.runInContext('state.unit='+JSON.stringify(plots[0]),context);
const snapshot=vm.runInContext('draftSnapshot()',context);
assert.equal(snapshot.unit.assetKind,'land');
assert.equal(snapshot.unit.totalArea,1241.17);
assert.equal(snapshot.features.streetCount,3);
assert.equal(snapshot.property.usage,'تجاري');
assert.equal(snapshot.financial.brokerageTotal,Math.round(plots[0].final_price*.025*.5*1.15));
context.snapshot=snapshot;
vm.runInContext('renderDocument(snapshot)',context);
assert(get('a4Document').innerHTML.includes('رقم البلوك'));
assert(get('a4Document').innerHTML.includes('عرض الشارع شمالًا'));
assert(!get('a4Document').innerHTML.includes('عدد الغرف'));
get('hasRealEstateTax').value='no';get('brokerageRatio').value='0';
assert.equal(vm.runInContext('finance().realEstateTax',context),0);
assert.equal(vm.runInContext('finance().brokerageTotal',context),0);
console.log('PASS: 967 plots, classifications, street counts, prices, JS syntax, land snapshot, financial choices, document fields.');

assert(get('a4Document').innerHTML.includes('مجموع عروض الشوارع'));
assert(get('a4Document').innerHTML.includes('65 م'));
assert(get('a4Document').innerHTML.includes('M7 3 3 21'));
assert(!get('a4Document').innerHTML.includes('صافي المساحة'));
assert(!get('a4Document').innerHTML.includes('إجمالي المساحة'));
assert(!get('a4Document').innerHTML.includes('رقم الصك'));
assert(get('a4Document').innerHTML.includes('لا يوجد'));
snapshot.unit.deedNumber='12345';snapshot.unit.deedDate='2026-01-01';
vm.runInContext('renderDocument(snapshot)',context);
assert(get('a4Document').innerHTML.includes('12345'));
snapshot.unit.assetKind='apartment';
vm.runInContext('renderDocument(snapshot)',context);
assert(get('a4Document').innerHTML.includes('صافي المساحة'));
assert(get('a4Document').innerHTML.includes('عدد الغرف'));
console.log('PASS: street total and icon, absent/present deeds, single land area, apartment compatibility.');
