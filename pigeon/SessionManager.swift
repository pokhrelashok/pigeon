import Foundation

struct WorkspaceBookmark: Codable, Identifiable {
    var id: UUID = UUID()
    var bookmarkData: Data
    var path: String
}

struct SessionState: Codable {
    var workspaceURLPath: String?
    var workspaceBookmarkData: Data?
    var workspaces: [WorkspaceBookmark]?
    var activeWorkspaceIndex: Int?
    var openDrafts: [DraftRequestData]
    var selectedDraftID: UUID?
    var workspaceDrafts: [String: [DraftRequestData]]?
    var workspaceSelectedDrafts: [String: UUID]?
    var workspaceEnvironmentDrafts: [String: [DraftEnvironmentData]]?
    var workspaceSelectedEnvironmentDrafts: [String: UUID]?
    var workspaceActiveEnvironments: [String: String]?
    var workspaceSelectedSidebarItems: [String: String]?
    var workspaceExpandedItems: [String: Set<String>]?
    var sidebarWidth: Double?
    var responsePaneWidth: Double?
    var responsePaneHeight: Double?
    var selectedTheme: String?
    var preferredLayoutMode: String?
}

struct DraftRequestData: Codable {
    var id: UUID
    var initialRequest: Request
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
    var bodyType: String?
    var multipartForm: [MultipartFormData]?
    var formUrlEncoded: [KeyValuePair]?
}

struct DraftEnvironmentData: Codable {
    let id: UUID
    let initialEnvironment: Environment
    let name: String
    let variables: [EnvironmentVariable]
}

class SessionManager {
    static let shared = SessionManager()
    
    var scratchpadURL: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportDir = paths[0].appendingPathComponent("pigeon")
        let scratchpadDir = appSupportDir.appendingPathComponent("scratchpad")
        if !FileManager.default.fileExists(atPath: scratchpadDir.path) {
            try? FileManager.default.createDirectory(at: scratchpadDir, withIntermediateDirectories: true, attributes: nil)
        }
        return scratchpadDir
    }
    
    private var sessionURL: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportDir = paths[0].appendingPathComponent("pigeon")
        if !FileManager.default.fileExists(atPath: appSupportDir.path) {
            try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true, attributes: nil)
        }
        return appSupportDir.appendingPathComponent("session.json")
    }
    
    func saveSession(state: SessionState) {
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: sessionURL, options: .atomic)
        } catch {
            print("Failed to save session: \(error)")
        }
    }
    
    func loadSession() -> SessionState? {
        do {
            let data = try Data(contentsOf: sessionURL)
            let state = try JSONDecoder().decode(SessionState.self, from: data)
            return state
        } catch {
            return nil
        }
    }
}
