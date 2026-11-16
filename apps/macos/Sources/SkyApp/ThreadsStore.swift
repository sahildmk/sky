import Foundation
import Observation
import SkyCore
import SwiftUI

/// The open threads from the Sky service, kept up to date while the shelf is showing.
@MainActor
@Observable
final class ThreadsStore {
    enum Availability: Equatable {
        /// Not asked yet.
        case unknown
        case available
        /// The service didn't answer, so the threads shown may be out of date.
        case unavailable
    }

    private(set) var threads: [SkyThread] = []
    private(set) var availability: Availability = .unknown

    /// Whether the service has ever answered on this Mac. Until it has, an
    /// unanswered request is not worth mentioning: most people never run it.
    var hasEverConnected: Bool {
        get { UserDefaults.standard.bool(forKey: "threadsServiceSeen") }
        set { UserDefaults.standard.set(newValue, forKey: "threadsServiceSeen") }
    }

    @ObservationIgnored private let client: SkyServiceClient?
    @ObservationIgnored private var polling: Task<Void, Never>?

    init(client: SkyServiceClient) {
        self.client = client
    }

    /// Fixed threads, for rendering snapshots. Nothing is fetched.
    init(threads: [SkyThread]) {
        client = nil
        self.threads = threads
        availability = .available
    }

    func refresh() async {
        guard let client else { return }
        do {
            let latest = try await client.openThreads()
            availability = .available
            hasEverConnected = true
            if latest != threads {
                withAnimation(Motion.rearrange) { threads = latest }
            }
        } catch {
            availability = .unavailable
        }
    }

    /// Refreshes now and then every few seconds, until `stopPolling`.
    func startPolling() {
        guard polling == nil, client != nil else { return }
        polling = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(4))
            }
        }
    }

    func stopPolling() {
        polling?.cancel()
        polling = nil
    }

    func detail(for id: String) async throws(SkyServiceError) -> SkyThreadDetail {
        guard let client else { throw .unreachable }
        return try await client.thread(id: id)
    }

    /// Resolves or reopens a thread. A resolved thread leaves the shelf.
    func setResolved(_ resolved: Bool, threadID: String) async throws(SkyServiceError) -> SkyThread {
        guard let client else { throw .unreachable }
        let updated = try await client.setResolved(resolved, threadID: threadID)
        await refresh()
        return updated
    }
}
