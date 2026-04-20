import SwiftUI
import UIKit
import SafariServices

struct FestivalNativeSheet: View {
    let festival: Festival
    let onDismiss: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: FestivalMapViewModel
    @State private var showCopied = false
    @State private var showSafari = false
    @State private var safariURL: URL? = nil
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showOpenChoice = false
    @State private var pendingOpenURL: URL? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
            }
            .padding(.top, 8)

            // 이미지 갤러리: detailImage2에서 가져온 여러 이미지가 있으면 상단에 좌우 스와이프 가능한 갤러리로 노출
            if let imgs = festival.imageURLs, !imgs.isEmpty {
                TabView {
                    ForEach(imgs, id: \.self) { img in
                        AsyncImage(url: URL(string: img)) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .failure, .empty:
                                placeholderView
                            @unknown default:
                                placeholderView
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipped()
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 220)
            }

            HStack(alignment: .top, spacing: 12) {
                // 갤러리가 없는 경우에만 썸네일을 우측에 표시
                if (festival.imageURLs?.isEmpty ?? true), let urlString = festival.imageURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure, .empty:
                            placeholderView
                        @unknown default:
                            placeholderView
                        }
                    }
                    .frame(width: 88, height: 88)
                    .clipped()
                    .cornerRadius(12)
                } else {
                    placeholderView
                        .frame(width: 88, height: 88)
                        .cornerRadius(12)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(festival.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(festival.formattedPeriod)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button(action: { copyAddress() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.and.ellipse")
                            Text(festival.address)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .buttonStyle(.plain)

                    if let phone = festival.phone, !phone.isEmpty {
                        Button(action: { callPhone(phone) }) {
                            HStack(spacing: 8) {
                                Image(systemName: "phone")
                                Text(phone)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if let homepage = festival.homepage, !homepage.isEmpty {
                        HStack(spacing: 12) {
                            Button(action: { openHomepage(homepage) }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "link")
                                    Text("앱 내에서 보기")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                            }
                            .buttonStyle(.plain)

                            Button(action: { openInExternalBrowser(homepage) }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "safari")
                                    Text("외부 브라우저로 열기")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 20)

            if let overview = festival.overview, !overview.isEmpty {
                Divider()
                    .padding(.horizontal, 20)
                ScrollView {
                    Text(overview)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .onDisappear { onDismiss() }
        .overlay(alignment: .bottom) {
            if showCopied {
                Text("주소가 복사되었습니다")
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.fraction(0.35), .medium])
        .sheet(isPresented: $showSafari) {
            if let url = safariURL {
                SafariView(url: url)
                    .edgesIgnoringSafeArea(.all)
            }
        }
        .zIndex(0)

        .alert(isPresented: $showAlert) {
            Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("확인")))
        }

        .confirmationDialog("링크 열기", isPresented: $showOpenChoice, titleVisibility: .visible) {
            Button("앱 내에서 열기") {
                if let url = pendingOpenURL {
                    safariURL = url
                    showSafari = true
                }
            }
            Button("Safari로 열기") {
                if let url = pendingOpenURL {
                    UIApplication.shared.open(url)
                }
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("이 링크는 안전 연결이 아닐 수 있습니다. 외부 브라우저로 여시겠습니까?")
        }

        // 로딩 오버레이
        .overlay(alignment: .center) {
            if viewModel.isDetailLoading {
                VStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.1)
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    Text("상세정보 불러오는 중...")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding()
                .transition(.opacity)
                .zIndex(1)
            }
        }
    }

    private var placeholderView: some View {
        LinearGradient(
            colors: [Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 1.0, green: 0.3, blue: 0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Text("🎪").font(.system(size: 36))
        )
    }

    private func copyAddress() {
        UIPasteboard.general.string = festival.address
        // 햅틱 피드백
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)

        withAnimation { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation { showCopied = false }
        }
    }

    private func callPhone(_ phone: String) {
        let digits = phone.filter { "0123456789+".contains($0) }
        guard !digits.isEmpty else { return }
        if let url = URL(string: "tel://\(digits)"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let url = URL(string: "tel://\(digits)") {
            openURL(url)
        }
    }

    private func openHomepage(_ urlString: String) {
        var str = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !str.hasPrefix("http://") && !str.hasPrefix("https://") {
            str = "https://\(str)"
        }
        guard let url = URL(string: str) else {
            presentAlert(title: "잘못된 주소", message: "홈페이지 주소가 올바르지 않습니다.")
            return
        }

        // 사전 체크: HEAD 요청으로 상태 코드 확인, 실패 시 GET으로 폴백
        Task {
            func presentAlertMain(_ title: String, _ message: String) async {
                await MainActor.run {
                    presentAlert(title: title, message: message)
                }
            }

            var ok = false
            // 1) HEAD 시도
            do {
                var req = URLRequest(url: url)
                req.httpMethod = "HEAD"
                req.timeoutInterval = 6
                let (_, response) = try await URLSession.shared.data(for: req)
                if let http = response as? HTTPURLResponse, (200...399).contains(http.statusCode) {
                    ok = true
                }
            } catch {
                // HEAD 실패하면 폴백으로 GET 시도
            }

            if !ok {
                do {
                    var req2 = URLRequest(url: url)
                    req2.httpMethod = "GET"
                    req2.timeoutInterval = 8
                    let (_, response2) = try await URLSession.shared.data(for: req2)
                    if let http2 = response2 as? HTTPURLResponse, (200...399).contains(http2.statusCode) {
                        ok = true
                    } else if let http2 = response2 as? HTTPURLResponse {
                        await presentAlertMain("홈페이지 열기 실패", "서버 응답 코드: \(http2.statusCode)")
                    }
                } catch {
                    await presentAlertMain("홈페이지에 연결할 수 없음", "네트워크 오류: \(error.localizedDescription)")
                }
            }

            if ok {
                await MainActor.run {
                    safariURL = url
                    showSafari = true
                }
            }
        }
    }

    private func presentAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }

    private func openInExternalBrowser(_ urlString: String) {
        var str = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !str.hasPrefix("http://") && !str.hasPrefix("https://") {
            str = "https://\(str)"
        }
        guard let url = URL(string: str) else {
            presentAlert(title: "잘못된 주소", message: "홈페이지 주소가 올바르지 않습니다.")
            return
        }
        UIApplication.shared.open(url)
    }
}

struct FestivalNativeSheet_Previews: PreviewProvider {
    static var previews: some View {
        FestivalNativeSheet(festival: Festival(id: "1", title: "샘플 축제", address: "서울시 강남구", longitude: 127.0, latitude: 37.0, imageURL: nil, startDate: "20240101", endDate: "20240103", phone: "02-1234-5678", overview: "샘플 축제 설명입니다. 다양한 공연과 먹거리장이 준비되어 있습니다.", homepage: "https://example.com", imageURLs: ["https://picsum.photos/800/400","https://picsum.photos/801/400"])) {
            // dismiss
        }
        .environmentObject(FestivalMapViewModel())
        .previewLayout(.sizeThatFits)
    }
}

// SFSafariViewController 래퍼
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.dismissButtonStyle = .close
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
