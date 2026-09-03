alter table public.units add column if not exists asset_kind text not null default 'apartment';
alter table public.units add column if not exists usage_type text;
alter table public.units add column if not exists zone text;
alter table public.units add column if not exists price_per_sqm numeric;
alter table public.units add column if not exists street_north numeric;
alter table public.units add column if not exists street_south numeric;
alter table public.units add column if not exists street_east numeric;
alter table public.units add column if not exists street_west numeric;
alter table public.units add column if not exists street_count integer;
grant select (asset_kind, usage_type, zone, price_per_sqm, street_north, street_south, street_east, street_west, street_count) on public.units to anon;
create or replace view public.public_units with (security_invoker=true) as  SELECT id,
    project_name,
    building_no,
    floor_name,
    unit_no,
    net_area,
    total_area,
    basement_parking,
    ground_parking,
    extra_parking_1,
    street_view,
    two_street_view,
    separate_majlis,
    storage,
    terraces_count,
    bedrooms_count,
    bathrooms_count,
    final_price, asset_kind, usage_type, zone, price_per_sqm, street_north, street_south, street_east, street_west, street_count
   FROM units
  WHERE is_public = true;
CREATE OR REPLACE FUNCTION public.efragh_issue_form(p_session_token text, p_unit_id bigint, p_manual jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_account_id uuid;
  v_username text;
  v_unit public.units%rowtype;
  v_buyer_name text;
  v_buyer_identity text;
  v_buyer_phone text;
  v_buyer_phone_display text;
  v_property_type text;
  v_city text;
  v_neighborhood text;
  v_usage text;
  v_other_features text;
  v_hijri_date text;
  v_issue_date date;
  v_notes text;
  v_tax_applied boolean := true;
  v_total_value numeric;
  v_total_area numeric;
  v_net_area numeric;
  v_price_per_sqm numeric;
  v_brokerage_base numeric;
  v_brokerage_ratio numeric := 1;
  v_brokerage_vat numeric;
  v_brokerage_total numeric;
  v_real_estate_tax numeric;
  v_parking_count integer;
  v_snapshot jsonb;
  v_document_type text;
  v_serial text;
  v_form_id uuid;
  v_issued_at timestamptz := now();
begin
  v_account_id := public._efragh_session_account(p_session_token);
  if v_account_id is null then
    raise exception 'انتهت الجلسة. سجل الدخول من جديد.' using errcode='42501';
  end if;

  select username into v_username from public.efragh_admin_accounts where id = v_account_id;
  select * into v_unit from public.units where id = p_unit_id;
  if not found then raise exception 'الوحدة غير موجودة.' using errcode='P0002'; end if;

  v_document_type := case when lower(coalesce(nullif(btrim(p_manual->>'documentType'),''), 'efragh')) = 'quote' then 'quote' else 'efragh' end;

  v_buyer_name := btrim(coalesce(p_manual->>'buyerName',''));
  v_buyer_identity := btrim(coalesce(p_manual->>'buyerIdentity',''));
  v_buyer_phone := regexp_replace(coalesce(p_manual->>'buyerPhone',''), '[^0-9]', '', 'g');

  if v_buyer_name = '' or v_buyer_identity = '' or v_buyer_phone = '' then
    raise exception 'اسم المشتري ورقم الهوية والجوال مطلوبة.' using errcode='22023';
  end if;
  if v_buyer_phone !~ '^05[0-9]{8}$' then
    raise exception 'رقم الجوال يجب أن يكون 10 أرقام ويبدأ بـ 05.' using errcode='22023';
  end if;
  if v_buyer_identity !~ '^[0-9]+$' then
    raise exception 'رقم الهوية / السجل يجب أن يحتوي على أرقام فقط.' using errcode='22023';
  end if;

  begin
    v_issue_date := nullif(btrim(p_manual->>'issueDate'),'')::date;
  exception when others then
    raise exception 'تاريخ الإفراغ غير صحيح.' using errcode='22023';
  end;
  if v_issue_date is null then raise exception 'تاريخ الإفراغ مطلوب.' using errcode='22023'; end if;
  if v_issue_date > (now() at time zone 'Asia/Riyadh')::date then
    raise exception 'لا يمكن اختيار تاريخ إفراغ مستقبلي.' using errcode='22023';
  end if;

  v_buyer_phone_display := '+966 ' || substr(v_buyer_phone,2,2) || ' ' || substr(v_buyer_phone,4,3) || ' ' || substr(v_buyer_phone,7,4);
  v_property_type := coalesce(nullif(btrim(p_manual->>'propertyType'),''), 'شقة');
  v_city := coalesce(nullif(btrim(p_manual->>'city'),''), 'الرياض');
  v_neighborhood := coalesce(nullif(btrim(p_manual->>'neighborhood'),''), 'لا يوجد');
  v_usage := coalesce(nullif(btrim(p_manual->>'usage'),''), 'سكني');
  v_other_features := coalesce(nullif(btrim(p_manual->>'otherFeatures'),''), 'لا يوجد');
  v_hijri_date := coalesce(nullif(btrim(p_manual->>'hijriDate'),''), 'لا يوجد');
  v_notes := coalesce(nullif(btrim(p_manual->>'notes'),''), 'لا يوجد');
  v_tax_applied := lower(coalesce(nullif(btrim(p_manual->>'hasRealEstateTax'),''), 'yes')) not in ('no','false','0');

  if v_unit.asset_kind = 'land' then
    v_property_type := 'أرض';
    v_usage := v_unit.usage_type;
  end if;
  v_brokerage_ratio := coalesce(nullif(p_manual->>'brokerageRatio','')::numeric,1);
  if v_brokerage_ratio < 0 or v_brokerage_ratio > 1 then raise exception 'نسبة السعي غير صحيحة'; end if;
  v_total_value := v_unit.final_price;
  v_total_area := v_unit.total_area;
  v_net_area := v_unit.net_area;
  if v_total_value is null then raise exception 'السعر النهائي غير موجود لهذه الوحدة.' using errcode='22023'; end if;

  v_price_per_sqm := case when v_net_area is not null and v_net_area > 0 then v_total_value / v_net_area else null end;
  v_brokerage_base := v_total_value * 0.025 * v_brokerage_ratio;
  v_brokerage_vat := v_brokerage_base * 0.15;
  v_brokerage_total := v_brokerage_base + v_brokerage_vat;
  v_real_estate_tax := case when v_tax_applied then v_total_value * 0.05 else 0 end;

  v_parking_count :=
    (case when v_unit.basement_parking is true then 1 else 0 end) +
    (case when v_unit.ground_parking is true then 1 else 0 end) +
    (case when v_unit.extra_parking_1 is true then 1 else 0 end) +
    (case when v_unit.surface_parking is true then 1 else 0 end) +
    (case when v_unit.extra_parking_2 is true then 1 else 0 end);

  v_snapshot := jsonb_build_object(
    'issuedAt', v_issued_at,
    'dates', jsonb_build_object('hijri', v_hijri_date, 'gregorian', to_char(v_issue_date,'YYYY-MM-DD')),
    'ownerName', 'شركة أبناء عبدالله تركي الضحيان للمقاولات',
    'buyer', jsonb_build_object('name', v_buyer_name, 'identity', v_buyer_identity, 'phone', v_buyer_phone_display),
    'property', jsonb_build_object('type', v_property_type, 'city', v_city, 'neighborhood', v_neighborhood, 'usage', v_usage, 'otherFeatures', v_other_features, 'notes', v_notes),
    'unit', jsonb_build_object(
      'id', v_unit.id,
      'assetKind',v_unit.asset_kind, 'zone',v_unit.zone,
      'projectName', coalesce(nullif(btrim(v_unit.project_name),''),'لا يوجد'),
      'buildingNumber', coalesce(nullif(btrim(v_unit.building_group),''),'لا يوجد'),
      'building', coalesce(nullif(btrim(v_unit.building_no),''),'لا يوجد'),
      'unitNumber', coalesce(nullif(btrim(v_unit.unit_no),''),'لا يوجد'),
      'floor', coalesce(nullif(btrim(v_unit.floor_name),''),'لا يوجد'),
      'deedNumber', coalesce(nullif(btrim(v_unit.deed_no),''),'لا يوجد'),
      'deedDate', coalesce(v_unit.deed_date::text,'لا يوجد'),
      'subdivisionRecordNumber', coalesce(nullif(btrim(v_unit.subdivision_record_no),''),'لا يوجد'),
      'subdivisionUnitCode', coalesce(nullif(btrim(v_unit.subdivision_unit_code),''),'لا يوجد'),
      'totalArea', v_total_area,
      'netArea', v_net_area
    ),
    'features', jsonb_build_object(
      'streetCount',v_unit.street_count, 'streetNorth',v_unit.street_north, 'streetSouth',v_unit.street_south, 'streetEast',v_unit.street_east, 'streetWest',v_unit.street_west,
      'bedrooms', coalesce(v_unit.bedrooms_count::text,'لا يوجد'),
      'bathrooms', coalesce(v_unit.bathrooms_count::text,'لا يوجد'),
      'laundry', 'لا يوجد',
      'emptyBalcony', 'لا يوجد',
      'terrace', v_unit.terrace_area,
      'terracesCount', coalesce(v_unit.terraces_count::text,'لا يوجد'),
      'privateRoof', v_unit.private_roof_area,
      'storage', case when v_unit.storage is true then 'نعم' when v_unit.storage is false then 'لا' else 'لا يوجد' end,
      'parkingCount', case when v_parking_count > 0 then v_parking_count::text else 'لا يوجد' end,
      'basementParking', case when v_unit.basement_parking is true then 'نعم' when v_unit.basement_parking is false then 'لا' else 'لا يوجد' end,
      'groundParking', case when v_unit.ground_parking is true then 'نعم' when v_unit.ground_parking is false then 'لا' else 'لا يوجد' end,
      'streetView', case when v_unit.street_view is true then 'نعم' when v_unit.street_view is false then 'لا' else 'لا يوجد' end,
      'twoStreetView', case when v_unit.two_street_view is true then 'نعم' when v_unit.two_street_view is false then 'لا' else 'لا يوجد' end,
      'separateMajlis', case when v_unit.separate_majlis is true then 'نعم' when v_unit.separate_majlis is false then 'لا' else 'لا يوجد' end,
      'otherFeatures', v_other_features
    ),
    'financial', jsonb_build_object(
      'totalArea', v_total_area,
      'netArea', v_net_area,
      'pricePerSqm', case when v_price_per_sqm is null then null else round(v_price_per_sqm) end,
      'brokerageBase', round(v_brokerage_base),
      'brokerageVat', round(v_brokerage_vat),
      'brokerageTotal', round(v_brokerage_total),
      'totalValue', round(v_total_value),
      'realEstateTax', round(v_real_estate_tax),
      'taxApplied', v_tax_applied,
      'brokerageRatio',v_brokerage_ratio,
      'brokerageRate', 0.025,
      'brokerageVatRate', 0.15,
      'taxRate', 0.05
    )
  );

  v_snapshot := jsonb_set(v_snapshot, '{documentType}', to_jsonb(v_document_type), true);

  v_serial := 'NRJ-EF-' || to_char(v_issued_at at time zone 'Asia/Riyadh','YYYY') || '-' || lpad(nextval('public.evacuation_form_serial_seq')::text, 6, '0');

  insert into public.evacuation_forms(serial_number, unit_id, project_name, buyer_name, buyer_identity, buyer_phone, form_data, status, created_by, issued_at)
  values (v_serial, v_unit.id, v_unit.project_name, v_buyer_name, v_buyer_identity, v_buyer_phone, v_snapshot, 'issued', v_username, v_issued_at)
  returning id into v_form_id;

  return jsonb_build_object('id', v_form_id, 'serial_number', v_serial, 'snapshot', v_snapshot, 'issued_at', v_issued_at);
end;
$function$
;
CREATE OR REPLACE FUNCTION public.efragh_unit(p_session_token text, p_unit_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare v_unit jsonb;
begin
  if public._efragh_session_account(p_session_token) is null then raise exception 'انتهت الجلسة. سجل الدخول من جديد.' using errcode='42501'; end if;
  select to_jsonb(u) into v_unit from public.units u where u.id = p_unit_id;
  if v_unit is null then raise exception 'الوحدة غير موجودة.' using errcode='P0002'; end if;
  return v_unit;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.efragh_units(p_session_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
begin
  if public._efragh_session_account(p_session_token) is null then raise exception 'انتهت الجلسة. سجل الدخول من جديد.' using errcode='42501'; end if;
  return coalesce((select jsonb_agg(to_jsonb(x)) from (select id, project_name, building_no, unit_no, asset_kind, usage_type, final_price from public.units order by project_name, building_no, unit_no) x), '[]'::jsonb);
end;
$function$
;
