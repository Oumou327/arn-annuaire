-- Vie de l'ARN : brouillons privés et projection publique des publications.
create function arn_private.arn_publication_photos_valid(p_id uuid,p_paths text[]) returns boolean language sql immutable security invoker set search_path='' as $$select p_paths is not null and cardinality(p_paths)<=4 and not exists(select 1 from unnest(p_paths) p where p is null or p !~ ('^'||p_id::text||'/[0-9a-f-]{36}[.]webp$'))$$;
revoke all on function arn_private.arn_publication_photos_valid(uuid,text[]) from public,anon,authenticated;
grant execute on function arn_private.arn_publication_photos_valid(uuid,text[]) to authenticated;
create table public.arn_publications (
 id uuid primary key default gen_random_uuid(),
 type text not null check(type in ('association','realisation','projet','actualite')),
 titre text not null check(char_length(btrim(titre)) between 3 and 140),
 resume text not null default '' check(char_length(resume)<=320),
 contenu text not null check(char_length(btrim(contenu)) between 10 and 12000),
 statut_projet text check(statut_projet in ('envisage','preparation','en_cours','termine')),
 date_evenement date,
 photos_privees text[] not null default '{}',
 photos_publiques text[] not null default '{}',
 publier boolean not null default false,
 ordre integer not null default 0 check(ordre between 0 and 9999),
 cree_le timestamptz not null default now(),
 modifie_le timestamptz not null default now(),
 publie_le timestamptz,
 check((type='projet' and statut_projet is not null) or (type<>'projet' and statut_projet is null)),
 check(arn_private.arn_publication_photos_valid(id,photos_privees)),
 check(arn_private.arn_publication_photos_valid(id,photos_publiques)),
 check((publier and cardinality(photos_publiques)=cardinality(photos_privees)) or (not publier and cardinality(photos_publiques)=0))
);
alter table public.arn_publications enable row level security;
revoke all on public.arn_publications from public,anon,authenticated;
grant select,insert,update,delete on public.arn_publications to authenticated;
create policy arn_editor_read on public.arn_publications for select to authenticated using(arn_private.arn_est_admin());
create policy arn_editor_insert on public.arn_publications for insert to authenticated with check(arn_private.arn_est_admin());
create policy arn_editor_update on public.arn_publications for update to authenticated using(arn_private.arn_est_admin()) with check(arn_private.arn_est_admin());
create policy arn_editor_delete on public.arn_publications for delete to authenticated using(arn_private.arn_est_admin());
create table public.arn_vie_publique (
 id uuid primary key references public.arn_publications(id) on delete cascade,
 type text not null,titre text not null,resume text not null,contenu text not null,
 statut_projet text,date_evenement date,photos_publiques text[] not null default '{}',
 ordre integer not null,publie_le timestamptz not null
);
alter table public.arn_vie_publique enable row level security;
revoke all on public.arn_vie_publique from public,anon,authenticated;
grant select on public.arn_vie_publique to anon,authenticated;
create policy arn_vie_read on public.arn_vie_publique for select to anon,authenticated using(true);
create function arn_private.arn_publication_dates() returns trigger language plpgsql set search_path='' as $$begin new.modifie_le:=now();if new.publier then if tg_op='INSERT' then new.publie_le:=now();elsif not old.publier then new.publie_le:=now();else new.publie_le:=old.publie_le;end if;else new.publie_le:=null;end if;return new;end$$;
revoke all on function arn_private.arn_publication_dates() from public,anon,authenticated;
create trigger arn_publication_dates before insert or update on public.arn_publications for each row execute function arn_private.arn_publication_dates();
create function arn_private.arn_sync_publication() returns trigger language plpgsql security definer set search_path='' as $$begin
 if new.publier then
  insert into public.arn_vie_publique(id,type,titre,resume,contenu,statut_projet,date_evenement,photos_publiques,ordre,publie_le) values(new.id,new.type,new.titre,new.resume,new.contenu,new.statut_projet,new.date_evenement,new.photos_publiques,new.ordre,new.publie_le)
  on conflict(id) do update set type=excluded.type,titre=excluded.titre,resume=excluded.resume,contenu=excluded.contenu,statut_projet=excluded.statut_projet,date_evenement=excluded.date_evenement,photos_publiques=excluded.photos_publiques,ordre=excluded.ordre,publie_le=excluded.publie_le;
 else delete from public.arn_vie_publique where id=new.id;end if;return new;
end$$;
revoke all on function arn_private.arn_sync_publication() from public,anon,authenticated;
create trigger arn_sync_publication after insert or update on public.arn_publications for each row execute function arn_private.arn_sync_publication();
create index arn_publications_modified on public.arn_publications(modifie_le desc);
create index arn_vie_order on public.arn_vie_publique(ordre,publie_le desc);
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('arn-vie-privee','arn-vie-privee',false,5242880,array['image/webp']),('arn-vie-publique','arn-vie-publique',true,5242880,array['image/webp']);
create policy arn_vie_media_read on storage.objects for select to authenticated using(bucket_id in ('arn-vie-privee','arn-vie-publique') and arn_private.arn_est_admin());
create policy arn_vie_media_insert on storage.objects for insert to authenticated with check(bucket_id in ('arn-vie-privee','arn-vie-publique') and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}[.]webp$' and arn_private.arn_est_admin());
create policy arn_vie_media_delete on storage.objects for delete to authenticated using(bucket_id in ('arn-vie-privee','arn-vie-publique') and arn_private.arn_est_admin());
