import Foundation
import Observation

/// Drives infinite-scroll lists backed by a `Page`-returning API call.
@Observable
@MainActor
final class PaginatedLoader<Element: Identifiable & Hashable> {
    enum Phase: Equatable {
        case idle, loading, loaded, failed(String)
    }

    private(set) var items: [Element] = []
    private(set) var phase: Phase = .idle
    private(set) var isLoadingMore = false

    private var nextPage: Int? = 1
    private let fetch: (Int) async throws -> Page<Element>

    /// - Parameter fetch: closure that, given a page number, returns a page.
    init(fetch: @escaping (Int) async throws -> Page<Element>) {
        self.fetch = fetch
    }

    var canLoadMore: Bool { nextPage != nil }

    func reload() async {
        nextPage = 1
        phase = items.isEmpty ? .loading : phase
        await load(replacing: true)
    }

    func loadFirstIfNeeded() async {
        guard items.isEmpty, phase == .idle else { return }
        phase = .loading
        await load(replacing: true)
    }

    func loadMoreIfNeeded(currentItem: Element) async {
        guard let last = items.last, last.id == currentItem.id else { return }
        guard canLoadMore, !isLoadingMore, phase != .loading else { return }
        isLoadingMore = true
        await load(replacing: false)
        isLoadingMore = false
    }

    private func load(replacing: Bool) async {
        guard let page = nextPage else { return }
        do {
            let result = try await fetch(page)
            if replacing {
                items = result.items
            } else {
                let existing = Set(items.map(\.id))
                items.append(contentsOf: result.items.filter { !existing.contains($0.id) })
            }
            nextPage = result.nextPage
            phase = .loaded
        } catch let error as APIError {
            phase = .failed(error.errorDescription ?? "Something went wrong.")
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
