import SwiftUI
import UIKit

struct FestivalNativeSheet: View {
    let festival: Festival
    let onDismiss: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var showCopied = false

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
                }

                Spacer()
            }
            .padding(.horizontal, 20)

            Spacer()
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
}

struct FestivalNativeSheet_Previews: PreviewProvider {
    static var previews: some View {
        FestivalNativeSheet(festival: Festival(id: "1", title: "샘플 축제", address: "서울시 강남구", longitude: 127.0, latitude: 37.0, imageURL: nil, startDate: "20240101", endDate: "20240103", phone: "02-1234-5678")) {
            // dismiss
        }
        .previewLayout(.sizeThatFits)
    }
}
