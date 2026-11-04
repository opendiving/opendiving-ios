import OpenDivingKit
import SwiftUI

extension DiveFormModel {
  /// A field of the form as a control writes it, through ``change(_:)``.
  func binding<Value>(_ field: WritableKeyPath<DiveFormValues, Value>) -> Binding<Value> {
    Binding(
      get: { self.values[keyPath: field] },
      set: { value in self.change { $0[keyPath: field] = value } })
  }
}
