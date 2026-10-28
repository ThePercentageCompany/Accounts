import { PGlite } from 'npm:@electric-sql/pglite@0.5.9';
import { pgcrypto } from 'npm:@electric-sql/pglite@0.5.9/contrib/pgcrypto';

export function assert(value: unknown,message='Assertion failed'){if(!value)throw new Error(message);}
export const owner='00000000-0000-0000-0000-000000000001';
export const other='00000000-0000-0000-0000-000000000002';

export async function setup(){
  const db=new PGlite({extensions:{pgcrypto}});
  await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;
    create schema auth;create schema storage;create schema cron;create schema realtime;
    create table realtime.messages(topic text,extension text,payload jsonb,event text,private boolean);
    alter table realtime.messages enable row level security;
    create function realtime.topic() returns text language sql stable as $$ select current_setting('realtime.topic',true) $$;
    create function realtime.send(jsonb,text,text,boolean) returns void language sql as $$ insert into realtime.messages(payload,event,topic,private,extension) values($1,$2,$3,$4,'broadcast') $$;
    create table auth.users(id uuid primary key,email text,raw_app_meta_data jsonb default '{}');
    create table auth.sessions(id uuid primary key,user_id uuid,created_at timestamptz default now());
    create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    grant usage on schema auth to authenticated,service_role;grant execute on function auth.uid() to authenticated,service_role;
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create function cron.schedule(text,text,text) returns bigint language sql as $$ select 1::bigint $$;
    create publication supabase_realtime;
    insert into auth.users(id,email) values('${owner}','admin@example.test'),('${other}','other@example.test');`);
  for(const file of ['202610130001_workspace.sql','202610130002_employee_access.sql','202610130003_notifications.sql','202610130004_deletion.sql','202610140001_business_groups.sql','202610140002_group_operations_lifecycle.sql','202610170001_group_deletion.sql','202610190001_structured_business.sql','202610190002_task_storage_realtime.sql','202610190003_task_topic_isolation.sql','202610210001_payroll_notes.sql','202610220001_record_delta_sync.sql','202610270001_company_loans.sql','202610270002_payroll_deduction_treatment.sql','202610270003_task_notifications.sql','202610280001_task_tracking_numbers.sql']){
    const sql=(await Deno.readTextFile(new URL(`../../migrations/${file}`,import.meta.url))).replace('create extension if not exists pg_cron with schema pg_catalog;','');
    try {await db.exec(sql);} catch(error) {
      const position=Number((error as {position?:string}).position)||0;
      throw new Error(`Migration ${file} failed near ${sql.slice(Math.max(0,position-100),position+100)}: ${error instanceof Error ? error.message : error}`,{cause:error});
    }
  }
  await db.query(`select set_config('request.jwt.claim.sub',$1,false)`,[owner]);
  const result=await db.query<{result:{companyId:string}}>(`select public.create_workspace('Company','company_create_0001') as result`);
  return {db,company:result.rows[0].result.companyId};
}

