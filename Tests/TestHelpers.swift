import Foundation
import SpryKit

extension Result {
    var error: Failure? {
        switch self {
        case .success:
            return nil
        case .failure(let e):
            return e
        }
    }

    var value: Success? {
        switch self {
        case .success(let v):
            return v
        case .failure:
            return nil
        }
    }
}

enum TestError: Swift.Error, Equatable {
    case anyError1
    case anyError2
}

enum TestError2: Swift.Error, Equatable {
    case anyError
}

#if swift(>=6.0)
final class SendableResult<T>: @unchecked Sendable {
    var value: T!

    init(value: T! = nil) {
        self.value = value
    }
}
#else
final class SendableResult<T> {
    var value: T!

    init(value: T! = nil) {
        self.value = value
    }
}
#endif
