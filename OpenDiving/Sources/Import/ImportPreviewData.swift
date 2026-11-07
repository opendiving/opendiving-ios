import Foundation
import OpenDivingKit

/// An import for the import screens' previews and hosted-draw tests: a dive new to the logbook, a
/// dive it changes and one it already holds.
enum ImportPreviewData {
  static let uuid = "01a0a51f-afe3-7363-a0bc-b0d634c35923"

  static let pending = read(status: "pending", appliedAt: "null")
  static let applied = read(status: "applied", appliedAt: #""2026-09-14T13:00:00+00:00""#)

  static let notes: LogbookImportNotes = decode(notesJSON)

  /// Answers the routes the history, the applied import and its log read.
  static var session: Session {
    Session.stub(
      transport: StubTransport(routes: [
        "GET imports": .json(
          #"{"data":[{"uuid":"\#(uuid)","created_at":"2026-09-14T12:00:00+00:00","#
            + #""applied_at":"2026-09-14T13:00:00+00:00","counts":{"new":1,"modified":1}}],"#
            + #""total_count":1,"has_more":false,"page":1,"items_per_page":50}"#),
        "GET import/\(uuid)": .json(
          json(status: "applied", appliedAt: #""2026-09-14T13:00:00+00:00""#)),
        "GET import/\(uuid)/notes": .json(notesJSON),
      ]))
  }

  private static let notesJSON = #"""
    {"dives":[{"uuid":"01a20000-0000-7000-8000-000000000001",
               "start_time":"2021-04-04T10:04:00+02:00",
               "device":{"brand":"Suunto","model":"Suunto Ocean","serial":null,"firmware":null,
                         "name":null,"dive_number":null},
               "outcome":"modified","reason":null,
               "notes":[{"code":"recording_filled","kind":null,"collection":"dives",
                         "message":"A recording of this dive gained a file."}],
               "notes_truncated":2},
              {"uuid":null,"start_time":null,"device":null,"outcome":"skipped",
               "reason":"A dive needs a start time, and this one has none.","notes":[],
               "notes_truncated":0}],
     "notes":[{"code":"tags_created","kind":null,"collection":"dives",
               "message":"1 tag is new to your logbook: drift.","count":1,"wheres":[]}],
     "notes_truncated":1}
    """#

  private static func read(status: String, appliedAt: String) -> LogbookImportRead {
    decode(json(status: status, appliedAt: appliedAt))
  }

  // The literals here are this file's own and decode.
  private static func decode<Value: Decodable>(_ json: String) -> Value {
    try! APICoding.decoder().decode(Value.self, from: Data(json.utf8))
  }

  private static func json(status: String, appliedAt: String) -> String {
    #"""
    {"uuid":"\#(uuid)","status":"\#(status)",
     "created_at":"2026-09-14T12:00:00+00:00","applied_at":\#(appliedAt),
     "expires_at":"2026-09-15T12:00:00+00:00","archive":false,
     "collections":[{"collection":"sites","created":1,"linked":2,"skipped":0}],
     "files":{"referenced":2,"restored":0,"not_contained":2,"skipped":0},
     "members":[{"part":0,"container":null,"name":"dive-0214.fit","byte_size":48213,
                 "sha256":"3f","format":"fit","opened":null,"kept":true,"not_kept":null,
                 "refusal":null},
                {"part":1,"container":null,"name":"notes.txt","byte_size":27,"sha256":"4a",
                 "format":null,"opened":null,"kept":false,"not_kept":null,
                 "refusal":"This file is not one OpenDiving reads."}],
     "dives":[\#(row(outcome: "new", changes: "[]")),
              \#(row(outcome: "modified", changes: changes)),
              {"uuid":null,"outcome":"unchanged","dive":null,"changes":[],
               "start_time":"2026-09-14T09:12:00+03:00","device":null,"members":[0],
               "reason":null}],
     "check_in_details":[{"detail":"phone","account":null,"proposed":"+1 555 0100"}],
     "portrait":null,
     "numbering":{"total_dives":3,"lowest":1,"highest":3,"missing_count":0,"duplicate_count":0,
                  "out_of_date_order_count":0,"is_sequential":true}}
    """#
  }

  private static let changes =
    #"[{"member":"max_depth","before":23.0,"after":23.41},"#
    + #"{"member":"recordings/0/files/1","before":null,"#
    + #""after":{"original_filename":"dive-0214.fit"}}]"#

  private static func row(outcome: String, changes: String) -> String {
    #"{"uuid":"01a20000-0000-7000-8000-000000000001","outcome":"\#(outcome)","#
      + #""dive":\#(DivePreviewData.dive),"changes":\#(changes),"#
      + #""start_time":"2021-04-04T10:04:00+02:00","device":null,"members":[0],"reason":null}"#
  }
}
