import wasmrt

type
  Region = object
    offset: ptr byte
    capacity: uint32
    length: uint32
  RegionRef = ref Region

when defined(debug):
  proc debug(source_ptr: RegionRef) {.importc.}
else:
  proc debug(source_ptr: RegionRef) = discard

proc newRegion*(data: seq[byte]): RegionRef =
  var
    buf = create(byte, data.len)
    buf_data = cast[ptr UncheckedArray[byte]](buf)
  
  for i in 0..<data.len:
    buf_data[i] = data[i]

  result = RegionRef()
  result.offset = buf
  result.capacity = uint32(data.len)
  result.length = uint32(data.len)

proc debug*(msg: seq[byte]) =
  let
    region = newRegion(msg)
  
  debug(region)

proc debug*(msg: string) =
  var
    buf = newSeq[byte](msg.len)
        
  for i in 0..<msg.len:
    buf[i] = byte(msg[i])
  
  debug(buf)

proc newRegion*(data: string): RegionRef =
  var
    buf = newSeq[byte](data.len)
  
  for i in 0..<data.len:
    buf[i] = data[i].byte
    
  newRegion(buf)

proc newRegioOfCap*(capacity: uint32): RegionRef =
  var
    data = newSeq[byte](capacity)
  newRegion(data)


proc consume*(region: RegionRef): seq[byte] =
  result = newSeq[byte](region.length)

  let
    data = cast[ptr UncheckedArray[byte]](region.offset)

  for i in 0..<region.length:
    result[i] = data[i]

proc interface_version_8() {.exportwasm.} = discard

proc allocate_internal(size: uint32): RegionRef {.inline.} =
    result = newRegioOfCap(size)
    GC_ref(result)
    
proc allocate*(size: uint32): RegionRef {.exportwasm.} =
  allocate_internal(size)

proc deallocate_internal(region: RegionRef) {.inline.} =
  GC_unref(region)
  dealloc(region.offset)
  discard consume(region)

proc deallocate*(region: RegionRef) {.exportwasm.} =
    deallocate_internal(region)


proc instantiate_internal(env_ptr: RegionRef, info_ptr: RegionRef, msg_ptr: RegionRef): RegionRef =
  let 
    env = consume(env_ptr)
    info = consume(info_ptr)
    msg = consume(msg_ptr)
  
  debug(env)
  debug(info)
  debug(msg)
  
  newRegion("{\"Ok\":{\"messages\":[],\"attributes\":[],\"events\":[],\"data\":null}}")

proc instantiate*(ptr0: RegionRef, ptr1: RegionRef, ptr2: RegionRef): RegionRef {.exportwasm.} =
  instantiate_internal(ptr0, ptr1, ptr2)

proc execute_internal(env_ptr: RegionRef, info_ptr: RegionRef, msg_ptr: RegionRef): RegionRef =
  let 
    env = consume(env_ptr)
    info = consume(info_ptr)
    msg = consume(msg_ptr)

  debug(env)
  debug(info)
  debug(msg)
  
  newRegion("{\"Ok\":{\"messages\":[],\"attributes\":[],\"events\":[],\"data\":null}}")

proc execute*(ptr0: RegionRef, ptr1: RegionRef, ptr2: RegionRef): RegionRef {.exportwasm.} =
  execute_internal(ptr0, ptr1, ptr2)

proc query_internal(env_ptr: RegionRef, msg_ptr: RegionRef): RegionRef =
  let 
    env = consume(env_ptr)
    msg = consume(msg_ptr)
  
  debug(env)
  debug(msg)

  newRegion("{\"ok\":\"SGVsbG8gZnJvbSBOaW0h\"}")

proc query*(ptr0: RegionRef, ptr1: RegionRef): RegionRef {.exportwasm.} =
  query_internal(ptr0, ptr1) 
