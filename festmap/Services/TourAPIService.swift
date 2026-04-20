import Foundation

class TourAPIService {
    static let shared = TourAPIService()
    private init() {}

    func fetchFestivals() async throws -> [Festival] {
        let baseURL = "https://apis.data.go.kr/B551011/KorService2/searchFestival2"
        let today = dateString(from: Date())
        let future = dateString(from: Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date())

        // +, /, = 를 %2B, %2F, %3D 로 인코딩 (URLComponents는 + 를 인코딩 안 함)
        var safeChars = CharacterSet.alphanumerics
        safeChars.insert(charactersIn: "-._~")
        let encodedKey = Config.tourAPIKey
            .addingPercentEncoding(withAllowedCharacters: safeChars) ?? Config.tourAPIKey

        let queryString = [
            "serviceKey=\(encodedKey)",
            "eventStartDate=\(today)",
            "eventEndDate=\(future)",
            "_type=json",
            "MobileOS=iOS",
            "MobileApp=FestMap",
            "numOfRows=100",
            "pageNo=1",
            "arrange=C",
        ].joined(separator: "&")

        guard let url = URL(string: "\(baseURL)?\(queryString)") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "TourAPI", code: code,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(code)"])
        }

        // 응답 내용 디버그 출력
        if let preview = String(data: data, encoding: .utf8) {
            print("[TourAPI] Response preview: \(preview.prefix(300))")
        }

        let decoded = try JSONDecoder().decode(TourAPIResponse.self, from: data)

        // API 레벨 에러 코드 확인
        if let code = decoded.response.header?.resultCode, code != "0000" {
            let msg = decoded.response.header?.resultMsg ?? "Unknown error"
            throw NSError(domain: "TourAPI", code: Int(code) ?? -1,
                          userInfo: [NSLocalizedDescriptionKey: "API Error \(code): \(msg)"])
        }

        let items = decoded.response.body?.items?.item ?? []
        return items.compactMap { item in
            guard
                let mapxStr = item.mapx, let mapyStr = item.mapy,
                let lng = Double(mapxStr), let lat = Double(mapyStr),
                lng != 0, lat != 0,
                !item.title.trimmingCharacters(in: .whitespaces).isEmpty
            else { return nil }

            return Festival(
                id: item.contentid,
                title: item.title,
                address: item.addr1 ?? "",
                longitude: lng,
                latitude: lat,
                imageURL: item.firstimage.flatMap { $0.isEmpty ? nil : $0 },
                startDate: item.eventstartdate ?? "",
                endDate: item.eventenddate ?? "",
                phone: item.tel.flatMap { $0.isEmpty ? nil : $0 }
            )
        }
    }

    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }
}
