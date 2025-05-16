//
//  ContentView.swift
//  BackgroundPhotoTest
//
//  Created by artemiithefrog . on 01.10.2024.
//

import SwiftUI
import AVKit
import CoreImage
import UIKit

struct ContentView: View {
    @State private var gradientColors: [Color] = [.clear, .clear]
    @State private var colorDescriptions: [String] = []
    @State private var player: AVPlayer = {
        let player = AVPlayer(url: Bundle.main.url(forResource: "pivo", withExtension: "MOV")!)
        player.actionAtItemEnd = .none
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                               object: player.currentItem, queue: .main) { _ in
            player.seek(to: .zero)
            player.play()
        }
        player.isMuted = true
        return player
    }()
    
    var body: some View {
        ZStack {
            // Градиентный фон на основе цветов видео
            LinearGradient(gradient: Gradient(colors: gradientColors),
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .frame(width: UIScreen.main.bounds.width * 1.5, height: UIScreen.main.bounds.height * 1.5)
                .blur(radius: 100)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 1), value: gradientColors) // Анимация изменения фона
            
            // Проигрыватель видео
            VideoPlayer(player: player)
                .onDisappear {
                    player.seek(to: .zero)
                    player.pause()
                }
                .onAppear {
                    startVideoWithDelay() // Запуск видео с задержкой
                    startColorExtraction()
                }
                .disabled(true)
                .cornerRadius(20)
                .frame(width: 299.5, height: 535)
                .padding()
        }
    }
    
    // Извлечение цветов из кадров видео
    func startColorExtraction() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600) // Извлечение цвета каждые 0.5 секунды
        player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            extractColors(from: player)
        }
    }
    
    // Извлечение средних цветов из текущего кадра видео
    func extractColors(from player: AVPlayer) {
        guard let currentItem = player.currentItem else { return }
        
        let asset = currentItem.asset
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let time = player.currentTime()
        if let cgImage = try? imageGenerator.copyCGImage(at: time, actualTime: nil) {
            let uiImage = UIImage(cgImage: cgImage)
            if let extractedColors = uiImage.getAverageColorsFromGrid(rows: 3, columns: 3) {
                withAnimation {
                    gradientColors = extractedColors
                    colorDescriptions = gradientColors.map { $0.rgbDescription() }
                }
            }
        }
    }
    
    // Запуск видео с задержкой 2 секунды
    func startVideoWithDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            player.play()
        }
    }
}
extension UIImage {
    func getAverageColorsFromGrid(rows: Int, columns: Int) -> [Color]? {
        guard let cgImage = self.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        
        let tileWidth = width / columns
        let tileHeight = height / rows
        
        var colors: [Color] = []
        
        for row in 0..<rows {
            for column in 0..<columns {
                let rect = CGRect(x: column * tileWidth, y: row * tileHeight, width: tileWidth, height: tileHeight)
                if let tileColor = self.averageColor(in: rect) {
                    colors.append(Color(tileColor))
                }
            }
        }
        
        return colors
    }
    
    func averageColor(in rect: CGRect) -> UIColor? {
        guard let cgImage = self.cgImage?.cropping(to: rect) else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext(options: [.workingColorSpace: kCFNull!])
        
        let extentVector = CIVector(x: ciImage.extent.origin.x, y: ciImage.extent.origin.y, z: ciImage.extent.size.width, w: ciImage.extent.size.height)
        
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: ciImage, kCIInputExtentKey: extentVector]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        let r = CGFloat(bitmap[0]) / 255.0
        let g = CGFloat(bitmap[1]) / 255.0
        let b = CGFloat(bitmap[2]) / 255.0
        let a = CGFloat(bitmap[3]) / 255.0
        
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}

// Расширение для добавления RGB описания для Color
extension Color {
    func rgbDescription() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Конвертация в 0-255 RGB значения
        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)
        
        return "R: \(r), G: \(g), B: \(b)"
    }
}


#Preview {
    ContentView()
}
