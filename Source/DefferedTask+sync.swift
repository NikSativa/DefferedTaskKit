import Foundation

@inline(__always)
@discardableResult
public func sync<T>(_ callback: DefferedTask<T>,
                    seconds: Double? = nil,
                    timeoutResult timeout: @autoclosure () -> T) -> T {
    return sync(callback,
                seconds: seconds,
                timeoutResult: timeout)
}

@inline(__always)
@discardableResult
public func sync<T>(_ callback: DefferedTask<T>,
                    seconds: Double? = nil,
                    timeoutResult timeout: () -> T) -> T {
    let group = DispatchGroup()
    let result: ResultHolder<T> = .init()

    group.enter()
    callback.strongify()
        .onComplete { [result] in
            result.value = $0
            group.leave()
        }

    assert(seconds.map { $0 > 0 } ?? true, "seconds must be nil or greater than 0")

    if let seconds, seconds > 0 {
        let timeoutResult = group.wait(timeout: .now() + seconds)
        switch timeoutResult {
        case .success:
            break
        case .timedOut:
            result.value = timeout()
        }
    } else {
        group.wait()
    }

    return result.value
}

#if swift(>=6.0)
private final class ResultHolder<T>: @unchecked Sendable {
    var value: T!
}
#else
private final class ResultHolder<T> {
    var value: T!
}
#endif
