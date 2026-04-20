import Foundation

enum Config {
    static var kakaoAppKey: String {
        Bundle.main.infoDictionary?["KAKAO_APP_KEY"] as? String ?? ""
    }
    static var tourAPIKey: String {
        Bundle.main.infoDictionary?["TOUR_API_KEY"] as? String ?? ""
    }
}
