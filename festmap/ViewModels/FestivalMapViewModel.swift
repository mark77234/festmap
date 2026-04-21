import Foundation
import Combine

struct FestivalMapFocusRequest: Identifiable {
    let id = UUID()
    let festival: Festival
}

@MainActor
class FestivalMapViewModel: ObservableObject {
    @Published var festivals: [Festival] = []
    @Published var searchText: String = ""
    @Published var mapFocusRequest: FestivalMapFocusRequest? = nil
    @Published var selectedFestival: Festival? = nil
    @Published var isDetailLoading: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    var filteredFestivals: [Festival] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return festivals }

        return festivals.filter { festival in
            festival.title.localizedCaseInsensitiveContains(query) ||
            festival.address.localizedCaseInsensitiveContains(query)
        }
    }

    var searchSuggestions: [Festival] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return Array(filteredFestivals.prefix(12))
    }

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
            var introItem: TourAPIIntroItem? = nil
            var images: [String] = []

            do {
                detailItem = try await TourAPIService.shared.fetchFestivalDetail(contentId: festival.id)
            } catch {
                print("[ViewModel] fetchFestivalDetail error: \(error)")
            }

            do {
                introItem = try await TourAPIService.shared.fetchFestivalIntro(contentId: festival.id)
            } catch {
                print("[ViewModel] fetchFestivalIntro error: \(error)")
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
                eventStartDate: introItem?.eventstartdate ?? festival.eventStartDate ?? festival.startDate,
                eventEndDate: introItem?.eventenddate ?? festival.eventEndDate ?? festival.endDate,
                eventPlace: introItem?.eventplace,
                useTimeFestival: introItem?.usetimefestival,
                playTime: introItem?.playtime,
                sponsor1: introItem?.sponsor1,
                ageLimit: introItem?.agelimit,
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

    func requestMapFocus(to festival: Festival) {
        mapFocusRequest = FestivalMapFocusRequest(festival: festival)
    }
}
