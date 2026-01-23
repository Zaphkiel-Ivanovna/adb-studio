import Foundation

final class DeviceIdentifier {
    private let adbService: ADBService

    init(adbService: ADBService) {
        self.adbService = adbService
    }

    func getPersistentSerial(for device: Device) async -> String? {
        guard device.state == .device else {
            return nil
        }

        do {
            let serial = try await adbService.getProperty("ro.serialno", deviceId: device.adbId)
            return serial.isEmpty ? nil : serial
        } catch {
            print("Failed to get ro.serialno for \(device.adbId): \(error)")
            return nil
        }
    }

    func fetchDeviceProperties(for device: Device) async -> Device {
        guard device.state == .device else {
            return device
        }

        var updatedDevice = device

        let properties = [
            "ro.serialno",
            "ro.product.model",
            "ro.product.brand",
            "ro.product.manufacturer",
            "ro.build.version.release",
            "ro.build.version.sdk"
        ]

        do {
            let props = try await adbService.getProperties(properties, deviceId: device.adbId)

            if let serial = props["ro.serialno"], !serial.isEmpty {
                updatedDevice.persistentSerial = serial
            }

            if let model = props["ro.product.model"], !model.isEmpty {
                updatedDevice.model = model
            }

            if let brand = props["ro.product.brand"], !brand.isEmpty {
                updatedDevice.brand = brand.capitalized
            } else if let manufacturer = props["ro.product.manufacturer"], !manufacturer.isEmpty {
                updatedDevice.brand = manufacturer.capitalized
            }

            if let version = props["ro.build.version.release"], !version.isEmpty {
                updatedDevice.androidVersion = version
            }

            if let sdk = props["ro.build.version.sdk"], !sdk.isEmpty {
                updatedDevice.sdkVersion = sdk
            }
        } catch {
            print("Failed to fetch properties for \(device.adbId): \(error)")
        }

        return updatedDevice
    }

    func isSameDevice(_ device1: Device, _ device2: Device) -> Bool {
        if let serial1 = device1.persistentSerial,
           let serial2 = device2.persistentSerial {
            return serial1 == serial2
        }
        return device1.adbId == device2.adbId
    }
}
