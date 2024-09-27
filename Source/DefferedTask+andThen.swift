import Foundation

#if swift(>=6.0)
public extension DefferedTask {
    func andThen<T>(_ waiter: @escaping @Sendable (ResultType) -> DefferedTask<T>) -> DefferedTask<(first: ResultType, second: T)> {
        let lazy = Cache(generator: waiter)
        return .init(execute: { [self] actual in
            strongify() // make sure the first task is retained
                .onComplete { result1 in
                    lazy.cached(result1)
                        .weakify() // the second task is retained by Cache
                        .onComplete { result2 in
                            actual((result1, result2))
                            lazy.cleanup()
                        }
                }
        }, onDeinit: {
            lazy.cleanup()
        })
    }

    func andThen<T>(_ waiter: @escaping @Sendable (ResultType) -> DefferedTask<T>) -> DefferedTask<T> {
        return andThen(waiter).flatMap { v in
            return v.second
        }
    }
}

private final class Cache<In: Sendable, Out: Sendable>: @unchecked Sendable {
    typealias Generator = @Sendable (In) -> DefferedTask<Out>
    private let generator: Generator
    private(set) var cachedCallback: DefferedTask<Out>?

    init(generator: @escaping Generator) {
        self.generator = generator
    }

    func cached(_ in: In) -> DefferedTask<Out> {
        if let cached = cachedCallback {
            return cached
        }
        let new = generator(`in`)
        cachedCallback = new
        return new
    }

    func cleanup() {
        cachedCallback = nil
    }
}
#else
public extension DefferedTask {
    func andThen<T>(_ waiter: @escaping (ResultType) -> DefferedTask<T>) -> DefferedTask<(first: ResultType, second: T)> {
        let lazy = Cache(generator: waiter)
        return .init(execute: { [self] actual in
            strongify() // make sure the first task is retained
                .onComplete { result1 in
                    lazy.cached(result1)
                        .weakify() // the second task is retained by Cache
                        .onComplete { result2 in
                            actual((result1, result2))
                            lazy.cleanup()
                        }
                }
        }, onDeinit: {
            lazy.cleanup()
        })
    }

    func andThen<T>(_ waiter: @escaping (ResultType) -> DefferedTask<T>) -> DefferedTask<T> {
        return andThen(waiter).flatMap { v in
            return v.second
        }
    }
}

private final class Cache<In, Out> {
    typealias Generator = (In) -> DefferedTask<Out>
    private let generator: Generator
    private(set) var cachedCallback: DefferedTask<Out>?

    init(generator: @escaping Generator) {
        self.generator = generator
    }

    func cached(_ in: In) -> DefferedTask<Out> {
        if let cached = cachedCallback {
            return cached
        }
        let new = generator(`in`)
        cachedCallback = new
        return new
    }

    func cleanup() {
        cachedCallback = nil
    }
}
#endif
