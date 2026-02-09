package com.tinkcil.data.model

data class TemperaturePoint(
    val timestamp: Long,
    val actualTemp: Int,
    val setpoint: Int
)
