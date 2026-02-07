//
//  BLEManager.swift
//  PinecilTime
//

import CoreBluetooth
import Foundation

@Observable
class BLEManager: NSObject {

    // MARK: - State

    var isScanning = false
    var discoveredDevices: [CBPeripheral] = []
    var connectedPeripheral: CBPeripheral?
    var connectionState: ConnectionState = .disconnected
    var liveData = IronOSLiveData()
    var deviceName: String = ""
    var firmwareVersion: String = ""
    var buildID: String = ""
    var deviceSerial: String = ""

    // Temperature history for graph
    var temperatureHistory: [TemperaturePoint] = []
    private let maxHistoryPoints = 60

    // MARK: - Private

    private var centralManager: CBCentralManager!
    private var discoveredCharacteristics: [CBUUID: CBCharacteristic] = [:]
    private var pollTimer: Timer?
    private var scanTimer: Timer?
    private let bleQueue = DispatchQueue(label: "com.pineciltime.ble", qos: .userInitiated)
    private var pendingWrites: [CBUUID: UInt16] = [:]
    private var settingReadCompletions: [CBUUID: (UInt16?) -> Void] = [:]

    // MARK: - Init

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: bleQueue)
    }

    // MARK: - Connection State

    enum ConnectionState: Equatable {
        case disconnected
        case scanning
        case connecting
        case connected
        case error(String)

        var isConnected: Bool {
            self == .connected
        }

        var isConnecting: Bool {
            self == .connecting
        }
    }

    // MARK: - Public Methods

    func startScanning() {
        guard centralManager.state == .poweredOn else { return }

        scanTimer?.invalidate()
        discoveredDevices.removeAll()
        connectionState = .scanning

        centralManager.scanForPeripherals(
            withServices: [IronOSUUIDs.bulkDataService],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        isScanning = true

        // Timeout after 10 seconds
        scanTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            self?.stopScanning()
        }
    }

    func stopScanning() {
        scanTimer?.invalidate()
        scanTimer = nil
        centralManager.stopScan()
        isScanning = false
        if connectionState == .scanning {
            connectionState = .disconnected
        }
    }

    func connect(to peripheral: CBPeripheral) {
        stopScanning()
        connectionState = .connecting
        connectedPeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect() {
        stopPolling()

        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }

        connectionState = .disconnected
        connectedPeripheral = nil
        discoveredCharacteristics.removeAll()
        temperatureHistory.removeAll()
    }

    func setTemperature(_ temp: UInt32) {
        writeSetting(index: 0, value: UInt16(temp))
    }
    
    func writeSetting(index: UInt16, value: UInt16) {
        guard connectionState == .connected,
              let peripheral = connectedPeripheral else {
            return
        }
        
        let uuid = IronOSUUIDs.settingUUID(index: index)
        
        // If we have the characteristic cached, use it
        if let characteristic = discoveredCharacteristics[uuid] {
            peripheral.writeValue(value.data, for: characteristic, type: .withResponse)
        } else {
            // Otherwise discover it first
            if let settingsService = peripheral.services?.first(where: { $0.uuid == IronOSUUIDs.settingsService }) {
                peripheral.discoverCharacteristics([uuid], for: settingsService)
                // Store for later write after discovery
                pendingWrites[uuid] = value
            }
        }
    }
    
    func readSetting(index: UInt16, completion: @escaping (UInt16?) -> Void) {
        guard connectionState == .connected,
              let peripheral = connectedPeripheral else {
            completion(nil)
            return
        }
        
        let uuid = IronOSUUIDs.settingUUID(index: index)
        
        // Store completion handler
        settingReadCompletions[uuid] = completion
        
        if let characteristic = discoveredCharacteristics[uuid] {
            peripheral.readValue(for: characteristic)
        } else {
            // Discover it first
            if let settingsService = peripheral.services?.first(where: { $0.uuid == IronOSUUIDs.settingsService }) {
                peripheral.discoverCharacteristics([uuid], for: settingsService)
            }
        }
    }
    
    func saveSettings() {
        guard connectionState == .connected,
              let peripheral = connectedPeripheral,
              let characteristic = discoveredCharacteristics[IronOSUUIDs.saveSettings] else {
            return
        }
        
        let value = UInt16(1).data
        peripheral.writeValue(value, for: characteristic, type: .withResponse)
    }

    func setSlowPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.readBulkData()
        }
    }

    func setFastPolling() {
        guard connectionState == .connected else { return }
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.readBulkData()
        }
    }

    // MARK: - Polling

    private func startPolling() {
        stopPolling()

        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.readBulkData()
        }

        readBulkData()
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func readBulkData() {
        guard let characteristic = discoveredCharacteristics[IronOSUUIDs.bulkLiveData],
              let peripheral = connectedPeripheral else { return }

        peripheral.readValue(for: characteristic)
    }

    private func recordTemperature() {
        let point = TemperaturePoint(
            timestamp: Date(),
            actualTemp: liveData.liveTemp,
            setpoint: liveData.setpoint
        )

        temperatureHistory.append(point)

        // Keep only last N points
        if temperatureHistory.count > maxHistoryPoints {
            temperatureHistory.removeFirst()
        }
    }

    private func handleCharacteristicValue(_ characteristic: CBCharacteristic) {
        guard let value = characteristic.value else { return }

        DispatchQueue.main.async { [self] in
            switch characteristic.uuid {
            case IronOSUUIDs.bulkLiveData:
                liveData.updateFromBulkData(value)
                recordTemperature()

            case IronOSUUIDs.liveTemp:
                liveData.liveTemp = value.toUInt32() ?? 0
            case IronOSUUIDs.setpointRead:
                liveData.setpoint = value.toUInt32() ?? 0
            case IronOSUUIDs.dcInput:
                liveData.dcInput = value.toUInt32() ?? 0
            case IronOSUUIDs.handleTemp:
                liveData.handleTemp = value.toUInt32() ?? 0
            case IronOSUUIDs.powerLevel:
                liveData.powerLevel = value.toUInt32() ?? 0
            case IronOSUUIDs.powerSource:
                liveData.powerSource = value.toUInt32() ?? 0
            case IronOSUUIDs.operatingMode:
                liveData.operatingMode = value.toUInt32() ?? 0
            case IronOSUUIDs.estimatedWatts:
                liveData.estimatedWatts = value.toUInt32() ?? 0
            case IronOSUUIDs.maxTemp:
                liveData.maxTemp = value.toUInt32() ?? 450

            case IronOSUUIDs.buildID:
                // Build version is the actual firmware version string
                firmwareVersion = value.toString() ?? ""
                buildID = value.toString() ?? ""
            
            case IronOSUUIDs.deviceSerial:
                if let serial = value.toUInt64() {
                    deviceSerial = String(format: "%016llX", serial)
                }

            default:
                break
            }
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async { [self] in
            switch central.state {
            case .poweredOn:
                startScanning()
            case .poweredOff:
                connectionState = .error("Bluetooth is off")
            case .unauthorized:
                connectionState = .error("Bluetooth access denied")
            case .unsupported:
                connectionState = .error("Bluetooth not supported")
            default:
                break
            }
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        DispatchQueue.main.async { [self] in
            // Auto-connect to first discovered Pinecil
            if connectedPeripheral == nil {
                // Match either Pinecil-* or by the advertised service UUID
                if peripheral.name?.hasPrefix("Pinecil-") == true ||
                   peripheral.name?.hasPrefix("PrattlePin-") == true ||
                   (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?.contains(IronOSUUIDs.bulkDataService) == true {
                    connect(to: peripheral)
                    return
                }
            }

            if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                discoveredDevices.append(peripheral)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async { [self] in
            connectionState = .connected
            deviceName = peripheral.name ?? "Pinecil"
        }
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        DispatchQueue.main.async { [self] in
            connectionState = .error(error?.localizedDescription ?? "Connection failed")
            connectedPeripheral = nil
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        DispatchQueue.main.async { [self] in
            stopPolling()
            connectionState = .disconnected
            connectedPeripheral = nil
            discoveredCharacteristics.removeAll()
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }

        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            discoveredCharacteristics[characteristic.uuid] = characteristic

            // Read bulk data and device info on connect
            if characteristic.uuid == IronOSUUIDs.bulkLiveData ||
               characteristic.uuid == IronOSUUIDs.buildID ||
               characteristic.uuid == IronOSUUIDs.deviceSerial {
                peripheral.readValue(for: characteristic)
            }

            // Enable notifications for operating mode
            if characteristic.uuid == IronOSUUIDs.operatingMode {
                peripheral.setNotifyValue(true, for: characteristic)
            }
            
            // Handle pending writes for dynamically discovered settings
            if let pendingValue = pendingWrites[characteristic.uuid] {
                peripheral.writeValue(pendingValue.data, for: characteristic, type: .withResponse)
                pendingWrites.removeValue(forKey: characteristic.uuid)
            }
            
            // Handle pending reads for dynamically discovered settings
            if settingReadCompletions[characteristic.uuid] != nil {
                peripheral.readValue(for: characteristic)
            }
        }

        // Start polling once we have the live data service
        if service.uuid == IronOSUUIDs.liveDataService || service.uuid == IronOSUUIDs.bulkDataService {
            DispatchQueue.main.async { [self] in
                startPolling()
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if error != nil { return }
        
        // Check if this is a setting read completion
        if let completion = settingReadCompletions[characteristic.uuid] {
            let value = characteristic.value?.withUnsafeBytes { $0.load(as: UInt16.self) }
            DispatchQueue.main.async {
                completion(value)
            }
            settingReadCompletions.removeValue(forKey: characteristic.uuid)
            return
        }
        
        handleCharacteristicValue(characteristic)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
    }
}
