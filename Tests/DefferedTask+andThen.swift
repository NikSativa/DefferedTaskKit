import DefferedTaskKit
import Dispatch
import Foundation
import SpryKit
import Threading
import XCTest

final class DefferedTask_andThen: XCTestCase {
    func test_andThen() {
        let subject: (Int) -> String? = { [unowned self] v in
            let actual: SendableResult<String?> = .init()
            let exp = expectation(description: "wait")
            DefferedTask<Int>(result: v).andThen { v in
                return .init { actual in
                    Queue.main.async {
                        actual("\(v)")
                    }
                }
                .set(workQueue: .n.async(.background))
                .set(completionQueue: .n.async(.background))
            }
            .set(workQueue: .n.async(.background))
            .set(completionQueue: .n.async(.background))
            // .weakify() <- 'andThen' makes 'strongify()'
            .onComplete { result in
                actual.value = result
                exp.fulfill()
            }
            wait(for: [exp], timeout: 1)
            return actual.value
        }

        XCTAssertEqual(subject(1), "1")
        XCTAssertEqual(subject(11), "11")
    }

    func test_andThen_destructed_task() {
        let subject: (Int) -> String? = { [unowned self] v in
            let actual: SendableResult<String?> = .init()
            var cached: Any?

            let exp = expectation(description: "wait")
            exp.isInverted = true
            DefferedTask<Int>(result: v).weakify()
                .andThen { v in
                    return .init { actual in
                        Queue.main.async {
                            actual("\(v)")
                        }
                    }
                    .set(workQueue: .n.async(.background))
                    .set(completionQueue: .n.async(.background))
                }
                .set(workQueue: .n.async(.background))
                .set(completionQueue: .n.async(.background))
                .assign(to: &cached)
                .weakify() // <- 'andThen' makes 'strongify()', but we are ignoring that
                .onComplete { result in
                    actual.value = result
                    exp.fulfill()
                }

            cached = nil

            wait(for: [exp], timeout: 0.2)
            return actual.value ?? nil
        }

        XCTAssertEqual(subject(1), nil)
        XCTAssertEqual(subject(11), nil)
    }
}
