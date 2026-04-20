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
        vc.updateUserLocation(locationManager.lastLocation)
        vc.setTrackingEnabled(isTracking)
    }
}

// MARK: - KakaoMapViewController


class KakaoMapViewController: UIViewController, MapControllerDelegate, KakaoMapEventDelegate {

    private var controller: KMController?
    private var kakaoMap: KakaoMap?
    private weak var viewModel: FestivalMapViewModel?
    private var festivalDict: [String: Festival] = [:]
    private var pendingFestivals: [Festival] = []
    private var isMapReady = false

    private var locationManager: LocationManager?
    private let userPoiID = "user_location"
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

    // MARK: - MapControllerDelegate

    func addViews() {
        print("[KakaoMap] addViews() called")
        let center = MapPoint(longitude: 127.5, latitude: 36.5)
        let mapInfo = MapviewInfo(
            viewName: "mapview",
            appName: "openmap",
            viewInfoName: "map",
            defaultPosition: center,
            defaultLevel: 6,
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
        isMapReady = true
        setupPOILayer()
        setupUserLayer()
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
        viewModel?.selectFestival(festival)
    }

    // MARK: - POI 레이어

    private func setupPOILayer() {
        guard let map = kakaoMap else { return }
        let lm = map.getLabelManager()

        let layerOption = LabelLayerOptions(
            layerID: "festivalLayer",
            competitionType: .none,
            competitionUnit: .symbolFirst,
            orderType: .rank,
            zOrder: 10001
        )
        _ = lm.addLabelLayer(option: layerOption)

        let iconStyle = PoiIconStyle(symbol: makeMarkerImage(), anchorPoint: CGPoint(x: 0.5, y: 1.0))
        let poiStyle = PoiStyle(styleID: "festivalStyle", styles: [PerLevelPoiStyle(iconStyle: iconStyle, level: 0)])
        lm.addPoiStyle(poiStyle)
    }

    private func setupUserLayer() {
        guard let map = kakaoMap else { return }
        let lm = map.getLabelManager()

        let layerOption = LabelLayerOptions(
            layerID: "userLayer",
            competitionType: .none,
            competitionUnit: .symbolFirst,
            orderType: .rank,
            zOrder: 10002
        )
        _ = lm.addLabelLayer(option: layerOption)

        let iconStyle = PoiIconStyle(symbol: makeUserMarkerImage(), anchorPoint: CGPoint(x: 0.5, y: 0.5))
        let poiStyle = PoiStyle(styleID: "userStyle", styles: [PerLevelPoiStyle(iconStyle: iconStyle, level: 0)])
        lm.addPoiStyle(poiStyle)
    }

    func updateUserLocation(_ coordinate: CLLocationCoordinate2D?) {
        guard let map = kakaoMap else { return }

        // ensure user layer exists
        if map.getLabelManager().getLabelLayer(layerID: "userLayer") == nil {
            setupUserLayer()
        }

        guard let layer = map.getLabelManager().getLabelLayer(layerID: "userLayer") else { return }

        // remove old user poi then add new one (if any)
        layer.removePois(poiIDs: [userPoiID])

        guard let coord = coordinate else {
            // nothing to add
            return
        }

        let option = PoiOptions(styleID: "userStyle", poiID: userPoiID)
        option.clickable = false
        _ = layer.addPoi(option: option, at: MapPoint(longitude: coord.longitude, latitude: coord.latitude))
        layer.showAllPois()

        if trackingEnabled {
            let center = MapPoint(longitude: coord.longitude, latitude: coord.latitude)
            // Try dynamic Objective-C invocation for setMapCenter:animated:
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

    private func makeUserMarkerImage() -> UIImage {
        let size = CGSize(width: 20, height: 20)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let outerRect = CGRect(origin: .zero, size: size)
            let outerPath = UIBezierPath(ovalIn: outerRect)
            UIColor.systemBlue.setFill()
            outerPath.fill()

            let innerSize = CGSize(width: 8, height: 8)
            let innerRect = CGRect(x: (size.width - innerSize.width) / 2,
                                   y: (size.height - innerSize.height) / 2,
                                   width: innerSize.width,
                                   height: innerSize.height)
            let innerPath = UIBezierPath(ovalIn: innerRect)
            UIColor.white.setFill()
            innerPath.fill()
        }
    }

    private func updateMarkers(festivals: [Festival]) {
        guard let map = kakaoMap,
              let layer = map.getLabelManager().getLabelLayer(layerID: "festivalLayer") else { return }

        let oldIDs = Array(festivalDict.keys)
        if !oldIDs.isEmpty { layer.removePois(poiIDs: oldIDs) }
        festivalDict.removeAll()

        for festival in festivals {
            let option = PoiOptions(styleID: "festivalStyle", poiID: festival.id)
            option.rank = 0
            option.clickable = true
            _ = layer.addPoi(option: option, at: MapPoint(longitude: festival.longitude, latitude: festival.latitude))
            festivalDict[festival.id] = festival
        }
        layer.showAllPois()
    }

    private func makeMarkerImage() -> UIImage {
        let size = CGSize(width: 30, height: 30)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let fillColor = UIColor(red: 0.95, green: 0.47, blue: 0.22, alpha: 1.0)
            fillColor.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))

            // SF Symbol 사용: ticket.fill (작고 식별 가능한 아이콘)
            let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            if let symbol = UIImage(systemName: "ticket.fill", withConfiguration: config)?.withTintColor(.white, renderingMode: .alwaysOriginal) {
                let symSize = symbol.size
                let rect = CGRect(x: (size.width - symSize.width) / 2,
                                  y: (size.height - symSize.height) / 2,
                                  width: symSize.width,
                                  height: symSize.height)
                symbol.draw(in: rect)
            }
        }
    }
}
