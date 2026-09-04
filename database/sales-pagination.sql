-- Small authenticated metadata response, with buildings only for the selected project.
create or replace function public.efragh_sales_meta(p_session_token text,p_project text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if public._efragh_session_account(p_session_token) is null then raise exception 'انتهت الجلسة. سجل الدخول من جديد.' using errcode='42501'; end if;
 select jsonb_build_object('available',count(*) filter(where coalesce(unit_status,'متاحة')='متاحة'),'reserved',count(*) filter(where unit_status='محجوزة'),'sold',count(*) filter(where unit_status='مباعة')) into result from public.units;
 return result || jsonb_build_object(
 'projects',coalesce((select jsonb_agg(project_name order by project_name) from (select distinct project_name from public.units where project_name is not null) p),'[]'::jsonb),
 'buildings',case when nullif(p_project,'') is null then '[]'::jsonb else coalesce((select jsonb_agg(building_no order by building_no) from (select distinct building_no from public.units where project_name=p_project and building_no is not null) b),'[]'::jsonb) end);
end $$;
create or replace function public.efragh_sales_page(p_session_token text,p_project text default null,p_building text default null,p_status text default null,p_search text default null,p_page integer default 1)
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb; v_search text; v_page integer;
begin
 if public._efragh_session_account(p_session_token) is null then raise exception 'انتهت الجلسة. سجل الدخول من جديد.' using errcode='42501'; end if;
 if nullif(p_status,'') is not null and p_status not in ('متاحة','محجوزة','مباعة') then raise exception 'حالة غير صحيحة' using errcode='22023'; end if;
 v_search:=translate(lower(btrim(coalesce(p_search,''))),'٠١٢٣٤٥٦٧٨٩','0123456789');
 if length(v_search)>100 then raise exception 'نص البحث طويل جدًا' using errcode='22023'; end if;
 v_page:=greatest(1,coalesce(p_page,1));
 with filtered as materialized (
 select id,project_name,building_no,unit_no,asset_kind,total_area,unit_status
 from public.units where (nullif(p_project,'') is null or project_name=p_project)
 and (nullif(p_building,'') is null or building_no=p_building)
 and (nullif(p_status,'') is null or coalesce(unit_status,'متاحة')=p_status)
 and (v_search='' or strpos(lower(unit_no),v_search)>0)
 ), counts as (select count(*) as total from filtered), paging as (
 select total,least(v_page,greatest(1,ceil(total/30.0)::integer)) as page from counts
 ) select jsonb_build_object('total',total,'page',page,'page_size',30,'rows',coalesce((
 select jsonb_agg(to_jsonb(r) order by r.project_name,r.building_no,r.unit_no,r.id) from (
 select * from filtered order by project_name,building_no,unit_no,id limit 30 offset ((paging.page-1)*30)
 ) r),'[]'::jsonb)) into result from paging;
 return result;
end $$;
revoke all on function public.efragh_sales_meta(text,text) from public;
revoke all on function public.efragh_sales_page(text,text,text,text,text,integer) from public;
-- Custom employee sessions are verified inside both endpoints on every call.
grant execute on function public.efragh_sales_meta(text,text) to anon,authenticated;
grant execute on function public.efragh_sales_page(text,text,text,text,text,integer) to anon,authenticated;
notify pgrst,'reload schema';
