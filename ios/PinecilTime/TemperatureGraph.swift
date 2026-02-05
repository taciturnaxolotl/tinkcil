//
//  TemperatureGraph.swift
//  PinecilTime
//

import Charts
import SwiftUI

struct TemperatureGraph: View {
    let history: [TemperaturePoint]
    let maxTemp: UInt32

    var body: some View {
        Chart {
            setpointLine
            actualTempLine
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartYScale(domain: 0...500)
    }

    @ChartContentBuilder
    private var setpointLine: some ChartContent {
        ForEach(history) { point in
            LineMark(
                x: .value("T", point.timestamp),
                y: .value("S", Int(point.setpoint)),
                series: .value("L", "S")
            )
            .foregroundStyle(Color.gray.opacity(0.4))
            .lineStyle(StrokeStyle(lineWidth: 1.5))
        }
    }

    @ChartContentBuilder
    private var actualTempLine: some ChartContent {
        ForEach(history) { point in
            LineMark(
                x: .value("T", point.timestamp),
                y: .value("A", Int(point.actualTemp)),
                series: .value("L", "A")
            )
            .foregroundStyle(lineColor)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
    }

    private var lineColor: Color {
        guard let last = history.last else { return .blue }
        let temp = last.actualTemp
        if temp < 150 { return .blue }
        if temp < 300 { return .orange }
        return .red
    }
}
