package com.tinkcil.ui.screens.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.tinkcil.data.ble.BLEManager
import com.tinkcil.data.repository.SettingsRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class HomeViewModel @Inject constructor(
    private val bleManager: BLEManager,
    private val settingsRepository: SettingsRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()

    private var lastSentSetpoint = 0

    init {
        observeBLEState()
        loadCachedSettings()
    }

    private fun observeBLEState() {
        viewModelScope.launch {
            combine(
                bleManager.connectionState,
                bleManager.liveData,
                bleManager.deviceName,
                bleManager.firmwareVersion,
                bleManager.serialNumber
            ) { connState, live, name, firmware, serial ->
                Tuple5(connState, live, name, firmware, serial)
            }.combine(
                combine(
                    bleManager.isDemo,
                    bleManager.settingsCache,
                    bleManager.lastError
                ) { demo, settings, error ->
                    Triple(demo, settings, error)
                }
            ) { (connState, live, name, firmware, serial), (demo, settings, error) ->
                HomeUiState(
                    connectionState = connState,
                    liveData = live,
                    deviceName = name,
                    firmwareVersion = firmware,
                    serialNumber = serial,
                    isDemo = demo,
                    settingsCache = settings,
                    lastError = error,
                    temperatureHistory = bleManager.temperatureHistory.toList(),
                    isTopBarExpanded = _uiState.value.isTopBarExpanded,
                    isSettingsSheetVisible = _uiState.value.isSettingsSheetVisible
                )
            }.collect { state ->
                _uiState.value = state
                if (state.settingsCache.isNotEmpty()) {
                    settingsRepository.cacheSettings(state.settingsCache)
                }
            }
        }
    }

    private fun loadCachedSettings() {
        viewModelScope.launch {
            val cached = settingsRepository.getCachedSettings()
            if (cached.isNotEmpty()) {
                // Pre-populate from cache (will be overwritten by device reads)
            }
        }
    }

    fun startScan() {
        bleManager.startScan()
    }

    fun startDemo() {
        bleManager.startDemo()
    }

    fun disconnect() {
        bleManager.disconnect()
        _uiState.update { it.copy(isSettingsSheetVisible = false, isTopBarExpanded = false) }
    }

    fun setTargetTemperature(temp: Int) {
        if (kotlin.math.abs(temp - lastSentSetpoint) >= 5) {
            lastSentSetpoint = temp
            viewModelScope.launch {
                bleManager.writeSetpoint(temp)
            }
        }
    }

    fun onSliderStart() {
        bleManager.setSlowPolling(true)
    }

    fun onSliderEnd() {
        bleManager.setSlowPolling(false)
    }

    fun writeSetting(index: Int, value: Int) {
        viewModelScope.launch {
            bleManager.writeSetting(index, value)
            settingsRepository.cacheSetting(index, value)
        }
    }

    fun saveSettings() {
        viewModelScope.launch {
            bleManager.saveSettingsToDevice()
        }
    }

    fun toggleTopBar() {
        _uiState.update { it.copy(isTopBarExpanded = !it.isTopBarExpanded) }
    }

    fun showSettings() {
        _uiState.update { it.copy(isSettingsSheetVisible = true) }
    }

    fun hideSettings() {
        _uiState.update { it.copy(isSettingsSheetVisible = false) }
    }

    fun clearError() {
        bleManager.clearError()
    }
}

private data class Tuple5<A, B, C, D, E>(val a: A, val b: B, val c: C, val d: D, val e: E)
