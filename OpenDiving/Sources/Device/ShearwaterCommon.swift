@preconcurrency import Clibdivecomputer

// libdivecomputer's own Shearwater transfers, which no public call reaches at the pinned release.
// Declared here and nowhere else, with the C calling convention, against their prototypes in the
// pinned fork's `src/shearwater_common.h`; the device is the open `dc_device_t`, whose Petrel
// struct begins with the common one. Re-read those prototypes at every move of the libdc-swift
// pin: see DECISIONS.md, "The app walks the Perdix and the Ocean itself".

/// `shearwater_common_rdbi`: *read data by identifier*. With `actual` nil the answer must fill
/// `size` exactly; otherwise it may be shorter, and `actual` says how long it was.
@_extern(c, "shearwater_common_rdbi")
nonisolated func shearwaterCommonRDBI(
  _ device: OpaquePointer, _ id: UInt32, _ data: UnsafeMutablePointer<UInt8>, _ size: UInt32,
  _ actual: UnsafeMutablePointer<UInt32>?
) -> dc_status_t

/// `shearwater_common_download`: `size` bytes of the computer's memory from `address` into
/// `buffer`, LRE- and XOR-decompressed where `compression` is 1. A nil `progress` emits nothing.
@_extern(c, "shearwater_common_download")
nonisolated func shearwaterCommonDownload(
  _ device: OpaquePointer, _ buffer: OpaquePointer, _ address: UInt32, _ size: UInt32,
  _ compression: UInt32, _ progress: UnsafeMutablePointer<dc_event_progress_t>?
) -> dc_status_t
