import Foundation
import Yams

class YamlParser {
    static func parse(_ yaml: String) -> [String: Any] {
        do {
            if let dict = try Yams.load(yaml: yaml) as? [String: Any] {
                return dict
            }
        } catch {
            print("YamlParser error: \(error)")
        }
        return [:]
    }
}
