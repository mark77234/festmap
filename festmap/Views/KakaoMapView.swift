import SwiftUI
import KakaoMapsSDK
import CoreLocation

struct KakaoMapView: UIViewControllerRepresentable {
    @ObservedObject var viewModel: FestivalMapViewModel
    @ObservedObject var locationManager: LocationManager
    var isTracking: Bool

    func makeUIViewController(context: Context) -> KakaoMapViewController {
        let vc = KakaoMapViewController(viewModel: viewModel, locationManager: locationManager)
        vc.setTrackingEnabled(isTracking)
        return vc
    }

    func updateUIViewController(_ vc: KakaoMapViewController, context: Context) {
        vc.updateFestivals(viewModel.festivals)
        vc.handleMapFocusRequest(viewModel.mapFocusRequest)
        vc.updateUserLocation(locationManager.lastLocation)
        vc.setTrackingEnabled(isTracking)
    }
}

// MARK: - KakaoMapViewController

class KakaoMapViewController: UIViewController, MapControllerDelegate, KakaoMapEventDelegate {

    private let festivalLayerID = "festivalLayer"
    private let festivalStyleID = "festivalStyle"
    private let userLayerID = "userLayer"
    private let userStyleID = "userStyle"
    private let userPoiID = "user_location"

    private let defaultCenterCoordinate = CLLocationCoordinate2D(latitude: 36.5, longitude: 127.5)
    private let initialNearbyZoomLevel = 2

    private var controller: KMController?
    private var kakaoMap: KakaoMap?
    private weak var viewModel: FestivalMapViewModel?
    private var locationManager: LocationManager?

    private var festivalDict: [String: Festival] = [:]
    private var poiIDsByImageURL: [String: Set<String>] = [:]
    private var imageStyleIDByURL: [String: String] = [:]
    private var imageFetchInProgress: Set<String> = []

    private var pendingFestivals: [Festival] = []
    private var isMapReady = false

    private var lastFestivalSignature: Int?
    private var lastHandledFocusRequestID: UUID?
    private var hasAppliedInitialCamera = false

    private var trackingEnabled = false

    init(viewModel: FestivalMapViewModel, locationManager: LocationManager) {
        self.viewModel = viewModel
        self.locationManager = locationManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        let mapContainer = KMViewContainer(frame: view.bounds)
        mapContainer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(mapContainer)

        controller = KMController(viewContainer: mapContainer)
        controller?.delegate = self
        controller?.prepareEngine()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        controller?.activateEngine()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        controller?.resetEngine()
    }

    func updateFestivals(_ festivals: [Festival]) {
        if isMapReady {
            updateMarkers(festivals: festivals)
        } else {
            pendingFestivals = festivals
        }
    }

    func handleMapFocusRequest(_ request: FestivalMapFocusRequest?) {
        guard let request else { return }
        guard request.id != lastHandledFocusRequestID else { return }
        lastHandledFocusRequestID = request.id
        moveCamera(to: request.festival)
    }

    // MARK: - MapControllerDelegate

    func addViews() {
        print("[KakaoMap] addViews() called")
        let center = MapPoint(longitude: defaultCenterCoordinate.longitude, latitude: defaultCenterCoordinate.latitude)
        let mapInfo = MapviewInfo(
            viewName: "mapview",
            appName: "openmap",
            viewInfoName: "map",
            defaultPosition: center,
            defaultLevel: initialNearbyZoomLevel,
            enabled: true
        )
        controller?.addView(mapInfo)
    }

    func addViewSucceeded(_ viewName: String, viewInfoName: String) {
        print("[KakaoMap] addViewSucceeded: \(viewName)")
        guard viewName == "mapview" else { return }

        kakaoMap = controller?.getView("mapview") as? KakaoMap
        kakaoMap?.eventDelegate = self
        kakaoMap?.poiClickable = true
        kakaoMap?.cameraAnimationEnabled = true
        kakaoMap?.cameraMinLevel = 0
        kakaoMap?.cameraMaxLevel = 14

        isMapReady = true
        setupPOILayer()
        setupUserLayer()
        applyInitialCameraIfNeeded()

        if !pendingFestivals.isEmpty {
            updateMarkers(festivals: pendingFestivals)
            pendingFestivals = []
        }
    }

    func addViewFailed(_ viewName: String, viewInfoName: String) {
        print("[KakaoMap] addViewFailed: \(viewName), \(viewInfoName)")
    }

    func containerDidResized(_ size: CGSize) {}

    func authenticationSucceeded() {
        print("[KakaoMap] 인증 성공")
    }

    func authenticationFailed(errorCode: Int, desc: String) {
        print("[KakaoMap] 인증 실패 - code: \(errorCode), desc: \(desc)")
    }

    // MARK: - KakaoMapEventDelegate

    func poiDidTapped(kakaoMap: KakaoMap, layerID: String, poiID: String, position: MapPoint) {
        guard let festival = festivalDict[poiID] else { return }
        moveCamera(to: festival)
        viewModel?.selectFestival(festival)
    }

    // MARK: - Layers

    private func setupPOILayer() {
        guard let map = kakaoMap else { return }
        let lm = map.getLabelManager()

        let layerOption = LabelLayerOptions(
            layerID: festivalLayerID,
            competitionType: .none,
            competitionUnit: .symbolFirst,
            orderType: .rank,
            zOrder: 10001
        )
        _ = lm.addLabelLayer(option: layerOption)

        let iconStyle = PoiIconStyle(symbol: makeFallbackMarkerImage(), anchorPoint: CGPoint(x: 0.5, y: 1.0))
        let poiStyle = PoiStyle(styleID: festivalStyleID, styles: [PerLevelPoiStyle(iconStyle: iconStyle, level: 0)])
        lm.addPoiStyle(poiStyle)
    }

    private func setupUserLayer() {
        guard let map = kakaoMap else { return }
        let lm = map.getLabelManager()

        let layerOption = LabelLayerOptions(
            layerID: userLayerID,
            competitionType: .none,
            competitionUnit: .symbolFirst,
            orderType: .rank,
            zOrder: 10002
        )
        _ = lm.addLabelLayer(option: layerOption)

        let iconStyle = PoiIconStyle(symbol: makeUserMarkerImage(), anchorPoint: CGPoint(x: 0.5, y: 0.5))
        let poiStyle = PoiStyle(styleID: userStyleID, styles: [PerLevelPoiStyle(iconStyle: iconStyle, level: 0)])
        lm.addPoiStyle(poiStyle)
    }

    func updateUserLocation(_ coordinate: CLLocationCoordinate2D?) {
        guard let map = kakaoMap else { return }
        applyInitialCameraIfNeeded()

        if map.getLabelManager().getLabelLayer(layerID: userLayerID) == nil {
            setupUserLayer()
        }

        guard let layer = map.getLabelManager().getLabelLayer(layerID: userLayerID) else { return }

        layer.removePois(poiIDs: [userPoiID])

        guard let coord = coordinate else { return }

        let option = PoiOptions(styleID: userStyleID, poiID: userPoiID)
        option.clickable = false
        _ = layer.addPoi(option: option, at: MapPoint(longitude: coord.longitude, latitude: coord.latitude))
        layer.showAllPois()

        if trackingEnabled {
            let center = MapPoint(longitude: coord.longitude, latitude: coord.latitude)
            let sel = NSSelectorFromString("setMapCenter:animated:")
            if let mapRef = kakaoMap {
                let ns = mapRef as NSObject
                if ns.responds(to: sel) {
                    ns.perform(sel, with: center, with: NSNumber(value: true))
                }
            }
        }
    }

    func setTrackingEnabled(_ enabled: Bool) {
        trackingEnabled = enabled
    }

    // MARK: - Markers

    private func updateMarkers(festivals: [Festival]) {
        guard let map = kakaoMap,
              let layer = map.getLabelManager().getLabelLayer(layerID: festivalLayerID) else { return }

        let signature = festivalsSignature(festivals)
        if signature == lastFestivalSignature { return }
        lastFestivalSignature = signature

        let oldIDs = Array(festivalDict.keys)
        if !oldIDs.isEmpty {
            layer.removePois(poiIDs: oldIDs)
        }

        festivalDict.removeAll()
        poiIDsByImageURL.removeAll()

        for festival in festivals {
            let styleID = styleIDForFestival(festival)
            let option = PoiOptions(styleID: styleID, poiID: festival.id)
            option.rank = 0
            option.clickable = true
            _ = layer.addPoi(option: option, at: MapPoint(longitude: festival.longitude, latitude: festival.latitude))
            festivalDict[festival.id] = festival

            if let imageURL = normalizedImageURL(from: festival.imageURL) {
                poiIDsByImageURL[imageURL, default: []].insert(festival.id)
                ensureRepresentativeImageStyle(for: imageURL)
            }
        }

        layer.showAllPois()
    }

    private func styleIDForFestival(_ festival: Festival) -> String {
        guard let imageURL = normalizedImageURL(from: festival.imageURL) else {
            return festivalStyleID
        }
        return imageStyleIDByURL[imageURL] ?? festivalStyleID
    }

    private func normalizedImageURL(from raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private func ensureRepresentativeImageStyle(for imageURL: String) {
        guard imageStyleIDByURL[imageURL] == nil else { return }
        guard !imageFetchInProgress.contains(imageURL) else { return }
        guard let url = URL(string: imageURL) else { return }

        imageFetchInProgress.insert(imageURL)

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, !(200...399).contains(http.statusCode) {
                    throw URLError(.badServerResponse)
                }
                guard let image = UIImage(data: data) else {
                    throw URLError(.cannotDecodeContentData)
                }

                await MainActor.run {
                    self.registerRepresentativeImageStyle(image, imageURL: imageURL)
                }
            } catch {
                await MainActor.run {
                    self.imageFetchInProgress.remove(imageURL)
                }
            }
        }
    }

    private func registerRepresentativeImageStyle(_ image: UIImage, imageURL: String) {
        defer { imageFetchInProgress.remove(imageURL) }
        guard let map = kakaoMap else { return }
        guard imageStyleIDByURL[imageURL] == nil else { return }

        let styleID = "festival_img_\(imageURL.hashValue.magnitude)"
        let markerImage = makeRepresentativeMarkerImage(from: image)
        let iconStyle = PoiIconStyle(symbol: markerImage, anchorPoint: CGPoint(x: 0.5, y: 0.5))
        let poiStyle = PoiStyle(styleID: styleID, styles: [PerLevelPoiStyle(iconStyle: iconStyle, level: 0)])
        map.getLabelManager().addPoiStyle(poiStyle)

        imageStyleIDByURL[imageURL] = styleID
        applyImageStyle(styleID: styleID, toMarkersWithImageURL: imageURL)
    }

    private func applyImageStyle(styleID: String, toMarkersWithImageURL imageURL: String) {
        guard let map = kakaoMap,
              let layer = map.getLabelManager().getLabelLayer(layerID: festivalLayerID),
              let poiIDs = poiIDsByImageURL[imageURL] else { return }

        for poiID in poiIDs {
            guard let poi = layer.getPoi(poiID: poiID) else { continue }
            poi.changeStyle(styleID: styleID, enableTransition: true)
        }
    }

    // MARK: - Camera

    private func moveCamera(to festival: Festival) {
        guard let map = kakaoMap else { return }
        let coordinate = CLLocationCoordinate2D(latitude: festival.latitude, longitude: festival.longitude)
        moveCamera(to: coordinate, zoomLevel: map.cameraMinLevel, animated: true)
    }

    private func moveCamera(to coordinate: CLLocationCoordinate2D, zoomLevel: Int, animated: Bool) {
        guard let map = kakaoMap else { return }

        let clampedLevel = min(map.cameraMaxLevel, max(map.cameraMinLevel, zoomLevel))
        let target = MapPoint(longitude: coordinate.longitude, latitude: coordinate.latitude)

        let cameraPosition = CameraPosition(target: target, zoomLevel: clampedLevel, rotation: 0, tilt: 0)
        cameraPosition.byLevel = true

        let cameraUpdate = CameraUpdate.make(cameraPosition: cameraPosition)

        if animated {
            let options = CameraAnimationOptions()
            map.animateCamera(cameraUpdate: cameraUpdate, options: options, callback: nil)
        } else {
            map.moveCamera(cameraUpdate, callback: nil)
        }
    }

    private func applyInitialCameraIfNeeded() {
        guard isMapReady, !hasAppliedInitialCamera else { return }

        if let current = locationManager?.lastLocation {
            moveCamera(to: current, zoomLevel: initialNearbyZoomLevel, animated: false)
            hasAppliedInitialCamera = true
            return
        }

        guard let status = locationManager?.authorizationStatus else { return }
        switch status {
        case .denied, .restricted:
            moveCamera(to: defaultCenterCoordinate, zoomLevel: initialNearbyZoomLevel, animated: false)
            hasAppliedInitialCamera = true
        default:
            break
        }
    }

    private func festivalsSignature(_ festivals: [Festival]) -> Int {
        var hasher = Hasher()
        hasher.combine(festivals.count)

        for festival in festivals.sorted(by: { $0.id < $1.id }) {
            hasher.combine(festival.id)
            hasher.combine(festival.latitude.bitPattern)
            hasher.combine(festival.longitude.bitPattern)
            hasher.combine(normalizedImageURL(from: festival.imageURL) ?? "")
        }

        return hasher.finalize()
    }

    // MARK: - Marker Drawing

    private func makeUserMarkerImage() -> UIImage {
        let size = CGSize(width: 20, height: 20)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let outerRect = CGRect(origin: .zero, size: size)
            let outerPath = UIBezierPath(ovalIn: outerRect)
            UIColor.systemBlue.setFill()
            outerPath.fill()

            let innerSize = CGSize(width: 8, height: 8)
            let innerRect = CGRect(
                x: (size.width - innerSize.width) / 2,
                y: (size.height - innerSize.height) / 2,
                width: innerSize.width,
                height: innerSize.height
            )
            let innerPath = UIBezierPath(ovalIn: innerRect)
            UIColor.white.setFill()
            innerPath.fill()
        }
    }

    private func makeFallbackMarkerImage() -> UIImage {
        let size = CGSize(width: 30, height: 30)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { _ in
            let fillColor = UIColor(red: 0.95, green: 0.47, blue: 0.22, alpha: 1.0)
            fillColor.setFill()
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()

            let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            if let symbol = UIImage(systemName: "ticket.fill", withConfiguration: config)?.withTintColor(.white, renderingMode: .alwaysOriginal) {
                let symSize = symbol.size
                let rect = CGRect(
                    x: (size.width - symSize.width) / 2,
                    y: (size.height - symSize.height) / 2,
                    width: symSize.width,
                    height: symSize.height
                )
                symbol.draw(in: rect)
            }
        }
    }

    private func makeRepresentativeMarkerImage(from source: UIImage) -> UIImage {
        let size = CGSize(width: 36, height: 36)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { _ in
            let circleRect = CGRect(origin: .zero, size: size)
            let circlePath = UIBezierPath(ovalIn: circleRect.insetBy(dx: 1, dy: 1))
            circlePath.addClip()
            source.draw(in: circleRect)

            UIColor.white.setStroke()
            circlePath.lineWidth = 2
            circlePath.stroke()
        }
    }
}
