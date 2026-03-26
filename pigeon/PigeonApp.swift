//  PigeonApp.swift
//  Pigeon
//
//  Created by Ashok pokhrel on 19/03/2026.
//

import SwiftUI

@main
struct PigeonApp: App {
    @State private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
                .preferredColorScheme(appState.selectedTheme.colorScheme)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    appState.saveSession()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
                    appState.saveSession()
                }
        }
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    appState.isShowingSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(replacing: .newItem) {
                Button("New Request") {
                    appState.newScratchRequest()
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("Open...") {
                    appState.openItem()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    appState.saveRequest()
                }
                .keyboardShortcut("s", modifiers: .command)
            }
        }
    }
}
