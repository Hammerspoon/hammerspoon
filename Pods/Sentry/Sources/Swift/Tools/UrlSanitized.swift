import Foundation

@objcMembers
class UrlSanitized: NSObject {
    static let SENSITIVE_DATA_SUBSTITUTE = "[Filtered]"
    private var components: URLComponents?

    var query: String? { components?.query }
    var queryItems: [URLQueryItem]? { components?.queryItems }
    var fragment: String? { components?.fragment }

    init(URL url: URL) {
        components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        if components?.user != nil {
            components?.user = UrlSanitized.SENSITIVE_DATA_SUBSTITUTE
        }

        if components?.password != nil {
            components?.password = UrlSanitized.SENSITIVE_DATA_SUBSTITUTE
        }
    }

    var sanitizedUrl: String? {
        guard var result = self.components?.string else { return nil }
        if let end = result.firstIndex(of: "?") ?? result.firstIndex(of: "#") {
            result = String(result[result.startIndex..<end])
        }
        return result.removingPercentEncoding
    }
}
