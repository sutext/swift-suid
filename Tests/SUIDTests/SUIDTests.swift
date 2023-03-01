import XCTest
@testable import SUID

final class SUIDTests: XCTestCase {
    let uuids = NSMutableDictionary(capacity: 500000)
    let suids = NSMutableDictionary(capacity: 500000)
    let lock = NSLock()
    func testMultiThread() {
        printUUID()
        printSUID()
    }
    func printUUID(){
        let time = Date().timeIntervalSince1970
        let group = DispatchGroup()
        for i in 0..<500 {
            let queue = DispatchQueue.init(label: "\(i)")
            group.enter()
            queue.async {
                for _ in 0..<900 {
                    self.addUUID()
                }
                group.leave()
            }
        }
        group.wait()
        print("UUID Time(ms):",(Date().timeIntervalSince1970 - time)*1000)
//        XCTAssertEqual(uuids.count, 450000)
    }
    func printSUID(){
        let time = Date().timeIntervalSince1970
        let group = DispatchGroup()
        for i in 0..<500 {
            let queue = DispatchQueue.init(label: "\(i)")
            group.enter()
            queue.async {
                for _ in 0..<900 {
                    self.addSUID()
                }
                group.leave()
            }
        }
        group.wait()
        print("SUID Time(ms):",(Date().timeIntervalSince1970 - time)*1000)
        XCTAssertEqual(suids.count, 450000)
    }
    func addUUID() {
        let id = UUID()
        self.lock.lock()
        self.uuids.setObject("" as NSString, forKey: id.uuidString as NSString)
        self.lock.unlock()
    }
    func addSUID() {
        let id = SUID()
        self.lock.lock()
        self.suids.setObject("" as NSString, forKey: id.string as NSString)
        self.lock.unlock()
    }
    func testParams(){
        let qu = DispatchQueue(label: "11")
        for _ in 0..<1000{
            qu.async {
                print(SUID())
            }
        }
    }
    static var allTests = [
        ("testMultiThread", testMultiThread),
    ]
}
