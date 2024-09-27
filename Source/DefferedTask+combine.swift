import Foundation

public extension Array {
    @inline(__always)
    func combine<ResultType>() -> DefferedTask<[ResultType]>
    where Element: DefferedTask<ResultType> {
        if isEmpty {
            return .init(result: [])
        }

        let infos: [Info<ResultType>] = map {
            return Info(original: $0)
        }

        let startTask: DefferedTask<[ResultType]>.TaskClosure = { [infos] original in
            for info in infos {
                info.start {
                    let responses: [ResultType] = infos.compactMap(\.result)
                    if infos.count == responses.count {
                        original(responses)
                    }
                }
            }
        }

        let stopTask: DefferedTask<[ResultType]>.DeinitClosure = {
            for info in infos {
                info.stop()
            }
        }

        return .init(execute: startTask,
                     onDeinit: stopTask)
    }
}

public extension DefferedTask {
    @inline(__always)
    static func combine(_ input: DefferedTask...) -> DefferedTask<[ResultType]> {
        return input.combine()
    }

    @inline(__always)
    static func combine(_ input: [DefferedTask]) -> DefferedTask<[ResultType]> {
        return input.combine()
    }

    #if swift(>=6.0)
    func combineSuccess<OriginalResult, OtherResult, Error>(with rhs: DefferedResult<OtherResult, Error>) -> DefferedResult<(lhs: OriginalResult, rhs: OtherResult), Error>
    where ResultType == Result<OriginalResult, Error>, Error: Swift.Error, OtherResult: Sendable {
        let new: DefferedTask<(ResultType, Result<OtherResult, Error>)> = combine(with: rhs)
        return new.flatMap {
            switch $0 {
            case (.success(let a), .success(let b)):
                let result: (OriginalResult, OtherResult) = (a, b)
                return .success(result)
            case (_, .failure(let a)),
                 (.failure(let a), _):
                return .failure(a)
            }
        }
    }

    func combine<OtherResult>(with rhs: DefferedTask<OtherResult>) -> DefferedTask<(ResultType, OtherResult)> {
        let info = Info2(a: self, b: rhs)

        let startTask: DefferedTask<(ResultType, OtherResult)>.TaskClosure = { [info] original in
            let check: @Sendable () -> Void = { [info] in
                if let a = info.rA, let b = info.rB {
                    let result = (a, b)
                    original(result)
                }
            }

            info.a.weakify().onComplete { [info] result in
                info.rA = result
                check()
            }

            info.b.weakify().onComplete { [info] result in
                info.rB = result
                check()
            }
        }

        let stopTask: DefferedTask<(ResultType, OtherResult)>.DeinitClosure = { [info] in
            info.a = nil
            info.b = nil
        }

        return .init(execute: startTask,
                     onDeinit: stopTask)
    }
    #else
    func combineSuccess<OriginalResult, OtherResult, Error>(with rhs: DefferedResult<OtherResult, Error>) -> DefferedResult<(lhs: OriginalResult, rhs: OtherResult), Error>
    where ResultType == Result<OriginalResult, Error>, Error: Swift.Error {
        let new: DefferedTask<(ResultType, Result<OtherResult, Error>)> = combine(with: rhs)
        return new.flatMap {
            switch $0 {
            case (.success(let a), .success(let b)):
                let result: (OriginalResult, OtherResult) = (a, b)
                return .success(result)
            case (_, .failure(let a)),
                 (.failure(let a), _):
                return .failure(a)
            }
        }
    }

    func combine<OtherResult>(with rhs: DefferedTask<OtherResult>) -> DefferedTask<(ResultType, OtherResult)> {
        let info = Info2(a: self, b: rhs)

        let startTask: DefferedTask<(ResultType, OtherResult)>.TaskClosure = { [info] original in
            let check: () -> Void = { [info] in
                if let a = info.rA, let b = info.rB {
                    let result = (a, b)
                    original(result)
                }
            }

            info.a.weakify().onComplete { [info] result in
                info.rA = result
                check()
            }

            info.b.weakify().onComplete { [info] result in
                info.rB = result
                check()
            }
        }

        let stopTask: DefferedTask<(ResultType, OtherResult)>.DeinitClosure = { [info] in
            info.a = nil
            info.b = nil
        }

        return .init(execute: startTask,
                     onDeinit: stopTask)
    }
    #endif
}

#if swift(>=6.0)
private final class Info2<A: Sendable, B: Sendable>: @unchecked Sendable {
    var a: DefferedTask<A>!
    var rA: A?
    var b: DefferedTask<B>!
    var rB: B?

    internal init(a: DefferedTask<A>, b: DefferedTask<B>) {
        self.a = a
        self.b = b
    }
}

private final class Info<R: Sendable>: @unchecked Sendable {
    enum State {
        case pending
        case value(R)
    }

    private var original: DefferedTask<R>!
    private var state: State = .pending

    var result: R? {
        switch state {
        case .pending:
            return nil
        case .value(let r):
            return r
        }
    }

    init(original: DefferedTask<R>) {
        self.original = original
    }

    func start(_ completion: @escaping @Sendable () -> Void) {
        assert(original != nil)

        original.weakify().onComplete { [weak self] result in
            self?.state = .value(result)
            self?.stop()
            completion()
        }
    }

    func stop() {
        original = nil
    }
}
#else
private final class Info2<A, B> {
    var a: DefferedTask<A>!
    var rA: A?
    var b: DefferedTask<B>!
    var rB: B?

    internal init(a: DefferedTask<A>, b: DefferedTask<B>) {
        self.a = a
        self.b = b
    }
}

private final class Info<R> {
    enum State {
        case pending
        case value(R)
    }

    private var original: DefferedTask<R>!
    private var state: State = .pending

    var result: R? {
        switch state {
        case .pending:
            return nil
        case .value(let r):
            return r
        }
    }

    init(original: DefferedTask<R>) {
        self.original = original
    }

    func start(_ completion: @escaping () -> Void) {
        assert(original != nil)

        original.weakify().onComplete { [weak self] result in
            self?.state = .value(result)
            self?.stop()
            completion()
        }
    }

    func stop() {
        original = nil
    }
}
#endif
