import SwiftUI

struct EnvironmentEditorView: View {
    @Bindable var draft: DraftEnvironment
    @State private var showSecrets = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                TextField("Environment Name", text: $draft.name)
                    .font(.title2.bold())
                    .textFieldStyle(.plain)
                
                Spacer()
                
                Button {
                    showSecrets.toggle()
                } label: {
                    Label(showSecrets ? "Hide Secrets" : "Show Secrets", 
                          systemImage: showSecrets ? "eye.slash" : "eye")
                }
                .buttonStyle(.bordered)
            }
            .padding()
            
            Divider()
            
            // Variables Table
            List {
                HStack {
                    Text("").frame(width: 20)
                    Text("Name").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Value").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Secret").frame(width: 50)
                    Text("").frame(width: 30)
                }
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                
                ForEach($draft.variables) { $variable in
                    EnvironmentVariableRow(variable: $variable, showSecrets: showSecrets) {
                        if let index = draft.variables.firstIndex(where: { $0.id == variable.id }) {
                            draft.variables.remove(at: index)
                            draft.ensureEmptyRow()
                        }
                    }
                    .onChange(of: variable.key) { _, _ in draft.ensureEmptyRow() }
                    .onChange(of: variable.value) { _, _ in draft.ensureEmptyRow() }
                }
            }
            .listStyle(.plain)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct EnvironmentVariableRow: View {
    @Binding var variable: EnvironmentVariable
    let showSecrets: Bool
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: $variable.isEnabled)
                .toggleStyle(.checkbox)
                .frame(width: 20)
            
            TextField("Key", text: $variable.key)
                .textFieldStyle(.plain)
                .frame(maxWidth: .infinity)
            
            Group {
                if variable.isSecret && !showSecrets {
                    SecureField("Value", text: $variable.value)
                        .textFieldStyle(.plain)
                } else {
                    TextField("Value", text: $variable.value)
                        .textFieldStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            
            Toggle("", isOn: $variable.isSecret)
                .toggleStyle(.checkbox)
                .frame(width: 50)
            
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 30)
        }
        .padding(.vertical, 4)
        .padding(.horizontal)
    }
}
