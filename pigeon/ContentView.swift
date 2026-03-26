//
//  ContentView.swift
//  pigeon
//
//  Created by Ashok pokhrel on 19/03/2026.
//

import SwiftUI

/// Debounces pane-resize writes to AppState.
/// Has NO @Published properties, so mutating it never triggers SwiftUI re-renders —
/// meaning zero layout passes happen during an active drag.
/// Has @Published properties to trigger SwiftUI re-renders of the debounced components.
final class PaneSizeDebouncer: ObservableObject {
    @Published var sidebarWidth: Double = 0
    @Published var responsePaneWidth: Double = 0
    @Published var responsePaneHeight: Double = 0
    
    private var widthTask: DispatchWorkItem?
    private var sidebarTask: DispatchWorkItem?
    private var heightTask: DispatchWorkItem?

    func debounceSidebar(delay: TimeInterval = 0.3, _ action: @escaping () -> Void) {
        sidebarTask?.cancel()
        let item = DispatchWorkItem(block: action)
        sidebarTask = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func debounceWidth(delay: TimeInterval = 0.3, _ action: @escaping () -> Void) {
        widthTask?.cancel()
        let item = DispatchWorkItem(block: action)
        widthTask = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func debounceHeight(delay: TimeInterval = 0.3, _ action: @escaping () -> Void) {
        heightTask?.cancel()
        let item = DispatchWorkItem(block: action)
        heightTask = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }
}

struct ContentView: View {
    @Bindable var appState: AppState
    @State private var keyboardMonitor: Any?
    @State private var mouseUpMonitor: Any?
    @State private var hasAppeared = false
    /// Stable reference across renders. No @Published → mutating it never causes re-renders.
    @StateObject private var paneDebouncer = PaneSizeDebouncer()
    
    var body: some View {
        NavigationSplitView {
            SidebarView(appState: appState)
                .navigationSplitViewColumnWidth(min: 200, ideal: appState.sidebarWidth)
                .background(GeometryReader { sidebarGeo in
                    Color.clear
                        .onChange(of: sidebarGeo.size.width) { _, newWidth in
                            guard hasAppeared, newWidth > 0 else { return }
                            let w = newWidth
                            paneDebouncer.debounceSidebar { appState.sidebarWidth = w }
                        }
                })
        } detail: {
            DetailContentView(appState: appState, hasAppeared: hasAppeared, paneDebouncer: paneDebouncer)
        }
        .frame(minWidth: 1000, minHeight: 650)
        .sheet(item: $appState.activeModal) { modal in
            switch modal {
            case .newRequest:
                NewRequestModal(appState: appState, manager: appState.activeWorkspaceManager)
            case .newFolder:
                NewFolderModal(appState: appState, manager: appState.activeWorkspaceManager)
            case .rename:
                RenameModal(appState: appState, manager: appState.activeWorkspaceManager)
            case .newEnvironment:
                NewEnvironmentModal(appState: appState, manager: appState.activeWorkspaceManager)
            case .settings:
                SettingsView(appState: appState)
            }
        }
        .onAppear {
            // Guard prevents duplicate monitors if onAppear fires more than once
            guard keyboardMonitor == nil else { return }
            keyboardMonitor = setupKeyboardMonitors()
            mouseUpMonitor = setupMouseMonitors()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                hasAppeared = true
            }
        }
        .onDisappear {
            if let m = keyboardMonitor { NSEvent.removeMonitor(m); keyboardMonitor = nil }
            if let m = mouseUpMonitor { NSEvent.removeMonitor(m); mouseUpMonitor = nil }
        }
    }
    
    @discardableResult
    private func setupKeyboardMonitors() -> Any {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) {
                switch event.charactersIgnoringModifiers {
                case "w":
                    if let selectedTab = appState.selectedTab {
                        switch selectedTab {
                        case .request(let id): appState.closeDraft(id: id)
                        case .environment(let id): appState.activeWorkspaceManager?.closeEnvironmentDraft(id: id)
                        }
                        return nil
                    }
                case "s":
                    appState.saveRequest()
                    return nil
                case "f":
                    if appState.response != nil {
                        NotificationCenter.default.post(name: .triggerResponseSearch, object: nil)
                        return nil
                    }
                case "\u{1B}": // Escape
                    NotificationCenter.default.post(name: .closeResponseSearch, object: nil)
                    return nil
                default:
                    break
                }
            }
            return event
        }
    }
    
    private func setupMouseMonitors() -> Any {
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp]) { [appState] event in
            // When user releases the mouse (end of drag/resize), trigger any pending saves immediately
            appState.debouncedSaveSession()
            return event
        }
    }
}

/// A subview for the detail content to prevent re-renders when sidebar-related state changes
struct DetailContentView: View {
    @Bindable var appState: AppState
    var hasAppeared: Bool // Pass this down to prevent overwrite
    @ObservedObject var paneDebouncer: PaneSizeDebouncer

    var body: some View {
        VStack(spacing: 0) {
            TabBarView(appState: appState)
            
            Divider()
            
            ZStack {
                if let selectedTab = appState.selectedTab {
                    switch selectedTab {
                    case .request(let id):
                        if let draft = appState.openDrafts.first(where: { $0.id == id }) {
                            requestView(draft: draft)
                        } else {
                            noSelectionView
                        }
                    case .environment(let id):
                        if let envDraft = appState.openEnvironmentDrafts.first(where: { $0.id == id }) {
                            EnvironmentEditorView(draft: envDraft)
                        } else {
                            noSelectionView
                        }
                    }
                } else {
                    noSelectionView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("")
    }
    
    @ViewBuilder
    private func requestView(draft: DraftRequest) -> some View {
        GeometryReader { geometry in
            let effectiveLayout: PaneLayout = {
                switch appState.preferredLayoutMode {
                case .left: return .left
                case .right: return .right
                case .bottom: return .bottom
                case .auto:
                    return geometry.size.width < 900 ? .bottom : .right
                }
            }()
            
            Group {
                if effectiveLayout == .bottom {
                    VSplitView {
                        RequestEditorView(draft: draft, appState: appState)
                            .frame(minHeight: 300)
                            .layoutPriority(1)
                        
                        responsePane
                            .frame(minHeight: 200, idealHeight: appState.responsePaneHeight)
                            .background(GeometryReader { paneGeo in
                                Color.clear
                                    .onChange(of: paneGeo.size.height) { _, newHeight in
                                        guard hasAppeared, newHeight > 0 else { return }
                                        // Debounce: only write to @Observable appState after drag ends.
                                        // Writing every frame triggers re-renders that fight NSSplitView.
                                        let h = newHeight
                                        paneDebouncer.debounceHeight { appState.responsePaneHeight = h }
                                    }
                            })
                    }
                } else if effectiveLayout == .left {
                    HSplitView {
                        responsePane
                            .frame(minWidth: 300, idealWidth: appState.responsePaneWidth)
                            .background(GeometryReader { paneGeo in
                                Color.clear
                                    .onChange(of: paneGeo.size.width) { _, newWidth in
                                        guard hasAppeared, newWidth > 0 else { return }
                                        let w = newWidth
                                        paneDebouncer.debounceWidth { appState.responsePaneWidth = w }
                                    }
                            })
                        
                        RequestEditorView(draft: draft, appState: appState)
                            .frame(minWidth: 400)
                            .layoutPriority(1)
                    }
                } else {
                    HSplitView {
                        RequestEditorView(draft: draft, appState: appState)
                            .frame(minWidth: 400)
                            .layoutPriority(1)
                        
                        responsePane
                            .frame(minWidth: 300, idealWidth: appState.responsePaneWidth)
                            .background(GeometryReader { paneGeo in
                                Color.clear
                                    .onChange(of: paneGeo.size.width) { _, newWidth in
                                        guard hasAppeared, newWidth > 0 else { return }
                                        let w = newWidth
                                        paneDebouncer.debounceWidth { appState.responsePaneWidth = w }
                                    }
                            })
                    }
                }
            }
        }
    }
    
    private var noSelectionView: some View {
        ContentUnavailableView(
            "No Tabs Open",
            systemImage: "plus.square.on.square",
            description: Text("Choose a request or environment from the sidebar, or click + to start a new scratch request.")
        )
    }
    
    @ViewBuilder
    private var responsePane: some View {
        ZStack {
            if let response = appState.response {
                ResponseView(response: response, appState: appState)
            } else {
                VStack(spacing: 0) {
                    // Header with Layout Picker even when no response
                    HStack {
                        Spacer()
                        LayoutPickerView(appState: appState)
                            .padding(.trailing, 8)
                    }
                    .frame(height: 34)
                    .background(Color(NSColor.windowBackgroundColor))
                    
                    Divider()
                    
                    VStack {
                        ContentUnavailableView("No Response", systemImage: "bolt.horizontal", description: Text("Send a request to see the response here."))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.1))
                }
            }
        }
        .frame(minWidth: 300, maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)
    }
    
    enum PaneLayout {
        case left, right, bottom
    }
}

struct TabBarView: View {
    @Bindable var appState: AppState
    
    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(appState.openDrafts) { draft in
                        TabItemView(appState: appState, draft: draft, isSelected: appState.selectedDraftID == draft.id) {
                            appState.selectedTab = .request(draft.id)
                        } onClose: {
                            appState.closeDraft(id: draft.id)
                        }
                    }
                    
                    ForEach(appState.openEnvironmentDrafts) { envDraft in
                        EnvironmentTabItemView(appState: appState, draft: envDraft, isSelected: appState.selectedEnvironmentDraftID == envDraft.id) {
                            appState.selectedTab = .environment(envDraft.id)
                        } onClose: {
                            appState.activeWorkspaceManager?.closeEnvironmentDraft(id: envDraft.id)
                        }
                    }
                    
                    Button(action: { appState.newScratchRequest() }) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 4)
                    .help("New Request (Cmd+N)")
                }
            }
            
            Spacer()
            
            // Environment Picker
            Menu {
                Button(action: { appState.activeEnvironmentName = nil }) {
                    if appState.activeEnvironmentName == nil {
                        Text("No Environment ") + Text(Image(systemName: "checkmark.circle.fill")).foregroundColor(.green)
                    } else {
                        Text("No Environment")
                    }
                }
                
                if let envs = appState.activeWorkspaceManager?.workspace?.environments, !envs.isEmpty {
                    Divider()
                    ForEach(envs) { env in
                        Button(action: { appState.activeEnvironmentName = env.name }) {
                            if appState.activeEnvironmentName == env.name {
                                Text("\(env.name) ") + Text(Image(systemName: "checkmark.circle.fill")).foregroundColor(.green)
                            } else {
                                Text(env.name)
                            }
                        }
                    }
                }
                
                Divider()
                
                Button(action: {
                    appState.newName = ""
                    appState.isShowingNewEnvironmentAlert = true
                }) {
                    Label("Create New Environment", systemImage: "plus")
                }
            } label: {
                Text(appState.activeEnvironmentName ?? "No Environment")
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .frame(maxHeight: .infinity)
                    .background(Color.secondary.opacity(0.1))
            }
            .menuStyle(.borderlessButton)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.trailing, 8)
        }
        .frame(height: 34)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(Divider(), alignment: .bottom)
    }
}

struct TabItemView: View {
    @Bindable var appState: AppState
    let draft: DraftRequest
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 6) {
            Text(draft.method)
                .font(.system(size: 8, weight: .black))
                .foregroundColor(methodColor(draft.method).opacity(0.8))
            
            Text(draft.name)
                .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                .foregroundColor(isSelected ? .primary : .secondary)
                .lineLimit(1)
            
            if draft.isDirty {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 5, height: 5)
            }
            
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 14, height: 14)
                    .background(isHovered ? Color.secondary.opacity(0.2) : Color.clear)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .opacity(isHovered || isSelected ? 1 : 0)
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(isSelected ? Color(NSColor.controlBackgroundColor) : Color.clear)
        .overlay(
            Rectangle()
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 1)
                .padding(.vertical, 8),
            alignment: .trailing
        )
        .onHover { isHovered = $0 }
        .onTapGesture(perform: onSelect)
        .help(draft.url)
        .contextMenu {
            Button("Close Tab") {
                onClose()
            }
            Button("Rename Tab") {
                appState.contextTargetTabID = draft.id
                appState.contextTargetURL = nil // Clear URL so we know it's a tab rename
                appState.newName = draft.name
                appState.isShowingRenameAlert = true
            }
            Divider()
            Button("Close All Others") {
                appState.closeOthers(id: draft.id)
            }
            Button("Close to the Right") {
                appState.closeToTheRight(id: draft.id)
            }
            Button("Close to the Left") {
                appState.closeToTheLeft(id: draft.id)
            }
        }
    }
    
    private func methodColor(_ method: String) -> Color {
        .methodColor(method)
    }
}

struct EnvironmentTabItemView: View {
    @Bindable var appState: AppState
    let draft: DraftEnvironment
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 6) {
            
            Text(draft.name)
                .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                .foregroundColor(isSelected ? .primary : .secondary)
                .lineLimit(1)
            
            if draft.isDirty {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 5, height: 5)
            }
            
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 14, height: 14)
                    .background(isHovered ? Color.secondary.opacity(0.2) : Color.clear)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .opacity(isHovered || isSelected ? 1 : 0)
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(isSelected ? Color(NSColor.controlBackgroundColor) : Color.clear)
        .overlay(
            Rectangle()
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 1)
                .padding(.vertical, 8),
            alignment: .trailing
        )
        .onHover { isHovered = $0 }
        .onTapGesture(perform: onSelect)
        .contextMenu {
            Button("Close Tab") {
                onClose()
            }
            Button("Rename Tab") {
                appState.contextTargetTabID = draft.id
                appState.contextTargetURL = nil
                appState.newName = draft.name
                appState.isShowingRenameAlert = true
            }
            Divider()
            Button("Close All Others") {
                // appState.closeOthers(id: draft.id) // TODO: Support environment close others
            }
        }
    }
}

struct LayoutPickerView: View {
    @Bindable var appState: AppState
    @State private var isShowingPicker = false
    
    var body: some View {
        Button(action: { isShowingPicker.toggle() }) {
            Image(systemName: appState.preferredLayoutMode.icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 28, height: 28)
                .background(isShowingPicker ? Color.secondary.opacity(0.1) : Color.clear)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .help("Change Layout")
        .popover(isPresented: $isShowingPicker, arrowEdge: .bottom) {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    LayoutOptionButton(mode: .left, current: $appState.preferredLayoutMode, icon: "square.leftthird.inset.filled", help: "Dock to Left")
                    LayoutOptionButton(mode: .bottom, current: $appState.preferredLayoutMode, icon: "square.bottomthird.inset.filled", help: "Dock to Bottom")
                    LayoutOptionButton(mode: .right, current: $appState.preferredLayoutMode, icon: "square.rightthird.inset.filled", help: "Dock to Right")
                }
                .padding(.top, 4)
                
                Divider()
                
                Toggle("Auto-switch when narrow", isOn: Binding(
                    get: { appState.preferredLayoutMode == .auto },
                    set: { if $0 { appState.preferredLayoutMode = .auto } else { appState.preferredLayoutMode = .right } }
                ))
                .font(.system(size: 11))
                .toggleStyle(.checkbox)
            }
            .padding(12)
            .frame(width: 180)
        }
    }
}

struct LayoutOptionButton: View {
    let mode: LayoutMode
    @Binding var current: LayoutMode
    let icon: String
    let help: String
    
    var isSelected: Bool { current == mode }
    
    var body: some View {
        Button(action: { current = mode }) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: 32, height: 32)
                .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

#Preview {
    ContentView(appState: AppState())
}
