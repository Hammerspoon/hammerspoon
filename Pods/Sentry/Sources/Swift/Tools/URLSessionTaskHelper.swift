import Foundation

@objcMembers
class URLSessionTaskHelper: NSObject {

    static func getGraphQLOperationName(from task: URLSessionTask?) -> String? {
        guard let task = task else { return nil }
        guard task.originalRequest?.value(forHTTPHeaderField: "Content-Type") == "application/json" else { return nil }
        guard let requestBody = task.originalRequest?.httpBody else { return nil }

        let requestInfo = try? JSONDecoder().decode(GraphQLRequest.self, from: requestBody)

        return requestInfo?.operationName
    }

}

private struct GraphQLRequest: Decodable {
    let operationName: String
}
