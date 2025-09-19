//
//  SpeedTestView.swift
//  cleanme2
//

import SwiftUI
import Foundation

struct SpeedTestView: View {
    @StateObject private var speedometerViewModel = SpeedometerViewModel()
    @Binding var isPaywallPresented: Bool

    @State private var graphDrawProgress: CGFloat = 0.0 // State variable for graph animation

    private var scalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24 * scalingFactor) {
                speedtestHeaderSection
                    
                // Карточка с датчиком скорости
                speedtestGaugeCard
                    
                // Карточки с информацией о соединении
                speedtestInfoCards
                    
                // График внизу
                speedtestGraph
            }
            .padding(.horizontal, 16 * scalingFactor)
            .padding(.bottom, 100 * scalingFactor)
            .onAppear {
                // Animate the graph drawing when this view appears
                self.graphDrawProgress = 0.0
                withAnimation(.easeInOut(duration: 1.5)) {
                    self.graphDrawProgress = 1.0
                }
                
                // Initialize IP address for display
                speedometerViewModel.updateIP()
            }
        }
    }
    
    // MARK: - Секция заголовка для Speedtest
    private var speedtestHeaderSection: some View {
        HStack {
            Text("Speedtest")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(CMColor.primaryText)
                
            Spacer()
            // todo PRO
//            ProBadgeView(isPaywallPresented: $isPaywallPresented)
        }
        .padding(.top, 20 * scalingFactor)
    }
    
    // MARK: - Вспомогательные элементы Speedtest
    private var speedtestGaugeCard: some View {
        VStack(spacing: 24 * scalingFactor) {
            // Информационная строка с IP и Ping
            HStack {
                Text("IP: \(speedometerViewModel.ip ?? "---")")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
                    
                Spacer()
                    
                Text("Ping: \(speedometerViewModel.latency)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
            }
            
            // Статус теста
            Text(speedometerViewModel.testPhase.description)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(speedometerViewModel.testPhase.isActive ? CMColor.primary : CMColor.secondaryText)
                .multilineTextAlignment(.center)
                
            // Динамический датчик скорости
            GaugeView(speed: $speedometerViewModel.speed, phase: speedometerViewModel.gaugePhase)
                .frame(width: 250 * scalingFactor, height: 250 * scalingFactor)
                .overlay(
                    // Кнопка запуска теста в центре датчика
                    Group {
                        if !speedometerViewModel.isTestInProgress && speedometerViewModel.testPhase == .idle {
                            Button(action: {
                                speedometerViewModel.startRealSpeedTest()
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 24, weight: .bold))
                                    Text("Start")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .foregroundColor(CMColor.primary)
                                .padding(16)
                                .background(CMColor.backgroundSecondary)
                                .clipShape(Circle())
                            }
                        } else if speedometerViewModel.testPhase == .completed {
                            Button(action: {
                                speedometerViewModel.resetTestData()
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 24, weight: .bold))
                                    Text("Again")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .foregroundColor(CMColor.primary)
                                .padding(16)
                                .background(CMColor.backgroundSecondary)
                                .clipShape(Circle())
                            }
                        } else if speedometerViewModel.isTestInProgress {
                            VStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                    .tint(CMColor.primary)
                                Text("Test")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(CMColor.primary)
                            }
                        }
                    }
                )
            
            // Результаты скорости загрузки и выгрузки
            HStack(spacing: 16 * scalingFactor) {
                HStack {
                    Image(systemName: "arrow.down")
                        .foregroundColor(speedometerViewModel.downloadSpeed > 0 ? CMColor.primaryLight : CMColor.tertiaryText)
                    Text("\(String(format: "%.1f", speedometerViewModel.finalDownloadSpeed > 0 ? speedometerViewModel.finalDownloadSpeed : speedometerViewModel.downloadSpeed)) Mbps")
                        .foregroundColor(speedometerViewModel.downloadSpeed > 0 ? CMColor.primaryLight : CMColor.tertiaryText)
                        .font(.system(size: 14, weight: .semibold))
                }
                    
                HStack {
                    Image(systemName: "arrow.up")
                        .foregroundColor(speedometerViewModel.uploadSpeed > 0 ? CMColor.success : CMColor.tertiaryText)
                    Text("\(String(format: "%.1f", speedometerViewModel.finalUploadSpeed > 0 ? speedometerViewModel.finalUploadSpeed : speedometerViewModel.uploadSpeed)) Mbps")
                        .foregroundColor(speedometerViewModel.uploadSpeed > 0 ? CMColor.success : CMColor.tertiaryText)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            
            // Сообщение об ошибке (если есть)
            if let errorMessage = speedometerViewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(CMColor.error)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
        }
        .padding(24 * scalingFactor)
        .background(CMColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24 * scalingFactor))
        .shadow(color: CMColor.primary.opacity(0.08), radius: 16, x: 0, y: 16)
    }
                
    private var speedtestInfoCards: some View {
        VStack(spacing: 16 * scalingFactor) {
            // Карточка с информацией о устройстве и соединении
            HStack(spacing: 16 * scalingFactor) {
                Image(systemName: "wifi")
                    .font(.system(size: 24 * scalingFactor))
                    .foregroundColor(CMColor.primaryLight)
                    .padding(12 * scalingFactor)
                    .background(CMColor.backgroundSecondary)
                    .clipShape(Circle())
                    
                VStack(alignment: .leading, spacing: 4 * scalingFactor) {
                    Text("Connection")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(CMColor.primaryText)
                    Text(getConnectionType())
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(CMColor.tertiaryText)
                }
                Spacer()
            }
            .padding(16 * scalingFactor)
            .background(CMColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16 * scalingFactor))
            .shadow(color: CMColor.primary.opacity(0.08), radius: 16, x: 0, y: 16)

            // Карточка с информацией о сервере
            HStack(spacing: 16 * scalingFactor) {
                Image(systemName: "server.rack")
                    .font(.system(size: 24 * scalingFactor))
                    .foregroundColor(CMColor.primaryLight)
                    .padding(12 * scalingFactor)
                    .background(CMColor.backgroundSecondary)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4 * scalingFactor) {
                    Text("Test server")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(CMColor.primaryText)
                    Text(speedometerViewModel.serverInfo)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(CMColor.tertiaryText)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(16 * scalingFactor)
            .background(CMColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16 * scalingFactor))
            .shadow(color: CMColor.primary.opacity(0.08), radius: 16, x: 0, y: 16)
        }
    }
    
    // MARK: - Helper Methods
    
    private func getConnectionType() -> String {
        // В реальном приложении здесь бы была логика определения типа соединения
        return "Wi-Fi • \(UIDevice.current.model)"
    }

    private var speedtestGraph: some View {
        VStack(spacing: 16 * scalingFactor) {
            // Заголовок графика
            HStack {
                Text("Testing History")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
                Spacer()
            }
            
            ZStack(alignment: .bottom) {
                // Фоновая сетка
                Path { path in
                    let width: CGFloat = UIScreen.main.bounds.width - 64 * scalingFactor
                    let height: CGFloat = 120 * scalingFactor
                    
                    // Горизонтальные линии
                    for i in 0...4 {
                        let y = height * CGFloat(i) / 4
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                    
                    // Вертикальные линии
                    for i in 0...6 {
                        let x = width * CGFloat(i) / 6
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: height))
                    }
                }
                .stroke(CMColor.border.opacity(0.3), lineWidth: 0.5)
                .frame(height: 120 * scalingFactor)
                
                // График загрузки (зеленый)
                if speedometerViewModel.downloadSpeed > 0 || speedometerViewModel.finalDownloadSpeed > 0 {
                    createSpeedLine(
                        speed: speedometerViewModel.finalDownloadSpeed > 0 ? speedometerViewModel.finalDownloadSpeed : speedometerViewModel.downloadSpeed,
                        color: CMColor.primaryLight,
                        isUpload: false
                    )
                }
                
                // График выгрузки (синий)
                if speedometerViewModel.uploadSpeed > 0 || speedometerViewModel.finalUploadSpeed > 0 {
                    createSpeedLine(
                        speed: speedometerViewModel.finalUploadSpeed > 0 ? speedometerViewModel.finalUploadSpeed : speedometerViewModel.uploadSpeed,
                        color: CMColor.success,
                        isUpload: true
                    )
                }
            }
            .frame(height: 120 * scalingFactor)
            
            // Легенда
            HStack(spacing: 24 * scalingFactor) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(CMColor.primaryLight)
                        .frame(width: 8, height: 8)
                    Text("Loading")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(CMColor.secondaryText)
                }
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(CMColor.success)
                        .frame(width: 8, height: 8)
                    Text("Uploading")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(CMColor.secondaryText)
                }
                
                Spacer()
            }
        }
        .padding(.vertical, 24 * scalingFactor)
    }
    
    private func createSpeedLine(speed: Double, color: Color, isUpload: Bool) -> some View {
        Path { path in
            let width: CGFloat = UIScreen.main.bounds.width - 64 * scalingFactor
            let height: CGFloat = 120 * scalingFactor
            let normalizedSpeed = min(speed / 100.0, 1.0) // Нормализация до 100 Mbps
            
            // Создаем плавную кривую на основе скорости
            let points = createSpeedPoints(width: width, height: height, maxSpeed: normalizedSpeed, isUpload: isUpload)
            
            if let firstPoint = points.first {
                path.move(to: firstPoint)
                for i in 1..<points.count {
                    let point = points[i]
                    let previousPoint = points[i - 1]
                    let controlPoint1 = CGPoint(
                        x: previousPoint.x + (point.x - previousPoint.x) / 3,
                        y: previousPoint.y
                    )
                    let controlPoint2 = CGPoint(
                        x: point.x - (point.x - previousPoint.x) / 3,
                        y: point.y
                    )
                    path.addCurve(to: point, control1: controlPoint1, control2: controlPoint2)
                }
            }
        }
        .trim(from: 0, to: speedometerViewModel.testPhase == .completed ? 1.0 : graphDrawProgress)
        .stroke(color, lineWidth: 2.5)
        .animation(.easeInOut(duration: 0.5), value: speed)
    }
    
    private func createSpeedPoints(width: CGFloat, height: CGFloat, maxSpeed: Double, isUpload: Bool) -> [CGPoint] {
        var points: [CGPoint] = []
        let stepCount = 20
        
        for i in 0...stepCount {
            let x = width * CGFloat(i) / CGFloat(stepCount)
            let progress = Double(i) / Double(stepCount)
            
            // Создаем реалистичную кривую скорости
            var speedAtPoint: Double
            if isUpload {
                // Выгрузка: медленный старт, затем рост
                speedAtPoint = maxSpeed * (1.0 - exp(-progress * 3))
            } else {
                // Загрузка: быстрый рост, затем стабилизация
                speedAtPoint = maxSpeed * (1.0 - cos(progress * .pi / 2))
            }
            
            let y = height * (1.0 - speedAtPoint)
            points.append(CGPoint(x: x, y: y))
        }
        
        return points
    }
}
