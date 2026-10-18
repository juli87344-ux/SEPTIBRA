export const STATES={ocupada:['Ocupada','#ce4657'],alta_espera:['Alta / traslado','#8055b8'],liberada:['Liberada / limpiar','#bc940c'],en_limpieza:['En limpieza','#cf721f'],lista:['Lista','#28805b'],reservada:['Reservada','#347bb6']};
export const ROLES={enfermeria:'Enfermería',limpieza:'Limpieza',supervision:'Supervisión'};
export function allowed(role,state){
 if(role==='supervision')return Object.keys(STATES).filter(s=>s!==state);
 if(role==='enfermeria')return ({lista:['ocupada'],reservada:['ocupada'],ocupada:['alta_espera','liberada'],alta_espera:['liberada']})[state]||[];
 if(role==='limpieza')return ({liberada:['en_limpieza'],en_limpieza:['lista']})[state]||[];
 return [];
}
