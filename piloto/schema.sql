-- Piloto independiente. No modifica tablas ni notificaciones operativas.
create schema if not exists septibra_private;
revoke all on schema septibra_private from public, anon, authenticated;
create table public.piloto_instituciones (
 id uuid primary key default gen_random_uuid(), nombre text not null
);
create table public.piloto_perfiles (
 usuario_id uuid primary key references auth.users(id),
 institucion_id uuid not null references public.piloto_instituciones(id),
 nombre text not null check(length(trim(nombre))>0),
 rol text not null check(rol in ('enfermeria','limpieza','supervision')),
 activo boolean not null default true
);
create table public.piloto_pisos (
 id uuid primary key default gen_random_uuid(),
 institucion_id uuid not null references public.piloto_instituciones(id),
 nombre text not null, orden integer not null default 0,
 unique(id,institucion_id)
);
create table public.piloto_camas (
 id uuid primary key default gen_random_uuid(),
 institucion_id uuid not null references public.piloto_instituciones(id),
 piso_id uuid not null,
 habitacion text not null, cama text not null,
 estado text not null default 'lista' check(estado in ('ocupada','alta_espera','liberada','en_limpieza','lista','reservada')),
 version integer not null default 0,
 actualizado timestamptz not null default now(),
 operador_id uuid references auth.users(id), operador_nombre text,
 checklist jsonb, motivo text,
 foreign key(piso_id,institucion_id) references public.piloto_pisos(id,institucion_id),
 unique(institucion_id,piso_id,habitacion,cama)
);
create table public.piloto_movimientos (
 id uuid primary key default gen_random_uuid(),
 institucion_id uuid not null references public.piloto_instituciones(id),
 cama_id uuid not null references public.piloto_camas(id),
 anterior text not null, nuevo text not null,
 usuario_id uuid not null references auth.users(id), nombre text not null,
 fecha timestamptz not null default now(), checklist jsonb, motivo text
);
alter table public.piloto_instituciones enable row level security;
alter table public.piloto_perfiles enable row level security;
alter table public.piloto_pisos enable row level security;
alter table public.piloto_camas enable row level security;
alter table public.piloto_movimientos enable row level security;
revoke all on public.piloto_instituciones,public.piloto_perfiles,public.piloto_pisos,public.piloto_camas,public.piloto_movimientos from public,anon,authenticated;
grant select on public.piloto_instituciones,public.piloto_perfiles,public.piloto_pisos,public.piloto_camas,public.piloto_movimientos to authenticated;
grant update(estado,checklist,motivo) on public.piloto_camas to authenticated;
create policy perfil_propio on public.piloto_perfiles for select to authenticated
 using(usuario_id=(select auth.uid()) and activo);
create policy institucion_propia on public.piloto_instituciones for select to authenticated
 using(id in (select institucion_id from public.piloto_perfiles where usuario_id=(select auth.uid()) and activo));
create policy pisos_propios on public.piloto_pisos for select to authenticated
 using(institucion_id in (select institucion_id from public.piloto_perfiles where usuario_id=(select auth.uid()) and activo));
create policy camas_propias on public.piloto_camas for select to authenticated
 using(institucion_id in (select institucion_id from public.piloto_perfiles where usuario_id=(select auth.uid()) and activo));
create policy cambiar_camas_propias on public.piloto_camas for update to authenticated
 using(institucion_id in (select institucion_id from public.piloto_perfiles where usuario_id=(select auth.uid()) and activo))
 with check(institucion_id in (select institucion_id from public.piloto_perfiles where usuario_id=(select auth.uid()) and activo));
create policy historial_supervision on public.piloto_movimientos for select to authenticated
 using(institucion_id in (select institucion_id from public.piloto_perfiles where usuario_id=(select auth.uid()) and activo and rol='supervision'));
create function septibra_private.validar_cambio() returns trigger language plpgsql security invoker set search_path='' as $$
declare perfil public.piloto_perfiles;
begin
 select * into perfil from public.piloto_perfiles where usuario_id=auth.uid() and activo;
 if perfil.usuario_id is null or perfil.institucion_id<>old.institucion_id then raise exception 'Acceso no autorizado'; end if;
 if new.id<>old.id or new.institucion_id<>old.institucion_id or new.piso_id<>old.piso_id or new.habitacion<>old.habitacion or new.cama<>old.cama then raise exception 'La estructura no se modifica desde el tablero'; end if;
 if new.estado=old.estado then raise exception 'El estado no cambió'; end if;
 if perfil.rol='enfermeria' then
  if not ((old.estado in ('lista','reservada') and new.estado='ocupada') or (old.estado='ocupada' and new.estado='alta_espera') or (old.estado in ('ocupada','alta_espera') and new.estado='liberada')) then raise exception 'Cambio no permitido para Enfermería'; end if;
 elsif perfil.rol='limpieza' then
  if not ((old.estado='liberada' and new.estado='en_limpieza') or (old.estado='en_limpieza' and new.estado='lista')) then raise exception 'Cambio no permitido para Limpieza'; end if;
 elsif perfil.rol='supervision' then
  if length(trim(coalesce(new.motivo,'')))<5 then raise exception 'Indicá el motivo de la corrección'; end if;
 else raise exception 'Rol no autorizado'; end if;
 if old.estado='en_limpieza' and new.estado='lista' then
  if not coalesce(new.checklist @> '{"cama":true,"superficies":true,"bano":true,"pisos":true,"residuos":true}'::jsonb,false) then raise exception 'Completá los cinco puntos del checklist'; end if;
 else new.checklist=null; end if;
 new.operador_id=auth.uid(); new.operador_nombre=perfil.nombre;
 new.actualizado=clock_timestamp(); new.version=old.version+1;
 return new;
end $$;
-- Privilegio limitado exclusivamente a insertar auditoría de un cambio ya validado.
-- No se expone como RPC ni permite inserciones directas de historial desde clientes.
create function septibra_private.auditar_cambio() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or new.operador_id is distinct from auth.uid() then raise exception 'Sesión requerida para auditar'; end if;
 insert into public.piloto_movimientos(institucion_id,cama_id,anterior,nuevo,usuario_id,nombre,fecha,checklist,motivo)
 values(new.institucion_id,new.id,old.estado,new.estado,new.operador_id,new.operador_nombre,new.actualizado,new.checklist,new.motivo);
 return new;
end $$;
revoke all on function septibra_private.validar_cambio() from public,anon,authenticated;
revoke all on function septibra_private.auditar_cambio() from public,anon,authenticated;
create trigger validar_cambio before update on public.piloto_camas for each row execute function septibra_private.validar_cambio();
create trigger auditar_cambio after update on public.piloto_camas for each row execute function septibra_private.auditar_cambio();
create index piloto_camas_institucion on public.piloto_camas(institucion_id,piso_id);
create index piloto_movimientos_institucion on public.piloto_movimientos(institucion_id,fecha);
-- Solo datos ficticios. No crea ni invita usuarios ni registra dispositivos.
with institucion as (
 insert into public.piloto_instituciones(nombre) values('Institución demostración SEPTIBRA') returning id
), pisos as (
 insert into public.piloto_pisos(institucion_id,nombre,orden)
 select id,'Planta baja',0 from institucion union all select id,'Primer piso',1 from institucion
 returning id,institucion_id,orden
)
insert into public.piloto_camas(institucion_id,piso_id,habitacion,cama)
select p.institucion_id,p.id,((p.orden+1)*100+h)::text,((p.orden+1)*100+h)::text||letra
from pisos p cross join generate_series(1,5) h cross join (values('A'),('B')) v(letra);
