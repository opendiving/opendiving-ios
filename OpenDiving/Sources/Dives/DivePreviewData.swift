import Foundation
import OpenDivingKit

/// A dive for the dive screens' previews, served by a stub session as the API would.
enum DivePreviewData {
  static let diveUUID = UUID(uuidString: "01a20000-0000-7000-8000-000000000001")!

  /// Signed in, answering the list, the dive and its neighbours.
  static var session: Session {
    Session.stub(
      transport: StubTransport(routes: [
        "GET dives": .json(page),
        "GET dive/01a20000-0000-7000-8000-000000000001": .json(dive),
        "GET dive/01a20000-0000-7000-8000-000000000001/neighbors": .json(
          #"{"previous":null,"next":null}"#),
      ]))
  }

  /// The page's content, metric, with no people table.
  static var content: DiveDetailContent {
    let read = try! APICoding.decoder().decode(DiveReadWithMixtures.self, from: Data(dive.utf8))
    return DiveDetailContent(
      dive: read, trip: nil, course: nil, contact: nil, people: [:], units: .metric)
  }

  static let dive =
    #"{"uuid":"01a20000-0000-7000-8000-000000000001","entry_latitude":28.420546,"entry_longitude"#
    + #"":34.457623,"exit_latitude":28.420563,"exit_longitude":34.457658,"dive_number":212,"start_"#
    + #"time":"2021-04-04T10:04:00.5+02:00","submerged_time":3243,"max_depth":23.41,"avg_depth":13"#
    + #".62,"bottom_temperature":27.2,"visibility":30,"weight":6.0,"water_type":"lake","altitude":"#
    + #"372,"type":"semi_closed","rating":4,"air_temperature":24.0,"current":"light","waves":"calm"#
    + #"","weather":"clear","entry_type":"boat","boat_name":"Legend","notes":"Two computers, two t"#
    + #"anks.","user_uuid":"01a0a51f-afe3-7363-a0bc-b0d634c35923","trip_uuid":null,"course_uuid":n"#
    + #"ull,"contact_uuid":null,"created_at":"2026-10-03T14:07:21.216050Z","dive_sites":[{"uuid":""#
    + #"01a20000-0000-7000-8000-0000000000a1","name":"Blue Hole","latitude":28.5722,"longitude":34"#
    + #".5372,"location":{"name":"Dahab, Egypt","latitude":28.4963633,"longitude":34.5145652,"bbox"#
    + #"_south":null,"bbox_north":null,"bbox_west":null,"bbox_east":null}}],"gear_items":[{"uuid":"#
    + #""01a20000-0000-7000-8000-0000000000b1","name":"Twinset","brand":"Faber","type":"cylinder","#
    + #""rented":false,"is_archived":false,"volume":12.0,"working_pressure":232.0,"material":"stee"#
    + #"l"}],"mixtures":[{"volume":12.0,"start_pressure":200.0,"end_pressure":60.0,"oxygen":32.0,""#
    + #"helium":0.0,"po2_limit":1.4,"gas_number":1,"role":"bottom","usage":null,"id":101,"gear_ite"#
    + #"m":{"uuid":"01a20000-0000-7000-8000-0000000000b1","name":"Twinset","brand":"Faber","type":"#
    + #""cylinder","rented":false,"is_archived":false,"volume":12.0,"working_pressure":232.0,"mate"#
    + #"rial":"steel"}},{"volume":7.0,"start_pressure":200.0,"end_pressure":150.0,"oxygen":50.0,"h"#
    + #"elium":0.0,"po2_limit":null,"gas_number":2,"role":"deco","usage":"staged","id":102,"gear_i"#
    + #"tem":null}],"sightings":[{"uuid":"01a20000-0000-7000-8000-0000000000c1","scientific_name":"#
    + #""Amphiprion bicinctus","common_name":"Twoband anemonefish","rank":"Species","photo_sha256""#
    + #":"ab12","count":3,"abundance":null,"notes":""},{"uuid":"01a20000-0000-7000-8000-0000000000"#
    + #"c2","scientific_name":"Muraenidae","common_name":null,"rank":"Family","photo_sha256":null,"#
    + #""count":null,"abundance":"teeming","notes":"By the arch"}],"people":[{"person_uuid":"01a0e"#
    + #"2ed-1be1-7142-996d-0639721e344d","role":"buddy"},{"person_uuid":"01a0e2ed-1be2-7069-b3e3-7"#
    + #"ffb32797bd0","role":null}],"tags":["deep","wall"],"recordings":[{"cns_start":null,"cns_end"#
    + #"":14.0,"otu_start":null,"otu_end":37.0,"surface_pressure_bar":null,"uuid":"01a10217-4283-7"#
    + #"ce1-ab0b-90d3adfed77d","ordinal":0,"device":{"brand":"Suunto","model":"Suunto Ocean","seri"#
    + #"al":"000000000000","firmware":"2.51.28","name":"My Computer","dive_number":2},"mode":null,"#
    + #""deco_model":{"algorithm":null,"name":null,"gf_low":50,"gf_high":85,"conservatism":null},""#
    + #"salinity":null,"started_at":"2021-04-04T10:04:00.5+02:00","files":[{"uuid":"01a10217-4287-"#
    + #"7034-a4ca-c1053ac50c5b","original_filename":"6abfb404aa1098559eda5053.json","content_type""#
    + #":"application/json","byte_size":1299979,"parser_key":"suunto_json","updated_at":null},{"uu"#
    + #"id":"01a10219-28d8-75f7-b181-cbae4898e6e0","original_filename":"6abfb404aa1098559eda5053.f"#
    + #"it","content_type":"application/vnd.ant.fit","byte_size":26335,"parser_key":"fit","updated"#
    + #"_at":null}],"profile":{"uuid":"01a1295d-3b76-7a05-a6c7-7cac0a28b57f","duration":3544010,"d"#
    + #"epth_sample_count":359,"provenance":"file","channels":["depth","temperature","pressure","n"#
    + #"dl","tts","gradient_factor","surface_gradient_factor"],"event_count":1,"max_depth":23.41,""#
    + #"max_ceiling":3.2,"min_temperature":27.19,"max_temperature":28.62,"min_pressure":78.5,"max_"#
    + #"pressure":130.0,"updated_at":null},"updated_at":null},{"cns_start":8.0,"cns_end":9.0,"otu_"#
    + #"start":22.0,"otu_end":23.0,"surface_pressure_bar":1.013,"uuid":"01a20000-0000-7000-8000-00"#
    + #"00000000d2","ordinal":1,"device":{"brand":"Shearwater","model":"Perdix 2","serial":null,"f"#
    + #"irmware":null,"name":null,"dive_number":null},"mode":"closed_circuit","deco_model":{"algor"#
    + #"ithm":"buhlmann","name":"ZHL-16C","gf_low":30,"gf_high":70,"conservatism":-1},"salinity":""#
    + #"en13319","started_at":"2021-04-04T10:05:10","files":[],"profile":{"uuid":"01a20000-0000-70"#
    + #"00-8000-0000000000e2","duration":3544010,"depth_sample_count":359,"provenance":"divejson_i"#
    + #"mport","channels":["depth","ceiling","temperature","pressure","ndl","tts","ppo2","cns","gr"#
    + #"adient_factor","surface_gradient_factor"],"event_count":null,"max_depth":23.41,"max_ceilin"#
    + #"g":null,"min_temperature":27.19,"max_temperature":28.62,"min_pressure":78.5,"max_pressure""#
    + #":130.0,"updated_at":null},"updated_at":null}],"gas_use":{"gas_used":1800.0,"rmv":14.29,"sa"#
    + #"c_bar_per_min":null,"tanks":[{"gas_number":1,"gas_used":1680.0,"rmv":14.0,"sac_bar_per_min"#
    + #"":1.19,"seconds_on_gas":2355,"mean_depth":24.8}],"attributed_seconds":2355,"duration":2900"#
    + #"}}"#

  static let page =
    #"{"data":[{"uuid":"01a20000-0000-7000-8000-000000000001","entry_latitude":28.420546,"entry_"#
    + #"longitude":34.457623,"exit_latitude":28.420563,"exit_longitude":34.457658,"dive_number":21"#
    + #"2,"start_time":"2021-04-04T10:04:00.5+02:00","submerged_time":3243,"max_depth":23.41,"avg_"#
    + #"depth":13.62,"bottom_temperature":27.2,"visibility":30,"weight":6.0,"water_type":"lake","a"#
    + #"ltitude":372,"type":"semi_closed","rating":4,"air_temperature":24.0,"current":"light","wav"#
    + #"es":"calm","weather":"clear","entry_type":"boat","boat_name":"Legend","notes":"Two compute"#
    + #"rs, two tanks.","user_uuid":"01a0a51f-afe3-7363-a0bc-b0d634c35923","trip_uuid":null,"cours"#
    + #"e_uuid":null,"contact_uuid":null,"created_at":"2026-10-03T14:07:21.216050Z","dive_sites":["#
    + #"{"uuid":"01a20000-0000-7000-8000-0000000000a1","name":"Blue Hole","latitude":28.5722,"long"#
    + #"itude":34.5372,"location":{"name":"Dahab, Egypt","latitude":28.4963633,"longitude":34.5145"#
    + #"652,"bbox_south":null,"bbox_north":null,"bbox_west":null,"bbox_east":null}}],"gear_items":"#
    + #"[{"uuid":"01a20000-0000-7000-8000-0000000000b1","name":"Twinset","brand":"Faber","type":"c"#
    + #"ylinder","rented":false,"is_archived":false,"volume":12.0,"working_pressure":232.0,"materi"#
    + #"al":"steel"}],"tags":["deep","wall"],"depth_outline":{"span":3243,"values":[0,900,1800,230"#
    + #"0,2341,2000,1500,500,500,0]},"recording_count":2}],"total_count":1,"has_more":false,"page""#
    + #":1,"items_per_page":50}"#
}
