//
//  WorkspaceManager.swift
//  pigeon
//
//  Created by Antigravity on 19/03/2026.
//

import Foundation
import Observation

@Observable
class WorkspaceManager {
    var workspace: Workspace?
    var currentWorkspaceURL: URL?
    /// Bumped on full workspace reloads (external events, manual refresh).
    /// NOT bumped on internal renames/moves — those use surgical in-memory patches.
    var refreshID: UUID = UUID()
    var isScratchpad: Bool = false
    var expandedItemIDs: Set<String> = []
    private var fileWatcher: DispatchSourceFileSystemObject?
    private var subDirectoryWatchers: [DispatchSourceFileSystemObject] = []
    private var refreshWorkItem: DispatchWorkItem?
    /// Suppresses the file-watcher debounced reload while *we* are performing
    /// an internal rename / move so the watcher doesn't trigger a redundant
    /// full tree rebuild on top of our already-correct in-memory update.
    private var isPendingInternalChange = false
    
    deinit {
        fileWatcher?.cancel()
        subDirectoryWatchers.forEach { $0.cancel() }
        refreshWorkItem?.cancel()
    }
    
    // UI State for this specific workspace
    var selectedSidebarItemID: String? {
        didSet {
            // guard oldValue != selectedSidebarItemID else { return }
            // Auto-opening removed as per user request to use Enter/Double-click instead
        }
    }
    
    var openDrafts: [DraftRequest] = []
    var openEnvironmentDrafts: [DraftEnvironment] = []
    
    enum TabSelection: Hashable {
        case request(UUID)
        case environment(UUID)
    }
    
    var selectedTab: TabSelection? {
        didSet {
            guard oldValue != selectedTab else { return }
            
            // Deprecated compatibility fields - keep updated for now
            switch selectedTab {
            case .request(let id): 
                selectedDraftID = id
                selectedEnvironmentDraftID = nil
            case .environment(let id):
                selectedEnvironmentDraftID = id
                selectedDraftID = nil
            case .none:
                selectedDraftID = nil
                selectedEnvironmentDraftID = nil
            }
            syncSidebarSelectionWithActiveTab()
        }
    }
    
    // For backward compatibility and specialized use cases
    var selectedDraftID: UUID?
    var selectedEnvironmentDraftID: UUID?
    
    var activeDraft: DraftRequest? {
        openDrafts.first { $0.id == selectedDraftID }
    }
    
    var activeEnvironmentDraft: DraftEnvironment? {
        openEnvironmentDrafts.first { $0.id == selectedEnvironmentDraftID }
    }
    
    var activeEnvironmentName: String?
    
    var activeEnvironment: Environment? {
        // If we have an open draft for this environment, use its current variables (including unsaved changes)
        if let draft = openEnvironmentDrafts.first(where: { $0.name == activeEnvironmentName }) {
            return draft.toEnvironment()
        }
        // Fallback to the saved version in the workspace
        return workspace?.environments.first { $0.name == activeEnvironmentName }
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
    
    func openRequest(_ request: Request) {
        // Try to find by path first (for saved requests)
        if let path = request.path, let existing = openDrafts.first(where: { $0.initialRequest.path == path }) {
            selectedTab = .request(existing.id)
            return
        } 
        
        // Fallback to initial ID (for scratch/unsaved requests)
        if let existing = openDrafts.first(where: { $0.initialRequest.id == request.id }) {
            selectedTab = .request(existing.id)
            return
        }
        
        let newDraft = DraftRequest(request: request)
        openDrafts.append(newDraft)
        selectedTab = .request(newDraft.id)
    }
    
    func openEnvironment(_ env: Environment) {
        if let existing = openEnvironmentDrafts.first(where: { $0.initialEnvironment.id == env.id }) {
            selectedTab = .environment(existing.id)
            return
        }
        
        if let filePath = env.filePath, let existing = openEnvironmentDrafts.first(where: { $0.initialEnvironment.filePath == filePath }) {
            selectedTab = .environment(existing.id)
            return
        }
        
        let newDraft = DraftEnvironment(env: env)
        openEnvironmentDrafts.append(newDraft)
        selectedTab = .environment(newDraft.id)
    }
    
    func newScratchRequest() {
        let request = Request(name: "New Request", method: "GET", url: "https://jsonplaceholder.typicode.com/todos/1", headers: nil, query: nil, pathParams: nil, body: nil, auth: nil, seq: nil, tags: nil, docs: nil, varsPreRequest: nil, varsPostResponse: nil, bodyType: "none", multipartForm: nil, formUrlEncoded: nil)
        openRequest(request)
    }
    
    func closeDraft(id: UUID) {
        if let index = openDrafts.firstIndex(where: { $0.id == id }) {
            openDrafts.remove(at: index)
            if case .request(let selectedID) = selectedTab, selectedID == id {
                if !openDrafts.isEmpty {
                    selectedTab = .request(openDrafts[max(0, index - 1)].id)
                } else if !openEnvironmentDrafts.isEmpty {
                    selectedTab = .environment(openEnvironmentDrafts.last!.id)
                } else {
                    selectedTab = nil
                }
            }
            syncSidebarSelectionWithActiveTab()
        }
    }
    
    func closeEnvironmentDraft(id: UUID) {
        if let index = openEnvironmentDrafts.firstIndex(where: { $0.id == id }) {
            openEnvironmentDrafts.remove(at: index)
            if case .environment(let selectedID) = selectedTab, selectedID == id {
                if !openEnvironmentDrafts.isEmpty {
                    selectedTab = .environment(openEnvironmentDrafts[max(0, index - 1)].id)
                } else if !openDrafts.isEmpty {
                    selectedTab = .request(openDrafts.last!.id)
                } else {
                    selectedTab = nil
                }
            }
            syncSidebarSelectionWithActiveTab()
        }
    }
    
    func closeOthers(id: UUID) {
        openDrafts = openDrafts.filter { $0.id == id }
        selectedDraftID = id
        syncSidebarSelectionWithActiveTab()
    }
    
    func closeToTheRight(id: UUID) {
        if let index = openDrafts.firstIndex(where: { $0.id == id }) {
            openDrafts = Array(openDrafts[0...index])
            selectedDraftID = id
            syncSidebarSelectionWithActiveTab()
        }
    }
    
    func closeToTheLeft(id: UUID) {
        if let index = openDrafts.firstIndex(where: { $0.id == id }) {
            openDrafts = Array(openDrafts[index..<openDrafts.count])
            selectedDraftID = id
            syncSidebarSelectionWithActiveTab()
        }
    }
    
    private func syncSidebarSelectionWithActiveTab() {
        if let draft = activeDraft, let path = draft.initialRequest.path {
            selectedSidebarItemID = path
        } else if let envDraft = activeEnvironmentDraft, let path = envDraft.initialEnvironment.filePath {
            selectedSidebarItemID = path
        } else if openDrafts.isEmpty && openEnvironmentDrafts.isEmpty {
            selectedSidebarItemID = nil
        }
    }
    
    func renameDraft(id: UUID, newName: String) {
        guard let draft = openDrafts.first(where: { $0.id == id }) else { return }
        
        if let path = draft.initialRequest.path {
            let oldURL = URL(fileURLWithPath: path)
            renameItem(at: oldURL, to: newName)
        } else {
            draft.name = newName
        }
    }
    
    func loadWorkspace(from url: URL) {
        let standardizedURL = url.standardized
        self.currentWorkspaceURL = standardizedURL
        
        // Start watching the directory for changes
        startWatching(url: standardizedURL)
        
        // Perform heavy I/O on a background thread to keep UI fluid
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let fileManager = FileManager.default
            let workspaceFileURL = standardizedURL.appendingPathComponent("workspace.json")
            let brunoFileURL = standardizedURL.appendingPathComponent("bruno.json")
            
            var loadedWorkspace: Workspace
            let targetURL = fileManager.fileExists(atPath: brunoFileURL.path) ? brunoFileURL : workspaceFileURL
            
            if fileManager.fileExists(atPath: targetURL.path) {
                do {
                    let data = try Data(contentsOf: targetURL)
                    let decoder = JSONDecoder()
                    loadedWorkspace = try decoder.decode(Workspace.self, from: data)
                } catch {
                    print("Failed to decode workspace file (\(error)), falling back to synthetic workspace.")
                    var name = standardizedURL.lastPathComponent
                    if name.lowercased() == "pigeon" { name = "Pigeon" }
                    loadedWorkspace = Workspace(name: name, path: standardizedURL.path, version: "1")
                }
            } else {
                var name = standardizedURL.lastPathComponent
                if name.lowercased() == "pigeon" { name = "Pigeon" }
                loadedWorkspace = Workspace(name: name, path: standardizedURL.path, version: "1")
            }
            
            let requestsURL = standardizedURL.appendingPathComponent("requests")
            if fileManager.fileExists(atPath: requestsURL.path) {
                loadedWorkspace.requests = self.loadSidebarItems(from: requestsURL)
            } else {
                loadedWorkspace.requests = self.loadSidebarItems(from: standardizedURL)
            }
            
            let envsURL = standardizedURL.appendingPathComponent("environments")
            if fileManager.fileExists(atPath: envsURL.path) {
                loadedWorkspace.environments = self.loadEnvironments(from: envsURL)
            }
            
            DispatchQueue.main.async {
                // Ensure we are still managing the same workspace before applying results
                guard self.currentWorkspaceURL?.standardized.path == standardizedURL.path else { return }
                
                self.workspace = loadedWorkspace
                self.reconcileOpenDrafts()
                
                // Auto-select first environment if nothing is selected
                if self.activeEnvironmentName == nil, let first = loadedWorkspace.environments.first {
                    self.activeEnvironmentName = first.name
                }
                
                // Bump refreshID so the List view fully re-renders after a disk reload.
                self.refreshID = UUID()
            }
        }
    }
    
    private func startWatching(url: URL) {
        // Cancel existing watchers
        fileWatcher?.cancel()
        fileWatcher = nil
        subDirectoryWatchers.forEach { $0.cancel() }
        subDirectoryWatchers.removeAll()
        
        watchDirectory(url: url, isRoot: true)
        
        // Also watch subdirectories so nested file renames are detected
        let fileManager = FileManager.default
        if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for case let subURL as URL in enumerator {
                let isDir = (try? subURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if isDir {
                    watchDirectory(url: subURL, isRoot: false)
                }
            }
        }
    }
    
    private func watchDirectory(url: URL, isRoot: Bool) {
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .extend, .rename, .delete, .attrib], queue: .global())
        
        source.setEventHandler { [weak self] in
            // Skip reload if we triggered this event ourselves.
            guard !(self?.isPendingInternalChange ?? true) else { return }
            self?.debouncedRefresh()
        }
        
        source.setCancelHandler {
            close(descriptor)
        }
        
        source.resume()
        
        if isRoot {
            fileWatcher = source
        } else {
            subDirectoryWatchers.append(source)
        }
    }
    
    func loadRequest(from url: URL) -> Request? {
        let ext = url.pathExtension.lowercased()
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            if let parser = RequestParserRegistry.shared.parser(for: ext) {
                return try parser.parse(content: content, url: url)
            }
            return nil
        } catch {
            print("Error loading request from \(url.path): \(error)")
            return nil
        }
    }
    
    func saveRequest(_ request: Request, to url: URL) {
        let path = url.path
        let content: String
        let ext = url.pathExtension.lowercased()
        
        if ext == "bru" {
            content = RequestSerializer.toBru(request)
        } else {
            content = RequestSerializer.toYaml(request)
        }
        
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to save request to \(path): \(error)")
        }
    }
    
    func saveEnvironment(_ env: Environment, to url: URL) {
        let path = url.path
        let ext = url.pathExtension.lowercased()
        let content: String
        
        if ext == "yml" || ext == "yaml" {
            content = YamlEnvironmentParser().serialize(env)
        } else {
            content = BruEnvironmentParser().serialize(env)
        }
        
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            debouncedRefresh()
        } catch {
            print("Failed to save environment to \(path): \(error)")
        }
    }
    
    private func loadSidebarItems(from url: URL) -> [SidebarItem] {
        let fileManager = FileManager.default
        var items: [SidebarItem] = []
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey])
            for fileURL in contents {
                let name = fileURL.lastPathComponent
                guard !name.hasPrefix(".") else { continue }
                if ["bruno.json", "workspace.json", "environments", "package.json", "package-lock.json", "node_modules"].contains(name) {
                    continue
                }
                
                let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                
                if isDirectory {
                    let children = loadSidebarItems(from: fileURL)
                    let folder = SidebarItem(
                        name: fileURL.lastPathComponent,
                        url: fileURL,
                        isFolder: true,
                        method: nil,
                        children: children.isEmpty ? [] : children
                    )
                    items.append(folder)
                } else {
                    let ext = fileURL.pathExtension.lowercased()
                    if ext == "json" || ext == "bru" || ext == "yml" || ext == "yaml" {
                        let method = extractMethod(from: fileURL, ext: ext)
                        let rawName = fileURL.deletingPathExtension().lastPathComponent
                        let item = SidebarItem(
                            name: rawName,
                            url: fileURL,
                            isFolder: false,
                            method: method,
                            children: nil
                        )
                        items.append(item)
                    }
                }
            }
        } catch {
            print("Error loading sidebar items: \(error)")
        }
        
        return items.sorted { a, b in
            if a.isFolder == b.isFolder {
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
            return a.isFolder && !b.isFolder
        }
    }
    
    func deleteItem(at url: URL) {
        let fileManager = FileManager.default
        let path = url.path
        
        // 1. Identify all drafts that should be closed (for the file or folder children)
        let draftsToClose = openDrafts.filter { draft in
            guard let draftPath = draft.initialRequest.path else { return false }
            return draftPath == path || draftPath.hasPrefix(path + "/")
        }
        
        let envDraftsToClose = openEnvironmentDrafts.filter { envDraft in
            guard let envPath = envDraft.initialEnvironment.filePath else { return false }
            return envPath == path || envPath.hasPrefix(path + "/")
        }
        
        // 2. Close them properly to update selectedTab
        for draft in draftsToClose {
            closeDraft(id: draft.id)
        }
        for envDraft in envDraftsToClose {
            closeEnvironmentDraft(id: envDraft.id)
        }
        
        do {
            try fileManager.removeItem(at: url)
            debouncedRefresh()
        } catch {
            print("Error deleting item: \(error)")
        }
    }
    
    func renameItem(at url: URL, to newName: String) {
        let fileManager = FileManager.default
        let ext = url.pathExtension
        let newURL = url.deletingLastPathComponent().appendingPathComponent(newName).appendingPathExtension(ext)
        
        // Suppress the file-watcher so its event for this rename doesn't
        // trigger a redundant full reload on top of our in-memory patch.
        isPendingInternalChange = true
        
        do {
            // First move the item on disk
            try fileManager.moveItem(at: url, to: newURL)
            
            // If it's a request file, update internal content (name field)
            let lowerExt = ext.lowercased()
            if !url.hasDirectoryPath && (lowerExt == "bru" || lowerExt == "yml" || lowerExt == "yaml") {
                if var request = loadRequest(from: newURL) {
                    request.name = newName
                    saveRequest(request, to: newURL)
                }
            }
            
            // Update any open tabs for this file OR its children if it's a folder
            let oldPath = url.path
            let newPath = newURL.path
            
            for draft in openDrafts {
                if let draftPath = draft.initialRequest.path {
                    if draftPath == oldPath {
                        draft.initialRequest.path = newPath
                        draft.initialRequest.name = newName
                        draft.name = newName
                    } else if draftPath.hasPrefix(oldPath + "/") {
                        let relativePath = String(draftPath.dropFirst(oldPath.count))
                        draft.initialRequest.path = newPath + relativePath
                    }
                }
            }
            
            for envDraft in openEnvironmentDrafts {
                if let envPath = envDraft.initialEnvironment.filePath {
                    if envPath == oldPath {
                        envDraft.initialEnvironment.filePath = newPath
                        envDraft.initialEnvironment.name = newName
                        envDraft.name = newName
                    } else if envPath.hasPrefix(oldPath + "/") {
                        let relativePath = String(envPath.dropFirst(oldPath.count))
                        envDraft.initialEnvironment.filePath = newPath + relativePath
                    }
                }
            }
            
            // 1. Patch the in-memory tree surgically — only the renamed node changes.
            //    SwiftUI diffs the ForEach by SidebarItem.id (= url.path) and will
            //    animate just that row without disturbing the rest of the tree.
            if let currentRequests = workspace?.requests {
                workspace?.requests = updateItemInTree(
                    oldPath: oldPath, newPath: newPath,
                    newName: newName, in: currentRequests
                )
            }
            
            // 2. Sync expansion state for renamed folders
            if expandedItemIDs.contains(oldPath) {
                expandedItemIDs.remove(oldPath)
                expandedItemIDs.insert(newPath)
            }
            
            // 3. Sync sidebar selection to the new path.
            //    We also re-assert it on the next run loop tick: .id(refreshID) destroys
            //    and recreates the entire List, so the freshly built rows need to receive
            //    the selection AFTER they exist, not before.
            let wasSelected = selectedSidebarItemID == oldPath
            if wasSelected { selectedSidebarItemID = newPath }
            
            // 4. Bump refreshID NOW — data, expansion, and selection are all patched.
            //    (debouncedRefresh is NOT called — no second rebuild 0.5 s later.)
            refreshID = UUID()
            
            // Re-assert selection after the new List rows are rendered.
            if wasSelected {
                DispatchQueue.main.async { self.selectedSidebarItemID = newPath }
            }
            
            // 5. Re-watch subdirectories (off main thread) so new paths are tracked.
            //    Clear the suppression flag once re-watching completes so future
            //    *external* fs events are processed normally.
            if let wsURL = currentWorkspaceURL {
                DispatchQueue.global(qos: .utility).async {
                    self.startWatching(url: wsURL)
                    // Brief window to let the OS settle before re-arming the watcher
                    Thread.sleep(forTimeInterval: 0.3)
                    DispatchQueue.main.async { self.isPendingInternalChange = false }
                }
            } else {
                isPendingInternalChange = false
            }
            // NOTE: No debouncedRefresh() here — the in-memory patch above is the
            // single source of truth. A full reload would only cause a visible flicker.
        } catch {
            isPendingInternalChange = false
            print("Error renaming item: \(error)")
        }
    }
    
    func cloneItem(at url: URL) {
        let fileManager = FileManager.default
        let baseName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let newName = "\(baseName)-copy"
        let newURL = url.deletingLastPathComponent().appendingPathComponent(newName).appendingPathExtension(ext)
        
        do {
            try fileManager.copyItem(at: url, to: newURL)
            debouncedRefresh()
        } catch {
            print("Error cloning item: \(error)")
        }
    }
    
    func createNewRequest(in folderURL: URL?, name: String) {
        let parentURL = folderURL ?? currentWorkspaceURL ?? URL(fileURLWithPath: "/")
        let fileName = name.hasSuffix(".bru") ? name : "\(name).bru"
        let fileURL = parentURL.appendingPathComponent(fileName)
        
        // Use a placeholder URL instead of empty string to avoid parser bugs and provide a better UX
        let defaultURL = "https://jsonplaceholder.typicode.com/todos/1"
        
        let request = Request(name: name, method: "GET", url: defaultURL, headers: [:], query: [:], pathParams: [:], body: nil, auth: nil, seq: 1, tags: nil, docs: nil, varsPreRequest: nil, varsPostResponse: nil, bodyType: nil, multipartForm: nil, formUrlEncoded: nil, path: fileURL.path)
        
        saveRequest(request, to: fileURL)
        
        // Ensure parent folder is expanded so the new request is visible in the sidebar
        if let folderPath = folderURL?.path {
            expandedItemIDs.insert(folderPath)
        }
        
        debouncedRefresh()
        
        if let req = loadRequest(from: fileURL) {
            openRequest(req)
            // Explicitly sync sidebar selection
            selectedSidebarItemID = fileURL.path
        }
    }
    
    func createNewFolder(in folderURL: URL?, name: String) {
        let fileManager = FileManager.default
        let parentURL = folderURL ?? currentWorkspaceURL ?? URL(fileURLWithPath: "/")
        let newFolderURL = parentURL.appendingPathComponent(name)
        
        do {
            try fileManager.createDirectory(at: newFolderURL, withIntermediateDirectories: true)
            debouncedRefresh()
        } catch {
            print("Error creating folder: \(error)")
        }
    }
    
    func createNewEnvironment(name: String) {
        guard let workspaceURL = currentWorkspaceURL else { return }
        let envsURL = workspaceURL.appendingPathComponent("environments")
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: envsURL.path) {
            try? fileManager.createDirectory(at: envsURL, withIntermediateDirectories: true)
        }
        
        let fileName = name.hasSuffix(".bru") ? name : "\(name).bru"
        let fileURL = envsURL.appendingPathComponent(fileName)
        
        let env = Environment(name: name, variables: [], filePath: fileURL.path)
        saveEnvironment(env, to: fileURL)
        debouncedRefresh()
        openEnvironment(env)
    }
    
    /// Returns true if `ancestorURL` is a parent of (or equal to) `childURL`.
    func isAncestor(_ ancestorURL: URL, of childURL: URL) -> Bool {
        let ancestorPath = ancestorURL.standardized.path
        let childPath = childURL.standardized.path
        return childPath == ancestorPath || childPath.hasPrefix(ancestorPath + "/")
    }
    
    func moveItem(at url: URL, to destinationFolderURL: URL) {
        let fileManager = FileManager.default
        let newURL = destinationFolderURL.appendingPathComponent(url.lastPathComponent)
        
        // Prevent moving into itself, its own directory, or any of its own descendants
        if url == newURL { return }
        if url.deletingLastPathComponent().standardized == destinationFolderURL.standardized { return }
        if isAncestor(url, of: destinationFolderURL) { return }
        
        // Suppress watcher so our own move event doesn't trigger a redundant reload.
        isPendingInternalChange = true
        
        do {
            // If the source is inside our workspace, MOVE it; otherwise COPY it.
            let isInternal = url.path.hasPrefix(currentWorkspaceURL?.path ?? "")
            
            if isInternal {
                try fileManager.moveItem(at: url, to: newURL)
                // Patch open tab paths for moved file/folder children
                let oldPath = url.path
                for draft in openDrafts {
                    if let path = draft.initialRequest.path, path.hasPrefix(oldPath) {
                        let relativePath = String(path.dropFirst(oldPath.count))
                        draft.initialRequest.path = newURL.path + relativePath
                    }
                }
            } else {
                // External drop — copy only
                try fileManager.copyItem(at: url, to: newURL)
            }
            
            // 1. Patch the in-memory tree surgically
            if let currentRequests = workspace?.requests {
                workspace?.requests = moveItemInTree(
                    oldPath: url.path,
                    newFolderURL: destinationFolderURL,
                    in: currentRequests
                )
            }
            
            // 2. Sync expansion state for moved folders
            if expandedItemIDs.contains(url.path) {
                expandedItemIDs.remove(url.path)
                expandedItemIDs.insert(newURL.path)
            }
            
            // 3. Sync selection to the new path
            if selectedSidebarItemID == url.path {
                selectedSidebarItemID = newURL.path
            }
            
            // 4. Bump refreshID NOW — data, expansion, and selection are all patched.
            //    The List re-renders immediately. No debouncedRefresh() = no second rebuild.
            refreshID = UUID()
            
            // 5. Re-watch so any new subdirectories are tracked, then re-arm the watcher.
            if let wsURL = currentWorkspaceURL {
                DispatchQueue.global(qos: .utility).async {
                    self.startWatching(url: wsURL)
                    Thread.sleep(forTimeInterval: 0.3)
                    DispatchQueue.main.async { self.isPendingInternalChange = false }
                }
            } else {
                isPendingInternalChange = false
            }
            // NOTE: No debouncedRefresh() — the in-memory patch is correct and complete.
        } catch {
            isPendingInternalChange = false
            print("Error moving/copying item: \(error)")
        }
    }
    
    func refreshWorkspace() {
        if let url = currentWorkspaceURL {
            loadWorkspace(from: url)
        }
    }
    
    func debouncedRefresh() {
        refreshWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            print("Refreshing workspace...")
            self?.refreshWorkspace()
        }
        refreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
    
    private func reconcileOpenDrafts() {
        let fileManager = FileManager.default
        var draftsToRemove: [UUID] = []
        
        // Collect all valid paths from the in-memory workspace tree as a safety net
        // to avoid closing tabs that were just renamed (in-memory path updated but
        // the disk refresh fires slightly before the file system settles).
        var validInMemoryPaths: Set<String> = []
        func collectPaths(_ items: [SidebarItem]) {
            for item in items {
                validInMemoryPaths.insert(item.url.path)
                if let children = item.children { collectPaths(children) }
            }
        }
        if let requests = workspace?.requests { collectPaths(requests) }
        
        for draft in openDrafts {
            if let path = draft.initialRequest.path {
                // Only close the tab if the file is missing on disk AND
                // it's not present anywhere in the current in-memory tree
                if !fileManager.fileExists(atPath: path) && !validInMemoryPaths.contains(path) {
                    draftsToRemove.append(draft.id)
                }
            }
        }
        
        if !draftsToRemove.isEmpty {
            DispatchQueue.main.async {
                for id in draftsToRemove {
                    self.closeDraft(id: id)
                }
            }
        }
    }

    private func updateItemInTree(oldPath: String, newPath: String, newName: String, in items: [SidebarItem]) -> [SidebarItem] {
        return items.map { item in
            var newItem = item
            if item.url.path == oldPath {
                newItem.url = URL(fileURLWithPath: newPath)
                newItem.name = newName
            }
            if let children = item.children {
                newItem.children = updateItemInTree(oldPath: oldPath, newPath: newPath, newName: newName, in: children)
            }
            return newItem
        }
    }
    
    private func moveItemInTree(oldPath: String, newFolderURL: URL, in items: [SidebarItem]) -> [SidebarItem] {
        var mutableItems = items
        var itemToMove: SidebarItem?
        
        // Find and remove the item from its current location
        func findAndRemove(from list: inout [SidebarItem]) -> SidebarItem? {
            for i in 0..<list.count {
                if list[i].url.path == oldPath {
                    return list.remove(at: i)
                }
                if var children = list[i].children {
                    if let found = findAndRemove(from: &children) {
                        list[i].children = children.isEmpty ? nil : children
                        return found
                    }
                }
            }
            return nil
        }
        
        itemToMove = findAndRemove(from: &mutableItems)
        
        guard var item = itemToMove else { return items }
        
        // Update item URL to reflect new parent
        item.url = newFolderURL.appendingPathComponent(item.url.lastPathComponent)
        
        // Insert into the target folder, then sort so position matches what disk-refresh will produce
        func insert(into list: inout [SidebarItem], targetPath: String) -> Bool {
            for i in 0..<list.count {
                if list[i].url.path == targetPath {
                    var children = list[i].children ?? []
                    children.append(item)
                    children = sortedSidebarItems(children)
                    list[i].children = children
                    return true
                }
                if var children = list[i].children {
                    if insert(into: &children, targetPath: targetPath) {
                        list[i].children = children
                        return true
                    }
                }
            }
            return false
        }
        
        if newFolderURL.path == currentWorkspaceURL?.path {
            mutableItems.append(item)
            mutableItems = sortedSidebarItems(mutableItems)
        } else if !insert(into: &mutableItems, targetPath: newFolderURL.path) {
            mutableItems.append(item) // Fallback to root
            mutableItems = sortedSidebarItems(mutableItems)
        }
        
        return mutableItems
    }
    
    private func sortedSidebarItems(_ items: [SidebarItem]) -> [SidebarItem] {
        items.sorted { a, b in
            if a.isFolder == b.isFolder {
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
            return a.isFolder && !b.isFolder
        }
    }
    
    private func extractMethod(from url: URL, ext: String) -> String? {
        if ext == "bru" {
            if let fileHandle = try? FileHandle(forReadingFrom: url) {
                defer { try? fileHandle.close() }
                let data = fileHandle.readData(ofLength: 1024)
                if let str = String(data: data, encoding: .utf8)?.lowercased() {
                    let methods = ["get", "post", "put", "delete", "patch", "head", "options"]
                    for method in methods {
                        if str.contains("\(method) {") {
                            return method.uppercased()
                        }
                    }
                }
            }
            return "GET"
        } else if ext == "yml" || ext == "yaml" {
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                let data = YamlParser.parse(content)
                if let http = data["http"] as? [String: Any], let method = http["method"] as? String {
                    return method.uppercased()
                }
                if let method = data["method"] as? String {
                    return method.uppercased()
                }
            }
            return "GET"
        } else if ext == "json" {
            if let data = try? Data(contentsOf: url),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let method = json["method"] as? String {
                    return method.uppercased()
                }
                if let http = json["http"] as? [String: Any], let method = http["method"] as? String {
                    return method.uppercased()
                }
            }
            return "GET"
        }
        return nil
    }
    
    private func loadEnvironments(from url: URL) -> [Environment] {
        let fileManager = FileManager.default
        var envs: [Environment] = []
        let parser = BruEnvironmentParser()
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            for fileURL in contents {
                let ext = fileURL.pathExtension.lowercased()
                if ext == "bru" {
                    do {
                        let content = try String(contentsOf: fileURL, encoding: .utf8)
                        let name = fileURL.deletingPathExtension().lastPathComponent
                        let env = try parser.parse(content: content, name: name, filePath: fileURL.path)
                        envs.append(env)
                    } catch {
                        print("Error parsing .bru environment \(fileURL.lastPathComponent): \(error)")
                    }
                } else if ext == "yml" || ext == "yaml" {
                    do {
                        let content = try String(contentsOf: fileURL, encoding: .utf8)
                        let name = fileURL.deletingPathExtension().lastPathComponent
                        let env = YamlEnvironmentParser().parse(content: content, name: name, filePath: fileURL.path)
                        envs.append(env)
                    } catch {
                        print("Error parsing yaml environment \(fileURL.lastPathComponent): \(error)")
                    }
                }
            }
        } catch {
            print("Error loading environments: \(error)")
        }
        
        return envs
    }
}
