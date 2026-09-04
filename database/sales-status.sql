-- Sales management uses the existing custom efragh session validator, not Supabase Auth.
-- No client can write units or audit records directly through these endpoints.
create table public.unit_status_history (
 id bigint generated always as identity primary key,
 unit_id bigint not null references public.units(id),
 old_status text, new_status text not null,
 changed_by uuid not null references public.efragh_admin_accounts(id),
 changed_at timestamptz not null default now(),
 constraint unit_status_history_value check (new_status in ('متاحة','محجوزة','مباعة'))
);
alter table public.unit_status_history enable row level security;
revoke all on public.unit_status_history from public, anon, authenticated;
create index unit_status_history_unit_time on public.unit_status_history(unit_id,changed_at desc);

create or replace function public.efragh_sales_units(p_session_token text)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
 if public._efragh_session_account(p_session_token) is null then
 raise exception 'انتهت الجلسة. سجل الدخول من جديد.' using errcode='42501'; end if;
 return coalesce((select jsonb_agg(to_jsonb(x)) from (
 select id, project_name, building_no, unit_no, asset_kind, usage_type, total_area,
 final_price, unit_status, updated_at from public.units order by project_name, building_no, unit_no
 ) x),'[]'::jsonb);
end $$;

create or replace function public.efragh_set_unit_status(p_session_token text,p_unit_id bigint,p_status text,p_expected_status text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_account uuid; v_old text;
begin
 v_account := public._efragh_session_account(p_session_token);
 if v_account is null then raise exception 'انتهت الجلسة. سجل الدخول من جديد.' using errcode='42501'; end if;
 if p_status is null or p_status not in ('متاحة','محجوزة','مباعة') then
 raise exception 'حالة الوحدة غير صحيحة.' using errcode='22023'; end if;
 select unit_status into v_old from public.units where id=p_unit_id for update;
 if not found then raise exception 'الوحدة غير موجودة.' using errcode='P0002'; end if;
 if v_old is distinct from p_expected_status then
 raise exception 'تم تغيير الحالة بواسطة مستخدم آخر. حدّث القائمة ثم حاول مجددًا.' using errcode='40001'; end if;
 if v_old is distinct from p_status then
 update public.units set unit_status=p_status,updated_at=now() where id=p_unit_id;
 insert into public.unit_status_history(unit_id,old_status,new_status,changed_by)
 values(p_unit_id,v_old,p_status,v_account);
 end if;
 return jsonb_build_object('id',p_unit_id,'unit_status',p_status);
end $$;

revoke all on function public.efragh_sales_units(text) from public;
revoke all on function public.efragh_set_unit_status(text,bigint,text,text) from public;
-- Anon has EXECUTE solely because employee authentication is a custom hashed session.
-- Both functions validate that session server-side on every request.
grant execute on function public.efragh_sales_units(text) to anon,authenticated;
grant execute on function public.efragh_set_unit_status(text,bigint,text,text) to anon,authenticated;

create or replace view public.public_units as
select id, project_name, building_no, floor_name, unit_no, net_area, total_area,
basement_parking, ground_parking, extra_parking_1, street_view, two_street_view,
separate_majlis, storage, terraces_count, bedrooms_count, bathrooms_count, final_price,
asset_kind, usage_type, zone, price_per_sqm, street_north, street_south, street_east,
street_west, street_count, unit_status from public.units where is_public=true;
-- Preserve the existing public projection; no internal identifiers/audit data are added.
NOTIFY pgrst, 'reload schema';
