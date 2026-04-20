import Foundation

struct Festival: Identifiable {
    let id: String
    let title: String
    let address: String
    let longitude: Double   // mapx
    let latitude: Double    // mapy
    let imageURL: String?
    let startDate: String
    let endDate: String
    let phone: String?
    // 추가 상세 정보
    let overview: String?
    let homepage: String?

    var formattedPeriod: String {
        "\(formatDate(startDate)) ~ \(formatDate(endDate))"
    }

    private func formatDate(_ raw: String) -> String {
        guard raw.count == 8 else { return raw }
        let y = raw.prefix(4)
        let m = raw.dropFirst(4).prefix(2)
        let d = raw.dropFirst(6).prefix(2)
        return "\(y).\(m).\(d)"
    }
}

// MARK: - TourAPI 응답 디코딩 타입

struct TourAPIResponse: Decodable {
    let response: TourAPIBody
}

struct TourAPIBody: Decodable {
    let header: TourAPIHeader?
    let body: TourAPIContent?
}

struct TourAPIHeader: Decodable {
    let resultCode: String
    let resultMsg: String
}

struct TourAPIContent: Decodable {
    let items: TourAPIItemList?
    let totalCount: AnyCodableInt?

    struct AnyCodableInt: Decodable {
        let value: Int
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let i = try? c.decode(Int.self) { value = i }
            else if let s = try? c.decode(String.self) { value = Int(s) ?? 0 }
            else { value = 0 }
        }
    }
}

struct TourAPIItemList: Decodable {
    let item: [FestivalItem]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let items = try? container.decode([FestivalItem].self, forKey: .item) {
            item = items
        } else if let single = try? container.decode(FestivalItem.self, forKey: .item) {
            item = [single]
        } else {
            item = []
        }
    }

    enum CodingKeys: String, CodingKey { case item }
}

struct FestivalItem: Decodable {
    let contentid: String
    let title: String
    let addr1: String?
    let mapx: String?
    let mapy: String?
    let firstimage: String?
    let eventstartdate: String?
    let eventenddate: String?
    let tel: String?
}

// MARK: - detailCommon2 응답 타입

struct TourAPIDetailResponse: Decodable {
    let response: TourAPIDetailBody
}

struct TourAPIDetailBody: Decodable {
    let header: TourAPIHeader?
    let body: TourAPIDetailContent?
}

struct TourAPIDetailContent: Decodable {
    let items: TourAPIDetailItemContainer?
    let numOfRows: Int?
    let pageNo: Int?
    let totalCount: Int?
}

struct TourAPIDetailItemContainer: Decodable {
    let item: [TourAPIDetailItem]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let arr = try? container.decode([TourAPIDetailItem].self, forKey: .item) {
            item = arr
        } else if let single = try? container.decode(TourAPIDetailItem.self, forKey: .item) {
            item = [single]
        } else {
            item = []
        }
    }

    enum CodingKeys: String, CodingKey { case item }
}

struct TourAPIDetailItem: Decodable {
    let overview: String?
    let contentid: String?
    let homepage: String?
    let tel: String?
    let firstimage: String?
    let title: String?
}
