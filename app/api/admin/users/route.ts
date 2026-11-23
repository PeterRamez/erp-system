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
 const roleModules:Record<string,string[]>={reception:['home','appointments','patients','operations','staff'],doctor:['home','operations'],hair_team:['home','patients','operations','staff'],finance:['home','finance','reports'],admin:['home','patients','appointments','operations','staff','finance','reports']};
 const permissions=body.permissions&&typeof body.permissions==='object'?body.permissions:{};
 const modules=Array.isArray(permissions.modules)?permissions.modules:roleModules[role];
 if(!Array.isArray(modules)||modules.some((m:string)=>!roleModules[role].includes(m)))return NextResponse.json({error:'Invalid module permission for selected role.'},{status:400});
 const branchIds=Array.isArray(body.branch_ids)?Array.from(new Set(body.branch_ids.map((x:any)=>String(x)))):body.branch_id?[String(body.branch_id)]:[];if(!body.full_name||!body.email||!body.password||String(body.password).length<8||branchIds.length===0)return NextResponse.json({error:'Name, email, password (8+ chars), and at least one branch are required.'},{status:400});
 const {data:branchRows,error:branchErr}=await admin.from('branches').select('id,organization_id').in('id',branchIds);
 if(branchErr||!branchRows||branchRows.length!==branchIds.length||branchRows.some((b:any)=>b.organization_id!==adminProfile.organization_id))return NextResponse.json({error:'Invalid branch selection.'},{status:400});const primaryBranch=branchRows.find((b:any)=>b.id===String(body.branch_id||branchIds[0]))||branchRows[0];
 const {data:created,error:createErr}=await admin.auth.admin.createUser({email:body.email,password:body.password,email_confirm:true});
 if(createErr||!created.user)return NextResponse.json({error:createErr?.message||'Could not create auth user.'},{status:400});
 const {error:insertErr}=await admin.from('profiles').insert({id:created.user.id,organization_id:adminProfile.organization_id,branch_id:primaryBranch.id,full_name:String(body.full_name),role,active:true,permissions:{...permissions,modules}});
 if(insertErr){await admin.auth.admin.deleteUser(created.user.id);return NextResponse.json({error:insertErr.message},{status:400});}
 const {error:membershipErr}=await admin.from('user_branch_access').insert(branchRows.map((b:any)=>({user_id:created.user.id,organization_id:adminProfile.organization_id,branch_id:b.id})));if(membershipErr){await admin.auth.admin.deleteUser(created.user.id);return NextResponse.json({error:'Could not save branch access: '+membershipErr.message},{status:400});}
 return NextResponse.json({user_id:created.user.id,full_name:body.full_name,role,branch_id:primaryBranch.id,branch_ids:branchRows.map((b:any)=>b.id)});
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

async function verifyAdmin(req:Request){
 if(!url||!anon||!service)return {error:NextResponse.json({error:'Server Supabase credentials are not configured.'},{status:503})};
 const token=req.headers.get('authorization')?.replace(/^Bearer\s+/i,'');if(!token)return {error:NextResponse.json({error:'Authentication required.'},{status:401})};
 const userClient=createClient(url,anon,{auth:{persistSession:false}});const {data:{user},error:userErr}=await userClient.auth.getUser(token);if(userErr||!user)return {error:NextResponse.json({error:'Invalid session.'},{status:401})};
 const admin=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}});const {data:profile,error}=await admin.from('profiles').select('id,organization_id,role,active').eq('id',user.id).maybeSingle();if(error||!profile||profile.active!==true||profile.role!=='admin')return {error:NextResponse.json({error:'Admin access required.'},{status:403})};return {admin,profile,user};
}
export async function GET(req:Request){
 const v=await verifyAdmin(req);if(v.error)return v.error;const {admin,profile}=v as any;
 const {data:users,error}=await admin.from('profiles').select('*').eq('organization_id',profile.organization_id).order('created_at',{ascending:false});if(error)return NextResponse.json({error:error.message},{status:500});
 const result=[];for(const u of users||[]){const {data:auth}=await admin.auth.admin.getUserById(u.id);const {data:access}=await admin.from('user_branch_access').select('branch_id').eq('user_id',u.id);result.push({...u,email:auth.user?.email||'',branch_ids:(access||[]).map((x:any)=>x.branch_id)});}
 return NextResponse.json({users:result});
}
export async function PUT(req:Request){
 const v=await verifyAdmin(req);if(v.error)return v.error;const {admin,profile,user}=v as any;let body:any;try{body=await req.json()}catch{return NextResponse.json({error:'Invalid request body.'},{status:400})}
 const id=String(body.user_id||'');if(!id)return NextResponse.json({error:'User ID required.'},{status:400});const {data:target,error:targetErr}=await admin.from('profiles').select('id,organization_id,role').eq('id',id).maybeSingle();if(targetErr||!target)return NextResponse.json({error:'User not found.'},{status:404});if(target.organization_id!==profile.organization_id)return NextResponse.json({error:'Organization mismatch.'},{status:403});
 const role=body.role||target.role;
 const roleModules:Record<string,string[]>={
  reception:['home','appointments','patients','operations','staff','finance'],
  doctor:['home','patient_files','operations'],
  hair_team:['home','patients','operations','staff'],
  image_manager:['home','patients'],
  finance:['home','finance','reports'],
  admin:['home','patients','patient_files','operations','appointments','finance','users','reports']
 };
 if(!Object.prototype.hasOwnProperty.call(roleModules,role))return NextResponse.json({error:'Invalid role.'},{status:400});
 const branchIds=Array.isArray(body.branch_ids)?Array.from(new Set(body.branch_ids.map((x:any)=>String(x)))):[];
 if(!branchIds.length)return NextResponse.json({error:'Select at least one branch.'},{status:400});
 const {data:branches,error:branchError}=await admin.from('branches').select('id,organization_id').in('id',branchIds);
 if(branchError||!branches||branches.length!==branchIds.length||branches.some((b:any)=>b.organization_id!==profile.organization_id))return NextResponse.json({error:'Invalid branch selection.'},{status:400});
 const perms=body.permissions&&typeof body.permissions==='object'?body.permissions:{};
 const requestedModules=Array.isArray(perms.modules)?perms.modules:roleModules[role];
 // Keep only modules supported by the selected role. This also safely handles
 // older saved permission keys when an admin only changes a password.
 const modules=Array.from(new Set(requestedModules.filter((m:any)=>typeof m==='string'&&roleModules[role].includes(m))));
 if(!modules.includes('home'))modules.unshift('home');
 const updateAuth:any={};
 if(body.email)updateAuth.email=String(body.email).trim();
 if(body.password){if(String(body.password).length<8)return NextResponse.json({error:'Password must be at least 8 characters.'},{status:400});updateAuth.password=String(body.password)}
 // Validate role, branches and permissions before changing the Auth account.
 if(Object.keys(updateAuth).length){const {error}=await admin.auth.admin.updateUserById(id,updateAuth);if(error)return NextResponse.json({error:error.message},{status:400});}
 const {error:profileUpdate}=await admin.from('profiles').update({full_name:String(body.full_name||''),role,branch_id:branchIds[0],active:body.active!==false,permissions:{...perms,modules}}).eq('id',id);
 if(profileUpdate)return NextResponse.json({error:profileUpdate.message},{status:400});
 await admin.from('user_branch_access').delete().eq('user_id',id);const {error:membershipError}=await admin.from('user_branch_access').insert(branchIds.map(branch_id=>({user_id:id,organization_id:profile.organization_id,branch_id})));if(membershipError)return NextResponse.json({error:membershipError.message},{status:400});return NextResponse.json({success:true,user_id:id});
}
