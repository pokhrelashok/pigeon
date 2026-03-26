//
//  AppState.swift
//  pigeon
//
//  Created by Antigravity on 19/03/2026.
//

import SwiftUI
import Observation
import UniformTypeIdentifiers

enum ModalType: Identifiable {
    case newRequest
    case newFolder
    case rename
    case newEnvironment
    case settings
    
    var id: String {
        switch self {
        case .newRequest: return "newRequest"
        case .newFolder: return "newFolder"
        case .rename: return "rename"
        case .newEnvironment: return "newEnvironment"
        case .settings: return "settings"
        }
    }
}

@Observable
class DraftRequest: Identifiable {
    var id: UUID = UUID()
    var name: String
    var method: String
    var url: String
    var headers: [KeyValuePair]
    var query: [KeyValuePair]
    var pathParams: [KeyValuePair]
    var body: String
    var auth: Auth?
    var docs: String?
    var varsPreRequest: [KeyValuePair]
    var varsPostResponse: [KeyValuePair]
    var bodyType: String
    var multipartForm: [MultipartFormData]
    var formUrlEncoded: [KeyValuePair]
    var initialRequest: Request
    
    var isDirty: Bool {
        return toRequest() != initialRequest
    }
    
    init(request: Request) {
        self.initialRequest = request
        self.name = request.name
        self.method = request.method
        self.url = request.url
        self.headers = (request.headers ?? [:]).map { KeyValuePair(key: $0.key, value: $0.value) }
        self.query = (request.query ?? [:]).map { KeyValuePair(key: $0.key, value: $0.value) }
        self.pathParams = (request.pathParams ?? [:]).map { KeyValuePair(key: $0.key, value: $0.value) }
        self.body = request.body ?? ""
        self.auth = request.auth
        self.docs = request.docs
        self.varsPreRequest = (request.varsPreRequest ?? [:]).map { KeyValuePair(key: $0.key, value: $0.value) }
        self.varsPostResponse = (request.varsPostResponse ?? [:]).map { KeyValuePair(key: $0.key, value: $0.value) }
        self.bodyType = request.bodyType ?? "none"
        self.multipartForm = request.multipartForm ?? []
        self.formUrlEncoded = request.formUrlEncoded ?? []
        
        ensureEmptyRows()
    }
    
    init(requestData: DraftRequestData) {
        self.initialRequest = requestData.initialRequest
        self.id = requestData.id
        self.name = requestData.name
        self.method = requestData.method
        self.url = requestData.url
        self.headers = requestData.headers.map { KeyValuePair(key: $0.key, value: $0.value) }
        self.query = requestData.query.map { KeyValuePair(key: $0.key, value: $0.value) }
        self.pathParams = requestData.pathParams.map { KeyValuePair(key: $0.key, value: $0.value) }
        self.body = requestData.body
        self.auth = requestData.auth
        self.docs = requestData.docs
        self.varsPreRequest = requestData.varsPreRequest.map { KeyValuePair(key: $0.key, value: $0.value) }
        self.varsPostResponse = requestData.varsPostResponse.map { KeyValuePair(key: $0.key, value: $0.value) }
        self.bodyType = requestData.bodyType ?? "none"
        self.multipartForm = requestData.multipartForm ?? []
        self.formUrlEncoded = requestData.formUrlEncoded ?? []
        
        ensureEmptyRows()
    }
    
    func ensureEmptyRows() {
        // Headers
        while headers.count > 1 && headers[headers.count - 2].key.isEmpty && headers[headers.count - 2].value.isEmpty {
            headers.remove(at: headers.count - 2)
        }
        if headers.last?.key.isEmpty == false || headers.last?.value.isEmpty == false || headers.isEmpty {
            headers.append(KeyValuePair(key: "", value: ""))
        }
        
        // Query
        while query.count > 1 && query[query.count - 2].key.isEmpty && query[query.count - 2].value.isEmpty {
            query.remove(at: query.count - 2)
        }
        if query.last?.key.isEmpty == false || query.last?.value.isEmpty == false || query.isEmpty {
            query.append(KeyValuePair(key: "", value: ""))
        }
        
        // Path Params
        while pathParams.count > 1 && pathParams[pathParams.count - 2].key.isEmpty && pathParams[pathParams.count - 2].value.isEmpty {
            pathParams.remove(at: pathParams.count - 2)
        }
        if pathParams.last?.key.isEmpty == false || pathParams.last?.value.isEmpty == false || pathParams.isEmpty {
            pathParams.append(KeyValuePair(key: "", value: ""))
        }
        
        // Vars
        while varsPreRequest.count > 1 && varsPreRequest[varsPreRequest.count - 2].key.isEmpty && varsPreRequest[varsPreRequest.count - 2].value.isEmpty {
            varsPreRequest.remove(at: varsPreRequest.count - 2)
        }
        if varsPreRequest.last?.key.isEmpty == false || varsPreRequest.last?.value.isEmpty == false || varsPreRequest.isEmpty {
            varsPreRequest.append(KeyValuePair(key: "", value: ""))
        }
        while varsPostResponse.count > 1 && varsPostResponse[varsPostResponse.count - 2].key.isEmpty && varsPostResponse[varsPostResponse.count - 2].value.isEmpty {
            varsPostResponse.remove(at: varsPostResponse.count - 2)
        }
        if varsPostResponse.last?.key.isEmpty == false || varsPostResponse.last?.value.isEmpty == false || varsPostResponse.isEmpty {
            varsPostResponse.append(KeyValuePair(key: "", value: ""))
        }
        
        // Multipart
        while multipartForm.count > 1 && multipartForm[multipartForm.count - 2].key.isEmpty && multipartForm[multipartForm.count - 2].value.isEmpty {
            multipartForm.remove(at: multipartForm.count - 2)
        }
        if multipartForm.last?.key.isEmpty == false || multipartForm.last?.value.isEmpty == false || multipartForm.isEmpty {
            multipartForm.append(MultipartFormData(key: "", value: "", type: "text"))
        }
        
        // FormUrlEncoded
        while formUrlEncoded.count > 1 && formUrlEncoded[formUrlEncoded.count - 2].key.isEmpty && formUrlEncoded[formUrlEncoded.count - 2].value.isEmpty {
            formUrlEncoded.remove(at: formUrlEncoded.count - 2)
        }
        if formUrlEncoded.last?.key.isEmpty == false || formUrlEncoded.last?.value.isEmpty == false || formUrlEncoded.isEmpty {
            formUrlEncoded.append(KeyValuePair(key: "", value: ""))
        }
    }
    
    func removeHeader(at index: Int) {
        headers.remove(at: index)
        ensureEmptyRows()
    }
    
    func removeQuery(at index: Int) {
        query.remove(at: index)
        ensureEmptyRows()
    }
    
    func removePathParam(at index: Int) {
        pathParams.remove(at: index)
        ensureEmptyRows()
    }
    
    func removeVarPreRequest(at index: Int) {
        varsPreRequest.remove(at: index)
        ensureEmptyRows()
    }
    
    func removeVarPostResponse(at index: Int) {
        varsPostResponse.remove(at: index)
        ensureEmptyRows()
    }
    
    func toRequest() -> Request {
        let activeHeaders = Dictionary(uniqueKeysWithValues: headers.filter { $0.isEnabled && !$0.key.isEmpty }.map { ($0.key, $0.value) })
        let activeQuery = Dictionary(uniqueKeysWithValues: query.filter { $0.isEnabled && !$0.key.isEmpty }.map { ($0.key, $0.value) })
        let activePathParams = Dictionary(uniqueKeysWithValues: pathParams.filter { $0.isEnabled && !$0.key.isEmpty }.map { ($0.key, $0.value) })
        let activeVarsPre = Dictionary(uniqueKeysWithValues: varsPreRequest.filter { $0.isEnabled && !$0.key.isEmpty }.map { ($0.key, $0.value) })
        let activeVarsPost = Dictionary(uniqueKeysWithValues: varsPostResponse.filter { $0.isEnabled && !$0.key.isEmpty }.map { ($0.key, $0.value) })
        
        let activeMultipart = multipartForm.filter { $0.isEnabled && !$0.key.isEmpty }
        let activeFormUrlEncoded = formUrlEncoded.filter { $0.isEnabled && !$0.key.isEmpty }
        
        return Request(
            name: name,
            method: method,
            url: url,
            headers: activeHeaders.isEmpty ? nil : activeHeaders,
            query: activeQuery.isEmpty ? nil : activeQuery,
            pathParams: activePathParams.isEmpty ? nil : activePathParams,
            body: body.isEmpty ? nil : body,
            auth: auth,
            seq: initialRequest.seq,
            tags: initialRequest.tags,
            docs: docs,
            varsPreRequest: activeVarsPre.isEmpty ? nil : activeVarsPre,
            varsPostResponse: activeVarsPost.isEmpty ? nil : activeVarsPost,
            bodyType: bodyType,
            multipartForm: activeMultipart.isEmpty ? nil : activeMultipart,
            formUrlEncoded: activeFormUrlEncoded.isEmpty ? nil : activeFormUrlEncoded,
            path: initialRequest.path
        )
    }

    func applyCurl(_ curl: String) {
        guard let parsed = CurlParser.shared.parse(curl) else { return }
        
        self.method = parsed.method
        self.url = parsed.url
        
        if let parsedAuth = parsed.auth {
            self.auth = parsedAuth
        }
        
        // Merge headers
        if let parsedHeaders = parsed.headers {
            for (key, value) in parsedHeaders {
                if let index = self.headers.firstIndex(where: { $0.key.lowercased() == key.lowercased() }) {
                    self.headers[index].value = value
                    self.headers[index].isEnabled = true
                } else {
                    // Insert before the last empty row
                    self.headers.insert(KeyValuePair(key: key, value: value), at: max(0, self.headers.count - 1))
                }
            }
        }
        
        if let parsedBody = parsed.body {
            self.body = parsedBody
            self.bodyType = parsed.bodyType ?? "json"
        }
        
        ensureEmptyRows()
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var id: String { self.rawValue }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum LayoutMode: String, CaseIterable, Codable, Identifiable {
    case left = "Left"
    case bottom = "Bottom"
    case right = "Right"
    case auto = "Auto"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .left: return "square.leftthird.inset.filled"
        case .bottom: return "square.bottomthird.inset.filled"
        case .right: return "square.rightthird.inset.filled"
        case .auto: return "square.grid.2x2"
        }
    }
}

@MainActor
@Observable
class AppState {
    var workspaceManagers: [WorkspaceManager] = []
    var activeWorkspaceIndex: Int = 0
    
    var workspace: Workspace? {
        guard workspaceManagers.indices.contains(activeWorkspaceIndex) else { return nil }
        return workspaceManagers[activeWorkspaceIndex].workspace
    }
    
    var activeWorkspaceManager: WorkspaceManager? {
        guard workspaceManagers.indices.contains(activeWorkspaceIndex) else { return nil }
        return workspaceManagers[activeWorkspaceIndex]
    }
    
    var selectedSidebarItemID: String? {
        get { activeWorkspaceManager?.selectedSidebarItemID }
        set { activeWorkspaceManager?.selectedSidebarItemID = newValue }
    }
    
    var openDrafts: [DraftRequest] {
        get { activeWorkspaceManager?.openDrafts ?? [] }
        set { activeWorkspaceManager?.openDrafts = newValue }
    }
    
    var openEnvironmentDrafts: [DraftEnvironment] {
        get { activeWorkspaceManager?.openEnvironmentDrafts ?? [] }
        set { activeWorkspaceManager?.openEnvironmentDrafts = newValue }
    }
    
    var selectedDraftID: UUID? {
        get { activeWorkspaceManager?.selectedDraftID }
        set { activeWorkspaceManager?.selectedDraftID = newValue }
    }
    
    var selectedEnvironmentDraftID: UUID? {
        get { activeWorkspaceManager?.selectedEnvironmentDraftID }
        set { activeWorkspaceManager?.selectedEnvironmentDraftID = newValue }
    }
    
    var selectedTab: WorkspaceManager.TabSelection? {
        get { activeWorkspaceManager?.selectedTab }
        set { activeWorkspaceManager?.selectedTab = newValue }
    }
    
    var activeDraft: DraftRequest? {
        activeWorkspaceManager?.activeDraft
    }
    
    var activeEnvironmentDraft: DraftEnvironment? {
        activeWorkspaceManager?.activeEnvironmentDraft
    }
    
    var activeEnvironmentName: String? {
        get { activeWorkspaceManager?.activeEnvironmentName }
        set { 
            activeWorkspaceManager?.activeEnvironmentName = newValue 
            saveSession()
        }
    }
    
    var activeEnvironment: Environment? {
        activeWorkspaceManager?.activeEnvironment
    }
    var response: Response?
    var isSending: Bool = false
    
    // Layout State
    var sidebarWidth: Double = 250 {
        didSet { debouncedSaveSession() }
    }
    var responsePaneWidth: Double = 400 {
        didSet { debouncedSaveSession() }
    }
    var responsePaneHeight: Double = 300 {
        didSet { debouncedSaveSession() }
    }
    var preferredLayoutMode: LayoutMode = .auto
    
    // Naming Alert State
    var activeModal: ModalType? = nil
    var selectedTheme: AppTheme = .system
    
    // Legacy flags kept for compatibility with SidebarView temporarily (will refactor next)
    var isShowingNewRequestAlert: Bool {
        get { activeModal == .newRequest }
        set { activeModal = newValue ? .newRequest : nil }
    }
    var isShowingNewFolderAlert: Bool {
        get { activeModal == .newFolder }
        set { activeModal = newValue ? .newFolder : nil }
    }
    var isShowingNewEnvironmentAlert: Bool {
        get { activeModal == .newEnvironment }
        set { activeModal = newValue ? .newEnvironment : nil }
    }
    var isShowingRenameAlert: Bool {
        get { activeModal == .rename }
        set { activeModal = newValue ? .rename : nil }
    }
    var isShowingSettings: Bool {
        get { activeModal == .settings }
        set { activeModal = newValue ? .settings : nil }
    }
    var newName = ""
    var contextTargetURL: URL? = nil
    var contextTargetFolderURL: URL? = nil
    var contextTargetTabID: UUID? = nil
    
    // Services
    let networkService = NetworkService()
    let requestBuilder = RequestBuilder()

    // Debounced save timer for pane resize (avoids disk I/O on every drag pixel)
    private var paneSaveTask: DispatchWorkItem?
    
    init() {
        if let state = SessionManager.shared.loadSession() {
            restoreSession(from: state)
        }
        ensureScratchpadWorkspace()
        
        // Ensure some request is open if possible
        if openDrafts.isEmpty && !workspaceManagers.isEmpty {
            // Optional: open first request? For now, leave as is.
        }
    }
    
    func ensureScratchpadWorkspace() {
        let scratchpadURL = SessionManager.shared.scratchpadURL
        
        // Check if scratchpad is already loaded (by flag)
        if workspaceManagers.contains(where: { $0.isScratchpad }) {
            return
        }
        
        // Try to find it by path (it might be loaded as a regular workspace from session)
        if let existingIndex = workspaceManagers.firstIndex(where: { $0.currentWorkspaceURL?.standardized.path == scratchpadURL.standardized.path }) {
            workspaceManagers[existingIndex].isScratchpad = true
            return
        }
        
        // Not loaded, so load it
        let manager = WorkspaceManager()
        manager.isScratchpad = true
        manager.loadWorkspace(from: scratchpadURL)
        
        // If the workspace name is just "scratchpad", we can beautify it
        if manager.workspace?.name == "scratchpad" {
            manager.workspace = Workspace(name: "Scratchpad", path: scratchpadURL.path, version: "1", requests: manager.workspace?.requests ?? [], environments: manager.workspace?.environments ?? [])
        }
        
        // Always make it the first workspace
        workspaceManagers.insert(manager, at: 0)
        // If we were at 0, we might need to increment activeWorkspaceIndex if we want to stay on the same one, 
        // but typically session restoration handles activeWorkspaceIndex.
        // If we just inserted at 0, we need to adjust activeWorkspaceIndex to keep pointing at the same workspace.
        // Actually, restoreSession sets activeWorkspaceIndex AFTER it loads managers. 
        // So I should call ensureScratchpad AFTER restoreSession.
    }
    
    func addWorkspace(from url: URL) {
        let manager = WorkspaceManager()
        manager.loadWorkspace(from: url)
        workspaceManagers.append(manager)
        activeWorkspaceIndex = workspaceManagers.count - 1
    }
    
    func closeWorkspace(_ manager: WorkspaceManager) {
        guard !manager.isScratchpad else { return } // Cannot close scratchpad
        guard let index = workspaceManagers.firstIndex(where: { $0 === manager }) else { return }
        workspaceManagers.remove(at: index)
        // Keep activeWorkspaceIndex in bounds
        activeWorkspaceIndex = max(0, min(activeWorkspaceIndex, workspaceManagers.count - 1))
    }
    
    func restoreSession(from state: SessionState) {
        var restoredWorkspaces: [WorkspaceBookmark] = state.workspaces ?? []
        
        if restoredWorkspaces.isEmpty, let legacyData = state.workspaceBookmarkData, let legacyPath = state.workspaceURLPath {
            restoredWorkspaces.append(WorkspaceBookmark(bookmarkData: legacyData, path: legacyPath))
        }
        
        for bookmark in restoredWorkspaces {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmark.bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
                if url.startAccessingSecurityScopedResource() {
                    let manager = WorkspaceManager()
                    manager.loadWorkspace(from: url)
                    self.workspaceManagers.append(manager)
                }
            }
        }
        
        self.activeWorkspaceIndex = state.activeWorkspaceIndex ?? 0
        if self.activeWorkspaceIndex >= self.workspaceManagers.count {
            self.activeWorkspaceIndex = max(0, self.workspaceManagers.count - 1)
        }
        
        self.sidebarWidth = state.sidebarWidth ?? 250
        self.responsePaneWidth = state.responsePaneWidth ?? 400
        self.responsePaneHeight = state.responsePaneHeight ?? 300
        if let layoutString = state.preferredLayoutMode, let mode = LayoutMode(rawValue: layoutString) {
            self.preferredLayoutMode = mode
        }
        if let themeString = state.selectedTheme, let theme = AppTheme(rawValue: themeString) {
            self.selectedTheme = theme
        }

        
            // 2. Restore Drafts to Each Workspace
            for manager in self.workspaceManagers {
                guard let managerURL = manager.currentWorkspaceURL else { continue }
                let path = managerURL.path
                
                // Restore Request Drafts
                if let draftsData = state.workspaceDrafts?[path] {
                    manager.openDrafts = draftsData.map { DraftRequest(requestData: $0) }
                    manager.selectedDraftID = state.workspaceSelectedDrafts?[path]
                } else {
                    // Backward Compatibility:
                    // Find any legacy global drafts that belong to this workspace
                    let legacyDraftsData = state.openDrafts.filter { $0.initialRequest.path?.hasPrefix(path) == true }
                    manager.openDrafts = legacyDraftsData.map { DraftRequest(requestData: $0) }
                    
                    if let legacySelected = state.selectedDraftID, manager.openDrafts.contains(where: { $0.id == legacySelected }) {
                        manager.selectedDraftID = legacySelected
                    } else {
                        manager.selectedDraftID = manager.openDrafts.first?.id
                    }
                }
                
                // Restore Environment Drafts
                if let envDraftsData = state.workspaceEnvironmentDrafts?[path] {
                    manager.openEnvironmentDrafts = envDraftsData.map { data in
                        let draft = DraftEnvironment(env: data.initialEnvironment)
                        draft.id = data.id 
                        draft.name = data.name
                        draft.variables = data.variables
                        return draft
                    }
                    manager.selectedEnvironmentDraftID = state.workspaceSelectedEnvironmentDrafts?[path]
                }
                
                // Restore Active Environment
                if let activeEnvName = state.workspaceActiveEnvironments?[path] {
                    manager.activeEnvironmentName = activeEnvName
                }
                
                // Restore selection state for the sidebar
                if let selectedSidebarItems = state.workspaceSelectedSidebarItems, let itemID = selectedSidebarItems[path] {
                    manager.selectedSidebarItemID = itemID
                }
                
                // Restore expansion state for the sidebar
                if let expandedItems = state.workspaceExpandedItems, let items = expandedItems[path] {
                    manager.expandedItemIDs = items
                }
                
                // Determine initial tab selection
                if let envID = manager.selectedEnvironmentDraftID {
                    manager.selectedTab = .environment(envID)
                } else if let draftID = manager.selectedDraftID {
                    manager.selectedTab = .request(draftID)
                }

                // Re-sync selection if it's currently nil but we have an active draft
                if manager.selectedSidebarItemID == nil, let draft = manager.activeDraft, let draftPath = draft.initialRequest.path {
                    let activeURL = URL(fileURLWithPath: draftPath)
                    if let requests = manager.workspace?.requests, let item = requests.flatMap({ getFlattenedFiles(from: $0) }).first(where: { $0.url == activeURL }) {
                        manager.selectedSidebarItemID = item.id
                    }
                }
            }
    }

    private func getFlattenedFiles(from item: SidebarItem) -> [SidebarItem] {
        var items: [SidebarItem] = []
        if !item.isFolder {
            items.append(item)
        }
        if let children = item.children {
            items.append(contentsOf: children.flatMap { getFlattenedFiles(from: $0) })
        }
        return items
    }
    
    /// Debounced save — coalesces rapid pane-resize events; only writes to disk 0.4s after the last change.
    private func debouncedSaveSession() {
        paneSaveTask?.cancel()
        let task = DispatchWorkItem { [weak self] in self?.saveSession() }
        paneSaveTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: task)
    }

    func saveSession() {
        var workspaceDrafts: [String: [DraftRequestData]] = [:]
        var workspaceSelectedDrafts: [String: UUID] = [:]
        var workspaceEnvironmentDrafts: [String: [DraftEnvironmentData]] = [:]
        var workspaceSelectedEnvironmentDrafts: [String: UUID] = [:]
        var workspaceActiveEnvironments: [String: String] = [:]
        var workspaceSelectedSidebarItems: [String: String] = [:]
        var workspaceExpandedItems: [String: Set<String>] = [:]
        var bookmarks: [WorkspaceBookmark] = []
        
        for manager in workspaceManagers {
            if let url = manager.currentWorkspaceURL {
                if let data = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                    bookmarks.append(WorkspaceBookmark(bookmarkData: data, path: url.path))
                }
                
                let draftsData = manager.openDrafts.map { draft in
                    DraftRequestData(
                        id: draft.id,
                        initialRequest: draft.initialRequest,
                        name: draft.name,
                        method: draft.method,
                        url: draft.url,
                        headers: draft.headers,
                        query: draft.query,
                        pathParams: draft.pathParams,
                        body: draft.body,
                        auth: draft.auth,
                        docs: draft.docs,
                        varsPreRequest: draft.varsPreRequest,
                        varsPostResponse: draft.varsPostResponse,
                        bodyType: draft.bodyType,
                        multipartForm: draft.multipartForm,
                        formUrlEncoded: draft.formUrlEncoded
                    )
                }
                workspaceDrafts[url.path] = draftsData
                workspaceSelectedDrafts[url.path] = manager.selectedDraftID
                workspaceExpandedItems[url.path] = manager.expandedItemIDs
                workspaceActiveEnvironments[url.path] = manager.activeEnvironmentName
                workspaceSelectedSidebarItems[url.path] = manager.selectedSidebarItemID
                
                let envDraftsData = manager.openEnvironmentDrafts.map { draft in
                    DraftEnvironmentData(
                        id: draft.id,
                        initialEnvironment: draft.initialEnvironment,
                        name: draft.name,
                        variables: draft.variables
                    )
                }
                workspaceEnvironmentDrafts[url.path] = envDraftsData
                workspaceSelectedEnvironmentDrafts[url.path] = manager.selectedEnvironmentDraftID
            }
        }
        
        let state = SessionState(
            workspaceURLPath: nil,
            workspaceBookmarkData: nil,
            workspaces: bookmarks,
            activeWorkspaceIndex: activeWorkspaceIndex,
            openDrafts: [], // Legacy field
            selectedDraftID: nil, // Legacy field
            workspaceDrafts: workspaceDrafts,
            workspaceSelectedDrafts: workspaceSelectedDrafts,
            workspaceEnvironmentDrafts: workspaceEnvironmentDrafts,
            workspaceSelectedEnvironmentDrafts: workspaceSelectedEnvironmentDrafts,
            workspaceActiveEnvironments: workspaceActiveEnvironments,
            workspaceSelectedSidebarItems: workspaceSelectedSidebarItems,
            workspaceExpandedItems: workspaceExpandedItems,
            sidebarWidth: sidebarWidth,
            responsePaneWidth: responsePaneWidth,
            responsePaneHeight: responsePaneHeight,
            selectedTheme: selectedTheme.rawValue,
            preferredLayoutMode: preferredLayoutMode.rawValue
        )
        SessionManager.shared.saveSession(state: state)
    }
    
    func openRequest(_ request: Request) {
        activeWorkspaceManager?.openRequest(request)
    }
    
    func newScratchRequest() {
        ensureScratchpadWorkspace()
        
        // Find scratchpad manager
        if let scratchpadManager = workspaceManagers.first(where: { $0.isScratchpad }) {
            activeWorkspaceIndex = workspaceManagers.firstIndex(where: { $0 === scratchpadManager }) ?? 0
            scratchpadManager.newScratchRequest()
        } else {
            // Fallback (should not happen with ensureScratchpadWorkspace)
            activeWorkspaceManager?.newScratchRequest()
        }
    }
    
    func closeDraft(id: UUID) {
        activeWorkspaceManager?.closeDraft(id: id)
    }
    
    func closeOthers(id: UUID) {
        activeWorkspaceManager?.closeOthers(id: id)
    }
    
    func closeToTheRight(id: UUID) {
        activeWorkspaceManager?.closeToTheRight(id: id)
    }
    
    func closeToTheLeft(id: UUID) {
        activeWorkspaceManager?.closeToTheLeft(id: id)
    }
    
    func renameDraft(id: UUID, newName: String) {
        activeWorkspaceManager?.renameDraft(id: id, newName: newName)
    }
    
    func sendRequest() async {
        guard let draft = activeDraft else { return }
        let request = draft.toRequest()
        
        isSending = true
        defer { isSending = false }
        
        // Use the resolved active environment from the workspace manager
        let env = activeEnvironment
        
        // Build the request on a background thread because it might involve 
        // heavy I/O (e.g., reading large files for multipart uploads).
        let urlRequest = await Task.detached(priority: .userInitiated) {
             self.requestBuilder.build(from: request, env: env)
        }.value
        
        if let urlRequest = urlRequest {
            do {
                let response = try await networkService.execute(request: urlRequest)
                self.response = response
            } catch {
                print("Request failed: \(error)")
                self.response = Response(statusCode: 0, executionTime: 0, headers: [:], body: "Error: \(error.localizedDescription)", size: 0, contentType: nil)
            }
        }
    }
    
    func saveRequest() {
        if let draft = activeDraft {
            if let path = draft.initialRequest.path {
                saveToPath(path)
            } else {
                // New request, show save panel
                let panel = NSSavePanel()
                let ymlType = UTType(filenameExtension: "yml") ?? .yaml
                let bruType = UTType(filenameExtension: "bru") ?? .data
                panel.allowedContentTypes = [ymlType, bruType]
                panel.nameFieldStringValue = "\(draft.name).yml"
                
                if panel.runModal() == .OK, let url = panel.url {
                    saveToPath(url.path)
                }
            }
        } else if let envDraft = activeEnvironmentDraft {
            if let path = envDraft.initialEnvironment.filePath {
                saveEnvironmentToPath(path)
            } else {
                // Should not happen for existing envs, but for new:
                let panel = NSSavePanel()
                let bruType = UTType(filenameExtension: "bru") ?? .data
                panel.allowedContentTypes = [bruType]
                panel.nameFieldStringValue = "\(envDraft.name).bru"
                
                if panel.runModal() == .OK, let url = panel.url {
                    saveEnvironmentToPath(url.path)
                }
            }
        }
    }
    
    private func saveEnvironmentToPath(_ path: String) {
        guard let draft = activeEnvironmentDraft else { return }
        let env = draft.toEnvironment()
        let url = URL(fileURLWithPath: path)
        
        activeWorkspaceManager?.saveEnvironment(env, to: url)
        
        // Update draft state
        var updatedEnv = env
        updatedEnv.filePath = path
        draft.initialEnvironment = updatedEnv // Reset dirty state
    }
    
    func openItem() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        let ymlType = UTType(filenameExtension: "yml") ?? .yaml
        let bruType = UTType(filenameExtension: "bru") ?? .data
        panel.allowedContentTypes = [.folder, ymlType, bruType, .json]
        
        if panel.runModal() == .OK, let url = panel.url {
            if url.hasDirectoryPath {
                addWorkspace(from: url)
            } else {
                if let request = activeWorkspaceManager?.loadRequest(from: url) ?? WorkspaceManager().loadRequest(from: url) {
                    openRequest(request)
                }
            }
        }
    }
    
    private func saveToPath(_ path: String) {
        guard let draft = activeDraft else { return }
        let request = draft.toRequest()
        let url = URL(fileURLWithPath: path)
        
        activeWorkspaceManager?.saveRequest(request, to: url)
        
        // Update draft state
        var updatedRequest = request
        updatedRequest.path = path
        draft.initialRequest = updatedRequest // Reset dirty state
    }
    
    func updateEnvironmentVariable(name: String, newValue: String) {
        guard let manager = activeWorkspaceManager, let envName = activeEnvironmentName else { return }
        
        // 1. Check if there's an open draft for this environment
        if let draft = manager.openEnvironmentDrafts.first(where: { $0.name == envName }) {
            if let index = draft.variables.firstIndex(where: { $0.key == name }) {
                if draft.variables[index].value != newValue {
                    draft.variables[index].value = newValue
                }
            } else {
                // New variable?
                draft.variables.insert(EnvironmentVariable(key: name, value: newValue, isSecret: false, isEnabled: true), at: max(0, draft.variables.count - 1))
            }
        } else if let envIndex = manager.workspace?.environments.firstIndex(where: { $0.name == envName }) {
            // 2. Update the workspace environment directly
            if let varIndex = manager.workspace?.environments[envIndex].variables.firstIndex(where: { $0.key == name }) {
                if manager.workspace?.environments[envIndex].variables[varIndex].value != newValue {
                    manager.workspace?.environments[envIndex].variables[varIndex].value = newValue
                }
            }
        }
    }
}
