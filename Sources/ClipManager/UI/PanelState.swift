import Foundation

// MARK: - PanelState
// The panel window is reused (only ordered out on close), so SwiftUI's onAppear runs once.
// The view observes `openID` to reset selection, scroll position and focus on every open.

final class PanelState: ObservableObject {
    @Published private(set) var openID = UUID()

    func didOpen() {
        openID = UUID()
    }
}
