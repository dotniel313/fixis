-- FIXIS PRO v1.10.8.2
-- Job Intake + Private Evidence + Arrival Guard
-- Target: audited LIVE schema as of 2026-09-14
-- IMPORTANT: apply first in staging / QA project and run validation SQL.

begin;

-- ============================================================
-- 1. JOB INTAKE: reference, preferred visit, arrival audit
-- ============================================================
alter table public.jobs
  add column if not exists address_reference text,
  add column if not exists requested_visit_at timestamptz,
  add column if not exists arrived_at timestamptz,
  add column if not exists arrival_latitude double precision,
  add column if not exists arrival_longitude double precision,
  add column if not exists arrival_accuracy double precision,
  add column if not exists arrival_distance_meters double precision;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'jobs_address_reference_length_check'
  ) then
    alter table public.jobs
      add constraint jobs_address_reference_length_check
      check (address_reference is null or char_length(address_reference) <= 500);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'jobs_arrival_accuracy_check'
  ) then
    alter table public.jobs
      add constraint jobs_arrival_accuracy_check
      check (arrival_accuracy is null or arrival_accuracy >= 0);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'jobs_arrival_distance_check'
  ) then
    alter table public.jobs
      add constraint jobs_arrival_distance_check
      check (arrival_distance_meters is null or arrival_distance_meters >= 0);
  end if;
end $$;

-- ============================================================
-- 2. CREATE JOB: preserve current behavior + optional new fields
--    Drop exact old signature to avoid PostgREST overload ambiguity.
-- ============================================================
drop function if exists public.create_job(
  text, text, text, text, double precision, double precision
);

create function public.create_job(
  p_title text,
  p_category text,
  p_address text,
  p_description text default null,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_address_reference text default null,
  p_requested_visit_at timestamptz default null
)
returns public.jobs
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_profile public.profiles;
  v_job public.jobs;
  v_title text;
  v_category text;
  v_address text;
  v_description text;
  v_reference text;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'AUTHENTICATION_REQUIRED';
  end if;

  select * into v_profile
  from public.profiles
  where id = v_user_id;

  if not found then raise exception 'PROFILE_NOT_FOUND'; end if;
  if v_profile.role <> 'customer' then raise exception 'NOT_A_CUSTOMER'; end if;
  if v_profile.account_status <> 'active' then raise exception 'ACCOUNT_NOT_ACTIVE'; end if;

  v_title := nullif(trim(p_title), '');
  v_category := nullif(trim(p_category), '');
  v_address := nullif(trim(p_address), '');
  v_description := nullif(trim(p_description), '');
  v_reference := nullif(trim(p_address_reference), '');

  if v_title is null then raise exception 'TITLE_REQUIRED'; end if;
  if v_category is null then raise exception 'CATEGORY_REQUIRED'; end if;
  if v_address is null then raise exception 'ADDRESS_REQUIRED'; end if;

  if length(v_title) > 150 then raise exception 'TITLE_TOO_LONG'; end if;
  if length(v_category) > 100 then raise exception 'CATEGORY_TOO_LONG'; end if;
  if length(v_address) > 300 then raise exception 'ADDRESS_TOO_LONG'; end if;
  if v_description is not null and length(v_description) > 2000 then
    raise exception 'DESCRIPTION_TOO_LONG';
  end if;
  if v_reference is not null and length(v_reference) > 500 then
    raise exception 'ADDRESS_REFERENCE_TOO_LONG';
  end if;

  if p_latitude is null or p_longitude is null then
    raise exception 'LOCATION_REQUIRED';
  end if;
  if p_latitude < -90 or p_latitude > 90 then raise exception 'INVALID_LATITUDE'; end if;
  if p_longitude < -180 or p_longitude > 180 then raise exception 'INVALID_LONGITUDE'; end if;

  -- It is a preferred/requested time, NOT an accepted appointment yet.
  if p_requested_visit_at is not null
     and p_requested_visit_at < now() - interval '5 minutes' then
    raise exception 'REQUESTED_VISIT_IN_PAST';
  end if;

  insert into public.jobs (
    client_id,
    client_name,
    category,
    title,
    description,
    address,
    address_reference,
    requested_visit_at,
    latitude,
    longitude,
    service_location,
    status,
    assigned_pro_id,
    accepted_quote_id
  ) values (
    v_user_id,
    coalesce(nullif(trim(v_profile.full_name), ''), 'Cliente FIXIS'),
    v_category,
    v_title,
    v_description,
    v_address,
    v_reference,
    p_requested_visit_at,
    p_latitude,
    p_longitude,
    extensions.ST_SetSRID(
      extensions.ST_MakePoint(p_longitude, p_latitude), 4326
    )::extensions.geography,
    'pending',
    null,
    null
  )
  returning * into v_job;

  return v_job;
end;
$$;

revoke all on function public.create_job(
  text, text, text, text, double precision, double precision, text, timestamptz
) from public, anon;
grant execute on function public.create_job(
  text, text, text, text, double precision, double precision, text, timestamptz
) to authenticated, service_role;

-- ============================================================
-- 3. PRIVATE JOB ATTACHMENTS
-- ============================================================
create table if not exists public.job_attachments (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  uploaded_by uuid not null references public.profiles(id) on delete restrict,
  attachment_type text not null,
  storage_path text not null unique,
  mime_type text not null,
  file_size_bytes bigint,
  created_at timestamptz not null default timezone('utc', now()),
  constraint job_attachments_type_check
    check (attachment_type in ('issue_initial', 'quote_support', 'before_work', 'after_work', 'dispute')),
  constraint job_attachments_size_check
    check (file_size_bytes is null or (file_size_bytes > 0 and file_size_bytes <= 8388608)),
  constraint job_attachments_mime_check
    check (mime_type in ('image/jpeg', 'image/png', 'image/webp'))
);

alter table public.job_attachments enable row level security;

revoke all on public.job_attachments from anon;
revoke insert, update, delete on public.job_attachments from authenticated;
grant select on public.job_attachments to authenticated;

drop policy if exists job_attachments_select_related on public.job_attachments;
create policy job_attachments_select_related
on public.job_attachments
for select
to authenticated
using (
  exists (
    select 1
    from public.jobs j
    where j.id = job_attachments.job_id
      and (
        j.client_id = auth.uid()
        or j.assigned_pro_id = auth.uid()
        or exists (
          select 1 from public.profiles p
          where p.id = auth.uid()
            and p.role = 'admin'
            and p.account_status = 'active'
        )
      )
  )
);

-- Dedicated private bucket. Do not reuse legacy evidencias_pro.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'job-evidence',
  'job-evidence',
  false,
  8388608,
  array['image/jpeg','image/png','image/webp']::text[]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Storage path contract:
--   <uploader_uuid>/<job_uuid>/<attachment_type>/<filename>

drop policy if exists job_evidence_insert_related on storage.objects;
create policy job_evidence_insert_related
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'job-evidence'
  and (storage.foldername(name))[1] = auth.uid()::text
  and array_length(storage.foldername(name), 1) >= 3
  and (storage.foldername(name))[3] in ('issue_initial','quote_support','before_work','after_work','dispute')
  and exists (
    select 1
    from public.jobs j
    where j.id::text = (storage.foldername(name))[2]
      and (
        j.client_id = auth.uid()
        or j.assigned_pro_id = auth.uid()
      )
  )
);

drop policy if exists job_evidence_select_related on storage.objects;
create policy job_evidence_select_related
on storage.objects
for select
to authenticated
using (
  bucket_id = 'job-evidence'
  and exists (
    select 1
    from public.jobs j
    where j.id::text = (storage.foldername(name))[2]
      and (
        j.client_id = auth.uid()
        or j.assigned_pro_id = auth.uid()
        or exists (
          select 1 from public.profiles p
          where p.id = auth.uid()
            and p.role = 'admin'
            and p.account_status = 'active'
        )
      )
  )
);

drop policy if exists job_evidence_delete_own on storage.objects;
create policy job_evidence_delete_own
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'job-evidence'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create or replace function public.register_job_attachment(
  p_job_id uuid,
  p_attachment_type text,
  p_storage_path text,
  p_mime_type text,
  p_file_size_bytes bigint default null
)
returns public.job_attachments
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_profile public.profiles;
  v_job public.jobs;
  v_attachment public.job_attachments;
  v_expected_prefix text;
  v_count integer;
begin
  v_user_id := auth.uid();
  if v_user_id is null then raise exception 'AUTHENTICATION_REQUIRED'; end if;

  select * into v_profile
  from public.profiles
  where id = v_user_id;

  if not found then raise exception 'PROFILE_NOT_FOUND'; end if;
  if v_profile.account_status <> 'active' then raise exception 'ACCOUNT_NOT_ACTIVE'; end if;

  select * into v_job
  from public.jobs
  where id = p_job_id
  for update;

  if not found then raise exception 'JOB_NOT_FOUND'; end if;

  if v_job.client_id is distinct from v_user_id
     and v_job.assigned_pro_id is distinct from v_user_id then
    raise exception 'JOB_ACCESS_DENIED';
  end if;

  if p_attachment_type not in ('issue_initial','quote_support','before_work','after_work','dispute') then
    raise exception 'INVALID_ATTACHMENT_TYPE';
  end if;

  if p_attachment_type = 'issue_initial' then
    if v_job.client_id is distinct from v_user_id then
      raise exception 'INITIAL_PHOTO_CUSTOMER_ONLY';
    end if;

    select count(*) into v_count
    from public.job_attachments
    where job_id = p_job_id and attachment_type = 'issue_initial';

    if v_count >= 3 then raise exception 'INITIAL_PHOTO_LIMIT_REACHED'; end if;
  end if;

  if p_mime_type not in ('image/jpeg','image/png','image/webp') then
    raise exception 'INVALID_ATTACHMENT_MIME';
  end if;

  if p_file_size_bytes is not null
     and (p_file_size_bytes <= 0 or p_file_size_bytes > 8388608) then
    raise exception 'ATTACHMENT_TOO_LARGE';
  end if;

  v_expected_prefix := v_user_id::text || '/' || p_job_id::text || '/' || p_attachment_type || '/';
  if p_storage_path is null or p_storage_path not like v_expected_prefix || '%' then
    raise exception 'INVALID_ATTACHMENT_PATH';
  end if;

  if not exists (
    select 1 from storage.objects o
    where o.bucket_id = 'job-evidence'
      and o.name = p_storage_path
  ) then
    raise exception 'ATTACHMENT_OBJECT_NOT_FOUND';
  end if;

  insert into public.job_attachments (
    job_id, uploaded_by, attachment_type, storage_path, mime_type, file_size_bytes
  ) values (
    p_job_id, v_user_id, p_attachment_type, p_storage_path, p_mime_type, p_file_size_bytes
  )
  returning * into v_attachment;

  return v_attachment;
end;
$$;

revoke all on function public.register_job_attachment(uuid,text,text,text,bigint) from public, anon;
grant execute on function public.register_job_attachment(uuid,text,text,text,bigint) to authenticated, service_role;

-- ============================================================
-- 4. ARRIVAL GUARD
-- Backend-authoritative using the last FIXIS Live location.
-- Thresholds for QA: <= 200 m, accuracy <= 100 m, location <= 120 sec old.
-- ============================================================
create or replace function public.mark_arrived(p_job_id uuid)
returns public.jobs
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_profile public.profiles;
  v_job public.jobs;
  v_live public.professional_live_locations;
  v_distance double precision;
begin
  v_user_id := auth.uid();

  if v_user_id is null then raise exception 'AUTHENTICATION_REQUIRED'; end if;

  select * into v_profile
  from public.profiles
  where id = v_user_id;

  if not found then raise exception 'PROFILE_NOT_FOUND'; end if;
  if v_profile.role <> 'professional' then raise exception 'NOT_A_PROFESSIONAL'; end if;
  if v_profile.verification_status <> 'approved' then raise exception 'PROFESSIONAL_NOT_APPROVED'; end if;
  if v_profile.account_status <> 'active' then raise exception 'ACCOUNT_NOT_ACTIVE'; end if;

  select * into v_job
  from public.jobs
  where id = p_job_id
  for update;

  if not found then raise exception 'JOB_NOT_FOUND'; end if;
  if v_job.assigned_pro_id is distinct from v_user_id then
    raise exception 'JOB_NOT_ASSIGNED_TO_PROFESSIONAL';
  end if;

  if v_job.status = 'arrived' then return v_job; end if;
  if v_job.status <> 'en_route' then raise exception 'INVALID_JOB_STATE'; end if;
  if v_job.service_location is null then raise exception 'SERVICE_LOCATION_REQUIRED'; end if;

  select * into v_live
  from public.professional_live_locations
  where job_id = p_job_id
    and professional_id = v_user_id
  for update;

  if not found then raise exception 'LIVE_LOCATION_NOT_FOUND'; end if;
  if v_live.updated_at < now() - interval '120 seconds' then
    raise exception 'LIVE_LOCATION_STALE';
  end if;
  if v_live.accuracy is null or v_live.accuracy > 100 then
    raise exception 'LOCATION_ACCURACY_TOO_LOW';
  end if;

  v_distance := extensions.ST_Distance(v_live.location, v_job.service_location);

  if v_distance > 200 then
    raise exception 'ARRIVAL_TOO_FAR:%', round(v_distance::numeric, 1);
  end if;

  update public.professional_live_locations
  set sharing_active = false,
      updated_at = now()
  where job_id = p_job_id
    and professional_id = v_user_id;

  update public.jobs
  set status = 'arrived',
      arrived_at = now(),
      arrival_latitude = v_live.latitude,
      arrival_longitude = v_live.longitude,
      arrival_accuracy = v_live.accuracy,
      arrival_distance_meters = v_distance
  where id = p_job_id
  returning * into v_job;

  return v_job;
end;
$$;

revoke all on function public.mark_arrived(uuid) from public, anon;
grant execute on function public.mark_arrived(uuid) to authenticated, service_role;

commit;
