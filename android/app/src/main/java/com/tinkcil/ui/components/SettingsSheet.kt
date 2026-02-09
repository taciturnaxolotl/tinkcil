package com.tinkcil.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.tinkcil.R
import com.tinkcil.data.model.IronOSLiveData
import kotlin.math.roundToInt

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsSheet(
    settingsCache: Map<Int, Int>,
    liveData: IronOSLiveData,
    deviceName: String?,
    firmwareVersion: String?,
    serialNumber: String?,
    onSettingChanged: (Int, Int) -> Unit,
    onSaveSettings: () -> Unit,
    onDisconnect: () -> Unit,
    onDismiss: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var selectedTab by remember { mutableIntStateOf(0) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState
    ) {
        Column(modifier = Modifier.padding(bottom = 32.dp)) {
            TabRow(selectedTabIndex = selectedTab) {
                Tab(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    text = { Text(stringResource(R.string.settings_tab)) }
                )
                Tab(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    text = { Text(stringResource(R.string.info_tab)) }
                )
            }

            when (selectedTab) {
                0 -> SettingsContent(
                    settingsCache = settingsCache,
                    onSettingChanged = onSettingChanged,
                    onSaveSettings = onSaveSettings
                )
                1 -> DiagnosticsContent(
                    liveData = liveData,
                    deviceName = deviceName,
                    firmwareVersion = firmwareVersion,
                    serialNumber = serialNumber,
                    onDisconnect = onDisconnect
                )
            }
        }
    }
}

@Composable
private fun SettingsContent(
    settingsCache: Map<Int, Int>,
    onSettingChanged: (Int, Int) -> Unit,
    onSaveSettings: () -> Unit
) {
    Column(
        modifier = Modifier
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp, vertical = 16.dp)
    ) {
        // Temperature section
        SectionHeader(stringResource(R.string.section_temperature))
        SettingSlider(stringResource(R.string.setting_soldering_temp), 0, 10, 450, "°C", settingsCache, onSettingChanged)
        SettingSlider(stringResource(R.string.setting_sleep_temp), 1, 10, 450, "°C", settingsCache, onSettingChanged)
        SettingSlider(stringResource(R.string.setting_boost_temp), 22, 10, 450, "°C", settingsCache, onSettingChanged)

        // Timers section
        SectionHeader(stringResource(R.string.section_timers))
        SettingSlider(stringResource(R.string.setting_sleep_time), 2, 0, 15, " min", settingsCache, onSettingChanged)
        SettingSlider(stringResource(R.string.setting_shutdown_time), 11, 0, 60, " min", settingsCache, onSettingChanged)

        // Power section
        SectionHeader(stringResource(R.string.section_power))
        SettingSlider(stringResource(R.string.setting_power_limit), 24, 0, 180, " W", settingsCache, onSettingChanged)

        // Display section
        SectionHeader(stringResource(R.string.section_display))
        SettingPicker(
            stringResource(R.string.setting_orientation),
            6,
            listOf(
                stringResource(R.string.option_right),
                stringResource(R.string.option_left),
                stringResource(R.string.option_auto)
            ),
            settingsCache,
            onSettingChanged
        )
        SettingSlider(stringResource(R.string.setting_brightness), 34, 1, 101, "%", settingsCache, onSettingChanged)
        SettingToggle(stringResource(R.string.setting_invert_display), 33, settingsCache, onSettingChanged)
        SettingToggle(stringResource(R.string.setting_detailed_idle), 13, settingsCache, onSettingChanged)
        SettingToggle(stringResource(R.string.setting_detailed_soldering), 14, settingsCache, onSettingChanged)

        // Sensors section
        SectionHeader(stringResource(R.string.section_sensors))
        SettingSlider(stringResource(R.string.setting_motion_sensitivity), 7, 0, 9, "", settingsCache, onSettingChanged)
        SettingSlider(stringResource(R.string.setting_hall_sensitivity), 28, 0, 9, "", settingsCache, onSettingChanged)

        // Controls section
        SectionHeader(stringResource(R.string.section_controls))
        SettingPicker(
            stringResource(R.string.setting_locking_mode),
            17,
            listOf(
                stringResource(R.string.option_off),
                stringResource(R.string.option_boost_only),
                stringResource(R.string.option_full)
            ),
            settingsCache,
            onSettingChanged
        )
        SettingToggle(stringResource(R.string.setting_reverse_buttons), 25, settingsCache, onSettingChanged)
        SettingSlider(stringResource(R.string.setting_short_press_step), 27, 1, 25, "°C", settingsCache, onSettingChanged)
        SettingSlider(stringResource(R.string.setting_long_press_step), 26, 5, 50, "°C", settingsCache, onSettingChanged)

        Spacer(modifier = Modifier.height(16.dp))

        Button(
            onClick = onSaveSettings,
            modifier = Modifier.fillMaxWidth(),
            shape = MaterialTheme.shapes.medium
        ) {
            Text(stringResource(R.string.button_save_to_device))
        }

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = stringResource(R.string.settings_footer_message),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
            modifier = Modifier.padding(horizontal = 4.dp)
        )
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.titleSmall,
        color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.padding(top = 16.dp, bottom = 8.dp)
    )
    HorizontalDivider()
}

@Composable
private fun SettingSlider(
    label: String,
    index: Int,
    min: Int,
    max: Int,
    unit: String,
    settingsCache: Map<Int, Int>,
    onSettingChanged: (Int, Int) -> Unit
) {
    val currentValue = settingsCache[index] ?: min
    var sliderValue by remember(currentValue) { mutableFloatStateOf(currentValue.toFloat()) }

    Column(modifier = Modifier.padding(vertical = 8.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(text = label, style = MaterialTheme.typography.bodyMedium)
            Text(
                text = "${sliderValue.roundToInt()}$unit",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.primary
            )
        }
        Slider(
            value = sliderValue,
            onValueChange = { sliderValue = it },
            onValueChangeFinished = { onSettingChanged(index, sliderValue.roundToInt()) },
            valueRange = min.toFloat()..max.toFloat(),
            colors = SliderDefaults.colors(
                activeTickColor = Color.Transparent,
                inactiveTickColor = Color.Transparent
            ),
            modifier = Modifier.fillMaxWidth()
        )
    }
}

@Composable
private fun SettingToggle(
    label: String,
    index: Int,
    settingsCache: Map<Int, Int>,
    onSettingChanged: (Int, Int) -> Unit
) {
    val currentValue = settingsCache[index] ?: 0

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(text = label, style = MaterialTheme.typography.bodyMedium)
        Switch(
            checked = currentValue != 0,
            onCheckedChange = { checked ->
                onSettingChanged(index, if (checked) 1 else 0)
            }
        )
    }
}

@Composable
private fun SettingPicker(
    label: String,
    index: Int,
    options: List<String>,
    settingsCache: Map<Int, Int>,
    onSettingChanged: (Int, Int) -> Unit
) {
    val currentValue = (settingsCache[index] ?: 0).coerceIn(0, options.size - 1)

    Column(modifier = Modifier.padding(vertical = 8.dp)) {
        Text(text = label, style = MaterialTheme.typography.bodyMedium)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            options.forEachIndexed { optionIndex, optionLabel ->
                val isSelected = optionIndex == currentValue
                Button(
                    onClick = { onSettingChanged(index, optionIndex) },
                    modifier = Modifier.weight(1f),
                    shape = MaterialTheme.shapes.small,
                    colors = if (isSelected) {
                        androidx.compose.material3.ButtonDefaults.buttonColors()
                    } else {
                        androidx.compose.material3.ButtonDefaults.outlinedButtonColors()
                    }
                ) {
                    Text(optionLabel, style = MaterialTheme.typography.labelMedium)
                }
            }
        }
    }
}
