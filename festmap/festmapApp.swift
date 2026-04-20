import SwiftUI
import KakaoMapsSDK

@main
struct festmapApp: App {
    init() {
        SDKInitializer.InitSDK(appKey: Config.kakaoAppKey)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
