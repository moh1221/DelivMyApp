import DelivMyCore
import MapKit
import SwiftUI
import UIKit

enum RequestMode: Equatable {
    case mine, deliveries, nearby

    var title: String {
        switch self {
        case .mine: "My Requests"
        case .deliveries: "My Deliveries"
        case .nearby: "Nearby"
        }
    }

    var emptyMessage: String {
        switch self {
        case .mine: "Requests you place appear here."
        case .deliveries: "Requests you accept appear here."
        case .nearby: "No nearby requests in this area."
        }
    }
}

struct RequestList: View {
    let client: APIClient
    let session: AuthSession
    let account: AccountModel
    let kind: RequestMode

    @State private var entries: [DeliveryRequest] = []
    @State private var loadID = UUID()
    @State private var loaded = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if isLoading { ProgressView("Loading…") }
                if let errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(errorMessage).foregroundStyle(.secondary)
                        Button("Try again") { Task { await load() } }
                            .disabled(isLoading)
                    }
                } else if loaded && entries.isEmpty && !isLoading {
                    Text(kind.emptyMessage).foregroundStyle(.secondary)
                }
                ForEach(entries) { request in
                    NavigationLink {
                        RequestDetail(request: request, mode: kind, client: client, session: session, account: account)
                    } label: {
                        RequestRow(request: request, client: client)
                    }
                }
            }
            .navigationTitle(kind.title)
            .refreshable { await load() }
        }
        .task(id: account.changeID) { await load() }
    }

    private func load() async {
        guard !Task.isCancelled else { return }
        let requestID = UUID()
        let change = account.changeID
        loadID = requestID
        isLoading = true
        errorMessage = nil
        defer {
            if loadID == requestID { isLoading = false }
        }
        do {
            let items = switch kind {
            case .mine: try await client.requests(session: session)
            case .deliveries: try await client.deliveries(session: session)
            case .nearby: [DeliveryRequest]()
            }
            try Task.checkCancellation()
            guard loadID == requestID, account.changeID == change else { return }
            entries = items
            loaded = true
        } catch {
            guard !Task.isCancelled, loadID == requestID, account.changeID == change else { return }
            errorMessage = account.failureMessage(error)
        }
    }
}

struct RequestRow: View {
    let request: DeliveryRequest
    let client: APIClient

    var body: some View {
        HStack(spacing: 12) {
            if let profile = request.profile {
                ProfileAvatar(profile: profile, client: client)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(request.name).font(.headline)
                if let category = request.category {
                    Text(category).font(.subheadline).foregroundStyle(.secondary)
                }
                Text(request.status.title).font(.subheadline)
                if let due = request.due {
                    Text("Due \(due.formatted(date: .abbreviated, time: .shortened))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let fee = request.fee {
                Text(fee, format: .currency(code: "USD"))
                    .font(.subheadline.weight(.semibold))
                    .accessibilityLabel(Text("Delivery fee \(fee.formatted(.currency(code: "USD")))"))
            }
        }
        .padding(.vertical, 4)
    }
}

struct RequestDetail: View {
    let request: DeliveryRequest
    let mode: RequestMode
    let client: APIClient
    let session: AuthSession
    let account: AccountModel

    @Environment(\.dismiss) private var dismiss
    @State private var items: [DeliveryItem] = []
    @State private var location: DeliveryLocation?
    @State private var itemsError: String?
    @State private var locationError: String?
    @State private var loading = true
    @State private var mutating = false
    @State private var confirmation = false

    var body: some View {
        List {
            Section("Request #\(request.id)") {
                LabeledContent("Status", value: request.status.title)
                if let category = request.category { LabeledContent("Category", value: category) }
                if let due = request.due {
                    LabeledContent("Delivery by", value: due.formatted(date: .abbreviated, time: .shortened))
                }
                if let cost = request.cost { LabeledContent("Item cost", value: cost.formatted(.currency(code: "USD"))) }
                if let fee = request.fee { LabeledContent("Delivery fee", value: fee.formatted(.currency(code: "USD"))) }
            }
            if request.profile != nil || request.delivery?.profile != nil {
                Section("People") {
                    if let profile = request.profile { person("Requester", profile: profile) }
                    if let profile = request.delivery?.profile { person("Courier", profile: profile) }
                }
            }
            Section("Items") {
                if loading && items.isEmpty { ProgressView("Loading items…") }
                if let itemsError {
                    Text(itemsError).foregroundStyle(.secondary)
                } else if !loading && items.isEmpty {
                    Text("No items listed.").foregroundStyle(.secondary)
                }
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name ?? "Item #\(item.id)")
                        if let notes = item.notes, !notes.isEmpty {
                            Text(notes).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("Location") {
                if let address = location?.address, !address.isEmpty { Text(address) }
                if let coordinate = location?.coordinate, let url = mapsURL(coordinate) {
                    Link("Open delivery location in Maps", destination: url)
                } else if loading {
                    ProgressView("Loading location…")
                } else if let locationError {
                    Text(locationError).foregroundStyle(.secondary)
                } else if location?.address == nil {
                    Text("Location is not available.").foregroundStyle(.secondary)
                }
            }
            if let delivery = request.delivery {
                Section("Delivery") {
                    if let completedAt = delivery.completedAt {
                        LabeledContent("Completed", value: completedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    if let receipt = client.mediaURL(delivery.receiptImage) {
                        RemoteImage(client: client, url: receipt) { image in
                            image.resizable().scaledToFit().frame(maxHeight: 300).accessibilityLabel("Receipt")
                        } placeholder: {
                            Text("Receipt image").foregroundStyle(.secondary)
                        }
                    } else {
                        Text("No receipt available.").foregroundStyle(.secondary)
                    }
                }
            }
            if canMutate {
                Section {
                    Button(actionTitle, role: mode == .mine ? .destructive : nil) { confirmation = true }
                        .disabled(mutating || account.signingOut)
                    if mutating { ProgressView("Updating…") }
                }
            }
        }
        .navigationTitle(request.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadDetails() }
        .refreshable { await loadDetails() }
        .confirmationDialog(confirmationTitle, isPresented: $confirmation, titleVisibility: .visible) {
            Button(actionTitle, role: mode == .mine ? .destructive : nil) {
                Task { await mutate() }
            }
        }
    }

    private var canMutate: Bool {
        (mode == .mine && request.status == .open) || (mode == .nearby && request.isAcceptable)
    }

    private var actionTitle: String { mode == .mine ? "Delete request" : "Accept delivery" }
    private var confirmationTitle: String {
        mode == .mine ? "Delete this request?" : "Accept this delivery?"
    }

    private func person(_ role: String, profile: Profile) -> some View {
        HStack(spacing: 12) {
            ProfileAvatar(profile: profile, client: client)
            LabeledContent(role, value: profile.displayName ?? "Name unavailable")
        }
    }

    private func mapsURL(_ coordinate: Coordinate) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "maps.apple.com"
        components.queryItems = [
            URLQueryItem(name: "ll", value: "\(coordinate.latitude),\(coordinate.longitude)"),
            URLQueryItem(name: "q", value: request.name)
        ]
        // The URL is generated from validated numeric coordinates and percent-encoded query items.
        return components.url
    }

    private func loadDetails() async {
        loading = true
        itemsError = nil
        locationError = nil
        defer { loading = false }
        if let snapshot = request.items, snapshot.allSatisfy({ $0.name != nil }) { items = snapshot }
        if location == nil { location = request.location }
        async let itemResponse = fetchItems()
        async let locationResponse = fetchLocation()
        _ = await (itemResponse, locationResponse)
    }

    private func fetchItems() async {
        do {
            let result = try await client.items(requestID: request.id, session: session)
            try Task.checkCancellation()
            items = result
        } catch {
            if (error as? APIError) == .forbidden || (error as? APIError) == .notFound { items = [] }
            itemsError = account.failureMessage(error)
        }
    }

    private func fetchLocation() async {
        do {
            let result = try await client.location(requestID: request.id, session: session)
            try Task.checkCancellation()
            location = result
        } catch {
            if (error as? APIError) == .forbidden || (error as? APIError) == .notFound { location = nil }
            locationError = account.failureMessage(error)
        }
    }

    private func mutate() async {
        guard canMutate, !mutating, !account.signingOut else { return }
        mutating = true
        defer { mutating = false }
        do {
            if mode == .mine {
                try await client.delete(requestID: request.id, session: session)
            } else {
                try await client.accept(requestID: request.id, session: session)
            }
            account.refreshLists()
            dismiss()
            if mode == .nearby {
                account.notice = "Delivery #\(request.id) accepted. It’s in My Deliveries."
            }
        } catch {
            _ = account.present(error)
            if (error as? APIError) == .conflict || (error as? APIError) == .notFound {
                account.refreshLists()
                dismiss()
            }
        }
    }
}

private struct ProfileAvatar: View {
    let profile: Profile
    let client: APIClient

    var body: some View {
        RemoteImage(client: client, url: client.mediaURL(profile.picture)) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Image(systemName: "person.circle")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

private struct RemoteImage<Content: View, Placeholder: View>: View {
    let client: APIClient
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            image = nil
            guard let url, let bytes = try? await client.imageData(at: url), !Task.isCancelled else { return }
            image = UIImage(data: bytes)
        }
    }
}
