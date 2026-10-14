import { databaseError } from './workspace.ts';
// One Postgres snapshot aggregates only directly authorized entity ledgers.
export async function groupOverview(db:any,userId:string,companyId?:string) {
  const {data,error}=await db.rpc('business_group_overview',{p_actor:userId,p_company:companyId??null});
  if(error)databaseError(error);
  return data;
}
