//
//  BLEManager.swift
//  TinkCil
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

    // Temperature history for graph (circular buffer)
    var temperatureHistory = CircularBuffer<TemperaturePoint>(capacity: 60)
    var temperatureHistoryArray: [TemperaturePoint] { temperatureHistory.elements }
    
    // Settings cache
    var settingsCache = SettingsCache()
    
    // Error state
    var lastError: BLEError?

    // MARK: - Private

    private var centralManager: CBCentralManager!
    private var discoveredCharacteristics: [CBUUID: CBCharacteristic] = [:]
    private var pollTimer: Timer?
    private var scanTimer: Timer?
    private let bleQueue = DispatchQueue(label: "sh.dunkirk.tinkcil.ble", qos: .userInitiated)
    private let timerQueue = DispatchQueue.main
    private let operationQueue = DispatchQueue(label: "sh.dunkirk.tinkcil.operations", qos: .userInitiated)
    private var pendingWrites: [CBUUID: UInt16] = [:]
    private var settingReadCompletions: [CBUUID: (UInt16?) -> Void] = [:]
    private var operationTimeouts: [CBUUID: DispatchWorkItem] = [:]

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
        timerQueue.async { [weak self] in
            guard let self else { return }
            self.scanTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
                self?.stopScanning()
            }
            if let timer = self.scanTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
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

        // Clean up all state
        operationQueue.sync {
            // Cancel all pending operations
            for timeout in operationTimeouts.values {
                timeout.cancel()
            }
            operationTimeouts.removeAll()
            pendingWrites.removeAll()
            settingReadCompletions.removeAll()
        }

        connectionState = .disconnected
        connectedPeripheral = nil
        discoveredCharacteristics.removeAll()
        temperatureHistory.clear()
        lastError = nil
    }

    @MainActor
    func setTemperature(_ temp: UInt32) {
        writeSetting(index: 0, value: UInt16(temp))
    }
    
    @MainActor
    func writeSetting(index: UInt16, value: UInt16) {
        guard connectionState == .connected,
              let peripheral = connectedPeripheral else {
            lastError = .notConnected
            return
        }

        let uuid = IronOSUUIDs.settingUUID(index: index)

        operationQueue.sync {
            // If we have the characteristic cached, use it
            if let characteristic = discoveredCharacteristics[uuid] {
                peripheral.writeValue(value.data, for: characteristic, type: .withResponse)
                settingsCache.set(value, for: index)
                scheduleOperationTimeout(for: uuid, type: "write")
            } else {
                // Otherwise discover it first
                if let settingsService = peripheral.services?.first(where: { $0.uuid == IronOSUUIDs.settingsService }) {
                    peripheral.discoverCharacteristics([uuid], for: settingsService)
                    // Store for later write after discovery
                    pendingWrites[uuid] = value
                    scheduleOperationTimeout(for: uuid, type: "discover-write")
                } else {
                    lastError = .characteristicNotFound(uuid)
                }
            }
        }
    }
    
    @MainActor
    func readSetting(index: UInt16, completion: @escaping (UInt16?) -> Void) {
        // Check cache first
        if let cached = settingsCache.get(index) {
            completion(cached)
            return
        }

        guard connectionState == .connected,
              let peripheral = connectedPeripheral else {
            lastError = .notConnected
            completion(nil)
            return
        }

        let uuid = IronOSUUIDs.settingUUID(index: index)

        operationQueue.sync {
            // Store completion handler
            settingReadCompletions[uuid] = completion

            if let characteristic = discoveredCharacteristics[uuid] {
                peripheral.readValue(for: characteristic)
                scheduleOperationTimeout(for: uuid, type: "read")
            } else {
                // Discover it first
                if let settingsService = peripheral.services?.first(where: { $0.uuid == IronOSUUIDs.settingsService }) {
                    peripheral.discoverCharacteristics([uuid], for: settingsService)
                    scheduleOperationTimeout(for: uuid, type: "discover-read")
                } else {
                    lastError = .characteristicNotFound(uuid)
                    completion(nil)
                    settingReadCompletions.removeValue(forKey: uuid)
                }
            }
        }
    }
    
    @MainActor
    func saveSettings() {
        guard connectionState == .connected,
              let peripheral = connectedPeripheral,
              let characteristic = discoveredCharacteristics[IronOSUUIDs.saveSettings] else {
            lastError = .notConnected
            return
        }
        
        let value = UInt16(1).data
        peripheral.writeValue(value, for: characteristic, type: .withResponse)
    }

    func setSlowPolling() {
        updatePollingInterval(0.2)
    }

    func setFastPolling() {
        guard connectionState == .connected else { return }
        updatePollingInterval(0.1)
    }

    private func updatePollingInterval(_ interval: TimeInterval) {
        timerQueue.async { [weak self] in
            guard let self else { return }
            self.pollTimer?.invalidate()
            self.pollTimer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    self.readBulkData()
                }
            }
            if let timer = self.pollTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }
    }

    // MARK: - Polling

    private func startPolling() {
        stopPolling()
        updatePollingInterval(0.1)

        Task { @MainActor in
            readBulkData()
        }
    }

    private func stopPolling() {
        timerQueue.async { [weak self] in
            self?.pollTimer?.invalidate()
            self?.pollTimer = nil
        }
    }

    // MARK: - Timeout Management

    private func scheduleOperationTimeout(for uuid: CBUUID, type: String) {
        // Cancel any existing timeout
        operationQueue.sync {
            operationTimeouts[uuid]?.cancel()

            let timeoutWork = DispatchWorkItem { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    self.handleOperationTimeout(uuid: uuid, type: type)
                }
            }

            operationTimeouts[uuid] = timeoutWork
            operationQueue.asyncAfter(deadline: .now() + 5.0, execute: timeoutWork)
        }
    }

    private func cancelOperationTimeout(for uuid: CBUUID) {
        operationQueue.sync {
            operationTimeouts[uuid]?.cancel()
            operationTimeouts.removeValue(forKey: uuid)
        }
    }

    @MainActor
    private func handleOperationTimeout(uuid: CBUUID, type: String) {
        operationQueue.sync {
            // Clean up any pending operations
            if let completion = settingReadCompletions.removeValue(forKey: uuid) {
                lastError = .timeout
                completion(nil)
            }
            pendingWrites.removeValue(forKey: uuid)
            operationTimeouts.removeValue(forKey: uuid)
        }
    }

    @MainActor
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
    }

    @MainActor
    private func handleCharacteristicValue(_ characteristic: CBCharacteristic) {
        guard let value = characteristic.value else { return }
        
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

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch central.state {
            case .poweredOn:
                self.startScanning()
            case .poweredOff:
                self.connectionState = .error("Bluetooth is off")
            case .unauthorized:
                self.connectionState = .error("Bluetooth access denied")
            case .unsupported:
                self.connectionState = .error("Bluetooth not supported")
            default:
                break
            }
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Auto-connect to first discovered Tinkcil
            if self.connectedPeripheral == nil {
                // Match either Pinecil-* (legacy) or by the advertised service UUID
                if peripheral.name?.hasPrefix("Pinecil-") == true ||
                   peripheral.name?.hasPrefix("PrattlePin-") == true ||
                   (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?.contains(IronOSUUIDs.bulkDataService) == true {
                    self.connect(to: peripheral)
                    return
                }
            }

            if !self.discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                self.discoveredDevices.append(peripheral)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.connectionState = .connected
            self.deviceName = peripheral.name ?? "Tinkcil"
        }
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.connectionState = .error(error?.localizedDescription ?? "Connection failed")
            self.connectedPeripheral = nil
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.stopPolling()
            self.connectionState = .disconnected
            self.connectedPeripheral = nil
            self.discoveredCharacteristics.removeAll()
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
            operationQueue.sync {
                if let pendingValue = pendingWrites[characteristic.uuid] {
                    peripheral.writeValue(pendingValue.data, for: characteristic, type: .withResponse)
                    pendingWrites.removeValue(forKey: characteristic.uuid)
                    scheduleOperationTimeout(for: characteristic.uuid, type: "write")
                }

                // Handle pending reads for dynamically discovered settings
                if settingReadCompletions[characteristic.uuid] != nil {
                    peripheral.readValue(for: characteristic)
                    scheduleOperationTimeout(for: characteristic.uuid, type: "read")
                }
            }
        }

        // Start polling once we have the live data service
        if service.uuid == IronOSUUIDs.liveDataService || service.uuid == IronOSUUIDs.bulkDataService {
            DispatchQueue.main.async { [weak self] in
                self?.startPolling()
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard error == nil else {
            cancelOperationTimeout(for: characteristic.uuid)
            DispatchQueue.main.async { [weak self] in
                self?.lastError = .readFailed(error?.localizedDescription ?? "Unknown error")
            }
            return
        }

        // Cancel timeout for successful read
        cancelOperationTimeout(for: characteristic.uuid)

        // Check if this is a setting read completion
        let completion = operationQueue.sync { () -> ((UInt16?) -> Void)? in
            settingReadCompletions.removeValue(forKey: characteristic.uuid)
        }

        if let completion = completion {
            let value = characteristic.value?.withUnsafeBytes { $0.load(as: UInt16.self) }
            if let value = value, let index = IronOSUUIDs.settingIndex(from: characteristic.uuid) {
                DispatchQueue.main.async { [weak self] in
                    self?.settingsCache.set(value, for: index)
                    completion(value)
                }
            } else {
                DispatchQueue.main.async {
                    completion(value)
                }
            }
            return
        }

        Task { @MainActor in
            handleCharacteristicValue(characteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            cancelOperationTimeout(for: characteristic.uuid)
            DispatchQueue.main.async { [weak self] in
                self?.lastError = .writeFailed(error.localizedDescription)
            }
        } else {
            // Cancel timeout on successful write
            cancelOperationTimeout(for: characteristic.uuid)
        }
    }
}
