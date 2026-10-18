import {API_URL,PUBLIC_KEY} from './config.mjs';
import {STATES,ROLES,allowed} from './rules.mjs';
const $=id=>document.getElementById(id);
let session=null,profile=null,beds=[],floors=[],selected=null,timer=null,expiryTimer=null,epoch=0,loading=false,saving=false;
function message(text){$('message').textContent=text;}
function clearSession(){epoch++;session=null;profile=null;beds=[];floors=[];selected=null;clearInterval(timer);clearTimeout(expiryTimer);timer=null;loading=false;$('beds').replaceChildren();$('summary').replaceChildren();$('identity').textContent='';$('institution').textContent='Camas por piso';$('board').hidden=true;$('login').hidden=false;$('password').value='';if($('change').open)$('change').close();}
async function request(path,options={},token=session?.access_token){
 const response=await fetch(API_URL+path,{...options,cache:'no-store',headers:{apikey:PUBLIC_KEY,...(token?{Authorization:'Bearer '+token}:{}),'Content-Type':'application/json',...options.headers}});
 const text=await response.text();let data;try{data=text?JSON.parse(text):null;}catch{data=null;}
 if(!response.ok){if(response.status===401&&session){clearSession();message('La sesión venció. Volvé a ingresar.');}throw new Error(path.startsWith('/auth/')?'No se pudo iniciar sesión. Revisá los datos o intentá más tarde.':data?.message||'No se pudo completar la operación.');}return data;
}
function option(value,label){const el=document.createElement('option');el.value=value;el.textContent=label;return el;}
function render(){
 const floor=$('floor').value,state=$('state').value;const inFloor=beds.filter(b=>!floor||b.piso_id===floor);const visible=inFloor.filter(b=>!state||b.estado===state);
 $('summary').replaceChildren();for(const [key,[label]] of Object.entries(STATES)){const metric=document.createElement('div');metric.className='metric';const n=document.createElement('b');n.textContent=inFloor.filter(b=>b.estado===key).length;metric.append(document.createTextNode(label),n);$('summary').append(metric);}
 $('beds').replaceChildren();for(const f of floors){const rows=visible.filter(b=>b.piso_id===f.id);if(!rows.length)continue;const title=document.createElement('h2');title.className='floor-title';title.textContent=f.nombre+' · '+rows.length+' camas';const grid=document.createElement('div');grid.className='bed-grid';for(const b of rows){const btn=document.createElement('button');btn.className='bed';btn.style.setProperty('--state-color',STATES[b.estado]?.[1]||'#777');const name=document.createElement('b');name.textContent='Cama '+b.cama;const stateLabel=document.createElement('span');stateLabel.textContent=STATES[b.estado]?.[0]||b.estado;const detail=document.createElement('small');detail.textContent='Hab. '+b.habitacion+(b.operador_nombre?' · '+b.operador_nombre:'');btn.append(name,stateLabel,detail);btn.onclick=()=>openBed(b);grid.append(btn);}$('beds').append(title,grid);}
 if(!visible.length)$('beds').textContent='No hay camas para estos filtros.';
}
async function load(){
 if(!session||loading)return;loading=true;const mine=epoch;
 try{const rows=await request('/rest/v1/piloto_camas?select=*&order=habitacion,cama');if(mine!==epoch)return;beds=rows;render();$('connection').textContent='Actualizado '+new Date().toLocaleTimeString('es-AR');}
 catch(e){if(mine===epoch)$('connection').textContent='No se pudo actualizar. Los datos pueden estar desactualizados. Usá Actualizar para reintentar.';}
 finally{if(mine===epoch)loading=false;}
}
function openBed(b){selected={...b};$('changeForm').reset();$('changeError').textContent='';$('bedTitle').textContent='Habitación '+b.habitacion+' · Cama '+b.cama;$('bedState').textContent='Estado actual: '+STATES[b.estado][0];const choices=allowed(profile.rol,b.estado);$('nextState').replaceChildren(...choices.map(s=>option(s,STATES[s][0])));$('nextState').disabled=!choices.length;$('save').disabled=!choices.length;$('reasonLabel').hidden=profile.rol!=='supervision';$('reason').required=profile.rol==='supervision';if(!choices.length)$('changeError').textContent='Tu perfil puede consultar esta cama; este estado no tiene cambios habilitados para tu función.';toggleChecklist();$('change').showModal();}
function toggleChecklist(){const needs=selected?.estado==='en_limpieza'&&$('nextState').value==='lista';$('checklist').hidden=!needs;for(const c of $('checklist').querySelectorAll('input'))c.required=needs;}
$('nextState').onchange=toggleChecklist;
$('cancel').onclick=()=>{if(!saving)$('change').close();};
$('change').addEventListener('cancel',event=>{if(saving)event.preventDefault();});
$('changeForm').onsubmit=async event=>{
 event.preventDefault();if(!session||!selected||saving)return;saving=true;$('save').disabled=true;$('cancel').disabled=true;const mine=epoch,bed={...selected};
 try{const checklist=$('checklist').hidden?null:Object.fromEntries([...$('checklist').querySelectorAll('input')].map(c=>[c.name,c.checked]));if(checklist)checklist.observaciones=$('observations').value.trim();const patch={estado:$('nextState').value,checklist,motivo:profile.rol==='supervision'?$('reason').value.trim():null};
 const changed=await request('/rest/v1/piloto_camas?id=eq.'+encodeURIComponent(bed.id)+'&version=eq.'+bed.version,{method:'PATCH',headers:{Prefer:'return=representation'},body:JSON.stringify(patch)});if(mine!==epoch)return;
 if(!changed.length){$('change').close();message('La cama cambió desde otro dispositivo o tu acceso cambió. Revisá el estado actualizado.');}else{$('change').close();message('');}await load();
 }catch(e){if(mine===epoch)$('changeError').textContent=e.message;}
 finally{saving=false;$('cancel').disabled=false;$('save').disabled=false;}
};
$('loginForm').onsubmit=async event=>{
 event.preventDefault();$('enter').disabled=true;message('');const mine=++epoch;
 try{const result=await request('/auth/v1/token?grant_type=password',{method:'POST',body:JSON.stringify({email:$('email').value.trim(),password:$('password').value})},null);$('password').value='';if(mine!==epoch)return;session={access_token:result.access_token};
 const profiles=await request('/rest/v1/piloto_perfiles?select=usuario_id,institucion_id,nombre,rol,activo');if(mine!==epoch)return;if(profiles.length!==1)throw new Error('Tu cuenta no tiene acceso asignado al piloto. Consultá a la persona responsable.');profile=profiles[0];
 const [ps,orgs]=await Promise.all([request('/rest/v1/piloto_pisos?select=*&order=orden,nombre'),request('/rest/v1/piloto_instituciones?select=nombre')]);if(mine!==epoch)return;floors=ps;$('floor').replaceChildren(option('','Todos los pisos'),...floors.map(f=>option(f.id,f.nombre)));$('state').replaceChildren(option('','Todos los estados'),...Object.entries(STATES).map(([k,v])=>option(k,v[0])));$('identity').textContent=profile.nombre+' · '+ROLES[profile.rol];$('institution').textContent=orgs[0]?.nombre||'Camas por piso';$('login').hidden=true;$('board').hidden=false;
 await load();if(mine!==epoch)return;timer=setInterval(()=>{if(!document.hidden)load();},15000);expiryTimer=setTimeout(()=>{clearSession();message('La sesión venció. Volvé a ingresar.');},Math.max(0,(result.expires_in||3600)-30)*1000);
 }catch(e){if(mine===epoch){clearSession();message(e.message);}}
 finally{$('enter').disabled=false;$('password').value='';}
};
$('logout').onclick=async()=>{const token=session?.access_token;clearSession();message('Sesión cerrada en este dispositivo.');if(token)try{await request('/auth/v1/logout?scope=local',{method:'POST'},token);}catch{message('Sesión cerrada en este dispositivo. No se pudo confirmar la revocación remota.');}};
$('reload').onclick=load;$('floor').onchange=render;$('state').onchange=render;
document.addEventListener('visibilitychange',()=>{if(!document.hidden)load();});
// Sesión solo en memoria; no almacena contraseñas, tokens ni datos de camas en el dispositivo.
