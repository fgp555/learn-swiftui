# De Objective-C y UIKit a Swift y SwiftUI

Objective-C y Swift son lenguajes. UIKit y SwiftUI son frameworks de interfaz. Esas dos partes del desarrollo nativo de Apple evolucionaron en momentos distintos.

## Años 80 · Objective-C y NeXT

Brad Cox y Tom Love desarrollaron Objective-C combinando C con un modelo de objetos inspirado en Smalltalk. NeXT, la empresa que Steve Jobs fundó tras salir de Apple, adoptó el lenguaje para su plataforma. Tras la compra de NeXT por Apple, esa tecnología contribuyó a las bases de Mac OS X.

[Universidad de Swansea · Historia de Objective-C](https://collections.swansea.ac.uk/s/history-of-computing-collection/page/objective-c-and-the-web)

## 2008 · SDK del iPhone y UIKit

Apple abrió el desarrollo de apps nativas para iPhone con su SDK. La combinación habitual era Objective-C para escribir el código y UIKit, parte de Cocoa Touch, para construir las pantallas.

[Apple · SDK del iPhone en WWDC 2008](https://www.apple.com/newsroom/2008/05/13Apple-Executives-to-Showcase-Mac-OS-X-Leopard-and-OS-X-iPhone-Development-Platforms-at-WWDC-2008-Keynote/)

## 2014 · Swift

Apple presentó Swift como un lenguaje para Cocoa y Cocoa Touch que podía convivir con Objective-C en la misma app. Un equipo podía escribir pantallas nuevas en Swift y seguir usando UIKit junto al código que ya tenía.

[Apple · Presentación de Swift](https://www.apple.com/ca/newsroom/2014/06/02Apple-Releases-iOS-8-SDK-With-Over-4-000-New-APIs/)

## 2019 · SwiftUI

Apple presentó SwiftUI como un framework declarativo. En un contador con UIKit, creas un `UILabel` y actualizas su texto cuando cambia el valor. En SwiftUI, describes la vista con `Text("Puntos: \(points)")` y el framework actualiza la interfaz cuando cambia el estado que lee la vista. Este modelo se parece al de React.

[Apple · Presentación de SwiftUI](https://www.apple.com/ie/newsroom/2019/06/apple-unveils-groundbreaking-new-technologies-for-app-development/)

Una misma app puede combinar pantallas de UIKit en Objective-C, pantallas de UIKit en Swift y pantallas de SwiftUI. La interoperabilidad permite migrarlas una a una. Por ejemplo, `UIHostingController` integra una vista SwiftUI en UIKit y `UIViewControllerRepresentable` permite insertar un controlador de UIKit en SwiftUI.

[Apple · Integración de UIKit y SwiftUI](https://developer.apple.com/documentation/swiftui/uikit-integration)
