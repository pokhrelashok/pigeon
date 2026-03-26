//
//  SidebarView.swift
//  Pigeon
//
//  Created by Antigravity on 19/03/2026.
//

import SwiftUI

struct SidebarView: View {
    var appState: AppState
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @FocusState private var isListFocused: Bool
    
    // Expansion State is now managed in WorkspaceManager
    @State private var springLoadedIDs: Set<String> = []
    @State private var draggingOverID: String? = nil
    
    var body: some View {
        @Bindable var appState = appState
        
        VStack(spacing: 0) {
            // Custom Search Bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                
                TextField("Search files", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .font(.system(size: 12))
                    .stopNewlineEntry(text: $searchText)
                    .onExitCommand { isSearchFocused = false }
                    .onKeyPress(phases: .down) { keyPress in
                        if keyPress.key == .tab {
                            isListFocused = true
                            return .handled
                        }
                        return .ignored
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        isSearchFocused = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSearchFocused ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSearchFocused ? 2 : 1)
            )
            .padding(10)
            
            if appState.workspaceManagers.isEmpty {
                VStack(alignment: .center, spacing: 12) {
                    Image(systemName: "folder.badge.minus")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No Workspace Loaded")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 40)
            } else {
                WorkspaceCarouselView(appState: appState, workspaceListView: workspaceListView)
            }
            
            Divider()
            
            HStack {
                Button(action: { appState.isShowingSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(10)
                .help("Settings")
                
                Spacer()
            }
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        }
        .onAppear {
            isListFocused = true
        }
        .background(
            Button("") {
                isSearchFocused = true
            }
            .keyboardShortcut("f", modifiers: [.control])
            .opacity(0)
        )
        .background(
            Button("") {
                isSearchFocused = true
            }
            .keyboardShortcut("f", modifiers: [.command])
            .opacity(0)
        )
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: loadWorkspace) {
                    Image(systemName: "folder.badge.plus")
                }
                .help("Load Workspace")
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
    
    @ViewBuilder
    private func workspaceListView(manager: WorkspaceManager) -> some View {
        @Bindable var bindableManager = manager

        VStack(spacing: 0) {
            // Workspace header — outside the List so it can never be collapsed
            if let workspace = manager.workspace {
                HStack(spacing: 4) {
                    if manager.isScratchpad {
                        Image(systemName: "scribble")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.accentColor)
                    }
                    
                    Text(workspace.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button {
                        appState.contextTargetFolderURL = manager.currentWorkspaceURL
                        appState.newName = ""
                        appState.isShowingNewRequestAlert = true
                    } label: {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("New Request")

                    Button {
                        appState.contextTargetFolderURL = manager.currentWorkspaceURL
                        appState.newName = ""
                        appState.isShowingNewFolderAlert = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("New Folder")

                    if !manager.isScratchpad {
                        Button {
                            appState.closeWorkspace(manager)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                                .frame(width: 22, height: 22)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Close Workspace")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                
                Divider()
            }

            sidebarListView(manager: manager)
                .focused($isListFocused)
                // Use a single onKeyPress handler to distinguish Tab and Shift-Tab
                .onKeyPress(phases: .down) { keyPress in
                    if keyPress.key == .tab {
                        isSearchFocused = true
                        return .handled
                    }
                    if keyPress.key == .return {
                        handleReturnKey(manager: manager)
                        return .handled
                    }
                    return .ignored
                }
                .dropDestination(for: URL.self) { items, location in
                    guard let sourceURL = items.first, let rootURL = manager.currentWorkspaceURL else { return false }
                    manager.moveItem(at: sourceURL, to: rootURL)
                    return true
                }
            .contextMenu {
                Button("New Request") {
                    appState.contextTargetFolderURL = manager.currentWorkspaceURL
                    appState.newName = ""
                    appState.isShowingNewRequestAlert = true
                }
                Button("New Folder") {
                    appState.contextTargetFolderURL = manager.currentWorkspaceURL
                    appState.newName = ""
                    appState.isShowingNewFolderAlert = true
                }
                Divider()
                Button("Refresh Workspace") {
                    manager.refreshWorkspace()
                }
                if !manager.isScratchpad {
                    Divider()
                    Button("Close Workspace", role: .destructive) {
                        appState.closeWorkspace(manager)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func sidebarListView(manager: WorkspaceManager) -> some View {
        @Bindable var manager = manager
        List(selection: $manager.selectedSidebarItemID) {
            if let workspace = manager.workspace {
                // Environments Section Header
                HStack {
                    Text("ENVIRONMENTS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button {
                        appState.contextTargetFolderURL = manager.currentWorkspaceURL
                        appState.newName = ""
                        appState.isShowingNewEnvironmentAlert = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
                .padding(.bottom, 2)
                
                ForEach(workspace.environments) { env in
                    EnvironmentSidebarRow(env: env, manager: manager, appState: appState)
                        .tag(env.filePath ?? env.id.uuidString)
                }

                // Requests Section Header
                HStack {
                    Text("REQUESTS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button {
                        appState.contextTargetFolderURL = manager.currentWorkspaceURL
                        appState.newName = ""
                        appState.isShowingNewRequestAlert = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .help("New Request")
                }
                .padding(.top, 8)
                .padding(.bottom, 2)
                
                SidebarTree(
                    items: filteredItems(workspace.requests),
                    manager: manager,
                    appState: appState,
                    springLoadedIDs: $springLoadedIDs,
                    draggingOverID: $draggingOverID
                )
            } else {
                Text("Loading Workspace...")
                    .foregroundColor(.secondary)
            }
        }
        .id(manager.refreshID)
        .listStyle(.sidebar)
    }

    private func handleReturnKey(manager: WorkspaceManager) {
        if let selectedID = manager.selectedSidebarItemID {
            if let item = findSidebarItem(id: selectedID, in: manager.workspace?.requests ?? []) {
                if item.isFolder {
                    if manager.expandedItemIDs.contains(item.id) {
                        manager.expandedItemIDs.remove(item.id)
                    } else {
                        manager.expandedItemIDs.insert(item.id)
                    }
                } else {
                    if let request = manager.loadRequest(from: item.url) {
                        manager.openRequest(request)
                    }
                }
            } else if let env = manager.workspace?.environments.first(where: { ($0.filePath ?? $0.id.uuidString) == selectedID }) {
                manager.openEnvironment(env)
            }
        }
    }
    
    private func filteredItems(_ items: [SidebarItem]) -> [SidebarItem] {
        if searchText.isEmpty { return items }
        return items.compactMap { filterItem($0) }
    }
    
    private func filterItem(_ item: SidebarItem) -> SidebarItem? {
        let matches = item.name.localizedCaseInsensitiveContains(searchText)
        
        if let children = item.children {
            let filteredChildren = children.compactMap { filterItem($0) }
            if matches || !filteredChildren.isEmpty {
                var copy = item
                copy.children = filteredChildren.isEmpty ? nil : filteredChildren
                return copy
            }
        } else if matches {
            return item
        }
        return nil
    }
    
    private func findSidebarItem(id: String, in items: [SidebarItem]) -> SidebarItem? {
        for item in items {
            if item.id == id { return item }
            if let children = item.children, let found = findSidebarItem(id: id, in: children) {
                return found
            }
        }
        return nil
    }

    private func loadWorkspace() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                appState.addWorkspace(from: url)
            }
        }
    }
}

struct SidebarTree: View {
    let items: [SidebarItem]
    let manager: WorkspaceManager
    @Bindable var appState: AppState
    @Binding var springLoadedIDs: Set<String>
    @Binding var draggingOverID: String?
    // Single source of truth for drop highlight — replaces the old dropTargetID
    @State private var highlightedDropID: String? = nil
    
    var body: some View {
        ForEach(items) { item in
            if item.isFolder {
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { manager.expandedItemIDs.contains(item.id) },
                        set: { isExpanded in
                            if isExpanded {
                                manager.expandedItemIDs.insert(item.id)
                            } else {
                                manager.expandedItemIDs.remove(item.id)
                                springLoadedIDs.remove(item.id)
                            }
                        }
                    )
                ) {
                    if let children = item.children {
                        SidebarTree(
                            items: children,
                            manager: manager,
                            appState: appState,
                            springLoadedIDs: $springLoadedIDs,
                            draggingOverID: $draggingOverID
                        )
                    }
                } label: {
                    sidebarRow(for: item)
                }
                .tag(item.id)
            } else {
                sidebarRow(for: item)
                    .tag(item.id)
            }
        }
    }
    
    @ViewBuilder
    private func sidebarRow(for item: SidebarItem) -> some View {
        // Only folders show a drop highlight — non-folders don't visually accept drops
        SidebarItemRow(appState: appState, manager: manager, item: item, isTargeted: item.isFolder && item.id == highlightedDropID)
            .onDrag { NSItemProvider(object: item.url as NSURL) }
            .dropDestination(for: URL.self) { droppedItems, _ in
                guard let sourceURL = droppedItems.first else { return false }
                
                let targetFolderURL = item.isFolder ? item.url : item.url.deletingLastPathComponent()
                
                // Bail out if trying to drop onto itself, same parent, or a descendant
                if manager.isAncestor(sourceURL, of: targetFolderURL) { return false }
                if sourceURL.deletingLastPathComponent().standardized == targetFolderURL.standardized { return false }
                
                manager.moveItem(at: sourceURL, to: targetFolderURL)
                
                // Keep the destination folder expanded so the user can see where the item landed
                if item.isFolder {
                    manager.expandedItemIDs.insert(item.id)
                    springLoadedIDs.remove(item.id) 
                }
                
                // Always expand the moved item at its new location (no-op for files)
                let newID = targetFolderURL.appendingPathComponent(sourceURL.lastPathComponent).path
                manager.expandedItemIDs.insert(newID)
                manager.expandedItemIDs.remove(sourceURL.path) // clean up old stale entry
                
                draggingOverID = nil
                highlightedDropID = nil
                return true
            } isTargeted: { targeted in
                if targeted {
                    // Only register folders as highlighted drop targets
                    if item.isFolder {
                        highlightedDropID = item.id
                    }
                    draggingOverID = item.id
                    
                    if item.isFolder {
                        // Spring-load: expand folder after hovering 0.6s
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            let stillOver = draggingOverID == item.id
                            let overChild = manager.workspace?.isID(draggingOverID, descendantOf: item.id) ?? false
                            if (stillOver || overChild) && !manager.expandedItemIDs.contains(item.id) {
                                manager.expandedItemIDs.insert(item.id)
                                springLoadedIDs.insert(item.id)
                            }
                        }
                    }
                } else {
                    if highlightedDropID == item.id { highlightedDropID = nil }
                    if draggingOverID == item.id { draggingOverID = nil }
                    
                    // Collapse spring-loaded folder, but only if we truly left it (not entered a child)
                    if springLoadedIDs.contains(item.id) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            let overChild = manager.workspace?.isID(draggingOverID, descendantOf: item.id) ?? false
                            let stillOver = draggingOverID == item.id
                            if !overChild && !stillOver {
                                manager.expandedItemIDs.remove(item.id)
                                springLoadedIDs.remove(item.id)
                            }
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                if item.isFolder {
                    if manager.expandedItemIDs.contains(item.id) {
                        manager.expandedItemIDs.remove(item.id)
                    } else {
                        manager.expandedItemIDs.insert(item.id)
                    }
                } else {
                    if let request = manager.loadRequest(from: item.url) {
                        manager.openRequest(request)
                    }
                }
            }
            .onTapGesture(count: 1) {
                if item.isFolder {
                    if manager.expandedItemIDs.contains(item.id) {
                        manager.expandedItemIDs.remove(item.id)
                    } else {
                        manager.expandedItemIDs.insert(item.id)
                    }
                } else {
                    manager.selectedSidebarItemID = item.id
                }
            }
            .contextMenu {
                Button("New Request") {
                    appState.contextTargetFolderURL = item.isFolder ? item.url : item.url.deletingLastPathComponent()
                    appState.newName = ""
                    appState.isShowingNewRequestAlert = true
                }
                Button("New Folder") {
                    appState.contextTargetFolderURL = item.isFolder ? item.url : item.url.deletingLastPathComponent()
                    appState.newName = ""
                    appState.isShowingNewFolderAlert = true
                }
                Divider()
                Button("Clone") {
                    manager.cloneItem(at: item.url)
                }
                Button("Rename") {
                    appState.contextTargetURL = item.url
                    appState.newName = item.name
                    appState.isShowingRenameAlert = true
                }
                Button("Reveal in Finder") {
                    NSWorkspace.shared.selectFile(item.url.path, inFileViewerRootedAtPath: "")
                }
                Divider()
                Button("Delete", role: .destructive) {
                    manager.deleteItem(at: item.url)
                }
            }
    }
}

struct SidebarItemRow: View {
    var appState: AppState
    var manager: WorkspaceManager
    let item: SidebarItem
    let isTargeted: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            if item.isFolder {
                Label(item.name, systemImage: "folder")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .allowsHitTesting(false)
            } else {
                if let method = item.method {
                    Text(method)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.methodColor(method).opacity(manager.selectedSidebarItemID == item.id ? 0.4 : 0.15))
                        .foregroundColor(Color.methodColor(method))
                        .cornerRadius(4)
                        .allowsHitTesting(false)
                } else {
                    Image(systemName: "doc.text")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .allowsHitTesting(false)
                }
                Text(item.name)
                    .font(.system(size: 12))
                    .allowsHitTesting(false)
                
                if let draft = appState.activeDraft, draft.initialRequest.path == item.url.path, draft.isDirty {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                        .allowsHitTesting(false)
                }
                
                Spacer()
                
                Button(action: {
                    manager.deleteItem(at: item.url)
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isTargeted ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isTargeted ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Workspace Carousel 

struct WorkspaceCarouselView: View {
    var appState: AppState
    var workspaceListView: (WorkspaceManager) -> AnyView

    @State private var dragOffset: CGFloat = 0
    @State private var accumulatedDelta: CGFloat = 0
    @State private var velocity: CGFloat = 0
    @State private var isHovering = false
    @State private var eventMonitor: Any?
    // Live page width — updated via onChange so the monitor never uses a stale value
    @State private var currentPageWidth: CGFloat = 0

    private let snapThresholdFraction: CGFloat = 0.25
    private let velocityThreshold: CGFloat = 8

    init(appState: AppState, workspaceListView: @escaping (WorkspaceManager) -> some View) {
        self.appState = appState
        self.workspaceListView = { AnyView(workspaceListView($0)) }
    }

    var body: some View {
        let count = appState.workspaceManagers.count
        let activeIndex = appState.activeWorkspaceIndex

        VStack(spacing: 0) {
            GeometryReader { geo in
                let pageWidth = geo.size.width

                HStack(spacing: 0) {
                    ForEach(0..<count, id: \.self) { index in
                        workspaceListView(appState.workspaceManagers[index])
                            .frame(width: pageWidth)
                    }
                }
                .offset(x: -CGFloat(activeIndex) * pageWidth + dragOffset)
                // Only animate index changes — never animate during live drag
                .animation(
                    .interactiveSpring(response: 0.32, dampingFraction: 0.82),
                    value: activeIndex
                )
                .onHover { isHovering = $0 }
                .clipped()
                .onAppear {
                    currentPageWidth = pageWidth
                    rebuildMonitor(count: count)
                }
                .onChange(of: pageWidth) { _, newWidth in
                    currentPageWidth = newWidth
                    // Rebuild so the monitor closure captures the refreshed width
                    tearDownMonitor()
                    rebuildMonitor(count: count)
                }
                .onDisappear { tearDownMonitor() }
            }

            if count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<count, id: \.self) { index in
                        Circle()
                            .fill(activeIndex == index ? Color.primary : Color.clear)
                            .frame(width: 6, height: 6)
                            .overlay(Circle().stroke(Color.primary.opacity(0.4), lineWidth: 1))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.82)) {
                                    dragOffset = 0
                                    appState.activeWorkspaceIndex = index
                                }
                            }
                            .animation(.easeInOut(duration: 0.18), value: activeIndex)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
        }
    }

    private func tearDownMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func rebuildMonitor(count: Int) {
        // Track dragging locally — NOT as @State — to avoid triggering SwiftUI
        // re-renders mid-gesture (which caused the initial jank).
        var localIsDragging = false

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [self] event in
            guard isHovering else { return event }

            let phase = event.phase
            guard phase == .began || phase == .changed || phase == .ended || phase == .cancelled else {
                return event
            }

            // Ignore vertical-dominant scrolls
            if phase == .began && abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX) {
                return event
            }

            let liveCount = appState.workspaceManagers.count
            guard liveCount > 1 else { return event }

            handleScroll(
                delta: event.scrollingDeltaX,
                phase: phase,
                pageWidth: currentPageWidth,   // always live
                count: liveCount,
                isDragging: &localIsDragging
            )
            return nil
        }
    }

    private func handleScroll(
        delta: CGFloat,
        phase: NSEvent.Phase,
        pageWidth: CGFloat,
        count: Int,
        isDragging: inout Bool
    ) {
        let activeIndex = appState.activeWorkspaceIndex

        switch phase {
        case .began:
            isDragging = true
            accumulatedDelta = 0
            velocity = 0
            dragOffset = 0

        case .changed:
            guard isDragging else { return }
            velocity = velocity * 0.5 + delta * 0.5
            accumulatedDelta += delta
            let atStart = activeIndex == 0 && accumulatedDelta < 0
            let atEnd   = activeIndex == count - 1 && accumulatedDelta > 0
            
            if atStart || atEnd {
                // Apply strong rubberband resistance to prevent pulling the spring too much
                let friction: CGFloat = 20.0
                dragOffset = (accumulatedDelta > 0 ? 1 : -1) * friction * log(1 + abs(accumulatedDelta) / friction)
            } else {
                dragOffset = accumulatedDelta
            }

        case .ended, .cancelled:
            guard isDragging else { return }
            isDragging = false

            var targetIndex = activeIndex
            let isFastSwipe = abs(velocity) > velocityThreshold
            let isPastThreshold = abs(accumulatedDelta) > pageWidth * snapThresholdFraction

            if isFastSwipe || isPastThreshold {
                targetIndex = accumulatedDelta > 0
                    ? max(activeIndex - 1, 0)
                    : min(activeIndex + 1, count - 1)
            }

            withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.82)) {
                dragOffset = 0
            }
            accumulatedDelta = 0
            velocity = 0
            appState.activeWorkspaceIndex = targetIndex

        default:
            break
        }
    }
}

struct EnvironmentSidebarRow: View {
    let env: Environment
    let manager: WorkspaceManager
    @Bindable var appState: AppState
    
    var body: some View {
        HStack {
            Text(env.name)
                .font(.system(size: 12))
            
            Spacer()
            
            if manager.activeEnvironmentName == env.name {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
            }
            
            if let draft = manager.openEnvironmentDrafts.first(where: { $0.initialEnvironment.id == env.id }), draft.isDirty {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
            }
            
            Button(action: {
                if let path = env.filePath {
                    manager.deleteItem(at: URL(fileURLWithPath: path))
                }
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)
        }
        .padding(.vertical, 1)
        .padding(.leading, 12)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            manager.activeEnvironmentName = env.name
            appState.saveSession()
        }
        .onTapGesture {
            manager.openEnvironment(env)
        }
        .contextMenu {
            Button("Set Active") {
                manager.activeEnvironmentName = env.name
                appState.saveSession()
            }
            Divider()
            Button("Rename") {
                if let path = env.filePath {
                    appState.contextTargetURL = URL(fileURLWithPath: path)
                    appState.newName = env.name
                    appState.isShowingRenameAlert = true
                }
            }
            Divider()
            Button("Delete", role: .destructive) {
                if let path = env.filePath {
                    manager.deleteItem(at: URL(fileURLWithPath: path))
                }
            }
        }
    }
}
