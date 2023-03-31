import XCTest
@testable import SUID

final class SUIDTests: XCTestCase {
    var uuids:[String:String] = [:]
    var suids:[SUID:String] = [:]
    let mutex = NSLock()
    func testPrintUUID(){
        let time = Date().timeIntervalSince1970
        let group = DispatchGroup()
        for i in 0..<10 {
            let queue = DispatchQueue.init(label: "\(i)")
            group.enter()
            queue.async {
                for _ in 0..<26000 {
                    self.addUUID()
                }
                group.leave()
            }
        }
        group.wait()
        print("[UUID] Time(ms):",(Date().timeIntervalSince1970 - time)*1000)
        XCTAssertEqual(uuids.count, 260000)
    }
    func addUUID() {
        let id = UUID()
        self.mutex.lock()
        self.uuids[id.uuidString] = id.uuidString
        self.mutex.unlock()
    }
    func testPrintSUID(){
        let time = Date().timeIntervalSince1970
        let group = DispatchGroup()
        for i in 0..<10 {
            let queue = DispatchQueue.init(label: "\(i)")
            group.enter()
            queue.async {
                for _ in 0..<26000 {
                    self.addSUID()
                }
                group.leave()
            }
        }
        group.wait()
        print("[SUID] Time(ms):",(Date().timeIntervalSince1970 - time)*1000)
        XCTAssertEqual(suids.count, 260000)
    }
    func addSUID() {
        let id = SUID()
        self.mutex.lock()
        self.suids[id] = id.string
        self.mutex.unlock()
    }
    func testParams(){
        let qu = DispatchQueue(label: "11")
        for _ in 0..<1000{
            qu.async {
                debugPrint(SUID(.B))
            }
        }
    }
}
