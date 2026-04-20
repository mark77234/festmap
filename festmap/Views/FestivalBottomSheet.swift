import SwiftUI
import UIKit

struct FestivalBottomSheet: View {
    let festival: Festival
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 핸들 바
            HStack {
                Spacer()
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(.systemGray4))
                    .frame(width: 40, height: 5)
                Spacer()
            }
            .padding(.top, 12)
            .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // 축제 이미지
                    if let urlString = festival.imageURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure, .empty:
                                placeholderView
                            @unknown default:
                                placeholderView
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipped()
                        .cornerRadius(12)
                    } else {
                        placeholderView
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .cornerRadius(12)
                    }

                    // 축제명
                    Text(festival.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)

                    // 날짜
                    Label(festival.formattedPeriod, systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    // 주소
                    if !festival.address.isEmpty {
                        Label(festival.address, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // 전화번호
                    if let phone = festival.phone {
                        Label(phone, systemImage: "phone")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .overlay(alignment: .topTrailing) {
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 12)
            .padding(.trailing, 16)
        }
    }

    private var placeholderView: some View {
        LinearGradient(
            colors: [Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 1.0, green: 0.3, blue: 0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Text("🎪")
                .font(.system(size: 48))
        )
    }
}

// MARK: - 모서리 선택 cornerRadius 확장
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
