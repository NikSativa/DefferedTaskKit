import DefferedTaskKit
import Dispatch
import Foundation
import SpryKit
import XCTest

final class DefferedTask_ResultTests: XCTestCase {
    func test_alternative_completion() {
        let actual: SendableResult<Result<[Int], TestError>> = .init()

        DefferedResult<[Int?], TestError>(success: [nil, 1, nil, 2, nil, 3, nil])
            .filterNils()
            .on(success: { result in
                actual.value = .success(result)
            }) { _ in
                fatalError("should never happen")
            }
        XCTAssertEqual(actual.value, .success([1, 2, 3]))

        DefferedResult<[Int?], TestError>(failure: .anyError1)
            .filterNils()
            .on(success: { _ in
                fatalError("should never happen")
            }) { error in
                actual.value = .failure(error)
            }
        XCTAssertEqual(actual.value, .failure(.anyError1))
    }

    func test_compactMap() {
        let actual: SendableResult<Result<[Int], TestError>> = .init()

        DefferedResult<[Int?], TestError>(success: {
            return [nil, 1, nil, 2, nil, 3, nil]
        })
        .compactMap {
            return $0
        }
        .on(success: { result in
            actual.value = .success(result)
        }) { _ in
            fatalError("should never happen")
        }
        XCTAssertEqual(actual.value, .success([1, 2, 3]))
    }

    func test_tryMap() {
        let actual: SendableResult<Result<[Int], TestError>> = .init()

        DefferedResult<[Int?], TestError>(success: {
            return [nil, 1, nil, 2, nil, 3, nil]
        })
        .tryMap { _ -> [Int] in
            throw TestError2.anyError
        }
        .mapError { _ -> TestError in
            return .anyError1
        }
        .on(success: { result in
            actual.value = .success(result)
        }) { error in
            actual.value = .failure(error)
        }
        XCTAssertEqual(actual.value, .failure(.anyError1))

        actual.value = nil
        DefferedResult<[Int?], TestError>(failure: {
            return .anyError1
        })
        .tryMap { _ -> [Int] in
            fatalError("should never happen")
        }
        .mapError { _ -> TestError in
            return .anyError1
        }
        .on(success: { result in
            actual.value = .success(result)
        }) { error in
            actual.value = .failure(error)
        }
        XCTAssertEqual(actual.value, .failure(.anyError1))
    }

    func test_before_after() {
        let actual: SendableResult<Result<[Int], TestError>> = .init()
        let actualBefore: SendableResult<Result<[Int], TestError>> = .init()
        let actualAfter: SendableResult<Result<[Int], TestError>> = .init()

        DefferedResult<[Int], TestError>(success: {
            return [1, 2, 3]
        })
        .beforeSuccess { result in
            XCTAssertNil(actual.value)
            actualBefore.value = .success(result)
        }
        .beforeFail { _ in
            fatalError("should never happen")
        }
        .afterSuccess { result in
            XCTAssertNotNil(actual.value)
            actualAfter.value = .success(result)
        }
        .afterFail { _ in
            fatalError("should never happen")
        }
        .on(success: { result in
            actual.value = .success(result)
        }) { error in
            actual.value = .failure(error)
        }
        XCTAssertEqual(actualBefore.value, .success([1, 2, 3]))
        XCTAssertEqual(actual.value, .success([1, 2, 3]))
        XCTAssertEqual(actualAfter.value, .success([1, 2, 3]))

        actual.value = nil
        DefferedResult<[Int?], TestError>(failure: {
            return .anyError1
        })
        .tryMap { _ -> [Int] in
            fatalError("should never happen")
        }
        .mapError { _ -> TestError in
            return .anyError1
        }
        .beforeSuccess { _ in
            fatalError("should never happen")
        }
        .beforeFail { error in
            XCTAssertNil(actual.value)
            actualBefore.value = .failure(error)
        }
        .afterSuccess { _ in
            fatalError("should never happen")
        }
        .afterFail { error in
            XCTAssertNotNil(actual)
            actualAfter.value = .failure(error)
        }
        .on(success: { result in
            actual.value = .success(result)
        }) { error in
            actual.value = .failure(error)
        }

        XCTAssertEqual(actualBefore.value, .failure(.anyError1))
        XCTAssertEqual(actual.value, .failure(.anyError1))
        XCTAssertEqual(actualAfter.value, .failure(.anyError1))
    }

    func test_recover_error() {
        let actual: SendableResult<Result<[Int], TestError>> = .init()

        DefferedResult<[Int], TestError>(failure: {
            return .anyError1
        })
        .recover(with: [1, 2, 3])
        .onComplete { result in
            actual.value = .success(result)
        }
        XCTAssertEqual(actual.value, .success([1, 2, 3]))

        DefferedResult<[Int], TestError>(failure: {
            return .anyError1
        })
        .recover {
            return [3, 2, 1]
        }
        .onComplete { result in
            actual.value = .success(result)
        }
        XCTAssertEqual(actual.value, .success([3, 2, 1]))

        DefferedResult<[Int], TestError>(failure: {
            return .anyError1
        })
        .recover { _ in
            return [1, 2, 3]
        }
        .onComplete { result in
            actual.value = .success(result)
        }
        XCTAssertEqual(actual.value, .success([1, 2, 3]))
    }

    func test_recover_result() {
        let actual: SendableResult<Result<[Int], TestError>> = .init()

        DefferedResult<[Int], TestError>(success: {
            return [1, 2, 3]
        })
        .recover(with: [])
        .onComplete { result in
            actual.value = .success(result)
        }
        XCTAssertEqual(actual.value, .success([1, 2, 3]))

        DefferedResult<[Int], TestError>(success: {
            return [3, 2, 1]
        })
        .recover {
            fatalError("should never happen")
        }
        .onComplete { result in
            actual.value = .success(result)
        }
        XCTAssertEqual(actual.value, .success([3, 2, 1]))

        DefferedResult<[Int], TestError>(success: {
            return [1, 2, 3]
        })
        .recover { _ in
            fatalError("should never happen")
        }
        .onComplete { result in
            actual.value = .success(result)
        }
        XCTAssertEqual(actual.value, .success([1, 2, 3]))
    }

    func test_nilIfFailure() {
        let actual: SendableResult<Result<[Int], TestError>> = .init()

        DefferedResult<[Int], TestError>(failure: {
            return .anyError1
        })
        .nilIfFailure()
        .onComplete { result in
            actual.value = result.map(Result.success)
        }
        XCTAssertEqual(actual.value, nil)

        DefferedResult<[Int], TestError>(success: {
            return [1, 2]
        })
        .nilIfFailure()
        .onComplete { result in
            actual.value = result.map(Result.success)
        }
        XCTAssertEqual(actual.value, .success([1, 2]))
    }

    func test_unwrap_with_value() {
        let actual: SendableResult<Result<[Int], TestError>> = .init()

        DefferedResult<[Int]?, TestError>(failure: {
            return .anyError1
        })
        .unwrap(with: [2, 1])
        .onComplete { result in
            actual.value = result
        }
        XCTAssertEqual(actual.value, .failure(.anyError1))

        DefferedResult<[Int]?, TestError>(success: {
            return [1, 2]
        })
        .unwrap(with: [2, 1])
        .onComplete { result in
            actual.value = result
        }
        XCTAssertEqual(actual.value, .success([1, 2]))

        DefferedResult<[Int]?, TestError>(success: {
            return nil
        })
        .unwrap(with: [2, 1])
        .onComplete { result in
            actual.value = result
        }
        XCTAssertEqual(actual.value, .success([2, 1]))
    }

    func test_unwrap_with_closure() {
        let actual: SendableResult<Result<[Int], TestError>> = .init()

        DefferedResult<[Int]?, TestError>(failure: {
            return .anyError1
        })
        .unwrap {
            return [2, 1]
        }
        .onComplete { result in
            actual.value = result
        }
        XCTAssertEqual(actual.value, .failure(.anyError1))

        DefferedResult<[Int]?, TestError>(success: {
            return [1, 2]
        })
        .unwrap {
            return [2, 1]
        }
        .onComplete { result in
            actual.value = result
        }
        XCTAssertEqual(actual.value, .success([1, 2]))

        DefferedResult<[Int]?, TestError>(success: {
            return nil
        })
        .unwrap {
            return [2, 1]
        }
        .onComplete { result in
            actual.value = result
        }
        XCTAssertEqual(actual.value, .success([2, 1]))
    }

    func test_unwrap_with_error() {
        let actual: SendableResult<Result<[Int], TestError>> = .init()

        DefferedResult<[Int]?, TestError>(failure: {
            return .anyError1
        })
        .unwrap(orThrow: .anyError2)
        .onComplete { result in
            actual.value = result
        }
        XCTAssertEqual(actual.value, .failure(.anyError1))

        DefferedResult<[Int]?, TestError>(success: {
            return [1, 2]
        })
        .unwrap(orThrow: .anyError2)
        .onComplete { result in
            actual.value = result
        }
        XCTAssertEqual(actual.value, .success([1, 2]))

        DefferedResult<[Int]?, TestError>(success: {
            return nil
        })
        .unwrap(orThrow: .anyError2)
        .onComplete { result in
            actual.value = result
        }
        XCTAssertEqual(actual.value, .failure(.anyError2))
    }
}
