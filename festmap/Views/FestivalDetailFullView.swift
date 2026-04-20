import SwiftUI
import UIKit

struct FestivalDetailFullView: View {
    @Environment(\.dismiss) private var dismiss
    let festival: Festival

    @State private var showSafari = false
    @State private var safariURL: URL? = nil
    @State private var showCopied = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let imgs = festival.imageURLs, !imgs.isEmpty {
                        TabView {
                            ForEach(imgs, id: \.self) { img in
                                AsyncImage(url: URL(string: img)) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().scaledToFill()
                                    case .failure, .empty:
                                        placeholderLarge
                                    @unknown default:
                                        placeholderLarge
                                    }
                                }
                                .frame(height: 260)
                                .clipped()
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .always))
                        .frame(height: 260)
                    } else if let urlString = festival.imageURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .failure, .empty:
                                placeholderLarge
                            @unknown default:
                                placeholderLarge
                            }
                        }
                        .frame(height: 260)
                        .clipped()
                    } else {
                        placeholderLarge.frame(height: 260)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text(festival.title)
                            .font(.title2)
                            .fontWeight(.semibold)

                        Group {
                            Text("기간: \(festival.formattedEventPeriod ?? festival.formattedPeriod)")
                            if let eventPlace = festival.eventPlace, !eventPlace.isEmpty {
                                Text("행사장: \(eventPlace)")
                            }
                            if let useTime = festival.useTimeFestival, !useTime.isEmpty {
                                Text("관람시간: \(useTime)")
                            }
                            if let play = festival.playTime, !play.isEmpty {
                                Text("공연시간: \(play)")
                            }
                            if let sponsor = festival.sponsor1, !sponsor.isEmpty {
                                Text("주최: \(sponsor)")
                            }
                            if let age = festival.ageLimit, !age.isEmpty {
                                Text("관람연령: \(age)")
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                        Divider()

                        HStack {
                            Text("주소")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: copyAddress) {
                                HStack(spacing: 8) {
                                    Image(systemName: "doc.on.doc")
                                    Text("복사")
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        Text(festival.address)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)

                        if let phone = festival.phone, !phone.isEmpty {
                            HStack {
                                Text("전화")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button(action: { callPhone(phone) }) {
                                    Text(phone)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if let rawHomepage = festival.homepage, !rawHomepage.isEmpty {
                            let hp = cleanHTML(rawHomepage)
                            HStack {
                                Text("홈페이지")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button(action: { openHomepageString(hp) }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "link")
                                        Text("열기")
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Divider()

                        if let overview = festival.overview, !overview.isEmpty {
                            Text(overview)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("설명 없음")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitle("상세정보", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
            .background(.ultraThinMaterial)
            .sheet(isPresented: $showSafari) {
                if let url = safariURL {
                    SafariView(url: url)
                        .edgesIgnoringSafeArea(.all)
                }
            }
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
        }
    }

    private var placeholderLarge: some View {
        LinearGradient(
            colors: [Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 1.0, green: 0.3, blue: 0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(Text("🎪").font(.system(size: 48)))
        .cornerRadius(8)
    }

    private func copyAddress() {
        UIPasteboard.general.string = festival.address
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
        }
    }

    private func cleanHTML(_ html: String) -> String {
        guard !html.isEmpty else { return html }
        if let data = html.data(using: .utf8) {
            if let attr = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) {
                return attr.string
            }
        }
        return html
    }

    private func openHomepageString(_ urlString: String) {
        var str = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !str.hasPrefix("http://") && !str.hasPrefix("https://") {
            str = "https://\(str)"
        }
        guard let url = URL(string: str) else { return }
        safariURL = url
        showSafari = true
    }
}

struct FestivalDetailFullView_Previews: PreviewProvider {
    static var previews: some View {
        FestivalDetailFullView(festival: Festival(id: "1", title: "샘플 축제 긴 제목 테스트입니다. 꽤 길게 표시됩니다.", address: "서울시 강남구 테헤란로 1", longitude: 127.0, latitude: 37.0, imageURL: nil, startDate: "20240101", endDate: "20240103", phone: "02-1234-5678", overview: String(repeating: "상세 설명 ", count: 20), homepage: "<a href=\"https://example.com\">https://example.com</a>", eventStartDate: "20240101", eventEndDate: "20240103", eventPlace: "강남광장", useTimeFestival: "10:00 - 18:00", playTime: "11:00 - 17:00", sponsor1: "샘플 주최", ageLimit: "전체", imageURLs: ["https://picsum.photos/800/400"]))
    }
}
