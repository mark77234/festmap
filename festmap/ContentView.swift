import SwiftUI
import CoreLocation

struct ContentView: View {
    @StateObject private var viewModel = FestivalMapViewModel()
    @StateObject private var locationManager = LocationManager()
    @State private var isTracking: Bool = false

    var body: some View {
        ZStack {
            // 풀스크린 카카오맵
            KakaoMapView(viewModel: viewModel, locationManager: locationManager, isTracking: isTracking)
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
                // 내 위치 버튼 (우측 상단)
                HStack {
                    Spacer()
                    Button {
                        // tracking 토글
                        isTracking.toggle()
                        if isTracking {
                            if locationManager.authorizationStatus == .authorizedAlways || locationManager.authorizationStatus == .authorizedWhenInUse {
                                locationManager.startUpdating()
                            } else {
                                locationManager.requestPermission()
                            }
                        } else {
                            locationManager.stopUpdating()
                        }
                    } label: {
                        Image(systemName: isTracking ? "location.fill" : "location")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(isTracking ? Color.blue : Color.gray.opacity(0.5))
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 44)
                }
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

            // 네이티브 바텀시트는 아래 .sheet로 표시됩니다
        }
        .sheet(item: $viewModel.selectedFestival, onDismiss: { viewModel.deselectFestival() }) { festival in
            FestivalNativeSheet(festival: festival) {
                viewModel.deselectFestival()
            }
            .environmentObject(viewModel)
            .presentationDetents([.fraction(0.35), .medium, .large])
            .presentationDragIndicator(.visible)
        }
        .statusBarHidden(true)
        .task {
            await viewModel.fetchFestivals()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.selectedFestival?.id)
        .animation(.easeInOut(duration: 0.3), value: viewModel.errorMessage)
    }
}
