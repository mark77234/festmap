import Foundation

final class APIClient {
    static let shared = APIClient()
    private init() {}

    private let baseURL = "https://apis.data.go.kr/B551011/KorService2"

    // 안전한 페이로드 인코딩 (serviceKey에 포함된 + 등 문자를 정확히 인코딩)
    private var safeChars: CharacterSet {
        var s = CharacterSet.alphanumerics
        s.insert(charactersIn: "-._~")
        return s
    }

    private func percentEncode(_ value: String) -> String {
        return value.addingPercentEncoding(withAllowedCharacters: safeChars) ?? value
    }

    private func buildURL(path: String, params: [String: String]) -> URL? {
        var parts: [String] = []
        for (k, v) in params {
            parts.append("\(k)=\(percentEncode(v))")
        }
        // 공통 파라미터
        parts.append("serviceKey=\(percentEncode(Config.tourAPIKey))")
        parts.append("_type=json")
        parts.append("MobileOS=iOS")
        parts.append("MobileApp=FestMap")

        let query = parts.joined(separator: "&")
        return URL(string: "\(baseURL)/\(path)?\(query)")
    }

    func get(path: String, params: [String: String]) async throws -> Data {
        guard let url = buildURL(path: path, params: params) else { throw URLError(.badURL) }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "TourAPI", code: code, userInfo: [NSLocalizedDescriptionKey: "HTTP \(code)"])
        }

        if let preview = String(data: data, encoding: .utf8) {
            print("[APIClient] GET \(path) preview: \(preview.prefix(300))")
        }

        return data
    }
}

final class TourAPIService {
    static let shared = TourAPIService(client: APIClient.shared)
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func fetchFestivals() async throws -> [Festival] {
        let today = dateString(from: Date())
        let future = dateString(from: Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date())

        let params: [String: String] = [
            "eventStartDate": today,
            "eventEndDate": future,
            "numOfRows": "100",
            "pageNo": "1",
            "arrange": "C"
        ]

        let data = try await client.get(path: "searchFestival2", params: params)
        let decoded = try JSONDecoder().decode(TourAPIResponse.self, from: data)

        if let code = decoded.response.header?.resultCode, code != "0000" {
            let msg = decoded.response.header?.resultMsg ?? "Unknown error"
            throw NSError(domain: "TourAPI", code: Int(code) ?? -1, userInfo: [NSLocalizedDescriptionKey: "API Error \(code): \(msg)"])
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
                phone: item.tel.flatMap { $0.isEmpty ? nil : $0 },
                overview: nil,
                homepage: nil,
                imageURLs: nil
            )
        }
    }

    func fetchFestivalDetail(contentId: String) async throws -> TourAPIDetailItem? {
        let params: [String: String] = [
            "contentId": contentId,
            "numOfRows": "1",
            "pageNo": "1"
        ]

        let data = try await client.get(path: "detailCommon2", params: params)
        let decoded = try JSONDecoder().decode(TourAPIDetailResponse.self, from: data)

        if let code = decoded.response.header?.resultCode, code != "0000" {
            let msg = decoded.response.header?.resultMsg ?? "Unknown error"
            throw NSError(domain: "TourAPI", code: Int(code) ?? -1, userInfo: [NSLocalizedDescriptionKey: "API Error \(code): \(msg)"])
        }

        let items = decoded.response.body?.items?.item ?? []
        print("[TourAPIService] detailCommon2 items count: \(items.count) for contentId: \(contentId)")
        if let first = items.first {
            print("[TourAPIService] detailCommon2 first: contentId=\(first.contentid ?? "-"), title=\(first.title ?? "-"), tel=\(first.tel ?? "-"), homepage=\(first.homepage ?? "-")")
        } else {
            print("[TourAPIService] detailCommon2: no item found for contentId=\(contentId)")
        }

        return items.first
    }

    func fetchFestivalImages(contentId: String) async throws -> [String] {
        let params: [String: String] = [
            "contentId": contentId,
            "imageYN": "Y",
            "numOfRows": "100",
            "pageNo": "1"
        ]

        let data = try await client.get(path: "detailImage2", params: params)
        let decoded = try JSONDecoder().decode(TourAPIDetailImageResponse.self, from: data)

        if let code = decoded.response.header?.resultCode, code != "0000" {
            let msg = decoded.response.header?.resultMsg ?? "Unknown error"
            throw NSError(domain: "TourAPI", code: Int(code) ?? -1, userInfo: [NSLocalizedDescriptionKey: "API Error \(code): \(msg)"])
        }

        let items = decoded.response.body?.items?.item ?? []
        print("[TourAPIService] detailImage2 items count: \(items.count) for contentId: \(contentId)")

        // 우선 originimgurl 우선, 없으면 smallimageurl 사용
        let urls = items.compactMap { $0.originimgurl?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? $0.originimgurl : ($0.smallimageurl?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? $0.smallimageurl : nil) }
        return urls
    }

    // 유틸
    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }
}
