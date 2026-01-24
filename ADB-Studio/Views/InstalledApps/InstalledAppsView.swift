import SwiftUI

struct InstalledAppsView: View {
    @StateObject private var viewModel: InstalledAppsViewModel

    init(deviceId: String, adbService: ADBService) {
        _viewModel = StateObject(wrappedValue: InstalledAppsViewModel(
            deviceId: deviceId,
            adbService: adbService
        ))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView

            Divider()
                .padding(.horizontal)

            filterBar
                .padding(.horizontal)
                .padding(.top, 12)

            if viewModel.isLoading && viewModel.apps.isEmpty {
                loadingView
            } else if viewModel.apps.isEmpty {
                emptyView
            } else {
                appList
            }

            footerView
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .onAppear {
            if viewModel.apps.isEmpty {
                Task {
                    await viewModel.loadApps()
                }
            }
        }
        .alert("Uninstall App", isPresented: $viewModel.showUninstallConfirmation) {
            Button("Cancel", role: .cancel) {
                viewModel.cancelUninstall()
            }
            Button("Uninstall", role: .destructive) {
                Task {
                    await viewModel.confirmUninstall()
                }
            }
        } message: {
            if let app = viewModel.appToUninstall {
                if viewModel.keepDataOnUninstall {
                    Text("Are you sure you want to uninstall \(app.effectiveDisplayName)? App data will be preserved.")
                } else {
                    Text("Are you sure you want to uninstall \(app.effectiveDisplayName)? This cannot be undone.")
                }
            }
        }
    }

    private var headerView: some View {
        HStack {
            Label("Installed Apps", systemImage: "square.grid.2x2")
                .font(.headline)

            Spacer()

            Button {
                Task {
                    await viewModel.loadApps()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.isLoading)
        }
        .padding(.bottom, 8)
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search apps...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)

            Picker("Filter", selection: $viewModel.filter) {
                ForEach(AppFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 120)

            Picker("Sort", selection: $viewModel.sortOrder) {
                ForEach(AppSortOrder.allCases) { order in
                    Text(order.rawValue).tag(order)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading apps...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "app.dashed")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No apps found")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var appList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: []) {
                ForEach(viewModel.filteredApps) { app in
                    InstalledAppRow(
                        app: app,
                        isActioning: viewModel.appBeingActioned == app.packageName,
                        onAction: { action in
                            if action == .uninstall {
                                viewModel.requestUninstall(app, keepData: false)
                            } else if action == .uninstallKeepData {
                                viewModel.requestUninstall(app, keepData: true)
                            } else {
                                Task {
                                    await viewModel.performAction(action, on: app)
                                }
                            }
                        }
                    )
                    .id(app.packageName)
                    .onAppear {
                        viewModel.loadDetailsIfNeeded(for: app)
                    }

                    if app.id != viewModel.filteredApps.last?.id {
                        Divider()
                            .padding(.leading, 48)
                    }
                }
            }
        }
        .frame(height: 350)
        .padding(.top, 8)
    }

    private var footerView: some View {
        HStack {
            Text(viewModel.appCount)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(1)
            } else if let success = viewModel.successMessage {
                Text(success)
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding(.top, 12)
    }
}
