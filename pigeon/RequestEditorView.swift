//
//  RequestEditorView.swift
//  pigeon
//
//  RequestEditorView.swift
//  pigeon
//
//  Created by Antigravity on 19/03/2026.
//

import SwiftUI

struct RequestEditorView: View {
    @Bindable var draft: DraftRequest
    @Bindable var appState: AppState
    
    @State private var selectedTab: Int = 0
    let methods = ["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"]
    
    var body: some View {
        @Bindable var draft = draft
        @Bindable var appState = appState
        
        VStack(spacing: 0) {
            header
                .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("Headers").tag(0)
                    Text("Body").tag(1)
                    Text("Auth").tag(2)
                    Text("Params").tag(3)
                }
                .pickerStyle(.segmented)
                .padding()
                
                Group {
                    switch selectedTab {
                    case 0: headersTab
                    case 1: bodyTab
                    case 2: authTab
                    case 3: paramsTab
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    private var header: some View {
        HStack(spacing: 12) {
            Picker("", selection: $draft.method) {
                ForEach(methods, id: \.self) { method in
                    Text(method).tag(method)
                }
            }
            .frame(width: 100)
            .controlSize(.large)
            
            HStack(spacing: 0) {
                VariableTextField(text: $draft.url, env: appState.activeEnvironment, placeholder: "https://api.example.com", onVariableUpdate: appState.updateEnvironmentVariable, onCommit: {
                    Task {
                        await appState.sendRequest()
                    }
                }, onPaste: { text in
                    if text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("curl ") {
                        draft.applyCurl(text)
                        return true
                    }
                    return false
                })
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                
                if draft.initialRequest.path == nil {
                    Button(action: { appState.saveRequest() }) {
                        Image(systemName: draft.isDirty ? "square.and.arrow.down.fill" : "square.and.arrow.down")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(draft.isDirty ? .accentColor : .secondary.opacity(0.6))
                            .padding(.trailing, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )

            Button(action: {
                Task {
                    await appState.sendRequest()
                }
            }) {
                ZStack {
                    Text("Send")
                        .bold()
                        .frame(width: 60)
                        .opacity(appState.isSending ? 0 : 1)
                    
                    if appState.isSending {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(appState.isSending)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.horizontal)
        .frame(height: 60)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var headersTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 0) {
                    // Header Row
                    GridRow {
                        Text("").frame(width: 20)
                        Text("Name").bold().foregroundColor(.secondary)
                        Text("Value").bold().foregroundColor(.secondary)
                        Text("").frame(width: 30)
                    }
                    .padding(.bottom, 8)
                    
                    Divider().gridCellColumns(4)
                    
                    ForEach($draft.headers) { $header in
                        GridRow {
                            Toggle("", isOn: $header.isEnabled)
                                .labelsHidden()
                                .controlSize(.small)
                            
                            VariableTextField(text: $header.key, env: appState.activeEnvironment, placeholder: "Name", font: .monospacedSystemFont(ofSize: 12, weight: .regular), onVariableUpdate: appState.updateEnvironmentVariable)
                                .frame(maxWidth: .infinity)
                                .onChange(of: header.key) { draft.ensureEmptyRows() }
                            
                            VariableTextField(text: $header.value, env: appState.activeEnvironment, placeholder: "Value", font: .monospacedSystemFont(ofSize: 12, weight: .regular), onVariableUpdate: appState.updateEnvironmentVariable)
                                .frame(maxWidth: .infinity)
                                .onChange(of: header.value) { draft.ensureEmptyRows() }
                            
                            if header.id != draft.headers.last?.id || !header.key.isEmpty || !header.value.isEmpty {
                                Button(action: {
                                    if let index = draft.headers.firstIndex(where: { $0.id == header.id }) {
                                        draft.removeHeader(at: index)
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.secondary)
                                        .frame(width: 30, height: 24)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Color.clear.frame(width: 30, height: 24)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        Divider().gridCellColumns(4)
                    }
                }
            }
            .padding()
        }
    }
    
    private var bodyTab: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                
                if !draft.body.isEmpty {
                    let validation = ValidatorService.shared.validate(body: draft.body, bodyType: draft.bodyType)
                    if !validation.isValid {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 11))
                            Text(validation.errorMessage ?? "Invalid JSON")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .frame(maxWidth: 200, alignment: .trailing)
                        }
                        .padding(.trailing, 8)
                    }
                }
                
                if draft.bodyType == "json" && !draft.body.isEmpty {
                    Button(action: {
                        draft.body = FormatterService.shared.format(body: draft.body, bodyType: "json")
                    }) {
                        Label("Beautify", systemImage: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    .padding(.trailing, 8)
                }
                
                Picker("", selection: $draft.bodyType) {
                    Text("No Body").tag("none")
                    Text("JSON").tag("json")
                    Text("XML").tag("xml")
                    Text("Text").tag("text")
                    Text("Multipart Form").tag("multipart-form")
                    Text("Form URL Encoded").tag("form-urlencoded")
                }
                .labelsHidden()
                .onChange(of: draft.bodyType) {
                    draft.ensureEmptyRows()
                    // Automatically format if switching to JSON and it's not empty
                    if draft.bodyType == "json" && !draft.body.isEmpty {
                        draft.body = FormatterService.shared.format(body: draft.body, bodyType: "json")
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 170)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            switch draft.bodyType {
            case "json":
                EditableJSONCodeView(text: $draft.body, env: appState.activeEnvironment, onVariableUpdate: appState.updateEnvironmentVariable)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 12)
                    )
            case "xml", "text":
                TextEditor(text: $draft.body)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(Color(NSColor.textBackgroundColor))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 12)
                    )
            case "multipart-form":
                multipartFormTab
            case "form-urlencoded":
                formUrlEncodedTab
            default:
                VStack {
                    Spacer()
                    Text("No Body")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    
    private var multipartFormTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 0) {
                    GridRow {
                        Text("").frame(width: 20)
                        Text("Name").bold().foregroundColor(.secondary)
                        Text("Value").bold().foregroundColor(.secondary)
                        Text("").frame(width: 30)
                    }
                    .padding(.bottom, 8)
                    Divider().gridCellColumns(4)
                    
                    ForEach($draft.multipartForm) { $param in
                        GridRow {
                            Toggle("", isOn: $param.isEnabled).labelsHidden().controlSize(.small)
                            VariableTextField(text: $param.key, env: appState.activeEnvironment, placeholder: "Name", font: .monospacedSystemFont(ofSize: 12, weight: .regular), onVariableUpdate: appState.updateEnvironmentVariable)
                                .frame(maxWidth: .infinity)
                                .onChange(of: param.key) { draft.ensureEmptyRows() }
                            
                            HStack(spacing: 8) {
                                Picker("", selection: $param.type) {
                                    Text("Text").tag("text")
                                    Text("File").tag("file")
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .frame(width: 65)
                                
                                if param.type == "file" {
                                    Text(param.value.isEmpty ? "Select File" : URL(fileURLWithPath: param.value).lastPathComponent)
                                        .foregroundColor(param.value.isEmpty ? .secondary : .primary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Button("Browse") {
                                        let panel = NSOpenPanel()
                                        panel.canChooseFiles = true
                                        panel.canChooseDirectories = false
                                        panel.allowsMultipleSelection = false
                                        if panel.runModal() == .OK, let url = panel.url {
                                            param.value = url.path
                                            draft.ensureEmptyRows()
                                        }
                                    }
                                } else {
                                    VariableTextField(text: $param.value, env: appState.activeEnvironment, placeholder: "Value", font: .monospacedSystemFont(ofSize: 12, weight: .regular), onVariableUpdate: appState.updateEnvironmentVariable)
                                        .frame(maxWidth: .infinity)
                                        .onChange(of: param.value) { draft.ensureEmptyRows() }
                                }
                            }
                            
                            if param.id != draft.multipartForm.last?.id || !param.key.isEmpty || !param.value.isEmpty {
                                Button(action: {
                                    if let index = draft.multipartForm.firstIndex(where: { $0.id == param.id }) {
                                        draft.multipartForm.remove(at: index)
                                        draft.ensureEmptyRows()
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.secondary)
                                        .frame(width: 30, height: 24)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Color.clear.frame(width: 30, height: 24)
                            }
                        }
                        .padding(.vertical, 4)
                        Divider().gridCellColumns(4)
                    }
                }
            }.padding()
        }
    }
    
    private var formUrlEncodedTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 0) {
                    GridRow {
                        Text("").frame(width: 20)
                        Text("Name").bold().foregroundColor(.secondary)
                        Text("Value").bold().foregroundColor(.secondary)
                        Text("").frame(width: 30)
                    }
                    .padding(.bottom, 8)
                    Divider().gridCellColumns(4)
                    
                    ForEach($draft.formUrlEncoded) { $param in
                        GridRow {
                            Toggle("", isOn: $param.isEnabled).labelsHidden().controlSize(.small)
                            VariableTextField(text: $param.key, env: appState.activeEnvironment, placeholder: "Name", font: .monospacedSystemFont(ofSize: 12, weight: .regular), onVariableUpdate: appState.updateEnvironmentVariable)
                                .frame(maxWidth: .infinity)
                                .onChange(of: param.key) { draft.ensureEmptyRows() }
                            VariableTextField(text: $param.value, env: appState.activeEnvironment, placeholder: "Value", font: .monospacedSystemFont(ofSize: 12, weight: .regular), onVariableUpdate: appState.updateEnvironmentVariable)
                                .frame(maxWidth: .infinity)
                                .onChange(of: param.value) { draft.ensureEmptyRows() }
                            
                            if param.id != draft.formUrlEncoded.last?.id || !param.key.isEmpty || !param.value.isEmpty {
                                Button(action: {
                                    if let index = draft.formUrlEncoded.firstIndex(where: { $0.id == param.id }) {
                                        draft.formUrlEncoded.remove(at: index)
                                        draft.ensureEmptyRows()
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.secondary)
                                        .frame(width: 30, height: 24)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Color.clear.frame(width: 30, height: 24)
                            }
                        }
                        .padding(.vertical, 4)
                        Divider().gridCellColumns(4)
                    }
                }
            }.padding()
        }
    }
    
    private var authTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 20) {
                authTypePicker
                
                Divider()
                
                authFields
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
            )
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var authTypePicker: some View {
        HStack(spacing: 12) {
            Text("Type")
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Picker("", selection: Binding(
                get: { draft.auth?.type ?? .none },
                set: { newType in
                    if draft.auth == nil {
                        draft.auth = Auth(type: newType)
                    } else {
                        draft.auth?.type = newType
                    }
                }
            )) {
                Text("No Auth").tag(AuthType.none)
                Text("Basic Auth").tag(AuthType.basic)
                Text("Bearer Token").tag(AuthType.bearer)
                Text("Digest Auth").tag(AuthType.digest)
                Text("API Key").tag(AuthType.apiKey)
                Text("Inherit").tag(AuthType.inherit)
            }
            .pickerStyle(.menu)
            .frame(width: 150)
        }
    }
    
    @ViewBuilder
    private var authFields: some View {
        let currentAuthType = draft.auth?.type ?? .none
        
        switch currentAuthType {
        case .none:
            Text("This request does not use any authentication.")
                .foregroundColor(.secondary)
                .italic()
                .padding(.top, 8)
            
        case .basic:
            basicAuthFields
            
        case .bearer:
            bearerAuthFields
            
        case .digest:
            digestAuthFields
            
        case .apiKey:
            Text("API Key authentication configuration is not yet available.")
                .foregroundColor(.secondary)
                .italic()
            
        case .inherit:
            Text("Authentication is inherited from the collection/folder.")
                .foregroundColor(.secondary)
                .italic()
        }
    }
    
    private var basicAuthFields: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
            LabeledOutlinedVariableTextField(
                label: "Username",
                text: Binding(
                    get: { draft.auth?.username ?? "" },
                    set: { draft.auth?.username = $0 }
                ),
                env: appState.activeEnvironment,
                placeholder: "username",
                onVariableUpdate: appState.updateEnvironmentVariable
            )
            
            LabeledOutlinedVariableTextField(
                label: "Password",
                text: Binding(
                    get: { draft.auth?.password ?? "" },
                    set: { draft.auth?.password = $0 }
                ),
                env: appState.activeEnvironment,
                placeholder: "password",
                onVariableUpdate: appState.updateEnvironmentVariable
            )
        }
    }
    
    private var bearerAuthFields: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
            LabeledOutlinedVariableTextField(
                label: "Token",
                text: Binding(
                    get: { draft.auth?.token ?? "" },
                    set: { draft.auth?.token = $0 }
                ),
                env: appState.activeEnvironment,
                placeholder: "Token",
                onVariableUpdate: appState.updateEnvironmentVariable
            )
        }
    }
    
    private var digestAuthFields: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
            LabeledOutlinedVariableTextField(
                label: "Username",
                text: Binding(
                    get: { draft.auth?.username ?? "" },
                    set: { draft.auth?.username = $0 }
                ),
                env: appState.activeEnvironment,
                placeholder: "username",
                onVariableUpdate: appState.updateEnvironmentVariable
            )
            
            LabeledOutlinedVariableTextField(
                label: "Password",
                text: Binding(
                    get: { draft.auth?.password ?? "" },
                    set: { draft.auth?.password = $0 }
                ),
                env: appState.activeEnvironment,
                placeholder: "password",
                onVariableUpdate: appState.updateEnvironmentVariable
            )
        }
    }
    
    private var paramsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 0) {
                    // Header Row
                    GridRow {
                        Text("").frame(width: 20)
                        Text("Name").bold().foregroundColor(.secondary)
                        Text("Value").bold().foregroundColor(.secondary)
                        Text("").frame(width: 30)
                    }
                    .padding(.bottom, 8)
                    
                    Divider().gridCellColumns(4)
                    
                    ForEach($draft.query) { $param in
                        GridRow {
                            Toggle("", isOn: $param.isEnabled)
                                .labelsHidden()
                                .controlSize(.small)
                            
                            VariableTextField(text: $param.key, env: appState.activeEnvironment, placeholder: "Name", font: .monospacedSystemFont(ofSize: 12, weight: .regular), onVariableUpdate: appState.updateEnvironmentVariable)
                                .frame(maxWidth: .infinity)
                                .onChange(of: param.key) { draft.ensureEmptyRows() }
                            
                            VariableTextField(text: $param.value, env: appState.activeEnvironment, placeholder: "Value", font: .monospacedSystemFont(ofSize: 12, weight: .regular), onVariableUpdate: appState.updateEnvironmentVariable)
                                .frame(maxWidth: .infinity)
                                .onChange(of: param.value) { draft.ensureEmptyRows() }
                            
                            if param.id != draft.query.last?.id || !param.key.isEmpty || !param.value.isEmpty {
                                Button(action: {
                                    if let index = draft.query.firstIndex(where: { $0.id == param.id }) {
                                        draft.removeQuery(at: index)
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.secondary)
                                        .frame(width: 30, height: 24)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Color.clear.frame(width: 30, height: 24)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        Divider().gridCellColumns(4)
                    }
                }
            }
            .padding()
        }
    }
}
