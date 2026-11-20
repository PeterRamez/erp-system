import { NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

const url=process.env.NEXT_PUBLIC_SUPABASE_URL;
const anon=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
const service=process.env.SUPABASE_SERVICE_ROLE_KEY;
export async function POST(req:Request){
 if(!url||!anon||!service)return NextResponse.json({error:'Server Supabase credentials are not configured.'},{status:503});
 const token=req.headers.get('authorization')?.replace(/^Bearer\s+/i,'');
 if(!token)return NextResponse.json({error:'Authentication required.'},{status:401});
 const userClient=createClient(url,anon,{auth:{persistSession:false}});
 const {data:{user},error:userErr}=await userClient.auth.getUser(token);
 if(userErr||!user)return NextResponse.json({error:'Invalid session.'},{status:401});
 // Auth is verified with the user's bearer token first. Profile verification
 // is then performed server-side using the service-role client to avoid RLS
 // recursion/permission issues in self-profile policies.
 const admin=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}});
 const {data:adminProfile,error:profileErr}=await admin.from('profiles').select('organization_id,role,active').eq('id',user.id).maybeSingle();
 if(profileErr)return NextResponse.json({error:'Could not verify your admin profile.',diagnostic:{code:profileErr.code,message:profileErr.message,hint:profileErr.hint}},{status:403});
 if(!adminProfile)return NextResponse.json({error:'No profile row found for the signed-in account.',diagnostic:'profile_missing'},{status:403});
 const normalizedRole=String(adminProfile.role||'').trim().toLowerCase();
 if(adminProfile.active!==true||normalizedRole!=='admin')return NextResponse.json({error:'This signed-in account is not recognized as an active admin.',diagnostic:{role:adminProfile.role,active:adminProfile.active}},{status:403});
 const body=await req.json();const role=body.role;
 if(!['admin','reception','doctor','hair_team','finance'].includes(role))return NextResponse.json({error:'Invalid role.'},{status:400});
 const roleModules:Record<string,string[]>={reception:['home','appointments','patients','operations','visits','staff'],doctor:['home','doctor','patients','visits'],hair_team:['home','doctor','patients','operations','staff'],finance:['home','finance','reports'],admin:['home','doctor','patients','appointments','operations','visits','staff','finance','reports']};
 const permissions=body.permissions&&typeof body.permissions==='object'?body.permissions:{};
 const modules=Array.isArray(permissions.modules)?permissions.modules:roleModules[role];
 if(!Array.isArray(modules)||modules.some((m:string)=>!roleModules[role].includes(m)))return NextResponse.json({error:'Invalid module permission for selected role.'},{status:400});
 if(!body.full_name||!body.email||!body.password||String(body.password).length<8||!body.branch_id)return NextResponse.json({error:'Name, email, password (8+ chars), and branch are required.'},{status:400});
 const {data:branch,error:branchErr}=await admin.from('branches').select('id,organization_id').eq('id',body.branch_id).single();
 if(branchErr||branch?.organization_id!==adminProfile.organization_id)return NextResponse.json({error:'Invalid branch.'},{status:400});
 const {data:created,error:createErr}=await admin.auth.admin.createUser({email:body.email,password:body.password,email_confirm:true});
 if(createErr||!created.user)return NextResponse.json({error:createErr?.message||'Could not create auth user.'},{status:400});
 const {error:insertErr}=await admin.from('profiles').insert({id:created.user.id,organization_id:adminProfile.organization_id,branch_id:branch.id,full_name:String(body.full_name),role,active:true,permissions:{...permissions,modules}});
 if(insertErr){await admin.auth.admin.deleteUser(created.user.id);return NextResponse.json({error:insertErr.message},{status:400});}
 return NextResponse.json({user_id:created.user.id,full_name:body.full_name,role,branch_id:branch.id});
}

export async function DELETE(req:Request){
 if(!url||!anon||!service)return NextResponse.json({error:'Server Supabase credentials are not configured.'},{status:503});
 const token=req.headers.get('authorization')?.replace(/^Bearer\s+/i,'');
 if(!token)return NextResponse.json({error:'Authentication required.'},{status:401});
 const userClient=createClient(url,anon,{auth:{persistSession:false}});
 const {data:{user},error:userErr}=await userClient.auth.getUser(token);
 if(userErr||!user)return NextResponse.json({error:'Invalid session.'},{status:401});
 const admin=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}});
 const {data:actor,error:actorErr}=await admin.from('profiles').select('organization_id,role,active').eq('id',user.id).maybeSingle();
 if(actorErr||!actor||actor.active!==true||actor.role!=='admin')return NextResponse.json({error:'الحذف متاح للـ Admin النشط فقط.'},{status:403});
 let body:{user_id?:string};try{body=await req.json();}catch{return NextResponse.json({error:'Invalid request body.'},{status:400});}
 const targetId=String(body.user_id||'');
 if(!targetId)return NextResponse.json({error:'معرف المستخدم مطلوب.'},{status:400});
 if(targetId===user.id)return NextResponse.json({error:'لا يمكنك حذف حسابك الحالي.'},{status:400});
 const {data:target,error:targetErr}=await admin.from('profiles').select('id,organization_id,role,full_name').eq('id',targetId).maybeSingle();
 if(targetErr||!target)return NextResponse.json({error:'المستخدم غير موجود.'},{status:404});
 if(target.organization_id!==actor.organization_id)return NextResponse.json({error:'لا يمكن حذف مستخدم من مؤسسة أخرى.'},{status:403});
 if(target.role==='admin'){
  const {count,error:countErr}=await admin.from('profiles').select('id',{count:'exact',head:true}).eq('organization_id',actor.organization_id).eq('role','admin').eq('active',true);
  if(countErr)return NextResponse.json({error:'تعذر التحقق من عدد المديرين.'},{status:500});
  if((count||0)<=1)return NextResponse.json({error:'لا يمكن حذف آخر Admin نشط في المؤسسة.'},{status:409});
 }
 const {error:deleteErr}=await admin.auth.admin.deleteUser(targetId);
 if(deleteErr)return NextResponse.json({error:'تعذر حذف حساب الدخول. تأكد من تطبيق migration حذف المستخدمين. التفاصيل: '+deleteErr.message},{status:409});
 return NextResponse.json({success:true,deleted_user_id:targetId});
}
