extension FieldMessage {
  /// A record sheet's sentence under a field, which is there only while the field breaks a rule.
  init?(_ text: String?) {
    guard let text else { return nil }
    self.init(text)
  }
}
