import Foundation
import OpenDivingKit

/// A preview's answer for the import screens' previews.
enum ImportPreviewData {
  static let preview: ImportPreview = {
    let json = #"""
      {"collections":[{"collection":"sites","created":1,"linked":2,"restored":0,"skipped":0}],
       "files":{"referenced":2,"restored":0,"not_contained":2,"skipped":0},
       "notes":[{"code":"tags_created","kind":null,"collection":"dives",
                 "message":"1 tag is new to your logbook: drift.","count":1,"wheres":[]}],
       "notes_truncated":0,
       "members":[{"part":0,"container":null,"name":"dive-0214.fit","byte_size":48213,
                   "sha256":"3f","format":"fit","opened":null,"kept":true,"not_kept":null,
                   "refusal":null}],
       "dives":[{"uuid":null,"outcome":"created","files_added":0,"recordings_added":0,
                 "reason":null,"start_time":"2026-09-14T09:12:00+03:00","submerged_time":2940,
                 "max_depth":24.6,"device":{"brand":"Garmin","model":"Descent Mk3","serial":null,
                 "firmware":null,"name":null,"dive_number":null},"members":[0],
                 "notes":[{"code":"gas_dropped","kind":"dropped","collection":"dives",
                           "message":"A tank pressure this dive recorded was dropped."}],
                 "notes_truncated":0}],
       "format":"fit","version":"1","generator":null,"archive":false,"token":"preview-token",
       "check_in_details":[{"detail":"phone","account":null,"proposed":"+1 555 0100"}],
       "portrait":null}
      """#
    // The literal above is this file's own and decodes.
    return try! APICoding.decoder().decode(ImportPreview.self, from: Data(json.utf8))
  }()
}
