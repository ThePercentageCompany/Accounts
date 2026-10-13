-- Fresh deployment requested: discard the unused operator migration interface.
drop function if exists public.import_workspace_snapshot(jsonb,jsonb,text);
drop table if exists private.cutover_imports;
