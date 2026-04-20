import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = FestivalMapViewModel()

    var body: some View {
        ZStack {
            // 풀스크린 카카오맵
            KakaoMapView(viewModel: viewModel)
                .ignoresSafeArea()

            // 상단 Glassy 제목 (네이티브 스타일)
            VStack {
                HStack {
                    Text("축제어디?")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 44)
                Spacer()
            }
            .ignoresSafeArea(edges: .top)

            // 로딩 인디케이터
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.2)
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }

            // 에러 토스트
            if let message = viewModel.errorMessage {
                VStack {
                    Spacer()
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.75), in: Capsule())
                        .padding(.bottom, 40)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // 축제 바텀시트
            if let festival = viewModel.selectedFestival {
                VStack {
                    Spacer()
                    FestivalBottomSheet(festival: festival) {
                        viewModel.deselectFestival()
                    }
                    .transition(.move(edge: .bottom))
                }
                .ignoresSafeArea(edges: .bottom)
                .background(Color.black.opacity(0.3).ignoresSafeArea())
                .onTapGesture { viewModel.deselectFestival() }
            }
        }
        .statusBarHidden(true)
        .task {
            await viewModel.fetchFestivals()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.selectedFestival?.id)
        .animation(.easeInOut(duration: 0.3), value: viewModel.errorMessage)
    }
}
