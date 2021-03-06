require "primitives"
require "../internal/external_types"
require "intrinsics"

require "../kernel/svc"
require "../kernel/ipc"
require "../types"
require "../internal/utils"
require "./environment"
require "./tls"
require "./allocator"

lib LibCrystalMain
  @[Raises]
  fun __crystal_main(argc : Int32, argv : UInt8**)
end

def clean_bss(start_bss, end_bss)
  until start_bss.address == end_bss.address
    start_bss.value = 0
    start_bss += 1
  end
end

# TODO: support all sort of relocation
def relocate(base, dynamic_section) : UInt64
  rela_offset = 0_u64
  rela_size = 0_u64
  rela_ent = 0_u64
  rela_count = 0_u64
  until dynamic_section.value.tag == 0_u64
    case dynamic_section.value.tag
    when 0x7_u64 # DT_RELA
      rela_offset = dynamic_section.value.un.value
    when 0x8_u64 # DT_RELASZ
      rela_size = dynamic_section.value.un.value
    when 0x9_u64 # DT_RELAENT
      rela_ent = dynamic_section.value.un.value
    when 0x6ffffff9_u64 # DT_RELACOUNT
      rela_count = dynamic_section.value.un.value
    end
    dynamic_section += 1
  end

  if rela_ent != 0x18 || rela_size != rela_ent * rela_count
    return 0xBEEF_u64
  end

  rela_base = Pointer(Elf::RelA).new(base + rela_offset)

  i = 0_i64
  rela_count.times do |i|
    rela = rela_base[i]

    case rela.reloc_type
    when 0x403_u32 # R_AARCH64_RELATIVE

      # TODO: supports symbol
      if rela.symbol != 0
        return 0x4243_u64
      end
      Pointer(Pointer(Void)).new(base + rela.offset).value = Pointer(Void).new(base + rela.addend)
    else
      return 0x4242_u64
    end
    i += 1
  end
  0_u64
end

def nx_init(loader_config, main_thread_handle, base, dynamic_section) : UInt64
  res = relocate(base, dynamic_section)
  if res != 0
    return res
  end

  res = Environment.init(loader_config.as(LoaderConfigEntry*), main_thread_handle)

  if res != 0
    return res
  end

  heap_init_res = Cryloc::HeapManager.init
  if heap_init_res != 0
    return heap_init_res.to_u64
  end

  # TODO: official argument parsing

  # TODO: kernel version detection
  res
end

module ReturnValue
  @@return_value = 0u64

  def self.return_value=(return_value : UInt64)
    @@return_value = return_value
  end

  def self.return_value
    @@return_value
  end
end

fun __crystal_nx_entrypoint(loader_config : Void*, main_thread_handle : Handle, base : UInt64, dynamic_section : Elf::Dyn*, bss_start : UInt64*, bss_end : UInt64*, loader_return_address : Void**) : UInt64
  clean_bss(bss_start, bss_end)

  # no previous LR so we are not running under the homebrew loader
  if loader_return_address.value.address == 0
    loader_return_address.value = ->SVC.exit_process(Int32).pointer
  end

  res = nx_init(loader_config, main_thread_handle, base, dynamic_section)
  if res != 0
    SVC.output_debug_string "Error:"
    SVC.output_debug_string res, 16
    return res
  end
  LibCrystalMain.__crystal_main(0, nil)
  ReturnValue.return_value
end
