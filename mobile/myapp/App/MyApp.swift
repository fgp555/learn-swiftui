//
//  MyApp.swift
//  myapp
//
//  Created by m1 on 05/11/2026.
//

import SwiftUI

@main
struct MyApp: App {
    @State private var session: AuthSession?

    var body: some Scene {
        WindowGroup {
            if let activeSession = session {
                MainTabView(session: activeSession) { session = nil }
            } else {
                LoginScreen { session = $0 }
            }
        }
    }
}
