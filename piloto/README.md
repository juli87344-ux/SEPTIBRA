# SEPTIBRA piloto

Implementación inicial independiente de la aplicación operativa.

## Estado

- Tablas piloto creadas, con acceso anónimo revocado y RLS por institución.
- 20 camas ficticias en Planta baja y Primer piso. No se copiaron camas operativas.
- Roles enfermeria, limpieza y supervision asignados en piloto_perfiles por administración; sin autoasignación ni registro público en la interfaz.
- Actualización de estado y auditoría atómicas mediante triggers. Hora e identidad determinadas en servidor.
- Checklist requerido y persistido al pasar de En limpieza a Lista.
- Cliente estático con login por correo y contraseña usando Supabase Auth; sesión solo en memoria y nuevo ingreso al vencer. Sin registro público ni recuperación de contraseña implementada aún.
- Notificaciones piloto pendientes, deshabilitadas. No se conecta al emisor ni a suscripciones operativas.
- No publicado. Ningún cambio en index.html de producción.

## Primer acceso pendiente

Hay que crear una cuenta personal mediante el mecanismo administrativo de Supabase Auth y asignar su usuario_id, nombre, rol e institucion_id en piloto_perfiles. No reutilizar contraseñas compartidas ni introducir claves service_role en el navegador. El correo para el primer acceso todavía no fue indicado.

El archivo config.mjs contiene únicamente la URL y la clave pública anon existente, validada antes de reutilizarla. Ningún token administrativo ni contraseña se incluye.

## Verificación realizada

schema.sql aplicado en el proyecto asociado a SEPTIBRA. pruebas.sql ejecutado dentro de una transacción con usuarios/datos temporales y ROLLBACK: anonimato bloqueado, aislamiento entre instituciones, acciones válidas e inválidas por rol, checklist obligatorio, historial no falsificable desde clientes, motivo de supervisión obligatorio y rechazo de actualización con versión obsoleta. Análisis de seguridad de Supabase sin avisos nuevos para tablas piloto. Sintaxis JavaScript comprobada con node --check.

Pendiente: prueba completa de login con cuenta real, inspección visual del cliente, dos dispositivos simultáneos, restauración de respaldo y notificaciones aisladas. No presentar esta versión como lista para operación clínica.

## Servir

Servir esta carpeta por HTTPS como sitio estático. No registrar el service worker de producción ni copiar esta carpeta sobre la raíz operativa. Los filtros de pisos se basan en identificadores explícitos. El cliente actualiza cada 15 segundos mientras está visible y también al volver a la pestaña.

## Reglas de transición

- Enfermería: Lista/Reservada → Ocupada; Ocupada → Alta/traslado o Liberada; Alta/traslado → Liberada.
- Limpieza: Liberada → En limpieza → Lista (cinco comprobaciones).
- Supervisión: correcciones con motivo de cinco caracteres como mínimo; checklist requerido al finalizar una limpieza.

Las altas/bajas de pisos, camas y cuentas se administran fuera del tablero. Respaldo y administración visual quedan pendientes.
