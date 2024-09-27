import Foundation
import Threading

public typealias DefferedResult<T, E: Error> = DefferedTask<Result<T, E>>

#if swift(>=6.0)
public final class DefferedTask<ResultType: Sendable>: @unchecked Sendable {
    public typealias Completion = @Sendable (_ result: ResultType) -> Void
    public typealias TaskClosure = @Sendable (_ completion: @escaping Completion) -> Void
    public typealias DeinitClosure = () -> Void

    public var userInfo: Any?

    private let work: TaskClosure
    private let cancel: DeinitClosure
    private var beforeCallback: Completion?
    private var completeCallback: Completion?
    private var afterCallback: Completion?
    private var options: MemoryOption = .selfRetained
    private var mutex: Mutexing = Mutex.pthread(.recursive)
    private var completionQueue: DelayedQueue = .absent
    private var workQueue: DelayedQueue = .absent
    private var strongyfy: DefferedTask?
    private var completed: Bool = false

    public required init(execute workItem: @escaping TaskClosure,
                         onDeinit cancelation: @escaping DeinitClosure = {}) {
        self.work = workItem
        self.cancel = cancelation
    }

    deinit {
        cancel()
    }
}
#else
public final class DefferedTask<ResultType> {
    public typealias Completion = (_ result: ResultType) -> Void
    public typealias TaskClosure = (_ completion: @escaping Completion) -> Void
    public typealias DeinitClosure = () -> Void

    public var userInfo: Any?

    private let work: TaskClosure
    private let cancel: DeinitClosure
    private var beforeCallback: Completion?
    private var completeCallback: Completion?
    private var afterCallback: Completion?
    private var options: MemoryOption = .selfRetained
    private var mutex: Mutexing = Mutex.pthread(.recursive)
    private var completionQueue: DelayedQueue = .absent
    private var workQueue: DelayedQueue = .absent
    private var strongyfy: DefferedTask?
    private var completed: Bool = false

    public required init(execute workItem: @escaping TaskClosure,
                         onDeinit cancelation: @escaping DeinitClosure = {}) {
        self.work = workItem
        self.cancel = cancelation
    }

    deinit {
        cancel()
    }
}
#endif

public extension DefferedTask {
    private func complete(_ result: ResultType) {
        let callbacks: Callbacks = mutex.sync {
            let callbacks: Callbacks = .init(before: self.beforeCallback, complete: self.completeCallback, deferred: self.afterCallback)

            self.beforeCallback = nil
            self.completeCallback = nil
            self.afterCallback = nil

            return callbacks
        }

        completionQueue.fire { [weak self, callbacks] in
            guard let self else {
                return
            }
            strongyfy = nil

            callbacks.before?(result)
            callbacks.complete?(result)
            callbacks.deferred?(result)
        }
    }

    func onComplete(_ callback: @escaping Completion) {
        assert(!completed, "`onComplete` was called twice, please check it!")

        mutex.sync {
            switch options {
            case .selfRetained:
                strongyfy = self
            case .weakness:
                break
            }

            completeCallback = callback
            completed = true
        }

        workQueue.fire { [weak self] in
            guard let self else {
                return
            }
            work { [weak self] in
                guard let self else {
                    return
                }
                complete($0)
            }
        }
    }
}

// MARK: - public

public extension DefferedTask {
    // MARK: - convenience init

    #if swift(>=6.0)
    convenience init(result: @escaping @Sendable () -> ResultType) {
        self.init(execute: { $0(result()) })
    }

    convenience init(result: @escaping @autoclosure @Sendable () -> ResultType) {
        self.init(execute: { $0(result()) })
    }
    #else
    convenience init(result: @escaping () -> ResultType) {
        self.init(execute: { $0(result()) })
    }

    convenience init(result: @escaping @autoclosure () -> ResultType) {
        self.init(execute: { $0(result()) })
    }
    #endif

    // MARK: - oneWay

    /// execute work and ignore result
    func oneWay() {
        onComplete { _ in }
    }

    // MARK: - map

    #if swift(>=6.0)
    func map(_ mapper: @escaping @Sendable (ResultType) -> ResultType) -> DefferedTask<ResultType> {
        return flatMap { result in
            return mapper(result)
        }
    }

    func compactMap<NewResultType>(_ mapper: @escaping @Sendable (ResultType?) -> NewResultType) -> DefferedTask<NewResultType> {
        return flatMap { result in
            return mapper(result)
        }
    }

    func flatMap<NewResultType: Sendable>(_ mapper: @escaping @Sendable (ResultType) -> NewResultType) -> DefferedTask<NewResultType> {
        assert(!completed, "you can't change configuration after `onComplete`")
        mutex.sync {
            completed = true
            options = .weakness
            strongyfy = nil
        }

        let copy = DefferedTask<NewResultType>(execute: { [self] actual in
            mutex.sync {
                completed = false
            }

            onComplete { [weak self, actual] result in
                guard let self else {
                    return
                }

                workQueue.fire { [weak self, actual] in
                    guard let self else {
                        return
                    }

                    let new = mapper(result)
                    completionQueue.fire { [weak self, actual] in
                        guard let _ = self else {
                            return
                        }

                        actual(new)
                    }
                }
            }
        })

        return copy
    }
    #else
    func map(_ mapper: @escaping (ResultType) -> ResultType) -> DefferedTask<ResultType> {
        return flatMap { result in
            return mapper(result)
        }
    }

    func compactMap<NewResultType>(_ mapper: @escaping (ResultType?) -> NewResultType) -> DefferedTask<NewResultType> {
        return flatMap { result in
            return mapper(result)
        }
    }

    func flatMap<NewResultType>(_ mapper: @escaping (ResultType) -> NewResultType) -> DefferedTask<NewResultType> {
        assert(!completed, "you can't change configuration after `onComplete`")
        mutex.sync {
            completed = true
            options = .weakness
            strongyfy = nil
        }

        let copy = DefferedTask<NewResultType>(execute: { [self] actual in
            mutex.sync {
                completed = false
            }

            onComplete { [weak self, actual] result in
                guard let self else {
                    return
                }

                workQueue.fire { [weak self, actual] in
                    guard let self else {
                        return
                    }

                    let new = mapper(result)
                    completionQueue.fire { [weak self, actual] in
                        guard let _ = self else {
                            return
                        }

                        actual(new)
                    }
                }
            }
        })

        return copy
    }
    #endif

    // MARK: - before

    @discardableResult
    func beforeComplete(_ callback: @escaping Completion) -> Self {
        mutex.sync {
            let originalCallback = beforeCallback
            beforeCallback = { result in
                originalCallback?(result)
                callback(result)
            }
        }

        return self
    }

    // MARK: - defer

    @discardableResult
    func afterComplete(_ callback: @escaping Completion) -> Self {
        mutex.sync {
            let originalCallback = afterCallback
            afterCallback = { result in
                originalCallback?(result)
                callback(result)
            }
        }

        return self
    }

    // MARK: - unwrap

    #if swift(>=6.0)
    func unwrap<Response>(with value: @escaping @autoclosure @Sendable () -> Response) -> DefferedTask<Response>
    where ResultType == Response? {
        return flatMap {
            return $0 ?? value()
        }
    }

    func unwrap<Response>(_ value: @escaping @Sendable () -> Response) -> DefferedTask<Response>
    where ResultType == Response? {
        return flatMap {
            return $0 ?? value()
        }
    }
    #else
    func unwrap<Response>(with value: @escaping @autoclosure () -> Response) -> DefferedTask<Response>
    where ResultType == Response? {
        return flatMap {
            return $0 ?? value()
        }
    }

    func unwrap<Response>(_ value: @escaping () -> Response) -> DefferedTask<Response>
    where ResultType == Response? {
        return flatMap {
            return $0 ?? value()
        }
    }
    #endif

    // MARK: - assign

    func assign(to variable: inout AnyObject?) -> Self {
        assert(!completed, "you can't change configuration after `onComplete`")
        variable = self
        return self
    }

    func assign(to variable: inout AnyObject) -> Self {
        assert(!completed, "you can't change configuration after `onComplete`")
        variable = self
        return self
    }

    func assign(to variable: inout Any?) -> Self {
        assert(!completed, "you can't change configuration after `onComplete`")
        variable = self
        return self
    }

    func assign(to variable: inout Any) -> Self {
        assert(!completed, "you can't change configuration after `onComplete`")
        variable = self
        return self
    }

    func assign(to variable: inout DefferedTask?) -> Self {
        assert(!completed, "you can't change configuration after `onComplete`")
        variable = self
        return self
    }

    func assign(to variable: inout DefferedTask) -> Self {
        assert(!completed, "you can't change configuration after `onComplete`")
        variable = self
        return self
    }

    // MARK: - options

    func weakify() -> Self {
        assert(!completed, "you can't change configuration after `onComplete`")
        if options == .weakness {
            return self
        }

        mutex.sync {
            options = .weakness
        }
        return self
    }

    func strongify() -> Self {
        assert(!completed, "you can't change configuration after `onComplete`")
        if options == .selfRetained {
            return self
        }

        mutex.sync {
            options = .selfRetained
        }
        return self
    }

    // MARK: - queue

    func set(workQueue queue: DelayedQueue) -> Self {
        assert(!completed, "you can't change configuration after `onComplete`")
        mutex.sync {
            workQueue = queue
        }
        return self
    }

    func set(completionQueue queue: DelayedQueue) -> Self {
        assert(!completed, "you can't change configuration after `onComplete`")
        mutex.sync {
            completionQueue = queue
        }
        return self
    }

    // MARK: - userInfo

    func set(userInfo value: Any) -> Self {
        assert(!completed, "you can't change configuration after `onComplete`")
        mutex.sync {
            userInfo = value
        }
        return self
    }
}

// MARK: - DefferedTask.MemoryOption

private extension DefferedTask {
    enum MemoryOption: Equatable {
        case selfRetained
        case weakness
    }

    #if swift(>=6.0)
    struct Callbacks: @unchecked Sendable {
        let before: Completion?
        let complete: Completion?
        let deferred: Completion?
    }
    #else
    struct Callbacks {
        let before: Completion?
        let complete: Completion?
        let deferred: Completion?
    }
    #endif
}
