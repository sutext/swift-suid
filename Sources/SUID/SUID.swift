//
//  SUID.swift
//
//
//  Created by supertext on 3/29/21.
//

import Foundation

/// Snowflake Unique Identifier
///
/// - See snowflake for more information
/// - The data structure: symbol(1)-plane(3)-time(34)-seq(18)-host(8)
/// - The machine code will read `SUID_HOST_ID` from environment firstly
/// - The machine code will read `SUID_HOST_IP` or ipaddr secondly and pick last part of ip
/// - The machine code will generate a random value of 10 bit at last
/// - Important The machine code algorithm  is not globally unique.
/// - Important The max date for SUID will be `2514-05-30 01:53:03 +0000`
/// - Important The maximum number of concurrent transactions is `262,143` per second. It will wait for next second automatically
///
public struct SUID : Codable,Hashable,Equatable,RawRepresentable{
    public let rawValue: Int64
    ///Init with Int64 value
    ///
    /// - Important You must verify this id before use it `see verify()`
    public init(rawValue: Int64){
        self.rawValue = rawValue
    }
    /// string value: encode with 16 radix.
    public var string:String { String(rawValue,radix: 16) }
    ///Init with hex string value
    ///
    /// - Important You must verify this id before use it `see verify()`
    public init<S:StringProtocol>(hex string:S){
        self.rawValue = Int64(string,radix: 16) ?? 0
    }
    /// Auto generate a  verified `SUID`instance
    ///
    /// - Parameter plane The logic plane. By default use `Plane.A`
    public init(_ plane:Plane = .A){
        self.rawValue = Builder.build(plane)
    }
    /// host number when generate
    public var host:Int64 {
        return rawValue&Builder.MASK_HOST
    }
    /// sequence number when generate
    public var seq:Int64 {
        return (rawValue>>Builder.LEN_HOST)&Builder.MASK_SEQ
    }
    /// timestamp when generate in seconds
    public var time:Int64 {
        return (rawValue>>(Builder.LEN_HOST+Builder.LEN_SEQ))&Builder.MASK_TIME
    }
    /// plane
    public var plane:Plane? {
        return Plane(rawValue: rawValue & Plane.G.rawValue)
    }
    /// Verify current id when  `.init(rawValue:)` and `.init(hex:)`
    public func verify()->Bool{
        guard let _ = self.plane else{
            return false
        }
        guard self.time > 1678204800 else{
            return false
        }
        return true
    }
}
extension SUID{
    /// The logic partition for SUID
    ///
    /// Only suport 7 plane. `A-G`. User can give them meaning freely
    ///
    public enum Plane :Int64, CaseIterable{
        case A = 0x1000_0000_0000_0000
        case B = 0x2000_0000_0000_0000
        case C = 0x3000_0000_0000_0000
        case D = 0x4000_0000_0000_0000
        case E = 0x5000_0000_0000_0000
        case F = 0x6000_0000_0000_0000
        case G = 0x7000_0000_0000_0000
    }
}
extension SUID:ExpressibleByIntegerLiteral{
    public init(integerLiteral value: Int64) {
        self.init(rawValue: value)
    }
}
extension SUID:CustomStringConvertible,CustomDebugStringConvertible{
    public var debugDescription: String {
        "SUID(value:\(rawValue),\nstring:\(string)),\nplane:\(plane ?? .A),\ntime:\(Date(timeIntervalSince1970: Double(time))),\nhost:\(host),\nseq:\(seq))\n"
    }
    public var description: String{
        "SUID(value:\(rawValue),string:\(string))\n"
    }
}
extension SUID{
    struct Builder {
        static let LEN_SEQ  :Int64 = { Int64(String(MASK_SEQ ,radix: 2).count) }()
        static let LEN_HOST :Int64 = { Int64(String(MASK_HOST,radix: 2).count) }()
        static let LEN_TIME :Int64 = { Int64(String(MASK_TIME,radix: 2).count) }()
        static let MASK_SEQ :Int64 = 0x3ffff
        static let MASK_HOST:Int64 = 0xff
        static let MASK_TIME:Int64 = 0x3ffffffff
        private static var seq:Int64        = 0
        private static var thisTime:Int64   = 0
        private static var zeroTime:Int64   = Int64(Date().timeIntervalSince1970)
        private static var mutex:os_unfair_lock_t = {
            var lock = os_unfair_lock_t.allocate(capacity: 1)
            lock.initialize(to: os_unfair_lock())
            return lock
        }()
        static func build(_ plane:Plane) -> Int64{
            os_unfair_lock_lock(mutex)
            defer {
                os_unfair_lock_unlock(mutex)
            }
            thisTime = Int64(Date().timeIntervalSince1970)
            if thisTime<zeroTime {
                fatalError("[SUID] Fatal Error!!! Host Clock moved backwards!")
            }
            if thisTime == zeroTime{
                seq = seq + 1
                if seq > MASK_SEQ{
                    thisTime = zeroTime+1
                    seq = 0
                    zeroTime = thisTime
                    // Wait for next seconds
                    print("[SUID] Force wait(ms):",(Double(thisTime) - Date().timeIntervalSince1970) * 1000)
                    Thread.sleep(until: Date(timeIntervalSince1970:Double(thisTime)))
                }
            }else{
                seq = 0
                zeroTime = thisTime
            }
            return plane.rawValue | (thisTime << (LEN_HOST + LEN_SEQ)) | (seq << LEN_HOST) | HOST_ID
        }
        private static let HOST_ID: Int64 = {
            let env = ProcessInfo.processInfo.environment
            if let str = (env["SUID_HOST_ID"] ?? ProcessInfo.processInfo.hostName)?.split(separator: "-").last,
               let num = Int64(str) {
                return num & MASK_HOST;
            }
            let ip = env["SUID_HOST_IP"] ?? iplist().first
            if let ary = ip?.split(separator: "."),ary.count == 4,
               let num = Int64(ary[3]){
                return num & MASK_HOST
            }
            return Int64(arc4random()) & MASK_HOST
        }()
        private static func iplist() -> [String] {
            var addresses = [String]()
            var ifaddr : UnsafeMutablePointer<ifaddrs>? = nil
            if getifaddrs(&ifaddr) == 0 {
                var ptr = ifaddr
                while ptr != nil {
                    let flags = Int32((ptr?.pointee.ifa_flags)!)
                    var addr = ptr?.pointee.ifa_addr.pointee
                    if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING),
                       addr?.sa_family == UInt8(AF_INET){
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if getnameinfo(&addr!,socklen_t((addr?.sa_len)!),
                                       &hostname,socklen_t(hostname.count),
                                       nil,socklen_t(0),NI_NUMERICHOST) == 0{
                            if let address = String(validatingUTF8: hostname) {
                                addresses.append(address)
                            }
                        }
                    }
                    ptr = ptr?.pointee.ifa_next
                }
                freeifaddrs(ifaddr)
            }
            return addresses
        }
    }
}

