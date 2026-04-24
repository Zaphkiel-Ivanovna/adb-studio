import Foundation
import Network
import Combine

@MainActor
final class DeviceDiscoveryService: NSObject, ObservableObject {
    @Published private(set) var discoveredDevices: [DiscoveredDevice] = []
    @Published private(set) var isScanning = false
    @Published private(set) var scanError: String?

    private var browsers: [NetServiceBrowser] = []
    private var resolvingServices: [NetService] = []
    private let historyStore: DeviceHistoryStore
    private var rawServices: [String: (name: String, host: String, port: Int, type: DiscoveredDevice.ServiceType)] = [:]

    private let serviceTypes: [(type: String, deviceType: DiscoveredDevice.ServiceType)] = [
        ("_adb-tls-connect._tcp.", .adbTlsConnect),
        ("_adb-tls-pairing._tcp.", .adbTlsPairing),
        ("_adb._tcp.", .adbLegacy)
    ]

    init(historyStore: DeviceHistoryStore) {
        self.historyStore = historyStore
        super.init()
    }

    func startScanning() {
        guard !isScanning else { return }

        stopScanning()
        isScanning = true
        scanError = nil
        discoveredDevices = []
        rawServices = [:]

        for (type, _) in serviceTypes {
            let browser = NetServiceBrowser()
            browser.delegate = self
            browsers.append(browser)
            browser.searchForServices(ofType: type, inDomain: "local.")
        }
    }

    func stopScanning() {
        browsers.forEach { $0.stop() }
        browsers.removeAll()
        resolvingServices.forEach { $0.stop() }
        resolvingServices.removeAll()
        isScanning = false
    }

    private func serviceTypeFor(_ netService: NetService) -> DiscoveredDevice.ServiceType? {
        serviceTypes.first { netService.type == $0.type }?.deviceType
    }

    func markDeviceConnecting(_ device: DiscoveredDevice, _ connecting: Bool) {
        guard let index = discoveredDevices.firstIndex(where: { $0.id == device.id }) else { return }
        discoveredDevices[index].isConnecting = connecting
    }

    func markDevicePaired(_ device: DiscoveredDevice) {
        guard let index = discoveredDevices.firstIndex(where: { $0.id == device.id }) else { return }
        discoveredDevices[index].isPaired = true
    }

    private func extractIPv4Address(from addresses: [Data]) -> String? {
        for addressData in addresses {
            guard addressData.count >= MemoryLayout<sockaddr>.size else { continue }

            let family = addressData.withUnsafeBytes { $0.load(as: sockaddr.self).sa_family }

            if family == sa_family_t(AF_INET) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let result = addressData.withUnsafeBytes { ptr -> Int32 in
                    let sockaddrPtr = ptr.baseAddress!.assumingMemoryBound(to: sockaddr.self)
                    return getnameinfo(sockaddrPtr, socklen_t(addressData.count),
                                       &hostname, socklen_t(hostname.count),
                                       nil, 0, NI_NUMERICHOST)
                }
                if result == 0 {
                    return String(cString: hostname)
                }
            }
        }
        return nil
    }

    private func rebuildDeviceList() {
        var devicesByIP: [String: (name: String, services: [DiscoveredDevice.ServiceInfo])] = [:]

        for (_, service) in rawServices {
            let serviceInfo = DiscoveredDevice.ServiceInfo(type: service.type, port: service.port)

            if var existing = devicesByIP[service.host] {
                if !existing.services.contains(where: { $0.type == service.type }) {
                    existing.services.append(serviceInfo)
                    devicesByIP[service.host] = existing
                }
            } else {
                devicesByIP[service.host] = (name: service.name, services: [serviceInfo])
            }
        }

        discoveredDevices = devicesByIP.map { (ip, data) in
            let isPaired = historyStore.allHistory().contains { $0.lastKnownIP == ip }
            let bestName = rawServices.values
                .filter { $0.host == ip }
                .map { $0.name }
                .min { $0.count < $1.count } ?? data.name

            return DiscoveredDevice(
                id: ip,
                name: bestName,
                host: ip,
                services: data.services.sorted { $0.type.priority < $1.type.priority },
                isPaired: isPaired
            )
        }.sorted { $0.host < $1.host }
    }

    private func removeService(id: String) {
        guard rawServices.removeValue(forKey: id) != nil else { return }
        rebuildDeviceList()
    }
}

// MARK: - NetServiceBrowserDelegate

extension DeviceDiscoveryService: NetServiceBrowserDelegate {
    nonisolated func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        Task { @MainActor in
            service.delegate = self
            resolvingServices.append(service)
            service.resolve(withTimeout: 10.0)
        }
    }

    nonisolated func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        Task { @MainActor in
            removeService(id: "\(service.name)-\(service.type)")
        }
    }

    nonisolated func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        Task { @MainActor in
            scanError = "Discovery failed"
        }
    }

    nonisolated func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        Task { @MainActor in }
    }
}

// MARK: - NetServiceDelegate

extension DeviceDiscoveryService: NetServiceDelegate {
    nonisolated func netServiceDidResolveAddress(_ sender: NetService) {
        Task { @MainActor in
            guard let serviceType = serviceTypeFor(sender),
                  let addresses = sender.addresses, !addresses.isEmpty,
                  let ipAddress = extractIPv4Address(from: addresses),
                  sender.port > 0 else {
                resolvingServices.removeAll { $0 === sender }
                return
            }

            let serviceId = "\(sender.name)-\(sender.type)"

            // Android re-advertises on a new port after pairing/restart. Evict any
            // stale entry for the same (host, type) so only the fresh one remains.
            for (key, existing) in rawServices
                where key != serviceId && existing.host == ipAddress && existing.type == serviceType {
                rawServices.removeValue(forKey: key)
            }

            rawServices[serviceId] = (name: sender.name, host: ipAddress, port: sender.port, type: serviceType)
            rebuildDeviceList()
            resolvingServices.removeAll { $0 === sender }
        }
    }

    nonisolated func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        Task { @MainActor in
            resolvingServices.removeAll { $0 === sender }
        }
    }
}
