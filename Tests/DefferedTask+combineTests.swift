import DefferedTaskKit
import Dispatch
import Foundation
import SpryKit
import XCTest

final class DefferedTask_combineTests: XCTestCase {
    func test_combine_list() {
        let actual: SendableResult<[Int]> = .init()
        DefferedTask.combine(DefferedTask<Int>(result: 1), DefferedTask<Int>(result: 2), DefferedTask<Int>(result: 3))
            .onComplete { result in
                actual.value = result
            }
        XCTAssertEqual(actual.value, [1, 2, 3])
    }

    func test_combine_array() {
        let actual: SendableResult<[Int]> = .init()
        let tasks: [DefferedTask<Int>] = [
            .init(result: 1),
            .init(result: 2),
            .init(result: 3)
        ]
        DefferedTask.combine(tasks)
            .onComplete { result in
                actual.value = result
            }
        XCTAssertEqual(actual.value, [1, 2, 3])
    }

    func test_combine_array2() {
        let actual: SendableResult<[Int]> = .init()
        let tasks: [DefferedTask<Int>] = [
            .init(result: 1),
            .init(result: 2),
            .init(result: 3)
        ]
        tasks.combine()
            .onComplete { result in
                actual.value = result
            }
        XCTAssertEqual(actual.value, [1, 2, 3])
    }

    func test_combine_empty_array() {
        let actual: SendableResult<[Int]> = .init()
        let tasks: [DefferedTask<Int>] = []
        DefferedTask.combine(tasks)
            .onComplete { result in
                actual.value = result
            }
        XCTAssertEqual(actual.value, [])
    }

    func test_combineSuccess() {
        let actual: SendableResult<(lhs: Int, rhs: String)> = .init()
        DefferedResult<Int, TestError>.success(1)
            .combineSuccess(with: .success("2"))
            .recover(with: (2, "3"))
            .onComplete { result in
                actual.value = result
            }
        XCTAssertEqualAny(actual.value, (1, "2"))
    }

    func test_combineError() {
        let actual: SendableResult<(lhs: Int, rhs: String)> = .init()
        DefferedResult<Int, TestError>.success(1)
            .combineSuccess(with: .failure(.anyError1))
            .recover(with: (2, "3"))
            .onComplete { result in
                actual.value = result
            }
        XCTAssertEqualAny(actual.value, (2, "3"))
    }
}
