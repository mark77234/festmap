import Foundation
import Combine

@MainActor
class FestivalMapViewModel: ObservableObject {
    @Published var festivals: [Festival] = []
    @Published var selectedFestival: Festival? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    func fetchFestivals() async {
        isLoading = true
        errorMessage = nil
        do {
            festivals = try await TourAPIService.shared.fetchFestivals()
        } catch {
            errorMessage = "오류: \(error.localizedDescription)"
            print("[ViewModel] fetchFestivals error: \(error)")
        }
        isLoading = false
    }

    func selectFestival(_ festival: Festival) {
        selectedFestival = festival
    }

    func deselectFestival() {
        selectedFestival = nil
    }
}
