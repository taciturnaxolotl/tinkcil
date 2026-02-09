package com.tinkcil.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.tinkcil.data.model.OperatingMode
import com.tinkcil.ui.theme.TemperatureTypography

@Composable
fun TemperatureDisplay(
    currentTemp: Int,
    setpoint: Int,
    maxTemp: Int,
    operatingMode: OperatingMode,
    isCompact: Boolean = false,
    modifier: Modifier = Modifier
) {
    val tempColor by animateColorAsState(
        targetValue = temperatureColor(currentTemp, maxTemp),
        animationSpec = tween(300),
        label = "tempColor"
    )

    Column(
        modifier = modifier.padding(vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "$currentTemp°",
            style = if (isCompact) TemperatureTypography.medium else TemperatureTypography.large,
            color = tempColor,
            textAlign = TextAlign.Center
        )

        if (operatingMode.isActive && setpoint != currentTemp) {
            Text(
                text = "→ $setpoint°",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                textAlign = TextAlign.Center
            )
        }
    }
}
