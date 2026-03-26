import Foundation
import Yams

class YamlEnvironmentParser {
    func parse(content: String, name: String, filePath: String? = nil) -> Environment {
        var envName = name
        var variables: [EnvironmentVariable] = []
        
        guard let dict = try? Yams.load(yaml: content) as? [String: Any] else {
            return Environment(name: envName, variables: [], filePath: filePath)
        }
        
        if let parsedName = dict["name"] as? String {
            envName = parsedName
        }
        
        if let varsArray = dict["variables"] as? [[String: Any]] {
            for vDict in varsArray {
                let key = (vDict["name"] as? String) ?? (vDict["key"] as? String) ?? ""
                let value = (vDict["value"] as? String) ?? ""
                
                var isSecret = false
                if let secretBool = vDict["secret"] as? Bool {
                    isSecret = secretBool
                } else if let secretString = vDict["secret"] as? String {
                    isSecret = (secretString.lowercased() == "true")
                }
                
                if !key.isEmpty {
                    variables.append(EnvironmentVariable(key: key, value: String(describing: value), isSecret: isSecret))
                }
            }
        }
        
        return Environment(name: envName, variables: variables, filePath: filePath)
    }
    
    func serialize(_ env: Environment) -> String {
        return (try? Yams.dump(object: serializeToDict(env))) ?? ""
    }
    
    private func serializeToDict(_ env: Environment) -> [String: Any] {
        var dict: [String: Any] = ["name": env.name]
        var varsArray: [[String: Any]] = []
        for v in env.variables {
            var vDict: [String: Any] = [
                "name": v.key,
                "value": v.value
            ]
            if v.isSecret {
                vDict["secret"] = true
            }
            varsArray.append(vDict)
        }
        dict["variables"] = varsArray
        return dict
    }
}
