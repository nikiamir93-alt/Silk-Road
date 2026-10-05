-- SilkRoad full production-oriented Supabase schema extension
-- Run AFTER silkroad_supabase_schema.sql

-- Application journey: a separate operational stage that drives the visual road from start to visa.
alter table public.applications add column if not exists journey_stage text not null default 'draft';
alter table public.applications drop constraint if exists applications_journey_stage_check;
alter table public.applications add constraint applications_journey_stage_check check (journey_stage in ('draft','documents','submitted','under_review','accepted','visa'));
create index if not exists applications_journey_stage_idx on public.applications(journey_stage);

alter table public.profiles add column if not exists date_of_birth date;
alter table public.profiles add column if not exists nationality text;
alter table public.profiles add column if not exists city text;
alter table public.profiles add column if not exists education_level text;
alter table public.profiles add column if not exists major text;
alter table public.profiles add column if not exists previous_university text;
alter table public.profiles add column if not exists gpa numeric(5,2);
alter table public.profiles add column if not exists graduation_year integer;
alter table public.profiles add column if not exists language_certificate text;
alter table public.profiles add column if not exists settings jsonb not null default '{}'::jsonb;

alter table public.universities add column if not exists website_url text;
alter table public.universities add column if not exists country text default 'China';
alter table public.universities add column if not exists programs jsonb not null default '[]'::jsonb;

alter table public.exhibitions add column if not exists category text;
alter table public.exhibitions add column if not exists venue text;
alter table public.exhibitions add column if not exists website_url text;
alter table public.exhibitions add column if not exists description text;

alter table public.flights add column if not exists flight_number text;
alter table public.flights add column if not exists stops integer not null default 0;
alter table public.flights add column if not exists baggage text;
alter table public.flights add column if not exists cabin text;
alter table public.flights add column if not exists provider text;
alter table public.flights add column if not exists external_id text;
alter table public.flights add column if not exists fetched_at timestamptz;

alter table public.orders add column if not exists metadata jsonb not null default '{}'::jsonb;
alter table public.payments add column if not exists metadata jsonb not null default '{}'::jsonb;

-- Allow flight reservations as orders.
alter table public.orders drop constraint if exists orders_order_type_check;
alter table public.orders add constraint orders_order_type_check check (order_type in ('ticket','booth','flight'));

-- Admin helper: security-definer avoids recursive RLS checks on profiles.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin');
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

-- Admin can manage operational data; users retain their own-data policies from the base schema.
drop policy if exists "universities_admin_all" on public.universities;
create policy "universities_admin_all" on public.universities for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "deadlines_admin_all" on public.deadlines;
create policy "deadlines_admin_all" on public.deadlines for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "exhibitions_admin_all" on public.exhibitions;
create policy "exhibitions_admin_all" on public.exhibitions for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "flights_admin_all" on public.flights;
create policy "flights_admin_all" on public.flights for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "profiles_admin_read" on public.profiles;
create policy "profiles_admin_read" on public.profiles for select to authenticated using (public.is_admin() or id = auth.uid());
drop policy if exists "profiles_admin_update" on public.profiles;
create policy "profiles_admin_update" on public.profiles for update to authenticated using (public.is_admin() or id = auth.uid()) with check (public.is_admin() or id = auth.uid());

drop policy if exists "applications_admin_all" on public.applications;
create policy "applications_admin_all" on public.applications for all to authenticated using (public.is_admin() or user_id = auth.uid()) with check (public.is_admin() or user_id = auth.uid());

drop policy if exists "documents_admin_all" on public.documents;
create policy "documents_admin_all" on public.documents for all to authenticated using (public.is_admin() or user_id = auth.uid()) with check (public.is_admin() or user_id = auth.uid());

drop policy if exists "orders_admin_all" on public.orders;
create policy "orders_admin_all" on public.orders for all to authenticated using (public.is_admin() or user_id = auth.uid()) with check (public.is_admin() or user_id = auth.uid());

drop policy if exists "payments_admin_all" on public.payments;
create policy "payments_admin_all" on public.payments for all to authenticated using (public.is_admin() or user_id = auth.uid()) with check (public.is_admin() or user_id = auth.uid());

drop policy if exists "messages_admin_all" on public.messages;
create policy "messages_admin_all" on public.messages for all to authenticated using (public.is_admin() or user_id = auth.uid()) with check (public.is_admin() or user_id = auth.uid());

-- Realtime for support chat and operational changes.
alter table public.messages replica identity full;
alter table public.applications replica identity full;
alter table public.orders replica identity full;

do $$
begin
  begin alter publication supabase_realtime add table public.messages; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.applications; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.orders; exception when duplicate_object then null; end;
end $$;

-- Useful indexes
create index if not exists universities_city_idx on public.universities(city);
create index if not exists universities_active_idx on public.universities(is_active);
create index if not exists exhibitions_start_date_idx on public.exhibitions(start_date);
create index if not exists flights_route_departure_idx on public.flights(origin,destination,departure_at);
create index if not exists payments_user_created_idx on public.payments(user_id,created_at desc);

-- Optional starter university records. These are factual institution/location records only;
-- current tuition/rank/deadline data should be maintained from official sources in the admin panel.
insert into public.universities (name,name_en,city,province,country,is_active)
select * from (values
 ('دانشگاه تسینگ‌هوا','Tsinghua University','پکن','Beijing','China',true),
 ('دانشگاه پکن','Peking University','پکن','Beijing','China',true),
 ('دانشگاه ژجیانگ','Zhejiang University','هانگژو','Zhejiang','China',true),
 ('دانشگاه فودان','Fudan University','شانگهای','Shanghai','China',true),
 ('دانشگاه شانگهای جیائوتونگ','Shanghai Jiao Tong University','شانگهای','Shanghai','China',true),
 ('دانشگاه نانجینگ','Nanjing University','نانجینگ','Jiangsu','China',true),
 ('دانشگاه ووهان','Wuhan University','ووهان','Hubei','China',true),
 ('مؤسسه فناوری هاربین','Harbin Institute of Technology','هاربین','Heilongjiang','China',true)
) as v(name,name_en,city,province,country,is_active)
where not exists (select 1 from public.universities u where u.name_en=v.name_en);
