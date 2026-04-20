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

            var detailItem: TourAPIDetailItem? = nil
            var images: [String] = []

            do {
                detailItem = try await TourAPIService.shared.fetchFestivalDetail(contentId: festival.id)
            } catch {
                print("[ViewModel] fetchFestivalDetail error: \(error)")
            }

            do {
                images = try await TourAPIService.shared.fetchFestivalImages(contentId: festival.id)
            } catch {
                print("[ViewModel] fetchFestivalImages error: \(error)")
            }

            // 병합: 상세정보 및 이미지 컬렉션
            let combinedImageURLs: [String]? = {
                if !images.isEmpty { return images }
                if let first = detailItem?.firstimage, !first.trimmingCharacters(in: .whitespaces).isEmpty { return [first] }
                return nil
            }()

            let updated = Festival(
                id: festival.id,
                title: festival.title,
                address: festival.address,
                longitude: festival.longitude,
                latitude: festival.latitude,
                imageURL: detailItem?.firstimage ?? festival.imageURL,
                startDate: festival.startDate,
                endDate: festival.endDate,
                phone: detailItem?.tel ?? festival.phone,
                overview: detailItem?.overview ?? festival.overview,
                homepage: detailItem?.homepage ?? festival.homepage,
                imageURLs: combinedImageURLs
            )

            print("[ViewModel] fetched detail for id: \(festival.id) homepage:\(updated.homepage ?? "-") overviewPresent:\(updated.overview != nil) images:\(updated.imageURLs?.count ?? 0)")

            await MainActor.run {
                self.selectedFestival = updated
            }
        }
    }

    func deselectFestival() {
        selectedFestival = nil
        isDetailLoading = false
    }
}
