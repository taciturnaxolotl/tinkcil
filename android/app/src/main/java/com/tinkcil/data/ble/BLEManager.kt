package com.tinkcil.data.ble

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import com.tinkcil.data.model.CircularBuffer
import com.tinkcil.data.model.IronOSLiveData
import com.tinkcil.data.model.OperatingMode
import com.tinkcil.data.model.PowerSource
import com.tinkcil.data.model.TemperaturePoint
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withTimeoutOrNull
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.coroutines.resume

enum class ConnectionState {
    DISCONNECTED, SCANNING, CONNECTING, CONNECTED
}

@Singleton
class BLEManager @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val bleScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    private val bluetoothAdapter: BluetoothAdapter? = bluetoothManager.adapter

    private var gatt: BluetoothGatt? = null
    private var pollingJob: Job? = null
    private var scanTimeoutJob: Job? = null
    private var demoJob: Job? = null
    private val operationMutex = Mutex()

    // Continuation for GATT connection
    private var connectionContinuation: ((Boolean) -> Unit)? = null
    private var serviceDiscoveryContinuation: ((Boolean) -> Unit)? = null

    // Read operation tracking
    private var pendingReadCharacteristic: UUID? = null
    private var pendingReadContinuation: ((ByteArray?) -> Unit)? = null
    private var pendingWriteContinuation: ((Boolean) -> Unit)? = null

    private val _connectionState = MutableStateFlow(ConnectionState.DISCONNECTED)
    val connectionState: StateFlow<ConnectionState> = _connectionState.asStateFlow()

    private val _liveData = MutableStateFlow(IronOSLiveData())
    val liveData: StateFlow<IronOSLiveData> = _liveData.asStateFlow()

    private val _deviceName = MutableStateFlow<String?>(null)
    val deviceName: StateFlow<String?> = _deviceName.asStateFlow()

    private val _firmwareVersion = MutableStateFlow<String?>(null)
    val firmwareVersion: StateFlow<String?> = _firmwareVersion.asStateFlow()

    private val _serialNumber = MutableStateFlow<String?>(null)
    val serialNumber: StateFlow<String?> = _serialNumber.asStateFlow()

    private val _lastError = MutableStateFlow<BLEError?>(null)
    val lastError: StateFlow<BLEError?> = _lastError.asStateFlow()

    private val _isDemo = MutableStateFlow(false)
    val isDemo: StateFlow<Boolean> = _isDemo.asStateFlow()

    private val _isSlowPolling = MutableStateFlow(false)

    val temperatureHistory = CircularBuffer<TemperaturePoint>(150)

    // Settings cache: index -> value
    private val _settingsCache = MutableStateFlow<Map<Int, Int>>(emptyMap())
    val settingsCache: StateFlow<Map<Int, Int>> = _settingsCache.asStateFlow()

    private val gattCallback = object : BluetoothGattCallback() {
        @SuppressLint("MissingPermission")
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                connectionContinuation?.invoke(true)
                connectionContinuation = null
                gatt.discoverServices()
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                connectionContinuation?.invoke(false)
                connectionContinuation = null
                serviceDiscoveryContinuation?.invoke(false)
                serviceDiscoveryContinuation = null
                scope.launch { handleDisconnection() }
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            val success = status == BluetoothGatt.GATT_SUCCESS
            serviceDiscoveryContinuation?.invoke(success)
            serviceDiscoveryContinuation = null
        }

        override fun onCharacteristicRead(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray,
            status: Int
        ) {
            if (characteristic.uuid == pendingReadCharacteristic) {
                pendingReadContinuation?.invoke(if (status == BluetoothGatt.GATT_SUCCESS) value else null)
                pendingReadContinuation = null
                pendingReadCharacteristic = null
            }
        }

        @Deprecated("Deprecated in API 33")
        override fun onCharacteristicRead(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int
        ) {
            if (characteristic.uuid == pendingReadCharacteristic) {
                @Suppress("DEPRECATION")
                val value = characteristic.value
                pendingReadContinuation?.invoke(if (status == BluetoothGatt.GATT_SUCCESS) value else null)
                pendingReadContinuation = null
                pendingReadCharacteristic = null
            }
        }

        override fun onCharacteristicWrite(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int
        ) {
            pendingWriteContinuation?.invoke(status == BluetoothGatt.GATT_SUCCESS)
            pendingWriteContinuation = null
        }
    }

    @SuppressLint("MissingPermission")
    fun startScan() {
        if (_connectionState.value == ConnectionState.SCANNING || _connectionState.value == ConnectionState.CONNECTED) return

        val scanner = bluetoothAdapter?.bluetoothLeScanner ?: run {
            _lastError.value = BLEError.PermissionDenied
            return
        }

        _connectionState.value = ConnectionState.SCANNING

        val scanSettings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        val scanCallback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                val name = result.device.name ?: return
                if (name.startsWith("Pinecil-") || name.startsWith("PrattlePin-")) {
                    scanner.stopScan(this)
                    scanTimeoutJob?.cancel()
                    scope.launch { connectToDevice(result.device, name) }
                }
            }

            override fun onScanFailed(errorCode: Int) {
                _connectionState.value = ConnectionState.DISCONNECTED
                _lastError.value = BLEError.ReadFailed("Scan failed: $errorCode")
            }
        }

        scanner.startScan(null, scanSettings, scanCallback)

        scanTimeoutJob = scope.launch {
            delay(10_000)
            try {
                scanner.stopScan(scanCallback)
            } catch (_: Exception) {}
            if (_connectionState.value == ConnectionState.SCANNING) {
                _connectionState.value = ConnectionState.DISCONNECTED
            }
        }
    }

    @SuppressLint("MissingPermission")
    private suspend fun connectToDevice(device: BluetoothDevice, name: String) {
        _connectionState.value = ConnectionState.CONNECTING
        _deviceName.value = name

        val connected = suspendCancellableCoroutine { cont ->
            connectionContinuation = { success -> cont.resume(success) }
            gatt = device.connectGatt(context, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
        }

        if (!connected) {
            _connectionState.value = ConnectionState.DISCONNECTED
            return
        }

        val servicesDiscovered = suspendCancellableCoroutine { cont ->
            serviceDiscoveryContinuation = { success -> cont.resume(success) }
        }

        if (!servicesDiscovered) {
            gatt?.disconnect()
            _connectionState.value = ConnectionState.DISCONNECTED
            return
        }

        _connectionState.value = ConnectionState.CONNECTED

        // Read device info
        bleScope.launch {
            readDeviceInfo()
            readAllSettings()
        }

        startPolling()
    }

    @SuppressLint("MissingPermission")
    private suspend fun readCharacteristic(serviceUuid: UUID, characteristicUuid: UUID): ByteArray? {
        val gatt = this.gatt ?: return null
        val service = gatt.getService(serviceUuid) ?: return null
        val characteristic = service.getCharacteristic(characteristicUuid) ?: return null

        return operationMutex.withLock {
            withTimeoutOrNull(5000L) {
                suspendCancellableCoroutine { cont ->
                    pendingReadCharacteristic = characteristicUuid
                    pendingReadContinuation = { data -> cont.resume(data) }
                    if (!gatt.readCharacteristic(characteristic)) {
                        pendingReadContinuation = null
                        pendingReadCharacteristic = null
                        cont.resume(null)
                    }
                }
            }
        }
    }

    @SuppressLint("MissingPermission")
    private suspend fun writeCharacteristic(serviceUuid: UUID, characteristicUuid: UUID, data: ByteArray): Boolean {
        val gatt = this.gatt ?: return false
        val service = gatt.getService(serviceUuid) ?: return false
        val characteristic = service.getCharacteristic(characteristicUuid) ?: return false

        return operationMutex.withLock {
            withTimeoutOrNull(5000L) {
                suspendCancellableCoroutine { cont ->
                    pendingWriteContinuation = { success -> cont.resume(success) }
                    characteristic.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
                    @Suppress("DEPRECATION")
                    characteristic.value = data
                    @Suppress("DEPRECATION")
                    if (!gatt.writeCharacteristic(characteristic)) {
                        pendingWriteContinuation = null
                        cont.resume(false)
                    }
                }
            } ?: false
        }
    }

    private suspend fun readDeviceInfo() {
        val buildIdData = readCharacteristic(IronOSUUIDs.BULK_DATA_SERVICE, IronOSUUIDs.BUILD_ID)
        if (buildIdData != null) {
            _firmwareVersion.value = String(buildIdData, Charsets.UTF_8).trim()
        }

        val serialData = readCharacteristic(IronOSUUIDs.BULK_DATA_SERVICE, IronOSUUIDs.DEVICE_SERIAL)
        if (serialData != null && serialData.size >= 8) {
            val buffer = ByteBuffer.wrap(serialData).order(ByteOrder.LITTLE_ENDIAN)
            val serial = buffer.getLong()
            _serialNumber.value = "%016X".format(serial)
        }
    }

    private fun startPolling() {
        pollingJob?.cancel()
        pollingJob = bleScope.launch {
            while (true) {
                val interval = if (_isSlowPolling.value) 200L else 100L
                pollBulkData()
                delay(interval)
            }
        }
    }

    private suspend fun pollBulkData() {
        val data = readCharacteristic(IronOSUUIDs.BULK_DATA_SERVICE, IronOSUUIDs.BULK_LIVE_DATA) ?: return
        if (data.size < 56) return

        val buffer = ByteBuffer.wrap(data).order(ByteOrder.LITTLE_ENDIAN)
        val values = IntArray(14) { buffer.getInt() }

        val newData = IronOSLiveData(
            liveTemp = values[0].coerceIn(0, 600),
            setpoint = values[1],
            dcInput = values[2],
            handleTemp = values[3],
            powerLevel = values[4].coerceIn(0, 255),
            powerSource = PowerSource.fromRaw(values[5]),
            tipResistance = values[6],
            uptime = values[7],
            lastMovement = values[8],
            maxTemp = values[9],
            rawTip = values[10],
            hallSensor = values[11],
            operatingMode = OperatingMode.fromRaw(values[12]),
            estimatedWatts = values[13]
        )

        _liveData.value = newData

        temperatureHistory.add(
            TemperaturePoint(
                timestamp = System.currentTimeMillis(),
                actualTemp = newData.liveTemp,
                setpoint = newData.setpoint
            )
        )
    }

    // --- Settings ---

    suspend fun readAllSettings() {
        val cache = mutableMapOf<Int, Int>()
        for (index in IronOSUUIDs.SETTING_INDICES) {
            val data = readCharacteristic(
                IronOSUUIDs.SETTINGS_SERVICE,
                IronOSUUIDs.settingCharacteristic(index)
            )
            if (data != null && data.size >= 2) {
                val value = ByteBuffer.wrap(data).order(ByteOrder.LITTLE_ENDIAN).getShort().toInt() and 0xFFFF
                cache[index] = value
            }
        }
        _settingsCache.value = cache
    }

    suspend fun writeSetting(index: Int, value: Int) {
        if (_isDemo.value) {
            _settingsCache.value = _settingsCache.value.toMutableMap().also { it[index] = value }
            return
        }
        val data = ByteBuffer.allocate(2).order(ByteOrder.LITTLE_ENDIAN).putShort(value.toShort()).array()
        val success = writeCharacteristic(
            IronOSUUIDs.SETTINGS_SERVICE,
            IronOSUUIDs.settingCharacteristic(index),
            data
        )
        if (success) {
            _settingsCache.value = _settingsCache.value.toMutableMap().also { it[index] = value }
        } else {
            _lastError.value = BLEError.WriteFailed("Setting $index")
        }
    }

    suspend fun saveSettingsToDevice() {
        if (_isDemo.value) return
        val data = ByteBuffer.allocate(2).order(ByteOrder.LITTLE_ENDIAN).putShort(1).array()
        val success = writeCharacteristic(IronOSUUIDs.SETTINGS_SERVICE, IronOSUUIDs.SAVE_SETTINGS, data)
        if (!success) {
            _lastError.value = BLEError.WriteFailed("Save settings")
        }
    }

    suspend fun writeSetpoint(temperature: Int) {
        if (_isDemo.value) {
            _settingsCache.value = _settingsCache.value.toMutableMap().also { it[0] = temperature }
            return
        }
        val data = ByteBuffer.allocate(2).order(ByteOrder.LITTLE_ENDIAN).putShort(temperature.toShort()).array()
        writeCharacteristic(
            IronOSUUIDs.SETTINGS_SERVICE,
            IronOSUUIDs.settingCharacteristic(0),
            data
        )
    }

    fun setSlowPolling(slow: Boolean) {
        _isSlowPolling.value = slow
    }

    // --- Demo Mode ---

    fun startDemo() {
        _isDemo.value = true
        _connectionState.value = ConnectionState.CONNECTED
        _deviceName.value = "Pinecil-DEMO"
        _firmwareVersion.value = "v2.22"
        _serialNumber.value = "DEMO000000000000"
        temperatureHistory.clear()

        _settingsCache.value = mapOf(
            0 to 320, 1 to 150, 2 to 1, 6 to 2, 7 to 6,
            11 to 10, 13 to 0, 14 to 0, 17 to 0, 22 to 420,
            24 to 65, 25 to 0, 26 to 10, 27 to 1, 28 to 7,
            33 to 0, 34 to 51
        )

        demoJob?.cancel()
        demoJob = scope.launch {
            var currentTemp = 25
            var tick = 0
            while (true) {
                val target = _settingsCache.value[0] ?: 320
                val delta = target - currentTemp

                val watts: Int
                val power: Int

                when {
                    kotlin.math.abs(delta) <= 2 -> {
                        currentTemp = target + (-1..1).random()
                        watts = (200..400).random()
                        power = (5..20).random()
                    }
                    delta > 0 -> {
                        val step = (delta / 8).coerceIn(3, 5)
                        currentTemp += step + (-1..1).random()
                        watts = (470..530).random()
                        power = (180..220).random()
                    }
                    else -> {
                        val step = (-delta / 10).coerceIn(2, 4)
                        currentTemp -= step + (-1..0).random()
                        watts = 0
                        power = 0
                    }
                }

                currentTemp = currentTemp.coerceIn(20, 500)
                tick++

                val mode = if (power > 0) OperatingMode.HEATING else OperatingMode.IDLE

                _liveData.value = IronOSLiveData(
                    liveTemp = currentTemp,
                    setpoint = target,
                    dcInput = 200,
                    handleTemp = 280 + (-5..5).random(),
                    powerLevel = power.coerceIn(0, 255),
                    powerSource = PowerSource.PD_TYPE1,
                    tipResistance = 620 + (-10..10).random(),
                    uptime = tick,
                    lastMovement = (0..50).random(),
                    maxTemp = 450,
                    rawTip = (500..1500).random(),
                    hallSensor = (400..600).random(),
                    operatingMode = mode,
                    estimatedWatts = watts
                )

                temperatureHistory.add(
                    TemperaturePoint(
                        timestamp = System.currentTimeMillis(),
                        actualTemp = currentTemp,
                        setpoint = target
                    )
                )

                delay(100)
            }
        }
    }

    // --- Disconnect ---

    @SuppressLint("MissingPermission")
    fun disconnect() {
        pollingJob?.cancel()
        pollingJob = null
        demoJob?.cancel()
        demoJob = null
        scanTimeoutJob?.cancel()

        try {
            gatt?.disconnect()
            gatt?.close()
        } catch (_: Exception) {}
        gatt = null

        _connectionState.value = ConnectionState.DISCONNECTED
        _isDemo.value = false
        _deviceName.value = null
        _firmwareVersion.value = null
        _serialNumber.value = null
        _liveData.value = IronOSLiveData()
        temperatureHistory.clear()
    }

    private fun handleDisconnection() {
        pollingJob?.cancel()
        pollingJob = null
        _connectionState.value = ConnectionState.DISCONNECTED
    }

    fun clearError() {
        _lastError.value = null
    }
}
