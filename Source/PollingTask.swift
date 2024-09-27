import Foundation
import Threading

private let defaultScheduleQueue: Queueable = Queue.custom(label: "PollingTask",
                                                           qos: .utility,
                                                           attributes: .concurrent)

#if swift(>=6.0)
public final class PollingTask<ResultType: Sendable>: @unchecked Sendable {
    private let generator: () -> DefferedTask<ResultType>
    private var cached: DefferedTask<ResultType>?
    private var isCanceled: Bool = false

    private let scheduleQueue: Queueable

    private let idleTimeInterval: TimeInterval
    private let shouldRepeat: (ResultType) -> Bool
    private let response: (ResultType) -> Void

    private let timestamp: TimeInterval
    private let minimumWaitingTime: TimeInterval?
    private let retryCount: Int

    public required init(scheduleQueue: Queueable? = nil,
                         idleTimeInterval: TimeInterval,
                         retryCount: Int,
                         minimumWaitingTime: TimeInterval? = nil,
                         generator: @escaping () -> DefferedTask<ResultType>,
                         shouldRepeat: @escaping (ResultType) -> Bool = { _ in false },
                         response: @escaping (ResultType) -> Void = { _ in }) {
        assert(retryCount > 1, "do you really need polling? seems like `retryCount <= 1` is ignoring polling")

        self.scheduleQueue = scheduleQueue ?? defaultScheduleQueue
        self.generator = generator
        self.idleTimeInterval = idleTimeInterval
        self.shouldRepeat = shouldRepeat
        self.retryCount = max(1, retryCount)
        self.minimumWaitingTime = minimumWaitingTime
        self.response = response
        self.timestamp = Self.timestamp()
    }
}
#else
public final class PollingTask<ResultType> {
    private let generator: () -> DefferedTask<ResultType>
    private var cached: DefferedTask<ResultType>?
    private var isCanceled: Bool = false

    private let scheduleQueue: Queueable

    private let idleTimeInterval: TimeInterval
    private let shouldRepeat: (ResultType) -> Bool
    private let response: (ResultType) -> Void

    private let timestamp: TimeInterval
    private let minimumWaitingTime: TimeInterval?
    private let retryCount: Int

    public required init(scheduleQueue: Queueable? = nil,
                         idleTimeInterval: TimeInterval,
                         retryCount: Int,
                         minimumWaitingTime: TimeInterval? = nil,
                         generator: @escaping () -> DefferedTask<ResultType>,
                         shouldRepeat: @escaping (ResultType) -> Bool = { _ in false },
                         response: @escaping (ResultType) -> Void = { _ in }) {
        assert(retryCount > 1, "do you really need polling? seems like `retryCount <= 1` is ignoring polling")

        self.scheduleQueue = scheduleQueue ?? defaultScheduleQueue
        self.generator = generator
        self.idleTimeInterval = idleTimeInterval
        self.shouldRepeat = shouldRepeat
        self.retryCount = max(1, retryCount)
        self.minimumWaitingTime = minimumWaitingTime
        self.response = response
        self.timestamp = Self.timestamp()
    }
}
#endif

public extension PollingTask {
    func start() -> DefferedTask<ResultType> {
        return .init { actual in
            self.startPolling(actual, retryCount: self.retryCount)
        } onDeinit: {
            self.cancel()
        }
    }

    private func cancel() {
        isCanceled = true
        cached = nil
    }

    private func cachingNew() -> DefferedTask<ResultType> {
        let new = generator()
        cached = new
        return new
    }

    private func canWait() -> Bool {
        if let minimumWaitingTime {
            return max(Self.timestamp() - timestamp, 0) < minimumWaitingTime
        }
        return false
    }

    private func canRepeat(_ retryCount: Int) -> Bool {
        return retryCount > 0 || canWait()
    }

    private static func timestamp() -> TimeInterval {
        return max(Date().timeIntervalSinceReferenceDate, 0)
    }

    private func startPolling(_ actual: @escaping DefferedTask<ResultType>.Completion, retryCount: Int) {
        if isCanceled {
            return
        }

        cachingNew().weakify().onComplete { [unowned self] result in
            if isCanceled {
                return
            }

            response(result)

            if canRepeat(retryCount), shouldRepeat(result) {
                schedulePolling(actual, retryCount: retryCount - 1)
            } else {
                actual(result)
            }
        }
    }

    private func schedulePolling(_ actual: @escaping DefferedTask<ResultType>.Completion, retryCount: Int) {
        scheduleQueue.asyncAfter(deadline: .now() + max(idleTimeInterval, .leastNormalMagnitude)) { [self] in
            startPolling(actual, retryCount: retryCount)
        }
    }
}

public extension PollingTask {
    convenience init(scheduleQueue: Queueable? = nil,
                     idleTimeInterval: TimeInterval,
                     retryCount: Int,
                     minimumWaitingTime: TimeInterval? = nil,
                     generator: @escaping @autoclosure () -> DefferedTask<ResultType>,
                     shouldRepeat: @escaping (ResultType) -> Bool = { _ in false },
                     response: @escaping (ResultType) -> Void = { _ in }) {
        self.init(scheduleQueue: scheduleQueue,
                  idleTimeInterval: idleTimeInterval,
                  retryCount: retryCount,
                  minimumWaitingTime: minimumWaitingTime,
                  generator: generator,
                  shouldRepeat: shouldRepeat,
                  response: response)
    }
}
