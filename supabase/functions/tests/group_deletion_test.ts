import {setup,owner,other,assert} from './_fixture.ts';

Deno.test('group deletion requires admin, rejects entities and permits retry after deletion',async()=>{
  const {db}=await setup();
  try {
    const result=await db.query<{g:{id:string}}>(`select public.create_business_group('Delete test','group_delete_test01') as g`);
    const group=result.rows[0].g.id;
    let rejected=false;
    try {await db.query(`select public.delete_business_group($1,$2)`,[group,other]);}catch(e){rejected=String(e).includes('ADMIN_REQUIRED');}
    assert(rejected);
    const entity=await db.query<{e:{companyId:string}}>(`select public.create_country_entity($1,'Entity','AE','AED','Asia/Dubai','','delete_entity_test01') as e`,[group]);
    rejected=false;
    try{await db.query(`select public.delete_business_group($1,$2)`,[group,owner]);}catch(e){rejected=String(e).includes('GROUP_NOT_EMPTY');}
    assert(rejected);
    const id=entity.rows[0].e.companyId;
    await db.query(`select public.begin_workspace_deletion($1,$2)`,[id,owner]);
    await db.query(`select public.complete_workspace_deletion($1,$2)`,[id,owner]);
    await db.query(`select public.delete_business_group($1,$2)`,[group,owner]);
    assert((await db.query(`select * from public.business_groups where id=$1`,[group])).rows.length===0);
    assert((await db.query(`select * from public.group_memberships where group_id=$1`,[group])).rows.length===0);
    await db.query(`select public.delete_business_group($1,$2)`,[group,owner]);
  }finally{await db.close();}
});
