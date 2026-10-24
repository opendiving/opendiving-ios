/// `POST /species/resolve`'s body: a search hit's AphiaID, which the server turns into a
/// catalog species.
struct SpeciesResolveRequest: Encodable {
  let aphiaId: Int
}
