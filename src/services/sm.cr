require "../kernel/svc"

struct ServiceManager
  def initialize(@session : Handle)
  end

  struct InitRequest < IpcCommand
    @reserved = 42u64
  end

  def init : Result
    req = IpcMessage.new
    req.send_pid
    req.pack(InitRequest.new(0))
    SVC.send_sync_request(@session)
  end

  struct GetServiceRequest < IpcCommand
    def initialize(@id : UInt64, @service_name : StaticArray(UInt8, 8))
    end
  end

  def get_service(handle : Handle*, service_name : String) : Result
    req = IpcMessage.new
    raw_service_name = StaticArray(UInt8, 8).new
    service_name_size = if service_name.bytesize.to_u64 > 8
                          8u64
                        else
                          service_name.bytesize.to_u64
                        end
    memcpy(raw_service_name.to_unsafe, service_name.to_unsafe, service_name_size)
    req.pack(GetServiceRequest.new(1, raw_service_name))
    res = SVC.send_sync_request(@session)
    if res == 0u32
      res = req.unpack.as(IpcRawResponse*).value
      return res.response_code.to_u32
    end
    res
  end

  def self.open : ServiceManager | Result
    session = uninitialized Handle
    res = SVC.connect_to_named_port(pointerof(session), "sm:")
    if res == 0
      sm = ServiceManager.new(session)
      tmp_session = uninitialized Handle
      # [3.0.1+] Checks if we have to init SM
      if (sm.get_service(pointerof(tmp_session), "") == 0x415)
        res = sm.init
        if res == 0
          return sm
        end
        return res
      end
      return sm
    end
    res
  end
end
