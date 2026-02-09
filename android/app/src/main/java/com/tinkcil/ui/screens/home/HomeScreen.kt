package com.tinkcil.ui.screens.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.windowsizeclass.WindowWidthSizeClass
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.tinkcil.R
import com.tinkcil.data.ble.ConnectionState
import com.tinkcil.ui.components.ScanningOverlay
import com.tinkcil.ui.components.SettingsSheet
import com.tinkcil.ui.components.SliderPanel
import com.tinkcil.ui.components.TemperatureDisplay
import com.tinkcil.ui.components.TemperatureGraph
import com.tinkcil.ui.components.TopStatsBar

@Composable
fun HomeScreen(
    widthSizeClass: WindowWidthSizeClass,
    viewModel: HomeViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) {
        viewModel.startScan()
    }

    Scaffold { innerPadding ->
        Box(modifier = Modifier.fillMaxSize().padding(innerPadding)) {
            if (uiState.connectionState == ConnectionState.CONNECTED) {
                if (widthSizeClass == WindowWidthSizeClass.Expanded) {
                    TabletLayout(uiState = uiState, viewModel = viewModel)
                } else {
                    PhoneLayout(uiState = uiState, viewModel = viewModel)
                }

                if (uiState.isSettingsSheetVisible) {
                    SettingsSheet(
                        settingsCache = uiState.settingsCache,
                        liveData = uiState.liveData,
                        deviceName = uiState.deviceName,
                        firmwareVersion = uiState.firmwareVersion,
                        serialNumber = uiState.serialNumber,
                        onSettingChanged = viewModel::writeSetting,
                        onSaveSettings = viewModel::saveSettings,
                        onDisconnect = viewModel::disconnect,
                        onDismiss = viewModel::hideSettings
                    )
                }
            } else {
                ScanningOverlay(
                    connectionState = uiState.connectionState,
                    discoveredDevices = uiState.discoveredDevices,
                    onDeviceSelected = viewModel::connectToDevice,
                    onScanAgain = viewModel::startScan,
                    onTryDemo = viewModel::startDemo
                )
            }

            // Error dialog
            uiState.lastError?.let { error ->
                AlertDialog(
                    onDismissRequest = viewModel::clearError,
                    title = { Text(stringResource(R.string.bluetooth_error_title)) },
                    text = { Text(error.message) },
                    confirmButton = {
                        TextButton(onClick = viewModel::clearError) {
                            Text(stringResource(R.string.button_ok))
                        }
                    }
                )
            }
        }
    }
}

@Composable
private fun PhoneLayout(
    uiState: HomeUiState,
    viewModel: HomeViewModel
) {
    Box(modifier = Modifier.fillMaxSize()) {
        // Background graph
        TemperatureGraph(
            points = uiState.temperatureHistory,
            currentTemp = uiState.liveData.liveTemp,
            maxTemp = uiState.liveData.maxTemp,
            showAxes = false,
            windowSeconds = 6f,
            modifier = Modifier
                .fillMaxSize()
                .padding(top = 80.dp, bottom = 140.dp)
        )

        // Top stats bar
        TopStatsBar(
            deviceName = uiState.deviceName ?: "",
            liveData = uiState.liveData,
            firmwareVersion = uiState.firmwareVersion,
            isExpanded = uiState.isTopBarExpanded,
            onExpandToggle = viewModel::toggleTopBar,
            onSettingsClick = viewModel::showSettings,
            modifier = Modifier
                .align(Alignment.TopCenter)
                .padding(horizontal = 16.dp, vertical = 8.dp)
        )

        // Center temperature display
        TemperatureDisplay(
            currentTemp = uiState.liveData.liveTemp,
            setpoint = uiState.liveData.setpoint,
            maxTemp = uiState.liveData.maxTemp,
            operatingMode = uiState.liveData.operatingMode,
            modifier = Modifier.align(Alignment.Center)
        )

        // Bottom slider
        SliderPanel(
            targetTemp = uiState.settingsCache[0] ?: uiState.liveData.setpoint,
            onTargetChanged = viewModel::setTargetTemperature,
            onSliderStart = viewModel::onSliderStart,
            onSliderEnd = viewModel::onSliderEnd,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(horizontal = 16.dp, vertical = 16.dp)
        )
    }
}

@Composable
private fun TabletLayout(
    uiState: HomeUiState,
    viewModel: HomeViewModel
) {
    Row(modifier = Modifier.fillMaxSize()) {
        // Left: Graph panel
        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxHeight()
                .padding(16.dp)
        ) {
            TemperatureGraph(
                points = uiState.temperatureHistory,
                currentTemp = uiState.liveData.liveTemp,
                maxTemp = uiState.liveData.maxTemp,
                showAxes = true,
                windowSeconds = 15f,
                modifier = Modifier.fillMaxSize()
            )
        }

        // Divider
        HorizontalDivider(
            modifier = Modifier
                .fillMaxHeight()
                .width(1.dp)
        )

        // Right: Control panel
        Column(
            modifier = Modifier
                .width(420.dp)
                .fillMaxHeight()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            TopStatsBar(
                deviceName = uiState.deviceName ?: "",
                liveData = uiState.liveData,
                firmwareVersion = uiState.firmwareVersion,
                isExpanded = uiState.isTopBarExpanded,
                onExpandToggle = viewModel::toggleTopBar,
                onSettingsClick = viewModel::showSettings
            )

            TemperatureDisplay(
                currentTemp = uiState.liveData.liveTemp,
                setpoint = uiState.liveData.setpoint,
                maxTemp = uiState.liveData.maxTemp,
                operatingMode = uiState.liveData.operatingMode,
                isCompact = true
            )

            SliderPanel(
                targetTemp = uiState.settingsCache[0] ?: uiState.liveData.setpoint,
                onTargetChanged = viewModel::setTargetTemperature,
                onSliderStart = viewModel::onSliderStart,
                onSliderEnd = viewModel::onSliderEnd
            )
        }
    }
}
