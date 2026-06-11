import SwiftUI

struct WaveSoundBar: View {
    var level: Float
    
    private let barCount = 15
    @State private var barParams: [(speed: Double, offset: Double)] = []
    
    var body: some View {
        TimelineView(.animation) { context in
            // TimelineView guarantees rendering at display refresh rate (60/120fps)
            // It completely bypasses Timer issues on macOS.
            let time = context.date.timeIntervalSinceReferenceDate
            
            HStack(spacing: 1.5) {
                if barParams.count == barCount {
                    ForEach(0..<barCount, id: \.self) { index in
                        Capsule()
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 2.5, height: barHeight(for: index, time: time))
                    }
                } else {
                    // Fallback before onAppear populates the random params
                    ForEach(0..<barCount, id: \.self) { index in
                        Capsule()
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 2.5, height: 3.0)
                    }
                }
            }
            .frame(height: 18, alignment: .center)
            .animation(.easeOut(duration: 0.2), value: level > 0.015)
        }
        .onAppear {
            // Replicate the exact random animation params from WaveForm.kt
            var params: [(Double, Double)] = []
            for _ in 0..<barCount {
                // Duration between 600ms and 2000ms equivalent
                let duration = Double.random(in: 0.6...2.0)
                let speed = .pi / duration
                let offset = Double.random(in: 0...(.pi * 2.0))
                params.append((speed: speed, offset: offset))
            }
            barParams = params
        }
    }
    
    private func barHeight(for index: Int, time: Double) -> CGFloat {
        let baseHeight: CGFloat = 3.0
        let maxExtra: CGFloat = 14.0
        
        let param = barParams[index]
        
        // This math perfectly maps to Compose's infiniteRepeatable tween with Reverse
        // animValue goes smoothly from 0 to 1 and back infinitely.
        let animValue = (sin(time * param.speed + param.offset) + 1.0) / 2.0
        
        // Combine audio level with the infinite animation, fold back if it exceeds 1.0
        var percent = (Double(level) * 2.5) + animValue
        if percent > 1.0 {
            percent = 2.0 - percent
        }
        percent = max(0, percent)
        
        let isListening = level > 0.015
        
        if isListening {
            // Envelope ensures the center bars are naturally taller
            let normalizedIndex = Double(index) / Double(max(1, barCount - 1))
            let envelope = 0.4 + 0.6 * sin(normalizedIndex * .pi)
            
            return baseHeight + CGFloat(percent * envelope) * maxExtra
        } else {
            return baseHeight
        }
    }
}
