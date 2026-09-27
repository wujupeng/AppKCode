import SwiftUI
import AppKCodeShared
import AppKCodeApplication

struct ModelProviderSettingsView: View {
    @ObservedObject var service: ModelProviderSettingsViewModel

    var body: some View {
        Form {
            Section("Providers") {
                ForEach(service.providers, id: \.id) { provider in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(provider.config.modelName)
                                .font(.body)
                            Text(provider.config.endpoint.absoluteString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Mode: \(provider.config.mode.rawValue)")
                                .font(.caption2)
                                .foregroundColor(modeColor(provider.config.mode))
                        }
                        Spacer()
                        if provider.id == service.defaultProviderID {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                        }
                    }
                }
            }

            Section("Local Mode (Default)") {
                LabeledContent("Endpoint") {
                    Text(LocalModeDefaults.endpoint.absoluteString)
                        .foregroundColor(.secondary)
                }
                LabeledContent("Model") {
                    Text(LocalModeDefaults.modelName)
                        .foregroundColor(.secondary)
                }
            }

            Section("Add Cloud Provider") {
                TextField("Endpoint URL", text: $service.cloudEndpoint)
                SecureField("API Key", text: $service.cloudAPIKey)
                TextField("Model Name", text: $service.cloudModelName)
                Button("Add Cloud Provider") {
                    service.addCloudProvider()
                }
                .disabled(service.cloudEndpoint.isEmpty || service.cloudAPIKey.isEmpty || service.cloudModelName.isEmpty)
                if let error = service.cloudError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func modeColor(_ mode: ModelProviderMode) -> Color {
        switch mode {
        case .local: return .green
        case .cloud: return .blue
        }
    }
}

@MainActor
public final class ModelProviderSettingsViewModel: ObservableObject {
    @Published public var providers: [ModelProviderInfo] = []
    @Published public var defaultProviderID: ModelProviderID?
    @Published public var cloudEndpoint: String = ""
    @Published public var cloudAPIKey: String = ""
    @Published public var cloudModelName: String = ""
    @Published public var cloudError: String? = nil

    private let appService: ModelProviderApplicationService

    public init(appService: ModelProviderApplicationService) {
        self.appService = appService
        refresh()
    }

    public func refresh() {
        providers = appService.allProviders.map { ModelProviderInfo(id: $0.id, config: $0.config) }
        defaultProviderID = appService.defaultProvider().id
    }

    public func addCloudProvider() {
        guard let url = URL(string: cloudEndpoint) else {
            cloudError = "Invalid endpoint URL"
            return
        }
        let config = ModelProviderConfig(
            kind: .cloudModel,
            mode: .cloud,
            endpoint: url,
            apiKey: cloudAPIKey,
            modelName: cloudModelName
        )
        do {
            try appService.configureCloud(config)
            cloudEndpoint = ""
            cloudAPIKey = ""
            cloudModelName = ""
            cloudError = nil
            refresh()
        } catch {
            cloudError = error.localizedDescription
        }
    }
}

public struct ModelProviderInfo: Identifiable {
    public let id: ModelProviderID
    public let config: ModelProviderConfig
    public init(id: ModelProviderID, config: ModelProviderConfig) {
        self.id = id
        self.config = config
    }
}