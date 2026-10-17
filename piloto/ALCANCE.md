# SEPTIBRA: piloto de Enfermería y Limpieza

Estado: diseño acordado; autenticación e integración pendientes. Esta rama no debe desplegarse sobre la aplicación operativa.

## Acceso

Inicio de sesión obligatorio antes de consultar camas. Cuentas personales asignadas por administración; sin registro público ni elección libre de rol. La autorización debe verificarse en la base de datos, además de la interfaz. No reutilizar la contraseña de supervisión incluida en el código actual.

## Permisos propuestos

- Enfermería: consultar el tablero; marcar ocupada, alta/traslado y liberada para limpiar.
- Limpieza: consultar el tablero; iniciar limpieza de una cama liberada y finalizarla como lista tras completar el checklist.
- Supervisión: consultar todos los pisos y corregir estados con motivo obligatorio y registro de auditoría.
- Reserva: pendiente de definir con la responsable; no habilitar por defecto a Enfermería o Limpieza.

La identidad y la hora de los movimientos deben obtenerse de la sesión y del servidor. No aceptar un nombre escrito como prueba de identidad.

## Instituciones y pisos

Institución, piso, habitación y cama deben tener identificadores explícitos. No deducir el piso del número de habitación. Cada usuario accede únicamente a su institución. La demo utilizará datos ficticios; propuesta inicial de 20 camas en dos pisos, cantidad aún no confirmada. Eliminar camas de la demo no debe afectar los registros operativos ni su historial.

## Separación del piloto

Usar tablas y políticas independientes para el piloto. No modificar las tablas camas, historial_camas ni notificaciones actuales. Las notificaciones del piloto solo deben dirigirse a sus usuarios y dispositivos. No invocar el emisor de notificaciones operativo.

## Comprobaciones de aceptación

1. Una persona sin sesión no puede leer ni modificar camas del piloto a través de la API.
2. Enfermería no puede finalizar limpiezas; Limpieza no puede ocupar camas.
3. Una cuenta de otra institución no puede consultar ni modificar datos ajenos.
4. Los pisos filtran habitaciones y los totales coinciden.
5. El cambio de estado y el historial se guardan juntos, o ninguno se guarda.
6. Dos cambios simultáneos sobre la misma cama no se sobrescriben silenciosamente.
7. El checklist se conserva en el servidor al finalizar la limpieza.
8. Cerrar sesión retira los datos de la pantalla y cancela actualizaciones periódicas.
9. La demo no cambia camas ni envía notificaciones del sistema operativo.
10. Documentar y probar la restauración de una copia de seguridad antes del piloto institucional.

## Hallazgos de la revisión del 17 de octubre de 2026

El código actual consulta y modifica camas mediante acceso anónimo; los permisos consultados admiten lectura y actualización anónimas. La supervisión valida una contraseña en JavaScript. El nombre de quien modifica se ingresa manualmente. El checklist se escribe en sessionStorage y no se observó persistencia en servidor en la función de cambio revisada. No hay columnas de institución o piso en camas. Estos puntos deben resolverse en el piloto; no se ha alterado producción.
