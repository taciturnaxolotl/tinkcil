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

    // Temperature history for graph
    var temperatureHistory: [TemperaturePoint] = []
    private let maxHistoryPoints = 60

    // MARK: - Private

    private var centralManager: CBCentralManager!
    private var discoveredCharacteristics: [CBUUID: CBCharacteristic] = [:]
    private var pollTimer: Timer?

    // MARK: - Init

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
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
    }

    // MARK: - Public Methods

    func startScanning() {
        guard centralManager.state == .poweredOn else { return }

        discoveredDevices.removeAll()
        connectionState = .scanning

        centralManager.scanForPeripherals(
            withServices: [IronOSUUIDs.bulkDataService],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        isScanning = true
    }

    func stopScanning() {
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
        guard connectionState == .connected,
              let peripheral = connectedPeripheral,
              let characteristic = discoveredCharacteristics[IronOSUUIDs.setpointSetting] else {
            return
        }

        let value = UInt16(temp).data
        peripheral.writeValue(value, for: characteristic, type: .withResponse)
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

        case IronOSUUIDs.firmwareVersion:
            firmwareVersion = value.toString() ?? ""

        default:
            break
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
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

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        // Auto-connect to first discovered Pinecil
        if connectedPeripheral == nil {
            if peripheral.name?.hasPrefix("PrattlePin-") == true ||
               advertisementData[CBAdvertisementDataServiceUUIDsKey] != nil {
                connect(to: peripheral)
                return
            }
        }

        if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredDevices.append(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionState = .connected
        deviceName = peripheral.name ?? "Pinecil"
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        connectionState = .error(error?.localizedDescription ?? "Connection failed")
        connectedPeripheral = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.startScanning()
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        stopPolling()
        connectionState = .disconnected
        connectedPeripheral = nil
        discoveredCharacteristics.removeAll()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.startScanning()
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

            // Read bulk data and firmware version on connect
            if characteristic.uuid == IronOSUUIDs.bulkLiveData ||
               characteristic.uuid == IronOSUUIDs.firmwareVersion {
                peripheral.readValue(for: characteristic)
            }

            // Enable notifications for operating mode
            if characteristic.uuid == IronOSUUIDs.operatingMode {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }

        // Start polling once we have the live data service
        if service.uuid == IronOSUUIDs.liveDataService || service.uuid == IronOSUUIDs.bulkDataService {
            startPolling()
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if error != nil { return }
        handleCharacteristicValue(characteristic)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
    }
}
