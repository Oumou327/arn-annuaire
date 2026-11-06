-- Formateurs et avis après service. Les évaluations ARN restent distinctes des avis clients.
create table public.arn_formateurs (
 id uuid primary key default gen_random_uuid(),
 prenom text not null check(char_length(btrim(prenom)) between 1 and 60),
 nom text not null check(char_length(btrim(nom)) between 1 and 60),
 telephone text not null check(telephone ~ '^[+0-9() .-]{6,30}$' and char_length(regexp_replace(telephone,'[^0-9]','','g')) between 6 and 15),
 email text not null check(char_length(email)<=150 and email ~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'),
 domaine text not null default '' check(char_length(domaine)<=100),
 presentation text not null default '' check(char_length(presentation)<=1200),
 photo_path text check(photo_path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}[.]webp$'),
 note_arn smallint check(note_arn between 1 and 5),
 cree_le timestamptz not null default now()
);
alter table public.arn_formateurs enable row level security;
revoke all on public.arn_formateurs from public,anon,authenticated;
grant select on public.arn_formateurs to anon,authenticated;
grant insert,update,delete on public.arn_formateurs to authenticated;
create policy arn_formateurs_public on public.arn_formateurs for select to anon,authenticated using(true);
create policy arn_formateurs_insert on public.arn_formateurs for insert to authenticated with check(arn_private.arn_est_admin());
create policy arn_formateurs_update on public.arn_formateurs for update to authenticated using(arn_private.arn_est_admin()) with check(arn_private.arn_est_admin());
create policy arn_formateurs_delete on public.arn_formateurs for delete to authenticated using(arn_private.arn_est_admin());

create table public.arn_avis_invitations (
 code uuid primary key default gen_random_uuid(),
 professionnel_id uuid references public.arn_candidatures(id) on delete cascade,
 formateur_id uuid references public.arn_formateurs(id) on delete cascade,
 cree_par uuid not null default auth.uid() references auth.users(id),
 cree_le timestamptz not null default now(),
 expire_le timestamptz not null default (now()+interval '30 days'),
 utilise_le timestamptz,
 revoquee boolean not null default false,
 check(num_nonnulls(professionnel_id,formateur_id)=1)
);
create index arn_avis_inv_prof on public.arn_avis_invitations(professionnel_id);
create index arn_avis_inv_form on public.arn_avis_invitations(formateur_id);
create index arn_avis_inv_admin on public.arn_avis_invitations(cree_par);
alter table public.arn_avis_invitations enable row level security;
revoke all on public.arn_avis_invitations from public,anon,authenticated;
grant select on public.arn_avis_invitations to authenticated;
grant insert(professionnel_id,formateur_id),update(revoquee) on public.arn_avis_invitations to authenticated;
create policy arn_inv_read on public.arn_avis_invitations for select to authenticated using(arn_private.arn_est_admin());
create policy arn_inv_create on public.arn_avis_invitations for insert to authenticated with check(arn_private.arn_est_admin() and (professionnel_id is null or exists(select 1 from public.arn_profils_publics p where p.id=professionnel_id)));
create policy arn_inv_revoke on public.arn_avis_invitations for update to authenticated using(arn_private.arn_est_admin()) with check(arn_private.arn_est_admin());

create table public.arn_avis_votes (
 invitation_code uuid primary key references public.arn_avis_invitations(code) on delete cascade,
 note smallint not null check(note between 1 and 5),
 cree_le timestamptz not null default now()
);
alter table public.arn_avis_votes enable row level security;
revoke all on public.arn_avis_votes from public,anon,authenticated;
grant select on public.arn_avis_votes to authenticated;
create policy arn_votes_admin on public.arn_avis_votes for select to authenticated using(arn_private.arn_est_admin());

create table public.arn_avis_stats (
 id uuid primary key default gen_random_uuid(),
 professionnel_id uuid unique references public.arn_candidatures(id) on delete cascade,
 formateur_id uuid unique references public.arn_formateurs(id) on delete cascade,
 nombre integer not null check(nombre>0),
 total bigint not null check(total>=nombre and total<=nombre::bigint*5),
 check(num_nonnulls(professionnel_id,formateur_id)=1)
);
alter table public.arn_avis_stats enable row level security;
revoke all on public.arn_avis_stats from public,anon,authenticated;
grant select on public.arn_avis_stats to anon,authenticated;
create policy arn_stats_public on public.arn_avis_stats for select to anon,authenticated using(formateur_id is not null or exists(select 1 from public.arn_profils_publics p where p.id=professionnel_id));

-- Un seul vote par lien, consommé sous verrou dans la même transaction que la moyenne.
create function arn_private.arn_deposer_avis(p_code uuid,p_note integer) returns boolean language plpgsql security definer set search_path='' as $$
declare invitation public.arn_avis_invitations%rowtype;
begin
 if p_note is null or p_note not between 1 and 5 then raise exception 'Choisissez une note de 1 à 5 étoiles.'; end if;
 select * into invitation from public.arn_avis_invitations where code=p_code for update;
 if not found or invitation.revoquee or invitation.utilise_le is not null or invitation.expire_le<=now() then raise exception 'Lien invalide, expiré ou déjà utilisé.'; end if;
 if invitation.professionnel_id is not null and not exists(select 1 from public.arn_profils_publics where id=invitation.professionnel_id) then raise exception 'Ce profil n’est plus disponible.'; end if;
 if invitation.formateur_id is not null and not exists(select 1 from public.arn_formateurs where id=invitation.formateur_id) then raise exception 'Ce formateur n’est plus disponible.'; end if;
 insert into public.arn_avis_votes(invitation_code,note) values(p_code,p_note);
 update public.arn_avis_invitations set utilise_le=now() where code=p_code;
 if invitation.professionnel_id is not null then
  insert into public.arn_avis_stats(professionnel_id,nombre,total) values(invitation.professionnel_id,1,p_note)
  on conflict(professionnel_id) do update set nombre=arn_avis_stats.nombre+1,total=arn_avis_stats.total+excluded.total;
 else
  insert into public.arn_avis_stats(formateur_id,nombre,total) values(invitation.formateur_id,1,p_note)
  on conflict(formateur_id) do update set nombre=arn_avis_stats.nombre+1,total=arn_avis_stats.total+excluded.total;
 end if;
 return true;
end $$;
revoke all on function arn_private.arn_deposer_avis(uuid,integer) from public,anon,authenticated;
grant usage on schema arn_private to anon;
grant execute on function arn_private.arn_deposer_avis(uuid,integer) to anon,authenticated;
create function public.arn_deposer_avis(p_code uuid,p_note integer) returns boolean language sql security invoker set search_path='' as $$select arn_private.arn_deposer_avis(p_code,p_note)$$;
revoke all on function public.arn_deposer_avis(uuid,integer) from public,anon,authenticated;
grant execute on function public.arn_deposer_avis(uuid,integer) to anon,authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('arn-formateurs','arn-formateurs',true,5242880,array['image/webp']);
create policy arn_trainer_photo_read on storage.objects for select to anon,authenticated using(bucket_id='arn-formateurs');
create policy arn_trainer_photo_insert on storage.objects for insert to authenticated with check(bucket_id='arn-formateurs' and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}[.]webp$' and arn_private.arn_est_admin());
create policy arn_trainer_photo_delete on storage.objects for delete to authenticated using(bucket_id='arn-formateurs' and arn_private.arn_est_admin());

create function arn_private.arn_lire_avis(p_code uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('type',case when i.formateur_id is null then 'professionnel' else 'formateur' end,'nom',coalesce(p.nom_complet,concat_ws(' ',f.prenom,f.nom))) from public.arn_avis_invitations i left join public.arn_profils_publics p on p.id=i.professionnel_id left join public.arn_formateurs f on f.id=i.formateur_id where i.code=p_code and not i.revoquee and i.utilise_le is null and i.expire_le>now() and (p.id is not null or f.id is not null)
$$;
revoke all on function arn_private.arn_lire_avis(uuid) from public,anon,authenticated;
grant execute on function arn_private.arn_lire_avis(uuid) to anon,authenticated;
create function public.arn_lire_avis(p_code uuid) returns jsonb language sql stable security invoker set search_path='' as $$select arn_private.arn_lire_avis(p_code)$$;
revoke all on function public.arn_lire_avis(uuid) from public,anon,authenticated;
grant execute on function public.arn_lire_avis(uuid) to anon,authenticated;
