'use strict';
const URL_BASE='https://qspyetuujfanlutqtqmd.supabase.co';
const API_KEY='sb_publishable_zKFrU03wtC5ayHLE8j4f2g_38_Cklv_';
const SESSION_KEY='narjuwan_efragh_session';
const $=id=>document.getElementById(id);
let units=[],page=1,selected=null,saving=false,loading=false;
const PAGE_SIZE=30;
const statusOf=u=>u.unit_status||'متاحة';
const statusClass=s=>s==='مباعة'?'sold':s==='محجوزة'?'reserved':'available';
const normalize=v=>String(v??'').replace(/[٠-٩]/g,c=>String('٠١٢٣٤٥٦٧٨٩'.indexOf(c))).trim().toLowerCase();
function lock(){units=[];selected=null;$('rows').replaceChildren();$('app').hidden=true;if($('edit').open)$('edit').close();sessionStorage.removeItem(SESSION_KEY);location.replace('../?next=sales');}
async function rpc(name,args={}){
 const token=sessionStorage.getItem(SESSION_KEY);if(!token){lock();throw new Error('يرجى تسجيل الدخول.');}
 const controller=new AbortController();const timer=setTimeout(()=>controller.abort(),20000);
 try{
 const response=await fetch(URL_BASE+'/rest/v1/rpc/'+name,{method:'POST',cache:'no-store',signal:controller.signal,headers:{apikey:API_KEY,'Content-Type':'application/json'},body:JSON.stringify({p_session_token:token,...args})});
 const data=await response.json();if(!response.ok){if(data.code==='42501'){lock();}throw new Error(data.message||'تعذر حفظ التغيير. حاول مجددًا.');}return data;
 }finally{clearTimeout(timer);}
}
function message(text,error=false){$('message').textContent=text;$('message').className='message'+(error?' error':'');$('message').hidden=!text;}
function options(id,values,placeholder){const old=$(id).value;$(id).replaceChildren(new Option(placeholder,''));values.forEach(v=>$(id).add(new Option(v,v)));if(values.includes(old))$(id).value=old;}
function buildings(){options('building',[...new Set(units.filter(u=>!$('project').value||u.project_name===$('project').value).map(u=>u.building_no).filter(Boolean))].sort((a,b)=>a.localeCompare(b,'ar',{numeric:true})),'الكل');}
function render(){
 const base=units.filter(u=>(!$('project').value||u.project_name===$('project').value)&&(!$('building').value||u.building_no===$('building').value)&&(!$('search').value||normalize(u.unit_no).includes(normalize($('search').value))));
 for(const [label,id]of [['متاحة','availableCount'],['محجوزة','reservedCount'],['مباعة','soldCount']])$(id).textContent=base.filter(u=>statusOf(u)===label).length;
 const filtered=base.filter(u=>!$('status').value||statusOf(u)===$('status').value);const pages=Math.max(1,Math.ceil(filtered.length/PAGE_SIZE));page=Math.min(page,pages);$('rows').replaceChildren();
 for(const unit of filtered.slice((page-1)*PAGE_SIZE,page*PAGE_SIZE)){
 const tr=document.createElement('tr');for(const value of [unit.project_name,unit.building_no,(unit.asset_kind==='land'?'قطعة ':'وحدة ')+unit.unit_no,unit.total_area==null?'—':new Intl.NumberFormat('ar-SA').format(unit.total_area)+' م²']){const td=document.createElement('td');td.textContent=value||'—';td.dataset.label=['المشروع',unit.asset_kind==='land'?'البلوك':'العمارة','القطعة / الوحدة','المساحة'][tr.children.length];tr.append(td);}
 const stateCell=document.createElement('td');stateCell.dataset.label='الحالة';stateCell.className='state-cell';const badge=document.createElement('span');badge.className='badge '+statusClass(statusOf(unit));badge.textContent=statusOf(unit);stateCell.append(badge);tr.append(stateCell);
 const action=document.createElement('td');action.className='action-cell';const button=document.createElement('button');button.textContent='تغيير الحالة';button.addEventListener('click',()=>{selected=unit;$('unitLabel').textContent=unit.project_name+' · '+(unit.asset_kind==='land'?'بلوك ':'عمارة ')+unit.building_no+' · '+(unit.asset_kind==='land'?'قطعة ':'وحدة ')+unit.unit_no+' — الحالة الحالية: '+statusOf(unit);$('newStatus').value=statusOf(unit);$('editError').hidden=true;$('edit').showModal();});action.append(button);tr.append(action);$('rows').append(tr);}
 if(!filtered.length){const tr=document.createElement('tr'),td=document.createElement('td');td.colSpan=6;td.textContent='لا توجد وحدات تطابق البحث.';tr.append(td);$('rows').append(tr);}
 $('pageInfo').textContent=page+' / '+pages+' · '+filtered.length+' نتيجة';$('prev').disabled=page<=1;$('next').disabled=page>=pages;
}
async function load(){if(loading)return;loading=true;$('refresh').disabled=true;try{units=await rpc('efragh_sales_units');options('project',[...new Set(units.map(u=>u.project_name))],'كل المشاريع');buildings();render();$('gate').hidden=true;$('app').hidden=false;message('');}catch(error){if($('app').hidden){$('gate').textContent='تعذر تحميل البيانات. أعد تحميل الصفحة أو ارجع للإفراغات.';}else message('تعذر تحديث القائمة. حاول مجددًا.',true);}finally{loading=false;$('refresh').disabled=false;}}
$('save').addEventListener('click',async()=>{if(!selected||saving)return;const next=$('newStatus').value;if(next===statusOf(selected)){$('edit').close();return;}saving=true;$('save').disabled=true;$('cancel').disabled=true;$('newStatus').disabled=true;try{const result=await rpc('efragh_set_unit_status',{p_unit_id:selected.id,p_status:next,p_expected_status:selected.unit_status??null});selected.unit_status=result.unit_status;render();$('edit').close();message('تم حفظ الحالة. ستظهر للعميل في الاستعلام.');}catch(error){$('editError').textContent=error.name==='AbortError'?'تعذر تأكيد الحفظ. حدّث القائمة للتحقق من الحالة قبل المحاولة مرة أخرى.':error.message;$('editError').hidden=false;}finally{saving=false;$('save').disabled=false;$('cancel').disabled=false;$('newStatus').disabled=false;}});
$('cancel').addEventListener('click',()=>$('edit').close());$('edit').addEventListener('cancel',e=>{if(saving)e.preventDefault();});
$('project').addEventListener('change',()=>{buildings();page=1;render();});for(const id of ['building','status','search'])$(id).addEventListener(id==='search'?'input':'change',()=>{page=1;render();});$('prev').addEventListener('click',()=>{page--;render();});$('next').addEventListener('click',()=>{page++;render();});$('refresh').addEventListener('click',load);
window.addEventListener('pageshow',()=>{if(!sessionStorage.getItem(SESSION_KEY))lock();});document.addEventListener('visibilitychange',()=>{if(document.visibilityState==='visible'&&!saving&&!$('edit').open)load();});load();
