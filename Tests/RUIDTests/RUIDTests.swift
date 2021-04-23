import XCTest
@testable import RUID

final class RUIDTests: XCTestCase {
    let ids = NSMutableDictionary(capacity: 20000)
    let lock = NSLock()
    var counter = 0
    func testMultiThread() {
        let group = DispatchGroup()
        for i in 0..<500 {
            let queue = DispatchQueue.init(label: "\(i)")
            group.enter()
            queue.async {
                for _ in 0..<30 {
                    self.addKey(key: RUID.create())
                }
                group.leave()
            }
        }
        group.wait()
        print(counter)
        XCTAssertEqual(ids.count, 15000)
    }
    func addKey(key:RUID) {
        self.lock.lock()
        self.counter+=1
        self.ids.setObject("" as NSString, forKey: key.description as NSString)
        self.lock.unlock()
    }
    static var allTests = [
        ("testMultiThread", testMultiThread),
    ]
}
