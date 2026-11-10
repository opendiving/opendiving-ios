/// A file's size as the web writes it (`formatFileSize`): whole kilobytes, at least one for a
/// file that has any bytes, then a megabyte or a gigabyte to one place.
public enum FileSizeText {
  public static func size(_ bytes: Int) -> String {
    guard bytes > 0 else { return "0 KB" }
    let kb = Double(bytes) / 1024
    if kb < 1024 { return "\(NumberText.plain(max(1, NumberText.round(kb)))) KB" }
    let mb = kb / 1024
    if mb < 1024 { return "\(NumberText.fixed(mb, decimals: 1)) MB" }
    return "\(NumberText.fixed(mb / 1024, decimals: 1)) GB"
  }
}
