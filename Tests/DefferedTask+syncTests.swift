import DefferedTaskKit
import Dispatch
import Foundation
import SpryKit
import XCTest

final class DefferedTask_syncTests: XCTestCase {
    func test_sync_value() {
        let subject = DefferedResult<[Int], TestError>(success: [1, 2, 3])
        let actual = sync(subject, timeoutResult: .failure(.anyError1))
        XCTAssertEqual(actual, .success([1, 2, 3]))
    }

    func test_sync_closure() {
        let subject = DefferedResult<[Int], TestError>(success: [1, 2, 3])
        let actual = sync(subject, seconds: 1) {
            return .failure(.anyError1)
        }
        XCTAssertEqual(actual, .success([1, 2, 3]))
    }

    func test_timeout() {
        let subject = DefferedResult<[Int], TestError> { _ in
            // should never end
        }
        let actual = sync(subject, seconds: 0.1) {
            return .failure(.anyError1)
        }
        XCTAssertEqual(actual, .failure(.anyError1))
    }

    func test_throws_assertion() {
        let subject = DefferedResult<[Int], TestError>(success: [1, 2, 3])
        XCTAssertThrowsAssertion {
            let actual = sync(subject, seconds: -1) {
                return .failure(.anyError1)
            }
            XCTAssertEqual(actual, .success([1, 2, 3]))
        }
    }
}
