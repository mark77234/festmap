import Foundation
import Combine

@MainActor
class FestivalMapViewModel: ObservableObject {
    @Published var festivals: [Festival] = []
    @Published var selectedFestival: Festival? = nil
    @Published var isDetailLoading: Bool = false
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
        isDetailLoading = true

        Task {
            defer {
                Task { @MainActor in self.isDetailLoading = false }
            }

            do {
                if let detail = try await TourAPIService.shared.fetchFestivalDetail(contentId: festival.id) {
                    // 병합: 상세정보로 업데이트
                    let updated = Festival(
                        id: festival.id,
                        title: festival.title,
                        address: festival.address,
                        longitude: festival.longitude,
                        latitude: festival.latitude,
                        imageURL: detail.firstimage ?? festival.imageURL,
                        startDate: festival.startDate,
                        endDate: festival.endDate,
                        phone: detail.tel ?? festival.phone,
                        overview: detail.overview ?? festival.overview,
                        homepage: detail.homepage ?? festival.homepage
                    )
                    print("[ViewModel] fetched detail for id: \(festival.id) homepage:\(updated.homepage ?? "-") overviewPresent:\(updated.overview != nil)")
                    // 메인 스레드에서 바인딩 업데이트
                    await MainActor.run {
                        self.selectedFestival = updated
                    }
                }
            } catch {
                print("[ViewModel] fetchFestivalDetail error: \(error)")
            }
        }
    }

    func deselectFestival() {
        selectedFestival = nil
        isDetailLoading = false
    }
}
