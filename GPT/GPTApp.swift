//
//  GPTApp.swift
//  GPT
//
//  Created by Adam Łuczak on 05/01/2023.
//

import SwiftUI

@main
struct GPTApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme( .dark )
                .onAppear
                {
                    UIApplication.shared.isIdleTimerDisabled = true
                }
        }
    }
}
