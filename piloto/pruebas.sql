begin;
create temporary table piloto_test_ids as select gen_random_uuid() as enfermeria,gen_random_uuid() as limpieza,gen_random_uuid() as supervision,gen_random_uuid() as ajeno,gen_random_uuid() as institucion,gen_random_uuid() as otra,gen_random_uuid() as piso,gen_random_uuid() as cama;
grant select on piloto_test_ids to authenticated,anon;
insert into auth.users(id) select enfermeria from piloto_test_ids union all select limpieza from piloto_test_ids union all select supervision from piloto_test_ids union all select ajeno from piloto_test_ids;
insert into public.piloto_instituciones(id,nombre) select institucion,'TEST' from piloto_test_ids union all select otra,'TEST OTRA' from piloto_test_ids;
insert into public.piloto_perfiles(usuario_id,institucion_id,nombre,rol)
select enfermeria,institucion,'Enfermera prueba','enfermeria' from piloto_test_ids union all
select limpieza,institucion,'Limpieza prueba','limpieza' from piloto_test_ids union all
select supervision,institucion,'Supervisión prueba','supervision' from piloto_test_ids union all
select ajeno,otra,'Otra institución','enfermeria' from piloto_test_ids;
insert into public.piloto_pisos(id,institucion_id,nombre) select piso,institucion,'TEST' from piloto_test_ids;
insert into public.piloto_camas(id,institucion_id,piso_id,habitacion,cama) select cama,institucion,piso,'TEST','TEST' from piloto_test_ids;
set local role anon;
do $$ begin
 begin perform * from public.piloto_camas; raise exception 'FALLO: anon puede leer';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claim.sub',(select enfermeria::text from piloto_test_ids),true);
set local role authenticated;
do $$ declare n integer; begin
 select count(*) into n from public.piloto_camas; if n<>1 then raise exception 'FALLO aislamiento'; end if;
 update public.piloto_camas set estado='ocupada' where id=(select cama from piloto_test_ids) and version=0;
 if not found then raise exception 'FALLO transición válida'; end if;
 begin update public.piloto_camas set estado='lista' where id=(select cama from piloto_test_ids); raise exception 'FALLO permiso enfermería'; exception when raise_exception then if SQLERRM='FALLO permiso enfermería' then raise; end if; end;
 update public.piloto_camas set estado='liberada' where id=(select cama from piloto_test_ids);
 update public.piloto_camas set estado='ocupada' where id=(select cama from piloto_test_ids) and version=0;
 if found then raise exception 'FALLO versión obsoleta'; end if;
end $$;
reset role;
select set_config('request.jwt.claim.sub',(select limpieza::text from piloto_test_ids),true);
set local role authenticated;
do $$ begin
 update public.piloto_camas set estado='en_limpieza' where id=(select cama from piloto_test_ids);
 begin update public.piloto_camas set estado='lista' where id=(select cama from piloto_test_ids); raise exception 'FALLO checklist'; exception when raise_exception then if SQLERRM='FALLO checklist' then raise; end if; end;
 update public.piloto_camas set estado='lista',checklist='{"cama":true,"superficies":true,"bano":true,"pisos":true,"residuos":true}' where id=(select cama from piloto_test_ids);
 begin update public.piloto_camas set estado='ocupada' where id=(select cama from piloto_test_ids); raise exception 'FALLO permiso limpieza'; exception when raise_exception then if SQLERRM='FALLO permiso limpieza' then raise; end if; end;
 begin insert into public.piloto_movimientos(institucion_id,cama_id,anterior,nuevo,usuario_id,nombre) select institucion,cama,'lista','ocupada',limpieza,'Falso' from piloto_test_ids; raise exception 'FALLO auditoría'; exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claim.sub',(select ajeno::text from piloto_test_ids),true);
set local role authenticated;
do $$ begin
 if exists(select 1 from public.piloto_camas) then raise exception 'FALLO lectura ajena'; end if;
 update public.piloto_camas set estado='ocupada' where id=(select cama from piloto_test_ids);
 if found then raise exception 'FALLO escritura ajena'; end if;
end $$;
reset role;
select set_config('request.jwt.claim.sub',(select supervision::text from piloto_test_ids),true);
set local role authenticated;
do $$ begin
 begin update public.piloto_camas set estado='reservada' where id=(select cama from piloto_test_ids); raise exception 'FALLO motivo'; exception when raise_exception then if SQLERRM='FALLO motivo' then raise; end if; end;
 update public.piloto_camas set estado='reservada',motivo='Corrección de prueba' where id=(select cama from piloto_test_ids);
 if (select count(*) from public.piloto_movimientos)<>5 then raise exception 'FALLO historial'; end if;
end $$;
reset role;
rollback;
select 'OK: anonimato, institución, roles, checklist, auditoría, motivo y versión' as pruebas;