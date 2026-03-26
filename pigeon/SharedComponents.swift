import SwiftUI
@preconcurrency import WebKit

struct WebView: NSViewRepresentable {
    let html: String
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground") // Make it transparent
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(html, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

struct OutlinedVariableTextField: View {
    @Binding var text: String
    var env: Environment?
    var placeholder: String
    var onVariableUpdate: ((String, String) -> Void)?
    var onCommit: (() -> Void)? = nil
    
    var body: some View {
        VariableTextField(
            text: $text,
            env: env,
            placeholder: placeholder,
            onVariableUpdate: onVariableUpdate,
            onCommit: onCommit
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

/// A component that wraps a label and an outlined variable text field in a GridRow.
/// Must be used within a Grid.
struct LabeledOutlinedVariableTextField: View {
    var label: String
    var labelWidth: CGFloat = 80
    @Binding var text: String
    var env: Environment?
    var placeholder: String
    var onVariableUpdate: ((String, String) -> Void)?
    
    var body: some View {
        GridRow {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: labelWidth, alignment: .leading)
            
            OutlinedVariableTextField(
                text: $text,
                env: env,
                placeholder: placeholder,
                onVariableUpdate: onVariableUpdate
            )
        }
    }
}

struct ModalTextField: View {
    @Binding var text: String
    let placeholder: String
    var onCommit: (() -> Void)? = nil
    
    var body: some View {
        OutlinedVariableTextField(text: $text, placeholder: placeholder, onCommit: onCommit)
    }
}

struct NewRequestModal: View {
    @SwiftUI.Environment(\.dismiss) var dismiss
    @Bindable var appState: AppState
    var manager: WorkspaceManager?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("New Request")
                    .font(.headline)
                
                ModalTextField(text: $appState.newName, placeholder: "e.g. Get Users") {
                    createAction()
                }
                
                HStack {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.escape, modifiers: [])
                    Spacer()
                    Button("Create") {
                        createAction()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appState.newName.isEmpty)
                    .keyboardShortcut(.return, modifiers: [])
                }
            }
            .padding(20)
        }
        .frame(width: 350)
        .frame(maxHeight: 400)
    }
    
    private func createAction() {
        if !appState.newName.isEmpty, let manager = manager {
            manager.createNewRequest(in: appState.contextTargetFolderURL, name: appState.newName)
            dismiss()
        }
    }
}

struct NewFolderModal: View {
    @SwiftUI.Environment(\.dismiss) var dismiss
    @Bindable var appState: AppState
    var manager: WorkspaceManager?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("New Folder")
                    .font(.headline)
                
                ModalTextField(text: $appState.newName, placeholder: "e.g. users") {
                    createAction()
                }
                
                HStack {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.escape, modifiers: [])
                    Spacer()
                    Button("Create") {
                        createAction()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appState.newName.isEmpty)
                    .keyboardShortcut(.return, modifiers: [])
                }
            }
            .padding(20)
        }
        .frame(width: 350)
        .frame(maxHeight: 400)
    }
    
    private func createAction() {
        if !appState.newName.isEmpty, let manager = manager {
            manager.createNewFolder(in: appState.contextTargetFolderURL, name: appState.newName)
            dismiss()
        }
    }
}

struct RenameModal: View {
    @SwiftUI.Environment(\.dismiss) var dismiss
    @Bindable var appState: AppState
    var manager: WorkspaceManager?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Rename")
                    .font(.headline)
                
                ModalTextField(text: $appState.newName, placeholder: "New name") {
                    renameAction()
                }
                
                HStack {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.escape, modifiers: [])
                    Spacer()
                    Button("Rename") {
                        renameAction()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appState.newName.isEmpty)
                    .keyboardShortcut(.return, modifiers: [])
                }
            }
            .padding(20)
        }
        .frame(width: 350)
        .frame(maxHeight: 400)
    }
    
    private func renameAction() {
        if !appState.newName.isEmpty {
            if let url = appState.contextTargetURL {
                manager?.renameItem(at: url, to: appState.newName)
            } else if let id = appState.contextTargetTabID {
                appState.renameDraft(id: id, newName: appState.newName)
            }
            dismiss()
        }
    }
}

struct NewEnvironmentModal: View {
    @SwiftUI.Environment(\.dismiss) var dismiss
    @Bindable var appState: AppState
    var manager: WorkspaceManager?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("New Environment")
                    .font(.headline)
                
                ModalTextField(text: $appState.newName, placeholder: "e.g. Staging") {
                    createAction()
                }
                
                HStack {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.escape, modifiers: [])
                    Spacer()
                    Button("Create") {
                        createAction()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appState.newName.isEmpty)
                    .keyboardShortcut(.return, modifiers: [])
                }
            }
            .padding(20)
        }
        .frame(width: 350)
        .frame(maxHeight: 400)
    }
    
    private func createAction() {
        if !appState.newName.isEmpty, let manager = manager {
            manager.createNewEnvironment(name: appState.newName)
            dismiss()
        }
    }
}
