import SwiftUI

public struct SeekBar: View {
    @Binding public var currentTime: Double
    public let duration: Double
    
    @State private var isDragging: Bool = false
    @State private var dragProgress: Double = 0.0
    
    private let normalHeight: CGFloat = 6.0
    private let draggingHeight: CGFloat = 10.0
    
    public init(currentTime: Binding<Double>, duration: Double) {
        self._currentTime = currentTime
        self.duration = duration
    }
    
    // Clamped progress between 0.0 and 1.0 (local drag takes precedence to prevent visual stutter)
    private var progress: Double {
        if isDragging {
            return dragProgress
        }
        guard duration > 0, duration.isFinite else { return 0.0 }
        return min(max(currentTime / duration, 0.0), 1.0)
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // Elapsed time (left)
            Text(formatTime(isDragging ? dragProgress * duration : currentTime))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .monospacedDigit()
            
            // Interactive scrubber bar
            GeometryReader { geo in
                let width = geo.size.width
                
                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(Color.white.opacity(0.20))
                    
                    // Progress fill
                    Capsule()
                        .fill(Color.white.opacity(0.70))
                        .frame(width: max(0, width * CGFloat(progress)))
                }
                .clipShape(Capsule())
                .frame(height: isDragging ? draggingHeight : normalHeight)
                .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isDragging)
                // Center vertically inside the enlarged hit area
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDragging {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                                    isDragging = true
                                }
                            }
                            let rawPct = width > 0 ? Double(value.location.x / width) : 0.0
                            let clamped = min(max(rawPct, 0.0), 1.0)
                            dragProgress = clamped
                            currentTime = clamped * duration
                        }
                        .onEnded { value in
                            let rawPct = width > 0 ? Double(value.location.x / width) : 0.0
                            let clamped = min(max(rawPct, 0.0), 1.0)
                            currentTime = clamped * duration
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                                isDragging = false
                            }
                        }
                )
            }
            .frame(height: 24) // Enlarged invisible hit target area for effortless touch/mouse scrubbing
            
            // Total duration (right)
            Text(formatTime(duration))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
    }
    
    // Format seconds into m:ss
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && !seconds.isNaN && seconds >= 0 else { return "0:00" }
        let totalSeconds = Int(seconds.rounded(.down))
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

#if compiler(>=5.9)
#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        SeekBar(currentTime: .constant(28), duration: 108)
            .padding(.horizontal, 20)
    }
}
#else
struct SeekBar_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            SeekBar(currentTime: .constant(28), duration: 108)
                .padding(.horizontal, 20)
        }
    }
}
#endif
