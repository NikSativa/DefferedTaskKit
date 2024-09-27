import DefferedTaskKit
import Dispatch
import Foundation
import SpryKit
import XCTest

final class DefferedTask_ArrayTests: XCTestCase {
    func test_filterNils() {
        let actual: SendableResult<[Int]> = .init(value: [])
        DefferedTask<[Int?]>(result: [nil, 1, nil, 2, nil, 3, nil])
            .filterNils()
            .onComplete { result in
                actual.value = result
            }
        XCTAssertEqual(actual.value, [1, 2, 3])

        DefferedResult<[Int?], TestError>(success: [nil, 3, nil, 2, nil, 1, nil])
            .filterNils()
            .onComplete { result in
                actual.value = try! result.get()
            }
        XCTAssertEqual(actual.value, [3, 2, 1])
    }
}
