module SVC
  def self.connect_to_named_port(session : Handle*, name : String) : Result
    res = uninitialized Result
    handle = uninitialized Handle
    asm("svc 0x1F" : "={w0}"(res), "={w1}"(handle) : "{x1}"(name.to_unsafe) :: "volatile")
    session.value = handle
    res
  end

  def self.send_sync_request(session : Handle) : UInt32
    res = uninitialized UInt32
    asm("svc 0x21" : "={w0}"(res) : "{x0}"(session))
    res
  end

  def self.break(reason : UInt64, unknown : UInt64, info : UInt64)
    res = uninitialized UInt32
    asm("svc 0x26" : "=w0"(res) : "x0"(reason), "x1"(unknown), "x2"(info))
    res
  end

  def self.exit_process(return_code : Int32) : NoReturn
    asm("svc 0x7" :: "x0"(return_code) :: "volatile")
    while true
    end
  end

  def self.output_debug_string(string : UInt8*, string_size : UInt64) : UInt32
    res = uninitialized UInt32
    asm("svc 0x27" : "=w0"(res) : "x0"(string), "x1"(string_size))
    res
  end

  def self.return_from_exception(error_code : UInt64) : NoReturn
    asm("svc 0x28" :: "x0"(error_code))
    while true
    end
  end

  def self.output_debug_string(string : String)
    output_debug_string(string.to_unsafe, string.bytesize.to_u64)
  end

  def self.output_debug_string(value : Int, base)
    value.internal_to_s(base, false) do |ptr, count|
      output_debug_string(ptr, count.to_u64)
    end
  end
end
