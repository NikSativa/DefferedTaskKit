import Foundation

#if swift(>=6.0)
public extension DefferedTask {
    func on<Response, Error: Swift.Error>(success: @escaping @Sendable (_ result: Response) -> Void,
                                          fail: @escaping @Sendable (_ error: Error) -> Void)
    where ResultType == Result<Response, Error> {
        onComplete { result in
            switch result {
            case .success(let response):
                success(response)
            case .failure(let error):
                fail(error)
            }
        }
    }

    // MARK: - convenience init

    convenience init<Response, Error>(success result: @escaping @Sendable () -> Response)
        where ResultType == Result<Response, Error> {
        self.init(execute: {
            let result = result()
            $0(.success(result))
        })
    }

    convenience init<Response, Error>(failure result: @escaping @Sendable () -> Error)
        where ResultType == Result<Response, Error> {
        self.init(execute: {
            let result = result()
            $0(.failure(result))
        })
    }

    convenience init<Response, Error>(success result: @escaping @autoclosure @Sendable () -> Response)
        where ResultType == Result<Response, Error> {
        self.init(execute: {
            let result = result()
            $0(.success(result))
        })
    }

    convenience init<Response, Error>(failure result: @escaping @autoclosure @Sendable () -> Error)
        where ResultType == Result<Response, Error> {
        self.init(execute: {
            let result = result()
            $0(.failure(result))
        })
    }

    static func success<Response, Error>(_ result: @escaping @autoclosure @Sendable () -> Response) -> DefferedResult<Response, Error>
    where ResultType == Result<Response, Error> {
        return .init {
            return .success(result())
        }
    }

    static func failure<Response, Error>(_ result: @escaping @autoclosure @Sendable () -> Error) -> DefferedResult<Response, Error>
    where ResultType == Result<Response, Error> {
        return .init {
            return .failure(result())
        }
    }

    // MARK: - map

    func map<NewResponse, Response, Error: Swift.Error>(_ mapper: @escaping @Sendable (_ value: Response) -> NewResponse) -> DefferedResult<NewResponse, Error>
    where ResultType == Result<Response, Error>, NewResponse: Sendable {
        return flatMap {
            return $0.map(mapper)
        }
    }

    func mapError<Response, Error: Swift.Error, NewError: Swift.Error>(_ mapper: @escaping @Sendable (_ error: Error) -> NewError) -> DefferedResult<Response, NewError>
    where ResultType == Result<Response, Error> {
        return flatMap {
            return $0.mapError(mapper)
        }
    }

    func compactMap<NewResponse, Response, Error: Swift.Error>(_ mapper: @escaping @Sendable (_ value: Response) -> NewResponse?) -> DefferedResult<[NewResponse], Error>
    where ResultType == Result<[Response], Error>, NewResponse: Sendable {
        return flatMap {
            return $0.map {
                return $0.compactMap(mapper)
            }
        }
    }

    func tryMap<NewResponse, Response, Error: Swift.Error>(_ mapper: @escaping @Sendable (_ value: Response) throws -> NewResponse) -> DefferedResult<NewResponse, Swift.Error>
    where ResultType == Result<Response, Error>, NewResponse: Sendable {
        return flatMap {
            do {
                switch $0 {
                case .success(let response):
                    return try .success(mapper(response))
                case .failure(let error):
                    return .failure(error)
                }
            } catch {
                return .failure(error)
            }
        }
    }

    // MARK: - before

    @discardableResult
    func beforeSuccess<Response, Error: Swift.Error>(_ success: @escaping @Sendable (_ value: Response) -> Void) -> Self
    where ResultType == Result<Response, Error> {
        return beforeComplete { result in
            switch result {
            case .success(let response):
                success(response)
            case .failure:
                break
            }
        }
    }

    @discardableResult
    func beforeFail<Response, Error: Swift.Error>(_ fail: @escaping @Sendable (_ error: Error) -> Void) -> Self
    where ResultType == Result<Response, Error> {
        return beforeComplete { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                fail(error)
            }
        }
    }

    // MARK: - defer

    @discardableResult
    func afterSuccess<Response, Error: Swift.Error>(_ success: @escaping @Sendable (_ value: Response) -> Void) -> Self
    where ResultType == Result<Response, Error> {
        return afterComplete { result in
            switch result {
            case .success(let response):
                success(response)
            case .failure:
                break
            }
        }
    }

    @discardableResult
    func afterFail<Response, Error: Swift.Error>(_ fail: @escaping @Sendable (_ error: Error) -> Void) -> Self
    where ResultType == Result<Response, Error> {
        return afterComplete { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                fail(error)
            }
        }
    }

    // MARK: - recover

    func recover<Response, Error: Swift.Error>(_ mapper: @escaping @Sendable (_ error: Error) -> Response) -> DefferedTask<Response>
    where ResultType == Result<Response, Error> {
        return flatMap {
            switch $0 {
            case .success(let v):
                return v
            case .failure(let e):
                return mapper(e)
            }
        }
    }

    func recover<Response, Error: Swift.Error>(_ recovered: @escaping @Sendable () -> Response) -> DefferedTask<Response>
    where ResultType == Result<Response, Error> {
        return flatMap {
            switch $0 {
            case .success(let v):
                return v
            case .failure:
                return recovered()
            }
        }
    }

    func recover<Response, Error: Swift.Error>(with recovered: @escaping @autoclosure @Sendable () -> Response) -> DefferedTask<Response>
    where ResultType == Result<Response, Error> {
        return flatMap {
            switch $0 {
            case .success(let v):
                return v
            case .failure:
                return recovered()
            }
        }
    }

    // MARK: - nil

    func nilIfFailure<Response, Error: Swift.Error>() -> DefferedTask<Response?>
    where ResultType == Result<Response, Error> {
        return flatMap {
            switch $0 {
            case .success(let v):
                return v
            case .failure:
                return nil
            }
        }
    }

    // MARK: - unwrap

    func unwrap<Response, Error: Swift.Error>(with value: @escaping @autoclosure @Sendable () -> Response) -> DefferedResult<Response, Error>
    where ResultType == Result<Response?, Error> {
        return flatMap {
            switch $0 {
            case .success(let v):
                return .success(v ?? value())
            case .failure(let error):
                return .failure(error)
            }
        }
    }

    func unwrap<Response, Error: Swift.Error>(_ value: @escaping @Sendable () -> Response) -> DefferedResult<Response, Error>
    where ResultType == Result<Response?, Error> {
        return flatMap {
            switch $0 {
            case .success(let v):
                return .success(v ?? value())
            case .failure(let error):
                return .failure(error)
            }
        }
    }

    func unwrap<Response, Error: Swift.Error>(orThrow newError: @escaping @autoclosure @Sendable () -> Error) -> DefferedResult<Response, Error>
    where ResultType == Result<Response?, Error> {
        return flatMap {
            switch $0 {
            case .success(.none):
                return .failure(newError())
            case .success(.some(let v)):
                return .success(v)
            case .failure(let error):
                return .failure(error)
            }
        }
    }
}
#else
public extension DefferedTask {
    func on<Response, Error: Swift.Error>(success: @escaping (_ result: Response) -> Void,
                                          fail: @escaping (_ error: Error) -> Void)
    where ResultType == Result<Response, Error> {
        onComplete { result in
            switch result {
            case .success(let response):
                success(response)
            case .failure(let error):
                fail(error)
            }
        }
    }

    // MARK: - convenience init

    convenience init<Response, Error>(success result: @escaping () -> Response)
        where ResultType == Result<Response, Error> {
        self.init(execute: {
            let result = result()
            $0(.success(result))
        })
    }

    convenience init<Response, Error>(failure result: @escaping () -> Error)
        where ResultType == Result<Response, Error> {
        self.init(execute: {
            let result = result()
            $0(.failure(result))
        })
    }

    convenience init<Response, Error>(success result: @escaping @autoclosure () -> Response)
        where ResultType == Result<Response, Error> {
        self.init(execute: {
            let result = result()
            $0(.success(result))
        })
    }

    convenience init<Response, Error>(failure result: @escaping @autoclosure () -> Error)
        where ResultType == Result<Response, Error> {
        self.init(execute: {
            let result = result()
            $0(.failure(result))
        })
    }

    static func success<Response, Error>(_ result: @escaping @autoclosure () -> Response) -> DefferedResult<Response, Error>
    where ResultType == Result<Response, Error> {
        return .init {
            return .success(result())
        }
    }

    static func failure<Response, Error>(_ result: @escaping @autoclosure () -> Error) -> DefferedResult<Response, Error>
    where ResultType == Result<Response, Error> {
        return .init {
            return .failure(result())
        }
    }

    // MARK: - map

    func map<NewResponse, Response, Error: Swift.Error>(_ mapper: @escaping (_ value: Response) -> NewResponse) -> DefferedResult<NewResponse, Error>
    where ResultType == Result<Response, Error> {
        return flatMap {
            return $0.map(mapper)
        }
    }

    func mapError<Response, Error: Swift.Error, NewError: Swift.Error>(_ mapper: @escaping (_ error: Error) -> NewError) -> DefferedResult<Response, NewError>
    where ResultType == Result<Response, Error> {
        return flatMap {
            return $0.mapError(mapper)
        }
    }

    func compactMap<NewResponse, Response, Error: Swift.Error>(_ mapper: @escaping (_ value: Response) -> NewResponse?) -> DefferedResult<[NewResponse], Error>
    where ResultType == Result<[Response], Error> {
        return flatMap {
            return $0.map {
                return $0.compactMap(mapper)
            }
        }
    }

    func tryMap<NewResponse, Response, Error: Swift.Error>(_ mapper: @escaping (_ value: Response) throws -> NewResponse) -> DefferedResult<NewResponse, Swift.Error>
    where ResultType == Result<Response, Error> {
        return flatMap {
            do {
                switch $0 {
                case .success(let response):
                    return try .success(mapper(response))
                case .failure(let error):
                    return .failure(error)
                }
            } catch {
                return .failure(error)
            }
        }
    }

    // MARK: - before

    @discardableResult
    func beforeSuccess<Response, Error: Swift.Error>(_ success: @escaping (_ value: Response) -> Void) -> Self
    where ResultType == Result<Response, Error> {
        return beforeComplete { result in
            switch result {
            case .success(let response):
                success(response)
            case .failure:
                break
            }
        }
    }

    @discardableResult
    func beforeFail<Response, Error: Swift.Error>(_ fail: @escaping (_ error: Error) -> Void) -> Self
    where ResultType == Result<Response, Error> {
        return beforeComplete { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                fail(error)
            }
        }
    }

    // MARK: - defer

    @discardableResult
    func afterSuccess<Response, Error: Swift.Error>(_ success: @escaping (_ value: Response) -> Void) -> Self
    where ResultType == Result<Response, Error> {
        return afterComplete { result in
            switch result {
            case .success(let response):
                success(response)
            case .failure:
                break
            }
        }
    }

    @discardableResult
    func afterFail<Response, Error: Swift.Error>(_ fail: @escaping (_ error: Error) -> Void) -> Self
    where ResultType == Result<Response, Error> {
        return afterComplete { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                fail(error)
            }
        }
    }

    // MARK: - recover

    func recover<Response, Error: Swift.Error>(_ mapper: @escaping (_ error: Error) -> Response) -> DefferedTask<Response>
    where ResultType == Result<Response, Error> {
        return flatMap {
            switch $0 {
            case .success(let v):
                return v
            case .failure(let e):
                return mapper(e)
            }
        }
    }

    func recover<Response, Error: Swift.Error>(_ recovered: @escaping () -> Response) -> DefferedTask<Response>
    where ResultType == Result<Response, Error> {
        return flatMap {
            switch $0 {
            case .success(let v):
                return v
            case .failure:
                return recovered()
            }
        }
    }

    func recover<Response, Error: Swift.Error>(with recovered: @escaping @autoclosure () -> Response) -> DefferedTask<Response>
    where ResultType == Result<Response, Error> {
        return flatMap {
            switch $0 {
            case .success(let v):
                return v
            case .failure:
                return recovered()
            }
        }
    }

    // MARK: - nil

    func nilIfFailure<Response, Error: Swift.Error>() -> DefferedTask<Response?>
    where ResultType == Result<Response, Error> {
        return flatMap {
            switch $0 {
            case .success(let v):
                return v
            case .failure:
                return nil
            }
        }
    }

    // MARK: - unwrap

    func unwrap<Response, Error: Swift.Error>(with value: @escaping @autoclosure () -> Response) -> DefferedResult<Response, Error>
    where ResultType == Result<Response?, Error> {
        return flatMap {
            switch $0 {
            case .success(let v):
                return .success(v ?? value())
            case .failure(let error):
                return .failure(error)
            }
        }
    }

    func unwrap<Response, Error: Swift.Error>(_ value: @escaping () -> Response) -> DefferedResult<Response, Error>
    where ResultType == Result<Response?, Error> {
        return flatMap {
            switch $0 {
            case .success(let v):
                return .success(v ?? value())
            case .failure(let error):
                return .failure(error)
            }
        }
    }

    func unwrap<Response, Error: Swift.Error>(orThrow newError: @escaping @autoclosure () -> Error) -> DefferedResult<Response, Error>
    where ResultType == Result<Response?, Error> {
        return flatMap {
            switch $0 {
            case .success(.none):
                return .failure(newError())
            case .success(.some(let v)):
                return .success(v)
            case .failure(let error):
                return .failure(error)
            }
        }
    }
}
#endif
