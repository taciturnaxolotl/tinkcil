package com.tinkcil.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import com.tinkcil.data.model.TemperaturePoint
import kotlinx.coroutines.delay

@Composable
fun TemperatureGraph(
    points: List<TemperaturePoint>,
    currentTemp: Int,
    maxTemp: Int,
    showAxes: Boolean = false,
    windowSeconds: Float = 6f,
    modifier: Modifier = Modifier
) {
    val surfaceVariant = MaterialTheme.colorScheme.surfaceVariant
    val onSurface = MaterialTheme.colorScheme.onSurface

    // Trigger recomposition every 100ms for real-time animation
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) {
        while (true) {
            now = System.currentTimeMillis()
            delay(100)
        }
    }

    Canvas(modifier = modifier.fillMaxSize()) {
        val w = size.width
        val h = size.height
        val yMax = 500f
        val windowMs = (windowSeconds * 1000).toLong()
        val endTime = now + 1000L
        val startTime = endTime - windowMs

        if (showAxes) {
            drawAxes(w, h, yMax, surfaceVariant, onSurface)
        }

        if (points.size < 2) return@Canvas

        val tempColor = temperatureColor(currentTemp, maxTemp)

        // Draw setpoint line (thin, semi-transparent)
        drawTemperatureLine(
            points = points,
            startTime = startTime,
            endTime = endTime,
            yMax = yMax,
            w = w,
            h = h,
            color = onSurface.copy(alpha = 0.3f),
            strokeWidth = 1.5.dp.toPx(),
            getValue = { it.setpoint.toFloat() }
        )

        // Draw actual temperature line (thick, colored)
        drawTemperatureLine(
            points = points,
            startTime = startTime,
            endTime = endTime,
            yMax = yMax,
            w = w,
            h = h,
            color = tempColor,
            strokeWidth = 2.5.dp.toPx(),
            getValue = { it.actualTemp.toFloat() }
        )
    }
}

private fun DrawScope.drawTemperatureLine(
    points: List<TemperaturePoint>,
    startTime: Long,
    endTime: Long,
    yMax: Float,
    w: Float,
    h: Float,
    color: Color,
    strokeWidth: Float,
    getValue: (TemperaturePoint) -> Float
) {
    val visiblePoints = points.filter { it.timestamp in startTime..endTime }
    if (visiblePoints.size < 2) return

    val path = Path()
    var first = true

    for (point in visiblePoints) {
        val x = ((point.timestamp - startTime).toFloat() / (endTime - startTime)) * w
        val y = h - (getValue(point) / yMax) * h

        if (first) {
            path.moveTo(x, y)
            first = false
        } else {
            path.lineTo(x, y)
        }
    }

    drawPath(
        path = path,
        color = color,
        style = Stroke(
            width = strokeWidth,
            cap = StrokeCap.Round,
            join = StrokeJoin.Round
        )
    )
}

private fun DrawScope.drawAxes(w: Float, h: Float, yMax: Float, lineColor: Color, textColor: Color) {
    val steps = listOf(0f, 100f, 200f, 300f, 400f, 500f)
    for (value in steps) {
        val y = h - (value / yMax) * h
        drawLine(
            color = lineColor.copy(alpha = 0.3f),
            start = Offset(0f, y),
            end = Offset(w, y),
            strokeWidth = 0.5.dp.toPx()
        )
    }
}

fun temperatureColor(temp: Int, maxTemp: Int): Color {
    val progress = if (maxTemp > 0) (temp.toFloat() / maxTemp).coerceIn(0f, 1f) else 0f
    return when {
        progress < 0.33f -> {
            val t = progress / 0.33f
            Color(
                red = 0.1f * t,
                green = 0.5f + 0.3f * t,
                blue = 1f - 0.2f * t
            )
        }
        progress < 0.66f -> {
            val t = (progress - 0.33f) / 0.33f
            Color(
                red = 0.1f + 0.9f * t,
                green = 0.8f - 0.2f * t,
                blue = 0.8f - 0.8f * t
            )
        }
        else -> {
            val t = (progress - 0.66f) / 0.34f
            Color(
                red = 1f,
                green = 0.6f - 0.4f * t,
                blue = 0.1f - 0.1f * t
            )
        }
    }
}
