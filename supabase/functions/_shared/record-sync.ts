// deno-lint-ignore-file no-explicit-any
import { digest } from './domain/crypto.js';
import { requireThat } from './domain/errors.js';
import { CHILDREN, SECTION_TABLES, visible } from './domain/employee-policy.js';
import { hasLedgerSources } from './domain/ledger-status.js';
import { databaseError } from './workspace.ts';

export const recordSyncScope = (ctx:any) => digest(JSON.stringify([
  ctx.company.id,ctx.user.id,ctx.member.employee_id,ctx.member.role,ctx.member.access_valid_after,
  Object.entries(ctx.principal.permissions).sort(),[...ctx.principal.writableSections].sort(),
]));

export async function recordSyncAnchor(ctx:any) {
  const {data,error}=await ctx.db.rpc('record_sync_head',{p_company:ctx.company.id,p_actor:ctx.user.id});
  if(error?.code==='PGRST202'||error?.code==='42883')return {};
  if(error)databaseError(error);
  return {syncCursor:data,syncScope:recordSyncScope(ctx)};
}

export async function recordDelta(ctx:any,table:string,query:URLSearchParams) {
  ctx.records.table(table);ctx.canRead((SECTION_TABLES as Record<string,string>)[table]);
  const after=query.get('after')??'',through=query.get('through');
  const cursor=(value:string)=>/^\d{1,19}$/.test(value)&&BigInt(value)<=9223372036854775807n;
  requireThat(cursor(after)&&(!through||cursor(through)),400,'INVALID_CURSOR','Use a valid server cursor.');
  if(query.get('scope')!==recordSyncScope(ctx))return {reset:true};
  const parent=(CHILDREN as any)[table]?.[0];
  const {data:page,error}=await ctx.db.rpc('record_delta_page',{
    p_company:ctx.company.id,p_actor:ctx.user.id,p_after:after,p_through:through,p_limit:500,
    p_sections:[table,...(parent?[parent]:[]),...(hasLedgerSources(table)?['Journals']:[])],
  });
  if(error)databaseError(error);
  if(page.reset)return {reset:true};
  const changes=page.changes as any[];
  // Parent reassignment can hide unchanged children. Reset the authorized
  // collection instead of exposing IDs of children the actor can no longer see.
  if(parent&&changes.some(c=>c.section===parent))return {reset:true};
  const ids=new Set<string>(changes.filter(c=>c.section===table).map(c=>c.record_id));
  if(hasLedgerSources(table)) {
    for(const change of changes.filter(c=>c.section==='Journals')) {
      for(const row of [change.old_payload,change.new_payload])if(row?.sourceId)ids.add(row.sourceId);
      if(table==='Assets')return {reset:true};
    }
  }
  const upserts:any[]=[],removed:any[]=[];
  if(ids.size) {
    const {data,error}=await ctx.db.from('business_records').select('ordinal,payload')
      .eq('company_id',ctx.company.id).eq('section',table).in('record_id',[...ids]);
    if(error)databaseError(error);
    // Reuse the existing authorized projection and derived ledger fields with
    // a bounded candidate set, preserving the normal records endpoint contract.
    ctx.records.cache.set(table,data.map((r:any)=>({...r.payload,_row:Number(r.ordinal)})));
    const allowed=await ctx.read(table);
    upserts.push(...allowed);
    const present=new Set(allowed.map((r:any)=>r.recordId));
    const parents=parent?await ctx.records.read(ctx.company.id,[parent]):{};
    for(const id of ids) {
      if(present.has(id))continue;
      const history=changes.filter(c=>c.section===table&&c.record_id===id);
      const wasVisible=ctx.admin||history.some(c=>
        visible(ctx.principal,table,c.old_payload,parents)||visible(ctx.principal,table,c.new_payload,parents));
      if(wasVisible&&history.length) {
        const latest=history.at(-1);
        removed.push({recordId:id,recordVersion:Math.max(0,...history.map(c=>
          Number(c.new_payload?.recordVersion??c.old_payload?.recordVersion??0)))+
          (latest.new_payload?0:1)});
      }
    }
  }
  return {reset:false,records:upserts,removed,cursor:page.cursor,through:page.head,
    hasMore:page.hasMore,syncScope:recordSyncScope(ctx)};
}
