import Foundation

// MARK: - Type Definitions

typealias dc_status_t = UInt32
typealias dc_family_t = UInt32
typealias dc_transport_t = UInt32

// Status codes
let DC_STATUS_SUCCESS: dc_status_t = 0
let DC_STATUS_UNSUPPORTED: dc_status_t = 1
let DC_STATUS_INVALIDARGS: dc_status_t = 2
let DC_STATUS_NOMEMORY: dc_status_t = 3
let DC_STATUS_NODEVICE: dc_status_t = 4
let DC_STATUS_NOACCESS: dc_status_t = 5
let DC_STATUS_IO: dc_status_t = 6
let DC_STATUS_TIMEOUT: dc_status_t = 7
let DC_STATUS_PROTOCOL: dc_status_t = 8
let DC_STATUS_DATAFORMAT: dc_status_t = 9
let DC_STATUS_CANCELLED: dc_status_t = 10

// Transport types
enum DCTransport: UInt32 {
    case NONE = 0
    case SERIAL = 1
    case USBHID = 2
    case USBS

TORAGE = 4
    case IRDA = 8
    case BLUETOOTH = 16
    case BLE = 32
    case USB = 64
}

let DC_TRANSPORT_NONE = DCTransport.NONE
let DC_TRANSPORT_SERIAL = DCTransport.SERIAL
let DC_TRANSPORT_USBHID = DCTransport.USBHID
let DC_TRANSPORT_USBSTORAGE = DCTransport.USBSTORAGE
let DC_TRANSPORT_IRDA = DCTransport.IRDA
let DC_TRANSPORT_BLUETOOTH = DCTransport.BLUETOOTH
let DC_TRANSPORT_BLE = DCTransport.BLE
let DC_TRANSPORT_USB = DCTransport.USB

// MARK: - Custom I/O Callbacks

typealias dc_custom_io_t = OpaquePointer

struct dc_custom_cbs_t {
    var userdata: UnsafeMutableRawPointer?
    var set_timeout: (@convention(c) (OpaquePointer?, Int32, UnsafeMutableRawPointer?) -> dc_status_t)?
    var read: (@convention(c) (OpaquePointer?, UnsafeMutableRawPointer?, Int, UnsafeMutablePointer<Int>?, UnsafeMutableRawPointer?) -> dc_status_t)?
    var write: (@convention(c) (OpaquePointer?, UnsafeRawPointer?, Int, UnsafeMutablePointer<Int>?, UnsafeMutableRawPointer?) -> dc_status_t)?
    var close: (@convention(c) (OpaquePointer?, UnsafeMutableRawPointer?) -> dc_status_t)?
    var get_available: (@convention(c) (OpaquePointer?, UnsafeMutablePointer<Int>?, UnsafeMutableRawPointer?) -> dc_status_t)?
}

// MARK: - Function Declarations

// Note: These are placeholder declarations. The actual functions will be linked from libdivecomputer.xcframework
// In a real implementation, these would be properly imported from the C library headers

@_silgen_name("dc_version")
func dc_version(_ version: UnsafeMutablePointer<CChar>?) -> UnsafePointer<CChar>

@_silgen_name("dc_context_new")
func dc_context_new(_ context: UnsafeMutablePointer<OpaquePointer?>) -> dc_status_t

@_silgen_name("dc_context_free")
func dc_context_free(_ context: OpaquePointer?)

@_silgen_name("dc_descriptor_iterator")
func dc_descriptor_iterator(_ iterator: UnsafeMutablePointer<OpaquePointer?>) -> dc_status_t

@_silgen_name("dc_descriptor_iterator_next")
func dc_descriptor_iterator_next(_ iterator: OpaquePointer?, _ descriptor: UnsafeMutablePointer<OpaquePointer?>) -> dc_status_t

@_silgen_name("dc_descriptor_iterator_free")
func dc_descriptor_iterator_free(_ iterator: OpaquePointer?)

@_silgen_name("dc_descriptor_get_vendor")
func dc_descriptor_get_vendor(_ descriptor: OpaquePointer?) -> UnsafePointer<CChar>

@_silgen_name("dc_descriptor_get_product")
func dc_descriptor_get_product(_ descriptor: OpaquePointer?) -> UnsafePointer<CChar>

@_silgen_name("dc_descriptor_get_model")
func dc_descriptor_get_model(_ descriptor: OpaquePointer?) -> UInt32

@_silgen_name("dc_descriptor_get_transports")
func dc_descriptor_get_transports(_ descriptor: OpaquePointer?) -> UInt32

@_silgen_name("dc_descriptor_free")
func dc_descriptor_free(_ descriptor: OpaquePointer?)

@_silgen_name("dc_custom_open")
func dc_custom_open(
    _ iostream: UnsafeMutablePointer<OpaquePointer?>,
    _ context: OpaquePointer?,
    _ transport: dc_transport_t,
    _ callbacks: UnsafeMutablePointer<dc_custom_cbs_t>
) -> dc_status_t

@_silgen_name("dc_iostream_close")
func dc_iostream_close(_ iostream: OpaquePointer?) -> dc_status_t

@_silgen_name("dc_device_open")
func dc_device_open(
    _ device: UnsafeMutablePointer<OpaquePointer?>,
    _ context: OpaquePointer?,
    _ descriptor: OpaquePointer?,
    _ iostream: OpaquePointer?
) -> dc_status_t

@_silgen_name("dc_device_close")
func dc_device_close(_ device: OpaquePointer?) -> dc_status_t

@_silgen_name("dc_device_foreach")
func dc_device_foreach(
    _ device: OpaquePointer?,
    _ callback: @convention(c) (UnsafePointer<UInt8>?, Int, UnsafePointer<UInt8>?, Int, UnsafeMutableRawPointer?) -> Int32,
    _ userdata: UnsafeMutableRawPointer?
) -> dc_status_t
