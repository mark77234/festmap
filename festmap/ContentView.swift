import SwiftUI
import CoreLocation

struct ContentView: View {
    @StateObject private var viewModel = FestivalMapViewModel()
    @StateObject private var locationManager = LocationManager()
    @State private var isTracking: Bool = false
    @FocusState private var isSearchFocused: Bool

    private var isSearching: Bool {
        !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var shouldShowSearchResults: Bool {
        isSearching && !viewModel.searchSuggestions.isEmpty
    }

    var body: some View {
        ZStack {
            // 풀스크린 카카오맵
            KakaoMapView(viewModel: viewModel, locationManager: locationManager, isTracking: isTracking)
                .ignoresSafeArea()

            // 상단 Glassy 검색/컨트롤
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Text("축제어디?")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)

                    Spacer()

                    Button(action: reloadFestivals) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(.ultraThinMaterial))
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.45), lineWidth: 0.8)
                            )
                            .shadow(color: Color.black.opacity(0.16), radius: 8, x: 0, y: 3)
                    }
                    .disabled(viewModel.isLoading)
                    .opacity(viewModel.isLoading ? 0.6 : 1.0)

                    Button(action: toggleTracking) {
                        Image(systemName: isTracking ? "location.fill" : "location")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isTracking ? .white : .primary)
                            .frame(width: 40, height: 40)
                            .background(
                                Group {
                                    if isTracking {
                                        Circle().fill(Color.blue)
                                    } else {
                                        Circle().fill(.ultraThinMaterial)
                                    }
                                }
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.white.opacity(isTracking ? 0.0 : 0.45), lineWidth: 0.8)
                            )
                            .shadow(color: Color.black.opacity(0.16), radius: 8, x: 0, y: 3)
                    }
                }

                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)

                        TextField("축제명 또는 주소 검색", text: $viewModel.searchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .focused($isSearchFocused)

                        if isSearching {
                            Text("\(viewModel.filteredFestivals.count)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.regularMaterial, in: Capsule())
                        }

                        if !viewModel.searchText.isEmpty {
                            Button {
                                viewModel.searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)

                    if shouldShowSearchResults {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(viewModel.searchSuggestions.enumerated()), id: \.element.id) { index, festival in
                                    Button {
                                        isSearchFocused = false
                                        viewModel.requestMapFocus(to: festival)
                                        viewModel.searchText = ""
                                        viewModel.selectFestival(festival)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(festival.title)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.primary)
                                                .lineLimit(1)

                                            Text(festival.address)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.plain)

                                    if index < viewModel.searchSuggestions.count - 1 {
                                        Divider()
                                            .padding(.leading, 14)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 260)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 44)
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
        .animation(.easeInOut(duration: 0.2), value: shouldShowSearchResults)
    }

    private func toggleTracking() {
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
    }

    private func reloadFestivals() {
        Task {
            await viewModel.fetchFestivals()
        }
    }
}
