import Foundation

extension String {
    func snakeToCamelCase() -> String {
        var result = ""
        
        var toUpper = false
        for char in self {
            if char == "_" {
                toUpper = true
            } else {
                result.append(toUpper ? char.uppercased() : String(char))
                toUpper = false
            }
        }
        
        return result
    }
}
