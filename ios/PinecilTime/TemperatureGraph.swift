//
//  TemperatureGraph.swift
//  PinecilTime
//

import Charts
import SwiftUI

private struct ChartDataPoint: Identifiable {
    let id: String
    let timestamp: Date
    let value: Int
    let series: String
}

struct TemperatureGraph: View {
    let history: [TemperaturePoint]
    let currentSetpoint: Int

    private var chartData: [ChartDataPoint] {
        var data: [ChartDataPoint] = []
        for point in history {
            data.append(ChartDataPoint(
                id: "\(point.id)-setpoint",
                timestamp: point.timestamp,
                value: Int(point.setpoint),
                series: "Setpoint"
            ))
            data.append(ChartDataPoint(
                id: "\(point.id)-temp",
                timestamp: point.timestamp,
                value: Int(point.actualTemp),
                series: "Temp"
            ))
        }
        return data
    }

    private var lineColor: Color {
        guard let last = history.last else { return .blue }
        let temp = last.actualTemp
        if temp < 150 { return .blue }
        if temp < 300 { return .orange }
        return .red
    }

    private func chartDataWithEdge(now: Date, windowSeconds: TimeInterval) -> [ChartDataPoint] {
        var data: [ChartDataPoint] = []

        // Add point slightly before first data point (only if data has scrolled to left edge)
        if let first = history.first {
            let windowStart = now.addingTimeInterval(-windowSeconds)
            if first.timestamp <= windowStart {
                let leftEdge = windowStart.addingTimeInterval(-1)
                data.append(ChartDataPoint(
                    id: "left-setpoint",
                    timestamp: leftEdge,
                    value: Int(first.setpoint),
                    series: "Setpoint"
                ))
                data.append(ChartDataPoint(
                    id: "left-temp",
                    timestamp: leftEdge,
                    value: Int(first.actualTemp),
                    series: "Temp"
                ))
            }
        }

        data.append(contentsOf: chartData)

        // Add point at right edge
        if let last = history.last {
            let rightEdge = now.addingTimeInterval(1)
            data.append(ChartDataPoint(
                id: "edge-setpoint",
                timestamp: rightEdge,
                value: currentSetpoint,
                series: "Setpoint"
            ))
            data.append(ChartDataPoint(
                id: "edge-temp",
                timestamp: rightEdge,
                value: Int(last.actualTemp),
                series: "Temp"
            ))
        }
        return data
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date
            let windowSeconds: TimeInterval = 6
            let xDomain = now.addingTimeInterval(-windowSeconds)...now

            Chart(chartDataWithEdge(now: now, windowSeconds: windowSeconds)) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Value", point.value),
                    series: .value("Series", point.series)
                )
                .foregroundStyle(point.series == "Setpoint" ? Color.gray.opacity(0.4) : lineColor)
                .lineStyle(StrokeStyle(lineWidth: point.series == "Setpoint" ? 1.5 : 2.5, lineCap: .round))
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .chartYScale(domain: 0...500)
            .chartXScale(domain: xDomain)
        }
    }
}
