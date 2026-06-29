import SwiftUI

/// Generic List wired to a `PaginatedLoader`, handling loading / error / empty
/// states, pull-to-refresh and infinite scroll.
struct PagedListView<Element: Identifiable & Hashable, RowContent: View>: View {
    @Bindable var loader: PaginatedLoader<Element>
    let emptyTitle: String
    var emptyMessage: String?
    var emptyImage: String = "tray"
    @ViewBuilder let row: (Element) -> RowContent

    var body: some View {
        switch loader.phase {
        case .loading where loader.items.isEmpty:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message) where loader.items.isEmpty:
            MessageStateView(systemImage: "wifi.exclamationmark",
                             title: "Something went wrong",
                             message: message) {
                Task { await loader.reload() }
            }
        default:
            List {
                ForEach(loader.items) { item in
                    row(item)
                        .task { await loader.loadMoreIfNeeded(currentItem: item) }
                }
                if loader.isLoadingMore {
                    ProgressView().frame(maxWidth: .infinity).listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .refreshable { await loader.reload() }
            .overlay {
                if loader.items.isEmpty, loader.phase == .loaded {
                    MessageStateView(systemImage: emptyImage, title: emptyTitle, message: emptyMessage)
                }
            }
        }
    }
}
