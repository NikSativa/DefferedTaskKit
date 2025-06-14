import DefferedTaskKit
import Dispatch
import Foundation
import SpryKit
import Threading
import XCTest

final class DefferedTaskTests: XCTestCase {
    private static let timeout: TimeInterval = 0.5

    private enum Value: Equatable, SpryEquatable {
        case idle
        case timedOut
        case correct
    }

    func test_strongify_both_on_same_thread() {
        let started: SendableResult<Int> = .init(value: 0)
        let stopped: SendableResult<Int> = .init(value: 0)

        let beforeCompleted: SendableResult<[Value]> = .init(value: [])
        let completed2: SendableResult<[Int]> = .init(value: [])
        let deferredCompleted: SendableResult<[Value]> = .init(value: [])

        var subject: DefferedTask<Value>! = .init { [started] completion in
            started.value += 1
            completion(.correct)
        } onDeinit: { [stopped] in
            stopped.value += 1
        }
        .beforeComplete { [beforeCompleted] result in
            beforeCompleted.value.append(result)
        }
        .afterComplete { [deferredCompleted] result in
            deferredCompleted.value.append(result)
        }
        .set(userInfo: "subject")

        var intSubject: DefferedTask<Int>! = subject.flatMap { _ in
            return 1
        }
        intSubject.set(userInfo: "intSubject")
            .onComplete { [completed2] in
                completed2.value.append($0)
            }

        XCTAssertEqual(started.value, 1)
        XCTAssertEqual(stopped.value, 0)

        XCTAssertEqual(beforeCompleted.value, [.correct])
        XCTAssertEqual(completed2.value, [1])
        XCTAssertEqual(deferredCompleted.value, [.correct])

        subject = nil

        XCTAssertEqual(started.value, 1)
        XCTAssertEqual(stopped.value, 0)

        intSubject = nil

        XCTAssertEqual(started.value, 1)
        XCTAssertEqual(stopped.value, 1)

        XCTAssertEqual(beforeCompleted.value, [.correct])
        XCTAssertEqual(completed2.value, [1])
        XCTAssertEqual(deferredCompleted.value, [.correct])
    }

    func test_strongify_both_on_other_threads() {
        let started: SendableResult<Int> = .init(value: 0)
        let stopped: SendableResult<Int> = .init(value: 0)

        let beforeCompleted: SendableResult<[Value]> = .init(value: [])
        let completed2: SendableResult<[Int]> = .init(value: [])
        let deferredCompleted: SendableResult<[Value]> = .init(value: [])

        let expSubject = expectation(description: "subject")
        let deinitSubject = expectation(description: "deinitSubject")
        var subject: DefferedTask<Value>! = .init { [started] completion in
            started.value += 1
            completion(.correct)
            expSubject.fulfill()
        } onDeinit: { [stopped] in
            stopped.value += 1
            deinitSubject.fulfill()
        }
        .set(workQueue: .async(Queue.background))
        .set(completionQueue: .async(Queue.background))
        .flatMap { v in
            return v
        }
        .beforeComplete { [beforeCompleted] result in
            beforeCompleted.value.append(result)
        }
        .afterComplete { [deferredCompleted] result in
            deferredCompleted.value.append(result)
        }
        .set(userInfo: "subject")

        let expIntSubject = expectation(description: "subject2")
        var intSubject: DefferedTask<Int>! = subject.flatMap { _ in
            return 1
        }
        .set(userInfo: "intSubject")
        .set(workQueue: .async(Queue.background))
        .set(completionQueue: .async(Queue.background))

        intSubject.onComplete { [completed2] in
            completed2.value.append($0)
            expIntSubject.fulfill()
        }

        XCTAssertEqual(started.value, 0)
        XCTAssertEqual(stopped.value, 0)
        wait(for: [expSubject, expIntSubject], timeout: Self.timeout)

        XCTAssertEqual(started.value, 1)
        XCTAssertEqual(stopped.value, 0)

        XCTAssertEqual(beforeCompleted.value, [.correct])
        XCTAssertEqual(completed2.value, [1])
        XCTAssertEqual(deferredCompleted.value, [.correct])

        // rm sub task first
        intSubject = nil

        XCTAssertEqual(started.value, 1)
        XCTAssertEqual(stopped.value, 0)

        subject = nil
        wait(for: [deinitSubject], timeout: Self.timeout)

        XCTAssertEqual(started.value, 1)
        XCTAssertEqual(stopped.value, 1)

        XCTAssertEqual(beforeCompleted.value, [.correct])
        XCTAssertEqual(completed2.value, [1])
        XCTAssertEqual(deferredCompleted.value, [.correct])
    }

    func test_behavior_unretaned_both_tasks() {
        let started: SendableResult<Int> = .init(value: 0)
        let stopped: SendableResult<Int> = .init(value: 0)

        let beforeCompleted: SendableResult<[Value]> = .init(value: [])
        let completed2: SendableResult<[Int]> = .init(value: [])
        let deferredCompleted: SendableResult<[Value]> = .init(value: [])

        let expSubject = expectation(description: "subject")
        expSubject.isInverted = true
        var subject: DefferedTask<Value>! = .init { [started] completion in
            started.value += 1
            completion(.correct)
        } onDeinit: { [stopped] in
            stopped.value += 1
        }
        .weakify()
        .set(workQueue: .async(Queue.background))
        .set(completionQueue: .async(Queue.background))
        .flatMap { v in
            return v
        }
        .beforeComplete { [beforeCompleted] result in
            beforeCompleted.value.append(result)
        }
        .afterComplete { [deferredCompleted] result in
            deferredCompleted.value.append(result)
            expSubject.fulfill()
        }
        .set(userInfo: "subject")

        let expIntSubject = expectation(description: "intSubject")
        expIntSubject.isInverted = true
        var intSubject: DefferedTask<Int>! = subject.flatMap { _ in
            return 1
        }
        .set(userInfo: "intSubject")
        .weakify()

        intSubject.onComplete { [completed2] in
            completed2.value.append($0)
            expIntSubject.fulfill()
        }

        XCTAssertEqual(started.value, 0)
        XCTAssertEqual(stopped.value, 0)

        // rm sub task first
        intSubject = nil
        subject = nil

        wait(for: [expSubject, expIntSubject], timeout: Self.timeout)

        XCTAssertEqual(started.value, 0)
        XCTAssertEqual(stopped.value, 1)

        XCTAssertEqual(beforeCompleted.value, [])
        XCTAssertEqual(completed2.value, [])
        XCTAssertEqual(deferredCompleted.value, [])
    }

    func test_behavior_unretained_subject() {
        let started: SendableResult<Int> = .init(value: 0)
        let stopped: SendableResult<Int> = .init(value: 0)

        let beforeCompleted: SendableResult<[Value]> = .init(value: [])
        let completed2: SendableResult<[Int]> = .init(value: [])
        let deferredCompleted: SendableResult<[Value]> = .init(value: [])

        let expSubject = expectation(description: "subject")
        var subject: DefferedTask<Value>! = .init { [started] completion in
            started.value += 1
            completion(.correct)
        } onDeinit: { [stopped] in
            stopped.value += 1
        }
        .weakify()
        .set(workQueue: .async(Queue.background))
        .set(completionQueue: .async(Queue.background))
        .flatMap { v in
            return v
        }
        .beforeComplete { [beforeCompleted] result in
            beforeCompleted.value.append(result)
        }
        .afterComplete { [deferredCompleted] result in
            deferredCompleted.value.append(result)
            expSubject.fulfill()
        }
        .set(userInfo: "subject")

        let expIntSubject = expectation(description: "intSubject")
        let intSubject: DefferedTask<Int>! = subject.flatMap { _ in
            return 1
        }
        .set(userInfo: "intSubject")
        .set(workQueue: .async(Queue.background))
        .set(completionQueue: .async(Queue.background))

        XCTAssertEqual(started.value, 0)
        XCTAssertEqual(stopped.value, 0)

        intSubject.onComplete { [completed2] in
            completed2.value.append($0)
            expIntSubject.fulfill()
        }

        // rm sub task first
        subject = nil

        wait(for: [expSubject, expIntSubject], timeout: Self.timeout)

        XCTAssertEqual(started.value, 1)
        XCTAssertEqual(stopped.value, 0)

        XCTAssertEqual(beforeCompleted.value, [.correct])
        XCTAssertEqual(completed2.value, [1])
        XCTAssertEqual(deferredCompleted.value, [.correct])
    }

    func test_behavior_unretaned_subtask() {
        let started: SendableResult<Int> = .init(value: 0)
        let stopped: SendableResult<Int> = .init(value: 0)

        let beforeCompleted: SendableResult<[Value]> = .init(value: [])
        let completed2: SendableResult<[Int]> = .init(value: [])
        let deferredCompleted: SendableResult<[Value]> = .init(value: [])

        let expSubject = expectation(description: "subject")
        expSubject.isInverted = true
        let subject: DefferedTask<Value>! = .init { [started] completion in
            started.value += 1
            completion(.correct)
        } onDeinit: { [stopped] in
            stopped.value += 1
        }
        .set(workQueue: .async(Queue.background))
        .set(completionQueue: .async(Queue.background))
        .flatMap { v in
            return v
        }
        .beforeComplete { [beforeCompleted] result in
            beforeCompleted.value.append(result)
        }
        .afterComplete { [deferredCompleted] result in
            deferredCompleted.value.append(result)
            expSubject.fulfill()
        }
        .set(userInfo: "subject")

        let expIntSubject = expectation(description: "intSubject")
        expIntSubject.isInverted = true
        var intSubject: DefferedTask<Int>! = subject.flatMap { _ in
            return 1
        }
        .set(userInfo: "intSubject")
        .weakify()
        .set(workQueue: .async(Queue.background))
        .set(completionQueue: .async(Queue.background))

        intSubject.onComplete { [completed2] in
            completed2.value.append($0)
            expIntSubject.fulfill()
        }

        XCTAssertEqual(started.value, 0)
        XCTAssertEqual(stopped.value, 0)

        // rm sub task first
        intSubject = nil

        wait(for: [expSubject, expIntSubject], timeout: Self.timeout)

        XCTAssertEqual(started.value, 0)
        XCTAssertEqual(stopped.value, 0)

        XCTAssertEqual(beforeCompleted.value, [])
        XCTAssertEqual(completed2.value, [])
        XCTAssertEqual(deferredCompleted.value, [])
    }

    func test_twice_onComplete() {
        let intSubject: DefferedTask<Int> = .init(execute: { _ in
            // shoulde never end
        })

        intSubject.onComplete { _ in
            assertionFailure("should never heppen")
        }

        XCTAssertThrowsAssertion {
            intSubject.onComplete { _ in
                assertionFailure("should never heppen")
            }
        }
    }

    func test_init() {
        let actual: SendableResult<Int?> = .init()

        let subject: DefferedTask<Int> = .init(result: 1)
        subject.onComplete { [actual] result in
            actual.value = result
        }
        XCTAssertEqual(actual.value, 1)

        let subject2: DefferedTask<Int> = .init(result: {
            return 2
        })
        subject2.onComplete { [actual] result in
            actual.value = result
        }
        XCTAssertEqual(actual.value, 2)
    }

    func test_oneWay() {
        let actual: SendableResult<Bool> = .init()

        DefferedTask<Int>(execute: { completion in
            completion(1)
        }, onDeinit: { [actual] in
            actual.value = true
        }).oneWay()

        XCTAssertTrue(actual.value ?? false)
    }

    func test_assertions() {
        let createSubject: () -> DefferedTask<Int> = {
            let intSubject: DefferedTask<Int> = .init(execute: { _ in
                // shoulde never end
            })
            .weakify()
            .weakify()
            .strongify()
            .strongify()
            .set(completionQueue: .absent)
            .set(workQueue: .absent)

            intSubject.onComplete { _ in
                assertionFailure("should never heppen")
            }
            return intSubject
        }

        XCTAssertThrowsAssertion {
            createSubject().onComplete { _ in
                assertionFailure("should never heppen")
            }
        }

        XCTAssertThrowsAssertion {
            _ = createSubject()
                .flatMap { _ in
                    return "str"
                }
                .flatMapVoid()
        }

        XCTAssertThrowsAssertion {
            _ = createSubject()
                .compactMap { _ in
                    return "str"
                }
                .flatMapVoid()
        }

        XCTAssertThrowsAssertion {
            var some: AnyObject?
            _ = createSubject().assign(to: &some)
        }

        XCTAssertThrowsAssertion {
            var some: AnyObject = NSObject()
            _ = createSubject().assign(to: &some)
        }

        XCTAssertThrowsAssertion {
            var some: Any?
            _ = createSubject().assign(to: &some)
        }

        XCTAssertThrowsAssertion {
            var some: Any = NSObject()
            _ = createSubject().assign(to: &some)
        }

        XCTAssertThrowsAssertion {
            var some: DefferedTask<Int>?
            _ = createSubject().assign(to: &some)
        }

        XCTAssertThrowsAssertion {
            var some: DefferedTask<Int> = .init(result: 1)
            _ = createSubject().assign(to: &some)
        }

        XCTAssertThrowsAssertion {
            _ = createSubject().weakify()
        }

        XCTAssertThrowsAssertion {
            _ = createSubject().strongify()
        }

        XCTAssertThrowsAssertion {
            _ = createSubject().set(workQueue: .absent)
        }

        XCTAssertThrowsAssertion {
            _ = createSubject().set(completionQueue: .absent)
        }

        XCTAssertThrowsAssertion {
            _ = createSubject().set(userInfo: "some")
        }
    }

    func test_unwrap() {
        let actual: SendableResult<Int?> = .init()

        DefferedTask<Int?>(result: nil)
            .unwrap(with: 1)
            .onComplete { [actual] result in
                actual.value = result
            }
        XCTAssertEqual(actual.value, 1)

        DefferedTask<Int?>(result: nil)
            .unwrap {
                return 2
            }
            .onComplete { [actual] result in
                actual.value = result
            }
        XCTAssertEqual(actual.value, 2)
    }

    func test_queue() {
        let actual: SendableResult<Int> = .init(value: -1)
        let isBackgroundThreadMap: SendableResult<Bool> = .init(value: false)
        let isMainThreadComplete: SendableResult<Bool> = .init(value: false)

        let expMap = expectation(description: "map")
        let expComplete = expectation(description: "complete")
        DefferedTask<Int>(result: 0)
            .set(workQueue: .async(Queue.background))
            .set(completionQueue: .async(Queue.main))
            .map { _ in
                isBackgroundThreadMap.value = !Thread.isMainThread
                expMap.fulfill()
                return 1
            }
            .onComplete { result in
                isMainThreadComplete.value = Thread.isMainThread
                actual.value = result
                expComplete.fulfill()
            }
        wait(for: [expMap, expComplete], timeout: Self.timeout)

        XCTAssertEqual(actual.value, 1)
        XCTAssertTrue(isBackgroundThreadMap.value)
        XCTAssertTrue(isMainThreadComplete.value)
    }

    func test_queue2() {
        let actual: SendableResult<Int> = .init(value: -1)
        let isBackgroundThreadMap: SendableResult<Bool> = .init(value: false)
        let isBackgroundThreadComplete: SendableResult<Bool> = .init(value: false)

        let expMap = expectation(description: "map")
        let expComplete = expectation(description: "complete")
        DefferedTask<Int?>(result: nil)
            .set(workQueue: .async(Queue.background))
            .set(completionQueue: .async(Queue.background))
            .compactMap { _ in
                isBackgroundThreadMap.value = !Thread.isMainThread
                expMap.fulfill()
                return 1
            }
            .onComplete { result in
                isBackgroundThreadComplete.value = !Thread.isMainThread
                actual.value = result
                expComplete.fulfill()
            }
        wait(for: [expMap, expComplete], timeout: Self.timeout)

        XCTAssertEqual(actual.value, 1)
        XCTAssertTrue(isBackgroundThreadMap.value)
        XCTAssertTrue(isBackgroundThreadComplete.value)
    }
}
