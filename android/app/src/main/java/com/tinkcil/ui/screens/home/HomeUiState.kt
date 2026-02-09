package com.tinkcil.ui.screens.home

import com.tinkcil.data.ble.BLEError
import com.tinkcil.data.ble.ConnectionState
import com.tinkcil.data.ble.DiscoveredDevice
import com.tinkcil.data.model.IronOSLiveData
import com.tinkcil.data.model.TemperaturePoint

data class HomeUiState(
    val connectionState: ConnectionState = ConnectionState.DISCONNECTED,
    val liveData: IronOSLiveData = IronOSLiveData(),
    val deviceName: String? = null,
    val firmwareVersion: String? = null,
    val serialNumber: String? = null,
    val isDemo: Boolean = false,
    val settingsCache: Map<Int, Int> = emptyMap(),
    val temperatureHistory: List<TemperaturePoint> = emptyList(),
    val discoveredDevices: List<DiscoveredDevice> = emptyList(),
    val lastError: BLEError? = null,
    val isTopBarExpanded: Boolean = false,
    val isSettingsSheetVisible: Boolean = false
)
