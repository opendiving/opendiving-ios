/// A ``BackgroundExecution`` with no app to keep running.
public struct NoBackgroundExecution: BackgroundExecution {
  public init() {}

  public func begin(name: String) async -> BackgroundExecutionToken {
    BackgroundExecutionToken(rawValue: 0)
  }

  public func end(_ token: BackgroundExecutionToken) async {}
}
