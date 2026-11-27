import CoreLocation
import DelivMyCore
import MapKit
import Observation
import SwiftUI

struct NearbyView: View {
    let client: APIClient
    let session: AuthSession
    let account: AccountModel

    @Environment(\.scenePhase) private var scenePhase
    @State private var position: MapCameraPosition = .region(Self.initialRegion)
    @State private var region = Self.initialRegion
    @State private var lastSearchRegion = Self.initialRegion
    @State private var entries: [DeliveryRequest] = []
    @State private var selected: DeliveryRequest?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var autoRefresh = false
    @State private var generation = UUID()
    @State private var locationAccess = LocationAccess()

    private static let initialRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.005, longitude: -77.403),
        span: MKCoordinateSpan(latitudeDelta: 0.14, longitudeDelta: 0.14)
    )

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Map(position: $position) {
                    if locationAccess.coordinate != nil { UserAnnotation() }
                    ForEach(entries) { request in
                        if let coordinate = request.location?.coordinate {
                            Annotation(request.name, coordinate: coordinate.mapCoordinate, anchor: .bottom) {
                                Button {
                                    selected = request
                                } label: {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.title2)
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, Color.accentColor)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(request.name)
                            }
                        }
                    }
                }
                .frame(minHeight: 180, idealHeight: 280, maxHeight: 320)
                .onMapCameraChange(frequency: .onEnd) { context in region = context.region }
                .onChange(of: locationAccess.updateID) { _, _ in
                    guard let coordinate = locationAccess.coordinate else { return }
                    let updated = MKCoordinateRegion(center: coordinate.mapCoordinate, span: Self.initialRegion.span)
                    position = .region(updated)
                    region = updated
                    refreshCurrentRegion()
                }
                HStack {
                    Button("Search this area", systemImage: "magnifyingglass", action: refreshCurrentRegion)
                        .buttonStyle(.borderedProminent)
                    Spacer()
                    Button {
                        locationAccess.locate()
                    } label: {
                        Label("Use my location", systemImage: "location")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                if let warning = locationAccess.warning {
                    Text(warning)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
                List {
                    if isLoading { ProgressView("Finding requests…") }
                    if let errorMessage { Text(errorMessage).foregroundStyle(.secondary) }
                    if entries.isEmpty && !isLoading && errorMessage == nil {
                        Text("No open requests in this area. Move the map, then search again.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(entries) { request in
                        Button {
                            selected = request
                        } label: {
                            RequestRow(request: request, client: client)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
                .refreshable { refreshCurrentRegion() }
            }
            .navigationTitle("Nearby")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Toggle("Auto-refresh", isOn: $autoRefresh)
                    } label: {
                        Label("Search options", systemImage: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $selected) { request in
                NavigationStack {
                    RequestDetail(request: request, mode: .nearby, client: client, session: session, account: account)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { selected = nil }
                            }
                        }
                }
            }
        }
        .task(id: generation) { await load() }
        .onChange(of: account.changeID) { _, _ in generation = UUID() }
        .task(id: autoRefresh && scenePhase == .active) {
            guard autoRefresh, scenePhase == .active else { return }
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(15)) } catch { return }
                if !isLoading { generation = UUID() }
            }
        }
    }

    private func refreshCurrentRegion() {
        lastSearchRegion = region
        generation = UUID()
    }

    private func load() async {
        let activeGeneration = generation
        isLoading = true
        errorMessage = nil
        defer { if generation == activeGeneration { isLoading = false } }
        do {
            let searchRegions = try lastSearchRegion.searchBounds()
            var results: [DeliveryRequest] = []
            var seen = Set<Int>()
            for bounds in searchRegions {
                let page = try await client.nearby(bounds, session: session)
                results.append(contentsOf: page.filter { seen.insert($0.id).inserted })
            }
            try Task.checkCancellation()
            guard generation == activeGeneration else { return }
            entries = results
        } catch {
            guard generation == activeGeneration, !Task.isCancelled else { return }
            errorMessage = account.failureMessage(error)
        }
    }
}

@MainActor
@Observable
private final class LocationAccess: NSObject, CLLocationManagerDelegate {
    @ObservationIgnored private lazy var manager: CLLocationManager = {
        let value = CLLocationManager()
        value.delegate = self
        value.desiredAccuracy = kCLLocationAccuracyKilometer
        return value
    }()

    @ObservationIgnored private var awaitingPermission = false
    var coordinate: Coordinate?
    var updateID = UUID()
    var warning: String?

    func locate() {
        warning = nil
        switch manager.authorizationStatus {
        case .notDetermined:
            awaitingPermission = true
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
        default: warning = "Location is unavailable. You can still move the map to search."
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self, self.awaitingPermission else { return }
            switch self.manager.authorizationStatus {
            case .notDetermined: break
            case .authorizedWhenInUse, .authorizedAlways:
                self.awaitingPermission = false
                self.manager.requestLocation()
            default:
                self.awaitingPermission = false
                self.warning = "Location access is off. You can still move the map to search."
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let value = locations.last?.coordinate else { return }
        let position = Coordinate(latitude: value.latitude, longitude: value.longitude)
        Task { @MainActor [weak self] in
            guard let self, let position else { return }
            self.coordinate = position
            self.updateID = UUID()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.warning = "Couldn’t get your location. Try again or search from the map."
        }
    }
}

extension Coordinate {
    var mapCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private extension MKCoordinateRegion {
    func searchBounds() throws -> [SearchBounds] {
        guard let midpoint = Coordinate(latitude: center.latitude, longitude: center.longitude) else {
            throw APIError.invalidRequest
        }
        let south = max(-90, center.latitude - span.latitudeDelta / 2)
        let north = min(90, center.latitude + span.latitudeDelta / 2)
        guard span.latitudeDelta <= 40, span.longitudeDelta <= 40 else {
            throw SearchAreaError.zoomIn
        }
        let west = center.longitude - span.longitudeDelta / 2
        let east = center.longitude + span.longitudeDelta / 2
        let longitudeRanges: [(Double, Double)]
        if west < -180 {
            longitudeRanges = [(west + 360, 180), (-180, east)]
        } else if east > 180 {
            longitudeRanges = [(west, 180), (-180, east - 360)]
        } else {
            longitudeRanges = [(west, east)]
        }
        return try longitudeRanges.map { west, east in
            guard let sw = Coordinate(latitude: south, longitude: west),
                  let ne = Coordinate(latitude: north, longitude: east),
                  let bounds = SearchBounds(southwest: sw, northeast: ne, center: midpoint) else {
                throw APIError.invalidRequest
            }
            return bounds
        }
    }
}

private enum SearchAreaError: LocalizedError {
    case zoomIn
    var errorDescription: String? { "Zoom in on the map to search a smaller area." }
}
