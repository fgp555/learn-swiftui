# Instrucciones del repositorio

- `mobile/` contiene la app SwiftUI y `backend/` contiene la API en Go con Gin.
- Cuando una solicitud sobre `mobile/` requiera cambios en la API, modifica también `backend/` como parte de la misma tarea. Revisa el contrato HTTP actual y mantén alineados los datos, estados y errores de ambos lados.
- Si cambia el contrato, actualiza las solicitudes de REST Client en `backend/requests/` y verifica el flujo afectado.
- Para desarrollo local, ejecuta `air` desde `backend/`. Air recompila y reinicia el servidor al guardar cambios en Go.
