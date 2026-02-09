package com.tinkcil.data.model

enum class PowerSource(val raw: Int, val label: String) {
    DC(0, "DC"),
    QC(1, "QC"),
    PD_TYPE1(2, "PD"),
    PD_TYPE2(3, "PD");

    companion object {
        fun fromRaw(value: Int): PowerSource =
            entries.find { it.raw == value } ?: DC
    }
}
