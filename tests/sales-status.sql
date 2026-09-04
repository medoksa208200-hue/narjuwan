-- Transactional integration test: no fixture, session, or status change is committed.
begin;
do $$
declare a uuid; token text := encode(extensions.gen_random_bytes(32),'hex'); uid bigint; old text; result jsonb;
begin
 insert into public.efragh_admin_accounts(username,password_hash,must_change_password)
 values('sales-test-'||gen_random_uuid(),extensions.crypt(encode(extensions.gen_random_bytes(24),'hex'),extensions.gen_salt('bf')),false) returning id into a;
 insert into public.efragh_admin_sessions(account_id,token_hash,expires_at)
 values(a,encode(extensions.digest(token,'sha256'),'hex'),now()+interval '5 minutes');
 select id,unit_status into uid,old from public.units where is_public=true order by id limit 1;
 perform set_config('role','anon',true);
 begin perform public.efragh_sales_units('invalid'); raise exception 'FAIL invalid read'; exception when insufficient_privilege then null; end;
 begin perform public.efragh_set_unit_status('invalid',uid,'مباعة',old); raise exception 'FAIL invalid write'; exception when insufficient_privilege then null; end;
 begin perform public.efragh_set_unit_status(token,uid,'invalid',old); raise exception 'FAIL invalid status'; exception when invalid_parameter_value then null; end;
 begin perform public.efragh_set_unit_status(token,-999999,'متاحة',null); raise exception 'FAIL missing unit'; exception when no_data_found then null; end;
 result:=public.efragh_sales_units(token); if jsonb_array_length(result)<1109 then raise exception 'FAIL list truncated'; end if;
 perform public.efragh_set_unit_status(token,uid,'محجوزة',old);
 if (select unit_status from public.public_units where id=uid)<>'محجوزة' then raise exception 'FAIL public reserved'; end if;
 begin perform public.efragh_set_unit_status(token,uid,'مباعة','stale'); raise exception 'FAIL conflict'; exception when serialization_failure then null; end;
 perform public.efragh_set_unit_status(token,uid,'مباعة','محجوزة');
 if (select unit_status from public.public_units where id=uid)<>'مباعة' then raise exception 'FAIL public sold'; end if;
 perform public.efragh_set_unit_status(token,uid,'متاحة','مباعة');
 perform public.efragh_set_unit_status(token,uid,'متاحة','متاحة');
 begin update public.units set unit_status='مباعة' where id=uid; raise exception 'FAIL direct update'; exception when insufficient_privilege then null; end;
 begin perform * from public.unit_status_history; raise exception 'FAIL audit exposure'; exception when insufficient_privilege then null; end;
 perform set_config('role','postgres',true);
 if (select count(*) from public.unit_status_history where changed_by=a)<>3 then raise exception 'FAIL audit count'; end if;
 update public.efragh_admin_sessions set expires_at=now()-interval '1 minute' where account_id=a;
 perform set_config('role','anon',true);
 begin perform public.efragh_set_unit_status(token,uid,'مباعة','متاحة'); raise exception 'FAIL expired session'; exception when insufficient_privilege then null; end;
 perform set_config('role','postgres',true);
end $$;
rollback;
select 'PASS: session guard, invalid state, conflict, all statuses, public projection, direct write denied, audit, expiry, rollback' as result;
