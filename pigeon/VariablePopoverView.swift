import SwiftUI

struct VariablePopoverView: View {
    let variableName: String
    let env: Environment?
    var onUpdate: ((String) -> Void)?
    
    @State private var editableValue: String = ""
    @FocusState private var isFocused: Bool
    @State private var updateTask: Task<Void, Never>? = nil
    
    private var resolvedValue: String? {
        env?.variables.first(where: { $0.key == variableName })?.value
    }
    
    private var envName: String {
        env?.name ?? "No Environment"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(variableName)
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Spacer()
                
                Button(action: copyToClipboard) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .help("Copy value")
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(envName)
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .foregroundColor(.secondary)
                    .clipShape(Capsule())
                
                if env != nil {
                    ZStack(alignment: .topLeading) {
                        if editableValue.isEmpty {
                            Text("Value")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary.opacity(0.5))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 8)
                        }
                        
                        TextEditor(text: $editableValue)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 60, maxHeight: 150)
                            .padding(4)
                            .scrollContentBackground(.hidden)
                            .focused($isFocused)
                            .onChange(of: editableValue) { _, newValue in
                                // Debounce the update to prevent flickering in the sidebar/UI
                                updateTask?.cancel()
                                updateTask = Task {
                                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                                    if !Task.isCancelled {
                                        onUpdate?(newValue)
                                    }
                                }
                            }
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                } else {
                    Text("Variable not defined in active environment")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            if let val = resolvedValue, val != editableValue {
                Text("Original: \(val)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(12)
        .frame(width: 280)
        .onAppear {
            editableValue = resolvedValue ?? ""
            isFocused = true
        }
    }
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(editableValue, forType: .string)
    }
}
