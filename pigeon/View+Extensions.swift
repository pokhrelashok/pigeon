import SwiftUI

extension Notification.Name {
    static let triggerResponseSearch = Notification.Name("triggerResponseSearch")
    static let closeResponseSearch = Notification.Name("closeResponseSearch")
}

extension View {
    /// Prevents newline characters from being entered into a TextField (e.g. via paste)
    /// which can cause layout overflow in single-line containers.
    func stopNewlineEntry(text: Binding<String>) -> some View {
        self.onChange(of: text.wrappedValue) { oldValue, newValue in
            if newValue.contains("\n") {
                text.wrappedValue = newValue.replacingOccurrences(of: "\n", with: "")
            }
        }
    }
    
    @ViewBuilder
    func variableTooltip(text: String, env: Environment?) -> some View {
        if let env = env {
            let mapping = VariableResolver().resolveMapping(in: text, env: env)
            if !mapping.isEmpty {
                let tooltip = mapping.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
                self.help(tooltip)
            } else {
                self.help("")
            }
        } else {
            self.help("")
        }
    }
}
