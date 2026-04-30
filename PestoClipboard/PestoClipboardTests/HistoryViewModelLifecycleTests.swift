import Testing
import Foundation
@testable import Pesto_Clipboard

@MainActor
struct HistoryViewModelLifecycleTests {

    func createSetup() -> (ClipboardHistoryManager, ClipboardMonitor, HistoryViewModel) {
        let persistenceController = PersistenceController(inMemory: true)
        let manager = ClipboardHistoryManager(persistenceController: persistenceController, maxItems: 100)
        let monitor = ClipboardMonitor(historyManager: manager)
        let viewModel = HistoryViewModel(historyManager: manager, clipboardMonitor: monitor)
        return (manager, monitor, viewModel)
    }

    func waitForSearchDebounce() async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
    }

    @Test func onPanelHideClearsSearchResetsSelectionAndRestoresFullHistory() async throws {
        let (manager, _, viewModel) = createSetup()

        manager.addTextItem("Apple")
        manager.addTextItem("Banana")
        manager.addTextItem("Apricot")

        viewModel.selectedIndex = 2
        viewModel.searchText = "Ap"
        try await waitForSearchDebounce()

        #expect(viewModel.filteredItems.count == 2)
        #expect(viewModel.selectedIndex == -1)

        viewModel.onPanelHide()
        try await waitForSearchDebounce()

        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.selectedIndex == 0)
        #expect(viewModel.filteredItems.count == 3)
    }

    @Test func onPanelShowReappliesSearchWhenBackingStoreWasReset() async throws {
        let (manager, _, viewModel) = createSetup()

        manager.addTextItem("Apple")
        manager.addTextItem("Banana")
        manager.addTextItem("Apricot")

        viewModel.searchText = "Ap"
        try await waitForSearchDebounce()
        #expect(viewModel.filteredItems.count == 2)

        manager.fetchItems()
        #expect(viewModel.filteredItems.count == 3)

        viewModel.onPanelShow()

        #expect(viewModel.filteredItems.count == 2)
        #expect(viewModel.filteredItems.allSatisfy { item in
            item.textContent?.contains("Ap") == true
        })
    }
}
