/// FastAPI's error body. `detail` is a sentence, except for a validation 422, where it is an
/// array of `{type, loc, msg, input}` whose `loc` mixes strings and integers — which is why
/// nothing here types `loc` at all.
struct ErrorDetail: Decodable {
  let message: String?

  private enum CodingKeys: String, CodingKey { case detail }
  private struct Item: Decodable { let msg: String? }

  init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    if let sentence = try? c.decode(String.self, forKey: .detail) {
      message = sentence
    } else if let items = try? c.decode([Item].self, forKey: .detail) {
      message = items.lazy.compactMap(\.msg).first
    } else {
      message = nil
    }
  }
}
