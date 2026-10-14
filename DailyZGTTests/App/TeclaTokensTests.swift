import CryptoKit
import Foundation
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct TeclaTokensTests {
    private func resource(_ name: String, _ type: String) throws -> Data {
        let bundle = Bundle(for: TestClock.self)
        let url = try #require(bundle.url(forResource: name, withExtension: type), "\(name).\(type)")
        return try Data(contentsOf: url)
    }

    private func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    @Test
    func theTokenFileComesFromTheJSONOfThisBuild() throws {
        #expect(TeclaTokens.sourceDigest == digest(try resource("tecla", "json")))
    }

    @Test
    func noHandEditChangedTheTokenFile() throws {
        let text = String(decoding: try resource("TeclaTokens", "swift"), as: UTF8.self)
        let lines = text.components(separatedBy: "\n").filter { !$0.contains("static let outputDigest = ") }
        let body = Data(lines.joined(separator: "\n").utf8)

        #expect(lines.count == text.components(separatedBy: "\n").count - 1)
        #expect(TeclaTokens.outputDigest == digest(body))
    }

    @Test
    func theTokenFileHasTheValuesOfTheJSON() throws {
        let json = try #require(try JSONSerialization.jsonObject(with: try resource("tecla", "json")) as? [String: Any])
        let panel = try #require(json["panel"] as? [String: [String: Any]])
        let radius = try #require(json["radius"] as? [String: Double])
        let duration = try #require(json["duration"] as? [String: Double])
        let fonts = try #require(json["font"] as? [String: [String: Any]])

        func hex(_ color: TeclaColor) -> String {
            String(format: "#%06x", color.hex)
        }

        #expect(panel["bg"]?["hex"] as? String == hex(TeclaTokens.Panel.bg))
        #expect(panel["accent"]?["hex"] as? String == hex(TeclaTokens.Panel.accent))
        #expect(panel["hl"]?["hex"] as? String == hex(TeclaTokens.Panel.hl))
        #expect(panel["hl"]?["alpha"] as? Double == TeclaTokens.Panel.hl.alpha)
        #expect(radius["panel"] == Double(TeclaTokens.Radius.panel))
        #expect(radius["checkbox"] == Double(TeclaTokens.Radius.checkbox))
        #expect(duration["undo"] == TeclaTokens.Durations.undo)
        #expect(fonts["text"]?["family"] as? String == TeclaTokens.Fonts.text.family)
        #expect(fonts["text"]?["file"] as? String == TeclaTokens.Fonts.text.file)
        #expect(json["name"] as? String == TeclaTokens.name)
    }
}
