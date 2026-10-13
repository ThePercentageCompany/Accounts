// deno-lint-ignore-file no-explicit-any
import { BusinessService } from './domain/business-service.js';
import { TABLES } from './domain/company-schema.js';
import { ApiError, requireThat } from './domain/errors.js';
import { digest } from './domain/crypto.js';
import { hasLedgerSources, ledgerStatus } from './domain/ledger-status.js';
import { SECTION_TABLES, CHILDREN, SECTIONS, scopeFor, visible, projectRecord } from './domain/employee-policy.js';

export function databaseError(error: any): never {
  const known = ['VERSION_CONFLICT','IDEMPOTENCY_CONFLICT','WORKSPACE_CHANGED','COMPANY_NOT_FOUND','INVALID_COMPANY'];
  const code = known.find(k => error?.message?.includes(k));
  throw new ApiError(code ? 409 : 503, code ?? 'SERVICE_UNAVAILABLE', code === 'VERSION_CONFLICT'
    ? 'Workspace changed. Refresh and retry the same operation.' : code ? 'Workspace access or operation changed.' : 'Database unavailable. Retry without discarding changes.');
}

export class RecordStore {
  cache = new Map<string, any[]>();
  changes = new Map<string, any>();
  constructor(public db: any, public companyId: string) {}
  table(name: string) {
    const table = TABLES.find((t: any) => t.title === name);
    requireThat(table, 403, 'TABLE_FORBIDDEN', 'This record section is unavailable.');
    return table;
  }
  async read(companyId: string, names: string[]) {
    requireThat(companyId === this.companyId, 403, 'WORKSPACE_CHANGED', 'Workspace changed.');
    await Promise.all([...new Set(names)].map(async name => {
      this.table(name);
      if (this.cache.has(name)) return;
      const rows: any[] = [];
      for (let offset = 0; ; offset += 1000) {
        const { data, error } = await this.db.from('business_records').select('ordinal,payload')
          .eq('company_id',companyId).eq('section',name).order('ordinal').range(offset,offset+999);
        if (error) databaseError(error);
        rows.push(...data.map((r: any) => ({ ...r.payload, _row: Number(r.ordinal) })));
        if (data.length < 1000) break;
        requireThat(rows.length < 50000, 503, 'REPORT_CAPACITY', 'This report needs a narrower range.');
      }
      this.cache.set(name, rows);
    }));
    return Object.fromEntries(names.map(name => [name,this.cache.get(name)!]));
  }
  readReferences(companyId: string, names: string[]) { return this.read(companyId,names); }
  async write(companyId: string, section: string, ordinal: number, values: any) {
    const rows = (await this.read(companyId,[section]))[section];
    const old = rows.find((r: any) => r._row === ordinal);
    const payload = { ...old, ...values }; delete payload._row;
    requireThat(payload.companyId === companyId && payload.recordId,403,'RECORD_IDENTITY_MISMATCH','Invalid record identity.');
    const key = `${section}:${payload.recordId}`, previous = this.changes.get(key);
    this.changes.set(key, { section,recordId:payload.recordId,ordinal,version:payload.recordVersion,
      expectedVersion:previous?.expectedVersion ?? old?.recordVersion ?? 0,payload });
    if (old) Object.assign(old,payload); else rows.push({...payload,_row:ordinal});
  }
  async writeBatch(companyId: string, writes: any[]) {
    for (const write of writes) await this.write(companyId,write.table,write.row,write.values);
  }
}

export async function workspace(db: any,user: any,companyId: string,keys: string[] = []) {
  const { data: company,error: ce } = await db.from('companies').select('*').eq('id',companyId).is('deleted_at',null).maybeSingle();
  if (ce) databaseError(ce);
  const { data: member,error: me } = await db.from('company_memberships').select('*').eq('company_id',companyId)
    .eq('user_id',user.id).eq('status','ACTIVE').maybeSingle();
  if (me) databaseError(me);
  requireThat(company && member,403,'WORKSPACE_CHANGED','Company access is unavailable.');
  const { data: grants,error: ge } = await db.from('section_permissions').select('*').eq('company_id',companyId).eq('user_id',user.id);
  if (ge) databaseError(ge);
  const admin = member.role === 'ADMIN';
  requireThat(admin || member.access_valid_after === '-infinity' ||
    user.sessionCreatedAt && new Date(user.sessionCreatedAt).getTime() >= new Date(member.access_valid_after).getTime(),
    401,'EMPLOYEE_SESSION_INVALID','Your employee access changed. Sign in again.');
  const principal: any = { companyId,employeeId:member.employee_id,role:admin ? 'ADMIN' : member.role,name:user.user_metadata?.full_name ?? '',
    permissions:Object.fromEntries(grants.map((g: any) => [g.section,g.scope === 'SELF' || scopeFor(member.role,g.section) === 'SELF' ? 'SELF' : 'COMPANY'])) };
  principal.allowedSections = admin ? [...SECTIONS] : SECTIONS.filter((s: string) => principal.permissions[s]);
  principal.writableSections = admin ? [...SECTIONS] : grants.filter((g: any) => g.can_write && principal.permissions[g.section] === 'COMPANY').map((g: any) => g.section);
  const opKeys = keys.map(key => digest(`business:${companyId}:${key}`));
  const { data: ops,error: oe } = await db.rpc('load_workspace_operations',{p_company:companyId,p_keys:opKeys});
  if (oe) databaseError(oe);
  let state: any = { companies:{[companyId]:{...company.configuration,id:companyId,name:company.name,stage:'READY',businessOps:ops ?? {}}} };
  const registry = {
    read:async () => ({state:structuredClone(state)}),
    transact:async (update: any) => {const next=structuredClone(state); const result=update(next);state=next;return result;},
  };
  const records = new RecordStore(db,companyId);
  const authorizeWrite = async (_token: any,_id: string,table: string,change?: any) => {
    if (admin) return;
    const section = SECTION_TABLES[table as keyof typeof SECTION_TABLES];
    if (!change && ['Tasks','TaskComments'].includes(table) && principal.permissions.Tasks) return;
    const task = table === 'Tasks' && principal.permissions.Tasks && change?.old?.employeeId === principal.employeeId &&
      Object.keys(change.values ?? {}).every(k => k === 'status') && change.action === 'update';
    const comment = table === 'TaskComments' && principal.permissions.Tasks && change?.action === 'create';
    if (task) return;
    if (comment) {
      const parent = (await records.read(companyId,['Tasks'])).Tasks.find((r: any) => r.recordId === change.values.taskId);
      requireThat(visible(principal,'Tasks',parent),403,'WRITE_FORBIDDEN','Task is unavailable.'); return;
    }
    requireThat(section && principal.writableSections.includes(section),403,'WRITE_FORBIDDEN','Edit access is not assigned to you.');
  };
  const accounts: any = {registry,companyOwner:(_state: any,_token: any,id: string) => {
    requireThat(id===companyId,403,'WORKSPACE_CHANGED','Workspace changed.');return {id:admin ? user.id : member.employee_id};
  }};
  const business = new (BusinessService as any)({accounts,records,authorizeWrite});
  const canRead = (section: string) => requireThat(admin || principal.permissions[section],403,'SECTION_FORBIDDEN','Section access is not assigned to you.');
  const read = async (table: string,includeDeleted = false) => {
    const section=SECTION_TABLES[table as keyof typeof SECTION_TABLES];
    requireThat(section,403,'TABLE_FORBIDDEN','This record section is unavailable.');canRead(section);
    if (admin && table !== 'Employees') return business.list('',companyId,table,{includeDeleted});
    const names=[table,...(CHILDREN[table as keyof typeof CHILDREN] ? [CHILDREN[table as keyof typeof CHILDREN][0]] : [])];
    const rows=await records.read(companyId,names);
    const journals=hasLedgerSources(table)?(await records.read(companyId,['Journals'])).Journals:[];
    return rows[table].filter((r: any) => admin ? includeDeleted || !r.isDeleted : visible(principal,table,r,rows)).map((r: any) => {
      const result=admin ? {...r} : projectRecord(principal,table,r);
      const posting=ledgerStatus(table,r,journals,companyId);if(posting!==undefined)result.ledgerStatus=posting;
      delete result._row;delete result.idempotencyKey;return result;
    });
  };
  const commit = async () => {
    const configuration={...state.companies[companyId]};
    const operations=configuration.businessOps;for (const k of ['id','name','stage','businessOps','businessWrite']) delete configuration[k];
    if (!records.changes.size && JSON.stringify(configuration)===JSON.stringify(company.configuration)) return;
    const {error}=await db.rpc('commit_workspace',{p_company:companyId,p_actor:user.id,p_revision:company.revision,
      p_changes:[...records.changes.values()],p_configuration:configuration,p_operations:operations,
      p_audit:[...records.changes.values()].map(c=>({section:c.section,recordId:c.recordId,version:c.version}))});
    if (error) databaseError(error);
  };
  const assertAccess = async () => {
    const {data:live,error}=await db.from('company_memberships').select('*').eq('company_id',companyId).eq('user_id',user.id).eq('status','ACTIVE').maybeSingle();
    if(error)databaseError(error);
    requireThat(live&&live.role===member.role&&live.employee_id===member.employee_id,
      401,'EMPLOYEE_SESSION_INVALID','Workspace access changed. Sign in again.');
    requireThat(admin||live.access_valid_after==='-infinity'||user.sessionCreatedAt&&
      Date.parse(user.sessionCreatedAt)>=Date.parse(live.access_valid_after),401,'EMPLOYEE_SESSION_INVALID','Employee access was reset. Sign in again.');
    if(!admin){
      const {data:current,error:pe}=await db.from('section_permissions').select('*').eq('company_id',companyId).eq('user_id',user.id);if(pe)databaseError(pe);
      const signature=(rows:any[])=>JSON.stringify(rows.map(r=>[r.section,r.scope,r.can_write]).sort());
      requireThat(signature(current)===signature(grants),403,'WORKSPACE_CHANGED','Your permissions changed. Refresh the workspace.');
    }
  };
  return {db,user,company,member,principal,admin,records,business,registry,canRead,read,commit,assertAccess};
}
