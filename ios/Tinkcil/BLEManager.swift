//
//  BLEManager.swift
//  Tinkcil
//

@preconcurrency import CoreBluetooth
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
    var isDemoMode = false

    // Temperature history for graph (circular buffer)
    var temperatureHistory = CircularBuffer<TemperaturePoint>(capacity: 150)
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
    private var demoTimer: Timer?

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
            if discoveredDevices.count == 1 {
                connect(to: discoveredDevices[0])
            } else {
                connectionState = .disconnected
            }
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
        if isDemoMode {
            stopDemoMode()
            return
        }

        stopPolling()

        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }

        // Clean up all state and call pending completions
        let pendingCompletions = operationQueue.sync { () -> [(CBUUID, (UInt16?) -> Void)] in
            // Cancel all pending operations
            for timeout in operationTimeouts.values {
                timeout.cancel()
            }
            operationTimeouts.removeAll()
            pendingWrites.removeAll()

            // Extract completions to call them outside the sync block
            let completions = Array(settingReadCompletions)
            settingReadCompletions.removeAll()
            return completions
        }

        // Call all pending completions with nil (disconnected)
        DispatchQueue.main.async {
            for (_, completion) in pendingCompletions {
                completion(nil)
            }
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
        if isDemoMode {
            settingsCache.set(value, for: index)
            if index == 0 {
                liveData.setpoint = UInt32(value)
            }
            return
        }

        guard connectionState == .connected,
              let peripheral = connectedPeripheral else {
            lastError = .notConnected
            return
        }

        let uuid = IronOSUUIDs.settingUUID(index: index)

        // Check if characteristic is cached and prepare operation
        let cachedCharacteristic = operationQueue.sync { () -> CBCharacteristic? in
            return discoveredCharacteristics[uuid]
        }

        bleQueue.async { [weak self] in
            guard let self = self else { return }

            if let characteristic = cachedCharacteristic {
                // Use cached characteristic
                peripheral.writeValue(value.data, for: characteristic, type: .withResponse)
                DispatchQueue.main.async {
                    self.settingsCache.set(value, for: index)
                }
                self.scheduleOperationTimeout(for: uuid, type: "write")
            } else {
                // Need to discover characteristic first
                if let settingsService = peripheral.services?.first(where: { $0.uuid == IronOSUUIDs.settingsService }) {
                    self.operationQueue.sync {
                        self.pendingWrites[uuid] = value
                    }
                    peripheral.discoverCharacteristics([uuid], for: settingsService)
                    self.scheduleOperationTimeout(for: uuid, type: "discover-write")
                } else {
                    DispatchQueue.main.async {
                        self.lastError = .characteristicNotFound(uuid)
                    }
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

        if isDemoMode {
            completion(nil)
            return
        }

        guard connectionState == .connected,
              let peripheral = connectedPeripheral else {
            lastError = .notConnected
            completion(nil)
            return
        }

        let uuid = IronOSUUIDs.settingUUID(index: index)

        // Store completion handler and check for cached characteristic
        let cachedCharacteristic = operationQueue.sync { () -> CBCharacteristic? in
            settingReadCompletions[uuid] = completion
            return discoveredCharacteristics[uuid]
        }

        bleQueue.async { [weak self] in
            guard let self = self else { return }

            if let characteristic = cachedCharacteristic {
                // Read from cached characteristic
                peripheral.readValue(for: characteristic)
                self.scheduleOperationTimeout(for: uuid, type: "read")
            } else {
                // Need to discover characteristic first
                if let settingsService = peripheral.services?.first(where: { $0.uuid == IronOSUUIDs.settingsService }) {
                    peripheral.discoverCharacteristics([uuid], for: settingsService)
                    self.scheduleOperationTimeout(for: uuid, type: "discover-read")
                } else {
                    DispatchQueue.main.async {
                        self.lastError = .characteristicNotFound(uuid)
                        completion(nil)
                    }
                    _ = self.operationQueue.sync {
                        self.settingReadCompletions.removeValue(forKey: uuid)
                    }
                }
            }
        }
    }
    
    @MainActor
    func saveSettings() {
        if isDemoMode { return }

        guard connectionState == .connected,
              let peripheral = connectedPeripheral,
              let characteristic = discoveredCharacteristics[IronOSUUIDs.saveSettings] else {
            lastError = .notConnected
            return
        }

        let value = UInt16(1).data
        bleQueue.async {
            peripheral.writeValue(value, for: characteristic, type: .withResponse)
        }
    }

    func setSlowPolling() {
        if isDemoMode { return }
        updatePollingInterval(0.2)
    }

    func setFastPolling() {
        if isDemoMode { return }
        guard connectionState == .connected else { return }
        updatePollingInterval(0.1)
    }

    // MARK: - Demo Mode

    @MainActor
    func startDemoMode() {
        isDemoMode = true
        connectionState = .connected

        deviceName = "Pinecil-DEMO"
        firmwareVersion = "v2.22"
        buildID = "v2.22"
        deviceSerial = "DEMO000000000000"

        liveData.liveTemp = 25
        liveData.setpoint = 320
        liveData.dcInput = 200        // 20.0V
        liveData.handleTemp = 250     // 25.0°C
        liveData.powerLevel = 0
        liveData.powerSource = 2      // PD
        liveData.tipResistance = 620  // 6.20 Ω
        liveData.uptime = 0
        liveData.lastMovement = 0
        liveData.maxTemp = 450
        liveData.rawTip = 0
        liveData.hallSensor = 0
        liveData.operatingMode = 1    // soldering
        liveData.estimatedWatts = 0

        // Populate settings cache with realistic defaults
        let defaults: [(UInt16, UInt16)] = [
            (0, 320),   // Soldering temp
            (1, 150),   // Sleep temp
            (2, 1),     // Sleep time (min)
            (6, 2),     // Orientation (auto)
            (7, 6),     // Motion sensitivity
            (11, 10),   // Shutdown time (min)
            (13, 0),    // Detailed idle screen (off)
            (14, 0),    // Detailed soldering screen (off)
            (17, 0),    // Locking mode (off)
            (22, 420),  // Boost temp
            (24, 65),   // Power limit (W)
            (25, 0),    // Reverse buttons (off)
            (26, 10),   // Long press step
            (27, 1),    // Short press step
            (28, 7),    // Hall sensitivity
            (33, 0),    // Invert display (off)
            (34, 51),   // Brightness
        ]
        for (index, value) in defaults {
            settingsCache.set(value, for: index)
        }

        temperatureHistory.clear()

        demoTimer?.invalidate()
        demoTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.demoTick()
            }
        }
        if let timer = demoTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    @MainActor
    private func demoTick() {
        let current = Int(liveData.liveTemp)
        let target = Int(liveData.setpoint)
        let delta = target - current
        let noise = Int.random(in: -1...1)

        if abs(delta) <= 2 {
            // At setpoint — hold steady with small fluctuation
            liveData.liveTemp = UInt32(clamping: target + noise)
            liveData.estimatedWatts = UInt32.random(in: 20...40) // ~2-4W maintenance
            liveData.powerLevel = UInt32.random(in: 5...20)
            liveData.operatingMode = 1 // soldering
        } else if delta > 0 {
            // Heating up
            let step = min(max(delta / 8, 3), 5)
            liveData.liveTemp = UInt32(clamping: current + step + noise)
            liveData.estimatedWatts = UInt32(clamping: 500 + Int.random(in: -30...30)) // ~50W
            liveData.powerLevel = UInt32(clamping: 200 + Int.random(in: -20...20))
            liveData.operatingMode = 1
        } else {
            // Cooling down
            let step = min(max(-delta / 10, 2), 4)
            liveData.liveTemp = UInt32(clamping: current - step + noise)
            liveData.estimatedWatts = 0
            liveData.powerLevel = 0
            liveData.operatingMode = 1
        }

        liveData.uptime += 1
        liveData.lastMovement = UInt32.random(in: 0...10)

        recordTemperature()
    }

    private func stopDemoMode() {
        demoTimer?.invalidate()
        demoTimer = nil
        isDemoMode = false
        liveData = IronOSLiveData()
        deviceName = ""
        firmwareVersion = ""
        buildID = ""
        deviceSerial = ""
        temperatureHistory.clear()
        connectionState = .disconnected
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

        bleQueue.async {
            peripheral.readValue(for: characteristic)
        }
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
            if !self.discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                self.discoveredDevices.append(peripheral)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.connectionState = .connected
            self.deviceName = peripheral.name ?? "Unknown Iron"
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

            // Note: Firmware does not support BLE notifications (no BT_GATT_CHRC_NOTIFY flag)
            // All data must be polled - notification subscription would have no effect
            
            // Handle pending writes for dynamically discovered settings
            let pendingValue = operationQueue.sync { () -> UInt16? in
                return pendingWrites.removeValue(forKey: characteristic.uuid)
            }
            if let pendingValue = pendingValue {
                peripheral.writeValue(pendingValue.data, for: characteristic, type: .withResponse)
                scheduleOperationTimeout(for: characteristic.uuid, type: "write")
            }

            // Handle pending reads for dynamically discovered settings
            let hasPendingRead = operationQueue.sync { () -> Bool in
                return settingReadCompletions[characteristic.uuid] != nil
            }
            if hasPendingRead {
                peripheral.readValue(for: characteristic)
                scheduleOperationTimeout(for: characteristic.uuid, type: "read")
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
        // Check if we're still connected to this peripheral
        guard peripheral == connectedPeripheral else {
            return
        }

        guard error == nil else {
            cancelOperationTimeout(for: characteristic.uuid)

            // Call any pending completion with nil for this characteristic
            let completion = operationQueue.sync { () -> ((UInt16?) -> Void)? in
                settingReadCompletions.removeValue(forKey: characteristic.uuid)
            }

            if let completion = completion {
                DispatchQueue.main.async { [weak self] in
                    self?.lastError = .readFailed(error?.localizedDescription ?? "Unknown error")
                    completion(nil)
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.lastError = .readFailed(error?.localizedDescription ?? "Unknown error")
                }
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
