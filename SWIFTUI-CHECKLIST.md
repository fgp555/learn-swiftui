# Checklist de SwiftUI para alguien que viene de React Native

Usa el contador de `myapp` como punto de partida. Prueba cambios visuales en el Canvas de Xcode con `#Preview` y los flujos completos en el simulador con `./run.sh`. Marca cada casilla cuando puedas reproducir el resultado.

## 1. Composición y layout

- [ ] Extrae el título del contador a una vista que reciba `puntos: Int`. Comprueba que se actualiza al tocar el botón. Piensa en esa propiedad como una prop de React.
- [ ] Coloca los botones de sumar y restar en un `HStack`, debajo del título en un `VStack`. Ajusta alineación, espaciado y tamaño con `Spacer` y `.frame()`. Observa qué cambia frente a Flexbox.
- [ ] Intercambia el orden de `.padding()` y `.background()`. Predice qué área se coloreará antes de abrir la vista previa.
- [ ] Añade un icono con `Image(systemName:)` y comprueba que la pantalla sigue siendo usable con el texto grande y en modo oscuro.

## 2. Estado, identidad y entradas

- [ ] Conserva el contador en `@State` en la vista padre. Extrae el botón de sumar y pásale una closure `onSumar`, como harías con `onPress`.
- [ ] Añade un `Stepper` para cambiar cuánto suma cada toque. Extrae el control a una vista hija con `@Binding` y pásale `$incremento`. Comprueba que padre e hija leen el mismo valor.
- [ ] Mueve un estado local a una vista hija y cambia su `.id()`. Observa cuándo vuelve al valor inicial y compáralo con cambiar una `key` en React.

## 3. Listas y navegación

- [ ] Convierte el contador en un historial de movimientos. Renderízalo con `List` y `ForEach` usando IDs estables. Borra una fila y comprueba que desaparece la correcta.
- [ ] Abre el detalle de un movimiento con `NavigationStack` y `NavigationLink`. Verifica que al volver conservas el historial.
- [ ] Crea una hoja con `.sheet` y un `Form` para añadir un movimiento. Desactiva Guardar con datos inválidos y comprueba que Cancelar descarta los cambios.

## 4. Proyecto final

- [ ] Construye un tracker de hábitos con una lista, un formulario de alta y una pantalla de detalle. Completa el flujo de crear un hábito, marcarlo y volver a la lista.
- [ ] Prepara previews con datos de ejemplo para lista vacía y lista con contenido. Comprueba el flujo con VoiceOver y con un tamaño de texto de accesibilidad.
