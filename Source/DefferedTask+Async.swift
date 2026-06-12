import Foundation
public extension DefferedTask {
    func onComplete() async -> ResultType
    where ResultType: Sendable {
        return await withCheckedContinuation { actual in
            onComplete {
                actual.resume(returning: $0)
            }
        }
    }

    func onComplete<Response, Error: Swift.Error>() async throws -> Response
    where ResultType == Result<Response, Error>, Response: Sendable {
        return try await withCheckedThrowingContinuation { actual in
            onComplete {
                actual.resume(with: $0)
            }
        }
    }
}
