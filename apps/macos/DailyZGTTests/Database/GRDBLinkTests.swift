import GRDB
import Testing

@Suite
struct GRDBLinkTests {
    @Test
    func readsFromAnInMemoryDatabase() throws {
        let queue = try DatabaseQueue()
        let value = try queue.read { database in
            try Int.fetchOne(database, sql: "select 1")
        }
        #expect(value == 1)
    }
}
