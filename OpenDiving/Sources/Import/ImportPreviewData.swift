import Foundation
import OpenDivingKit

/// A pending import for the import screens' previews.
enum ImportPreviewData {
  static let pending: LogbookImportRead = {
    let json = #"""
      {"uuid":"01a0a51f-afe3-7363-a0bc-b0d634c35923","status":"pending",
       "created_at":"2026-09-14T12:00:00+00:00","applied_at":null,
       "expires_at":"2026-09-15T12:00:00+00:00","archive":false,
       "collections":[{"collection":"sites","created":1,"linked":2,"skipped":0}],
       "files":{"referenced":2,"restored":0,"not_contained":2,"skipped":0},
       "members":[{"part":0,"container":null,"name":"dive-0214.fit","byte_size":48213,
                   "sha256":"3f","format":"fit","opened":null,"kept":true,"not_kept":null,
                   "refusal":null}],
       "dives":[{"uuid":null,"outcome":"new","dive":null,"changes":[],
                 "start_time":"2026-09-14T09:12:00+03:00",
                 "device":{"brand":"Garmin","model":"Descent Mk3","serial":null,
                 "firmware":null,"name":null,"dive_number":null},"members":[0],"reason":null}],
       "check_in_details":[{"detail":"phone","account":null,"proposed":"+1 555 0100"}],
       "portrait":null,
       "numbering":{"total_dives":3,"lowest":1,"highest":3,"missing_count":0,"duplicate_count":0,
                    "out_of_date_order_count":0,"is_sequential":true}}
      """#
    // The literal above is this file's own and decodes.
    return try! APICoding.decoder().decode(LogbookImportRead.self, from: Data(json.utf8))
  }()
}
