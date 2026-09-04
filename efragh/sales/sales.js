'use strict';
const URL_BASE='https://qspyetuujfanlutqtqmd.supabase.co';
const API_KEY='sb_publishable_zKFrU03wtC5ayHLE8j4f2g_38_Cklv_';
const SESSION_KEY='narjuwan_efragh_session';
const $=id=>document.getElementById(id);
let units=[],page=1,total=0,selected=null,saving=false,loading=false;
let requestId=0,activeController=null,searchTimer=null;
const pageCache=new Map(),metaCache=new Map(),CACHE_MS=300000;
const PAGE_SIZE=30;
const statusOf=u=>u.unit_status||'متاحة';
const statusClass=s=>s==='مباعة'?'sold':s==='محجوزة'?'reserved':'available';
const normalize=v=>String(v??'').replace(/[٠-٩]/g,c=>String('٠١٢٣٤٥٦٧٨٩'.indexOf(c))).trim().toLowerCase();
function lock(){units=[];selected=null;$('rows').replaceChildren();$('app').hidden=true;if($('edit').open)$('edit').close();sessionStorage.removeItem(SESSION_KEY);location.replace('../?next=sales');}
async function rpc(name,args={},signal){
 const token=sessionStorage.getItem(SESSION_KEY);if(!token){lock();throw new Error('يرجى تسجيل الدخول.');}
 const controller=new AbortController();if(signal){if(signal.aborted)controller.abort();else signal.addEventListener('abort',()=>controller.abort(),{once:true});}const timer=setTimeout(()=>controller.abort(),20000);
 try{
 const response=await fetch(URL_BASE+'/rest/v1/rpc/'+name,{method:'POST',cache:'no-store',signal:controller.signal,headers:{apikey:API_KEY,'Content-Type':'application/json'},body:JSON.stringify({p_session_token:token,...args})});
 const data=await response.json();if(!response.ok){if(data.code==='42501'){lock();}throw new Error(data.message||'تعذر حفظ التغيير. حاول مجددًا.');}return data;
 }finally{clearTimeout(timer);}
}
function message(text,error=false){$('message').textContent=text;$('message').className='message'+(error?' error':'');$('message').hidden=!text;}
function options(id,values,placeholder){const old=$(id).value;$(id).replaceChildren(new Option(placeholder,''));values.forEach(v=>$(id).add(new Option(v,v)));if(values.includes(old))$(id).value=old;}
function render(){
 const pages=Math.max(1,Math.ceil(total/PAGE_SIZE));$('rows').replaceChildren();
 for(const unit of units){
 const tr=document.createElement('tr');for(const value of [unit.project_name,unit.building_no,(unit.asset_kind==='land'?'قطعة ':'وحدة ')+unit.unit_no,unit.total_area==null?'—':new Intl.NumberFormat('ar-SA').format(unit.total_area)+' م²']){const td=document.createElement('td');td.textContent=value||'—';td.dataset.label=['المشروع',unit.asset_kind==='land'?'البلوك':'العمارة','القطعة / الوحدة','المساحة'][tr.children.length];tr.append(td);}
 const stateCell=document.createElement('td');stateCell.dataset.label='الحالة';stateCell.className='state-cell';const badge=document.createElement('span');badge.className='badge '+statusClass(statusOf(unit));badge.textContent=statusOf(unit);stateCell.append(badge);tr.append(stateCell);
 const action=document.createElement('td');action.className='action-cell';const button=document.createElement('button');button.textContent='تغيير الحالة';button.addEventListener('click',()=>{selected=unit;$('unitLabel').textContent=unit.project_name+' · '+(unit.asset_kind==='land'?'بلوك ':'عمارة ')+unit.building_no+' · '+(unit.asset_kind==='land'?'قطعة ':'وحدة ')+unit.unit_no+' — الحالة الحالية: '+statusOf(unit);$('newStatus').value=statusOf(unit);$('editError').hidden=true;$('edit').showModal();});action.append(button);tr.append(action);$('rows').append(tr);}
 if(!units.length){const tr=document.createElement('tr'),td=document.createElement('td');td.colSpan=6;td.textContent='لا توجد وحدات تطابق البحث.';tr.append(td);$('rows').append(tr);}
 $('pageInfo').textContent=page+' / '+pages+' · '+total+' نتيجة';$('prev').disabled=page<=1;$('next').disabled=page>=pages;
}
function filters(){return {p_project:$('project').value||null,p_building:$('building').value||null,p_status:$('status').value||null,p_search:normalize($('search').value)||null,p_page:page};}
function cached(map,key){const hit=map.get(key);return hit&&Date.now()-hit.time<CACHE_MS?hit.data:null;}
function put(map,key,data){if(map.size>=20)map.delete(map.keys().next().value);map.set(key,{time:Date.now(),data});}
async function load(force=false){
 if(!sessionStorage.getItem(SESSION_KEY)){lock();return;}
 const id=++requestId;activeController?.abort();activeController=new AbortController();const signal=activeController.signal;
 const args=filters(),key=JSON.stringify(args),metaKey=args.p_project||'';loading=true;$('refresh').disabled=true;$('prev').disabled=true;$('next').disabled=true;$('rows').replaceChildren();$('pageInfo').textContent='جارٍ التحميل…';
 if(force){pageCache.clear();metaCache.clear();}
 try{
 const [data,meta]=await Promise.all([
 cached(pageCache,key)||rpc('efragh_sales_page',args,signal),
 cached(metaCache,metaKey)||rpc('efragh_sales_meta',{p_project:args.p_project},signal)
 ]);
 if(id!==requestId)return;
 put(pageCache,key,data);put(metaCache,metaKey,meta);
 units=data.rows;page=data.page;total=data.total;
 options('project',meta.projects,'كل المشاريع');options('building',meta.buildings,'كل البلوكات / العمارات');$('building').disabled=!args.p_project;
 $('availableCount').textContent=meta.available;$('reservedCount').textContent=meta.reserved;$('soldCount').textContent=meta.sold;
 render();$('gate').hidden=true;$('app').hidden=false;message('');
 }catch(error){if(id!==requestId)return;units=[];total=0;render();message('تعذر تحميل النتائج. اضغط تحديث للمحاولة مجددًا.',true);$('gate').hidden=true;$('app').hidden=false;}
 finally{if(id===requestId){loading=false;$('refresh').disabled=false;}}
}
function filterChanged(){clearTimeout(searchTimer);page=1;load();}
$('save').addEventListener('click',async()=>{if(!selected||saving)return;const next=$('newStatus').value;if(next===statusOf(selected)){$('edit').close();return;}saving=true;$('save').disabled=true;$('cancel').disabled=true;$('newStatus').disabled=true;try{const result=await rpc('efragh_set_unit_status',{p_unit_id:selected.id,p_status:next,p_expected_status:selected.unit_status??null});selected.unit_status=result.unit_status;$('edit').close();await load(true);message('تم حفظ الحالة. ستظهر للعميل في الاستعلام.');}catch(error){$('editError').textContent=error.name==='AbortError'?'تعذر تأكيد الحفظ. حدّث القائمة للتحقق من الحالة قبل المحاولة مرة أخرى.':error.message;$('editError').hidden=false;}finally{saving=false;$('save').disabled=false;$('cancel').disabled=false;$('newStatus').disabled=false;}});
$('cancel').addEventListener('click',()=>$('edit').close());$('edit').addEventListener('cancel',e=>{if(saving)e.preventDefault();});
$('project').addEventListener('change',()=>{options('building',[],'كل البلوكات / العمارات');$('building').disabled=true;filterChanged();});
for(const id of ['building','status'])$(id).addEventListener('change',filterChanged);
$('search').maxLength=100;
$('search').addEventListener('input',()=>{clearTimeout(searchTimer);activeController?.abort();++requestId;$('rows').replaceChildren();$('prev').disabled=true;$('next').disabled=true;searchTimer=setTimeout(filterChanged,150);});
$('prev').addEventListener('click',()=>{page--;load();});$('next').addEventListener('click',()=>{page++;load();});$('refresh').addEventListener('click',()=>{clearTimeout(searchTimer);load(true);});
window.addEventListener('pageshow',()=>{if(!sessionStorage.getItem(SESSION_KEY))lock();});
// Returning to the tab does not re-download units. The refresh button requests fresh data.
load();
