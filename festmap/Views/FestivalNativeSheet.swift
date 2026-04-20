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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
            }
            .padding(.top, 8)

            HStack(alignment: .top, spacing: 12) {
                if let urlString = festival.imageURL, let url = URL(string: urlString) {
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
                        Button(action: { openHomepage(homepage) }) {
                            HStack(spacing: 8) {
                                Image(systemName: "link")
                                Text("홈페이지 보기")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        }
                        .buttonStyle(.plain)
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
            _ = openURL(url)
        }
    }

    private func openHomepage(_ urlString: String) {
        var str = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !str.hasPrefix("http://") && !str.hasPrefix("https://") {
            str = "https://\(str)"
        }
        guard let url = URL(string: str) else { return }
        safariURL = url
        showSafari = true
    }
}

struct FestivalNativeSheet_Previews: PreviewProvider {
    static var previews: some View {
        FestivalNativeSheet(festival: Festival(id: "1", title: "샘플 축제", address: "서울시 강남구", longitude: 127.0, latitude: 37.0, imageURL: nil, startDate: "20240101", endDate: "20240103", phone: "02-1234-5678", overview: "샘플 축제 설명입니다. 다양한 공연과 먹거리장이 준비되어 있습니다.", homepage: "https://example.com")) {
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
