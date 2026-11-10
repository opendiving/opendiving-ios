extension GearSetFormValues {
  /// A new set's form, a copy of `set`: its gear, its weight and its name with *copy* on the
  /// end.
  public init(duplicating set: GearSetRead) {
    self.init(editing: set)
    name = set.name + " copy"
  }
}
