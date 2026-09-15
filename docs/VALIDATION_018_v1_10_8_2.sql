-- FIXIS PRO v1.10.8.2 — POST-MIGRATION VALIDATION (read only)

select column_name, data_type, is_nullable
from information_schema.columns
where table_schema='public' and table_name='jobs'
  and column_name in (
    'address_reference','requested_visit_at','arrived_at','arrival_latitude',
    'arrival_longitude','arrival_accuracy','arrival_distance_meters'
  )
order by ordinal_position;

select relname, relrowsecurity
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and relname='job_attachments';

select id, public, file_size_limit, allowed_mime_types
from storage.buckets where id='job-evidence';

select policyname, roles, cmd
from pg_policies
where (schemaname='public' and tablename='job_attachments')
   or (schemaname='storage' and tablename='objects' and policyname like 'job_evidence_%')
order by schemaname, policyname;

select p.proname, pg_get_function_identity_arguments(p.oid), p.prosecdef
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public'
  and p.proname in ('create_job','register_job_attachment','mark_arrived')
order by p.proname;
