const LIBRATSALUD_SW_VERSION = "libratsalud-sw-v6";

self.addEventListener("install", () => {
  self.skipWaiting();
});

self.addEventListener("activate", event => {
  event.waitUntil(self.clients.claim());
});


function leerConfiguracionSilencio(){
  return new Promise(resolve=>{
    try{
      const req=indexedDB.open("libratsalud-notificaciones",1);
      req.onupgradeneeded=()=>{try{req.result.createObjectStore("config")}catch(e){}};
      req.onsuccess=()=>{
        const db=req.result;
        try{
          const tx=db.transaction("config","readonly");
          const get=tx.objectStore("config").get("horario");
          get.onsuccess=()=>{const v=get.result||{activo:false};db.close();resolve(v);};
          get.onerror=()=>{db.close();resolve({activo:false});};
        }catch(e){db.close();resolve({activo:false});}
      };
      req.onerror=()=>resolve({activo:false});
    }catch(e){resolve({activo:false});}
  });
}
function notificacionesEnSilencio(c){
  if(!c) return false;
  return !!(c.ubicacion && c.ubicacion.activo && c.ubicacion.fuera);
}

self.addEventListener("push", event => {
  let data = {};

  try {
    data = event.data ? event.data.json() : {};
  } catch (e) {
    data = {
      title: "SEPTIBRA",
      body: event.data ? event.data.text() : "Nueva actualización"
    };
  }

  event.waitUntil(
    leerConfiguracionSilencio().then(config=>{
      if(notificacionesEnSilencio(config)) return;
      return self.registration.showNotification(
      data.title || "SEPTIBRA",
      {
        body: data.body || "Hay una actualización de habitación.",
        icon: "./icon-libracare.svg",
        badge: "./icon-notification.svg",
        tag: data.tag || "libratsalud",
        renotify: true,
        data: data.data || { url: "./" }
      }
    );
    })
  );
});

self.addEventListener("notificationclick", event => {
  event.notification.close();

  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then(lista => {
      for (const cliente of lista) {
        if (cliente.url.startsWith(self.registration.scope) && "focus" in cliente) {
          return cliente.focus();
        }
      }
      return clients.openWindow((event.notification.data && event.notification.data.url) || "./");
    })
  );
});
