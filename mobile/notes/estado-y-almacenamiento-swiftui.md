# Estado y almacenamiento en SwiftUI

Dos preguntas orientan la elección. ¿Quién es dueño del dato? ¿Debe sobrevivir al cierre de la app?

## Estado en memoria

| En React Native | En SwiftUI | Cuándo usarlo |
| --- | --- | --- |
| `useState` | `@State` | Una vista posee un valor, como los puntos del contador o el borrador de un formulario. |
| Prop con valor y setter | `@Binding` | Una vista hija necesita leer y modificar un valor que posee el padre. `$points` pasa ese acceso. |
| Context o un store compartido | `@Observable` + `@Environment` | Varias pantallas necesitan el mismo modelo. Puedes crearlo en `App` e inyectarlo en el árbol. |

`@Binding` conecta con una fuente de verdad existente. `@Observable` permite que las vistas reaccionen a cambios del modelo y `@Environment` les da acceso a la instancia inyectada. El estado en memoria dura mientras vive su dueño y se pierde al terminar el proceso.

[Apple · Estado y modelos en SwiftUI](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app)

## Almacenamiento persistente

| En React Native | En iOS | Cuándo usarlo |
| --- | --- | --- |
| AsyncStorage para preferencias pequeñas | `UserDefaults` / `@AppStorage` | Preferencias sencillas, como el orden de una lista. `@AppStorage` conecta el valor con SwiftUI. |
| SecureStore | Keychain | Tokens, credenciales y otros secretos pequeños. |
| SQLite o Realm | SwiftData, Core Data o SQLite | Colecciones que quieres consultar, ordenar y modificar, como un historial de mensajes. |
| Almacenamiento de archivos | `FileManager` | Imágenes, documentos, exportaciones y cachés. El sistema puede eliminar los archivos de caché. |

[Apple · UserDefaults](https://developer.apple.com/documentation/foundation/userdefaults) · [Keychain](https://developer.apple.com/documentation/security/keychain-services) · [SwiftData](https://developer.apple.com/documentation/swiftdata) · [FileManager](https://developer.apple.com/documentation/foundation/filemanager)

## Ejercicios en myapp

- [ ] En `CounterScreen`, prueba `@AppStorage("counter.points") private var points = 0`. Suma puntos, pulsa **r** en la terminal de `run.sh` y comprueba que el valor sobrevive al relanzamiento.
- [ ] En **Form**, convierte el último mensaje en un historial con SwiftData. Guarda dos mensajes, relanza la app y verifica que puedes listarlos.
