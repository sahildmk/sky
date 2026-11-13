import Foundation
import Testing
@testable import SkyCore

/// Reading the JSON the Sky service sends.
@Suite struct SkyThreadDecodingTests {
    @Test func aThreadWithItsMessagesDecodes() throws {
        let json = Data("""
        {
          "id": "t1", "title": "Factory runs", "summary": "Stuck in **queued**.",
          "createdAt": "2026-11-10T09:00:00.000Z", "updatedAt": "2026-11-10T15:00:00.000Z",
          "resolvedAt": null,
          "messages": [
            {"id": "m1", "threadId": "t1", "createdAt": "2026-11-10T09:00:00.000Z", "body": "[Original](https://example.com)"},
            {"id": "m2", "threadId": "t1", "createdAt": "2026-11-10T12:00:00.250Z", "body": "Fixed."}
          ]
        }
        """.utf8)

        let detail = try SkyServiceClient.decoder.decode(SkyThreadDetail.self, from: json)

        #expect(detail.thread.title == "Factory runs")
        #expect(!detail.thread.isResolved)
        #expect(detail.thread.updatedAt.timeIntervalSince(detail.thread.createdAt) == 6 * 3600)
        #expect(detail.messages.map(\.body) == ["[Original](https://example.com)", "Fixed."])
        #expect(detail.messages[1].createdAt.timeIntervalSince(detail.thread.createdAt) == 3 * 3600 + 0.25)
    }

    @Test func aResolvedThreadKnowsWhen() throws {
        let json = Data("""
        [{"id": "t2", "title": "Done", "summary": "", "createdAt": "2026-11-01T09:00:00.000Z",
          "updatedAt": "2026-11-02T09:00:00.000Z", "resolvedAt": "2026-11-02T09:00:00.000Z"}]
        """.utf8)

        let threads = try SkyServiceClient.decoder.decode([SkyThread].self, from: json)

        #expect(threads.count == 1)
        #expect(threads[0].isResolved)
        #expect(threads[0].resolvedAt == threads[0].updatedAt)
    }

    @Test func aMalformedDateIsAnError() {
        let json = Data("""
        {"id": "t3", "title": "x", "summary": "", "createdAt": "yesterday",
         "updatedAt": "2026-11-02T09:00:00.000Z", "resolvedAt": null}
        """.utf8)

        #expect(throws: DecodingError.self) { try SkyServiceClient.decoder.decode(SkyThread.self, from: json) }
    }

    @Test func theServiceAddressCanBeOverridden() {
        #expect(SkyServiceClient.fromEnvironment([:]).baseURL == SkyServiceClient.defaultBaseURL)
        #expect(SkyServiceClient.fromEnvironment(["SKY_SERVICE_URL": "http://127.0.0.1:5050"]).baseURL.port == 5050)
    }
}
