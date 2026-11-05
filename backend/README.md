# Backend de myapp

API local de autenticación para la app SwiftUI. Usa Gin, SQLite y Argon2id. Ejecuta los comandos desde `backend/` con Go 1.27.

## Arrancar

```sh
go run ./cmd/api
```

Gin escribe en la terminal el método, la ruta, el estado HTTP y la latencia de cada petición. El servidor escucha en `http://127.0.0.1:8080` y guarda datos en `data/myapp.sqlite`. En cada arranque deja disponible `demo@example.com` con contraseña `demo`, incluso si se eliminó la cuenta o si tenía otra contraseña.

## Recarga automática con Air

Desde `backend/`, instala Air una vez y arráncalo en lugar de `go run ./cmd/api`:

```sh
go install github.com/air-verse/air@latest
"$(go env GOPATH)/bin/air"
```

Si tienes `GOBIN` configurado, ejecuta `air` desde ese directorio. Si el binario ya está en tu `PATH`, basta con `air`.

Air recompila y reinicia el servidor al guardar cambios en el código Go o sus módulos. Los datos de SQLite se conservan y los logs de Gin aparecen en la misma terminal.

## Probar el flujo

```sh
curl -i http://127.0.0.1:8080/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"demo@example.com","password":"demo"}'

# Copia el token que devuelve el login.
TOKEN='TOKEN_DEL_LOGIN'
curl -i http://127.0.0.1:8080/v1/auth/me \
  -H "Authorization: Bearer $TOKEN"
curl -i -X POST http://127.0.0.1:8080/v1/auth/logout \
  -H "Authorization: Bearer $TOKEN"
```

| Ruta | Respuesta |
| --- | --- |
| `POST /v1/auth/register` | Recibe `email` y `password` de al menos cuatro caracteres. Devuelve `201` con `id` y `email`, `400` para datos inválidos o `409` si el correo ya existe. |
| `POST /v1/auth/login` | `200` con `token` y `expires_at` en RFC 3339. `400` para una petición inválida o `401` para credenciales incorrectas. |
| `GET /v1/auth/me` | `200` con `id` y `email`, o `401` si la sesión no es válida. |
| `DELETE /v1/auth/me` | Requiere Bearer token. Devuelve `204` al eliminar la cuenta autenticada y todas sus sesiones, o `401` si el token es inválido. |
| `POST /v1/auth/logout` | `204` después de revocar la sesión, o `401` si la sesión no es válida. |

Los errores incluyen un campo JSON `error`. Cada token es aleatorio, dura 24 horas y se guarda como hash en SQLite. El servidor está configurado para desarrollo local. Antes de exponerlo, añade HTTPS y límites de intentos de login.

## Probar desde REST Client en VS Code

Con el servidor encendido, abre `requests/auth.http` y pulsa **Send Request** sobre cada solicitud en orden. El login usa las credenciales demo y las siguientes solicitudes toman el token de esa respuesta.

`requests/accounts.http` registra un usuario de práctica, inicia sesión y elimina esa cuenta. `requests/auth-errors.http` contiene casos de error que puedes ejecutar por separado.

## Pruebas

```sh
go test ./...
```
