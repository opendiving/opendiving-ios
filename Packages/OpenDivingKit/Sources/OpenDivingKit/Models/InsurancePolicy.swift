/// One dive-insurance policy on the check-in sheet.
public struct InsurancePolicy: Codable, Hashable, Sendable {
  public let provider: String
  public let number: String?
  public let expiresOn: CalendarDate?
}
