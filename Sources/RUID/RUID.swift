//
//  RUID.swift
//
//
//  Created by supertext on 3/29/21.
//

import Foundation.NSLock

/// Random Unique Identifier
///
/// - See snowflake for more information
/// - The data structure: symbol(1)-plane(3)-time(42)-host(8)-seq(10)
/// - The machine code will read `RUID_HOST_ID` from environment firstly
/// - The machine code will read `RUID_HOST_IP` or ipaddr secondly and pick last part of ip
/// - The machine code will generate a random value of 10 bit at last
///
public struct RUID : Codable,Hashable,Equatable,RawRepresentable{
    /// The logic partition for RUID
    ///
    /// Only suport 7 plane. `A-G`. User can give them meaning freely
    ///
    public enum Plane :Int{
        case A = 0x1000_0000_0000_0000
        case B = 0x2000_0000_0000_0000
        case C = 0x3000_0000_0000_0000
        case D = 0x4000_0000_0000_0000
        case E = 0x5000_0000_0000_0000
        case F = 0x6000_0000_0000_0000
        case G = 0x7000_0000_0000_0000
        public static let `default` = Plane.A
    }
    public var rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    /// raw string value: encode with 16 radix.
    public var strValue:String { String(rawValue,radix: 16) }
    /// init with string value
    public init?<S:StringProtocol>(strValue:S){
        guard let value = Int(strValue,radix: 16) else{
            return nil
        }
        self.rawValue = value
    }
    /// sequence number when generate
    public var seq:Int {
        return rawValue&Builder.MASK_SEQ
    }
    /// host number when generate
    public var host:Int {
        return (rawValue>>Builder.LEN_SEQ)&Builder.MASK_HOST
    }
    /// timestamp when generate
    public var time:Int {
        return (rawValue>>(Builder.LEN_HOST+Builder.LEN_SEQ))&Builder.MASK_TIME
    }
    /// ID plane
    public var plane:Plane? {
        return Plane(rawValue: rawValue & Plane.G.rawValue)
    }
    
    private static let mutex = NSLock()
    private static var builders:[String:Builder] = [:]
    private static func builder(for name:String) -> Builder {
        if let ins = builders[name] {
            return ins
        }
        let ins = Builder()
        builders[name] = ins
        return ins
    }
    ///
    /// Create an RUID instance
    ///
    /// - Parameter group: RUID Generator group. RUID will keep monotone increasing and unique in same group. It maybe a database table name mostly!
    /// - Parameter plane: RUID Logic plane.
    ///
    public static func create(_ group:String = "default",plane:Plane = .default)->RUID{
        mutex.lock()
        defer {
            mutex.unlock()
        }
        return RUID.builder(for: group).build(plane)
    }
}
extension RUID:ExpressibleByIntegerLiteral{
    public init(integerLiteral value: Int) {
        self.init(rawValue: value)
    }
}
extension RUID:CustomStringConvertible{
    public var description: String{
        return self.strValue
    }
}
extension RUID{
    fileprivate class Builder {
        static let MASK_SEQ :Int = 0x3ff
        static let MASK_HOST:Int = 0xff
        static let MASK_TIME:Int = 0x3ffffffffff
        static let LEN_SEQ:Int   = {
            return String(MASK_SEQ ,radix: 2).count
        }()
        static let LEN_HOST:Int  = {
            return String(MASK_HOST,radix: 2).count
        }()
        static let LEN_TIME:Int  = {
            return String(MASK_TIME,radix: 2).count
        }()
        private var seq:Int = 0
        private var thisTime:Int = 0
        private var zeroTime:Int = 0
        fileprivate func build(_ plane:Plane) -> RUID{
            thisTime = Int(Date().timeIntervalSince1970*1000)
            if zeroTime == 0 {
                zeroTime = thisTime
            }
            seq = seq + 1
            if seq > Self.MASK_SEQ {
                seq = 0
                if thisTime<zeroTime {
                    fatalError("Warning!!! Clock moved backwards!")
                }else if thisTime == zeroTime{
                    thisTime = nextTime()
                }
                zeroTime = thisTime
            }
            let value =
                plane.rawValue |
                (thisTime << (Self.LEN_HOST + Self.LEN_SEQ)) |
                (Self.HOST_ID << Self.LEN_SEQ) | seq
            return RUID(rawValue: value)
        }
        private func nextTime()->Int{
            var now = Int(Date().timeIntervalSince1970*1000)
            while now <= zeroTime {
                now = Int(Date().timeIntervalSince1970*1000)
            }
            return now
        }
        private static let HOST_ID: Int = {
            let env = ProcessInfo.processInfo.environment
            if let str = env["RUID_HOST_ID"]?.split(separator: "-").last,
               let num = Int(str) {
                return num & MASK_HOST;
            }
            let ip = env["RUID_HOST_IP"] ?? iplist().first
            if let ary = ip?.split(separator: "."),ary.count == 4,
               let num = Int(ary[3]){
                return num & MASK_HOST
            }
            if let host = ProcessInfo.processInfo.hostName.split(separator: "-").last{
                return Int(host.hash) & MASK_HOST
            }
            return Int(arc4random()) & MASK_HOST
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

