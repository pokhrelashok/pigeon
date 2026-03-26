import Foundation
import Observation

@Observable
class DraftEnvironment: Identifiable {
    var id: UUID
    var name: String
    var variables: [EnvironmentVariable]
    var initialEnvironment: Environment
    
    var isDirty: Bool {
        return toEnvironment() != initialEnvironment
    }
    
    init(env: Environment) {
        self.initialEnvironment = env
        self.id = env.id
        self.name = env.name
        self.variables = env.variables
        ensureEmptyRow()
    }
    
    func ensureEmptyRow() {
        if variables.last?.key.isEmpty == false || variables.last?.value.isEmpty == false || variables.isEmpty {
            variables.append(EnvironmentVariable(key: "", value: "", isSecret: false, isEnabled: true))
        }
    }
    
    func toEnvironment() -> Environment {
        let activeVars = variables.filter { !$0.key.isEmpty || !$0.value.isEmpty }
        return Environment(name: name, variables: activeVars, filePath: initialEnvironment.filePath)
    }
}

