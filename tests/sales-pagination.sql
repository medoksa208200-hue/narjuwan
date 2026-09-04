-- Transactional integration test: no fixture, session, or status change is committed.
begin;
do $$
declare a uuid; token text := encode(extensions.gen_random_bytes(32),'hex'); uid bigint; old text; result jsonb;
begin
 insert into public.efragh_admin_accounts(username,password_hash,must_change_password)
 values('sales-test-'||gen_random_uuid(),extensions.crypt(encode(extensions.gen_random_bytes(24),'hex'),extensions.gen_salt('bf')),false) returning id into a;
 insert into public.efragh_admin_sessions(account_id,token_hash,expires_at)
 values(a,encode(extensions.digest(token,'sha256'),'hex'),now()+interval '5 minutes');
 perform set_config('role','anon',true);
 begin perform public.efragh_sales_page('invalid'); raise exception 'FAIL anonymous'; exception when insufficient_privilege then null; end;
 result:=public.efragh_sales_page(token);
 if jsonb_array_length(result->'rows')<>30 or (result->>'total')::int<1109 then raise exception 'FAIL page bound'; end if;
 if (public.efragh_sales_page(token,null,null,null,null,999999)->>'page')::int<>ceil((result->>'total')::numeric/30) then raise exception 'FAIL last page'; end if;
 result:=public.efragh_sales_page(token,'المها');
 if exists(select 1 from jsonb_array_elements(result->'rows') r where r->>'project_name'<>'المها') then raise exception 'FAIL project'; end if;
 result:=public.efragh_sales_page(token,null,null,'مباعة');
 if exists(select 1 from jsonb_array_elements(result->'rows') r where r->>'unit_status'<>'مباعة') then raise exception 'FAIL status'; end if;
 result:=public.efragh_sales_page(token,'المها','1',null,'١');
 if exists(select 1 from jsonb_array_elements(result->'rows') r where r->>'building_no'<>'1' or strpos(r->>'unit_no','1')=0) then raise exception 'FAIL filter'; end if;
 if (public.efragh_sales_page(token,null,null,null,'NO-MATCH-TEST')->>'total')::int<>0 then raise exception 'FAIL no result'; end if;
 if jsonb_array_length(public.efragh_sales_meta(token)->'buildings')<>0 then raise exception 'FAIL eager buildings'; end if;
 perform set_config('role','postgres',true);
 if (public.efragh_sales_meta(token)->>'sold')::int<>(select count(*) from public.units where unit_status='مباعة') then raise exception 'FAIL global counts'; end if;
 raise notice 'old bytes %, new page bytes %, metadata bytes %',octet_length(public.efragh_sales_units(token)::text),octet_length(public.efragh_sales_page(token)::text),octet_length(public.efragh_sales_meta(token)::text);

end $$;
rollback;
select 'PASS: bounded pages, project/building/status/search filters, global counts, invalid session, empty results' as result;
