import SwiftUI
import AppKit

struct SubtitleResizeOverlay: NSViewRepresentable {
    func makeNSView(context: Context) -> ResizeOverlayView {
        ResizeOverlayView()
    }

    func updateNSView(_ nsView: ResizeOverlayView, context: Context) {}
}

final class ResizeOverlayView: NSView {
    private let edgeSize: CGFloat = 8
    private var activeEdges: RectEdge = []
    private var initialFrame = NSRect.zero
    private var initialMouse = NSPoint.zero
    private var tracking: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking {
            removeTrackingArea(tracking)
        }
        let tracking = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(tracking)
        self.tracking = tracking
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        edges(at: point).isEmpty ? nil : self
    }

    override func mouseMoved(with event: NSEvent) {
        cursor(for: edges(at: convert(event.locationInWindow, from: nil))).set()
    }

    override func cursorUpdate(with event: NSEvent) {
        cursor(for: edges(at: convert(event.locationInWindow, from: nil))).set()
    }

    override func mouseDown(with event: NSEvent) {
        activeEdges = edges(at: convert(event.locationInWindow, from: nil))
        initialFrame = window?.frame ?? .zero
        initialMouse = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, !activeEdges.isEmpty else { return }
        let current = NSEvent.mouseLocation
        let dx = current.x - initialMouse.x
        let dy = current.y - initialMouse.y
        var frame = initialFrame
        let minSize = window.minSize

        if activeEdges.contains(.left) {
            frame.origin.x += dx
            frame.size.width -= dx
        }
        if activeEdges.contains(.right) {
            frame.size.width += dx
        }
        if activeEdges.contains(.bottom) {
            frame.origin.y += dy
            frame.size.height -= dy
        }
        if activeEdges.contains(.top) {
            frame.size.height += dy
        }

        if frame.size.width < minSize.width {
            if activeEdges.contains(.left) {
                frame.origin.x -= minSize.width - frame.size.width
            }
            frame.size.width = minSize.width
        }
        if frame.size.height < minSize.height {
            if activeEdges.contains(.bottom) {
                frame.origin.y -= minSize.height - frame.size.height
            }
            frame.size.height = minSize.height
        }

        window.setFrame(frame, display: true)
    }

    private func edges(at point: NSPoint) -> RectEdge {
        var edges: RectEdge = []
        if point.x <= edgeSize {
            edges.insert(.left)
        }
        if point.x >= bounds.width - edgeSize {
            edges.insert(.right)
        }
        if point.y <= edgeSize {
            edges.insert(.bottom)
        }
        if point.y >= bounds.height - edgeSize {
            edges.insert(.top)
        }
        return edges
    }

    private func cursor(for edges: RectEdge) -> NSCursor {
        if edges.contains(.left) || edges.contains(.right) {
            return .resizeLeftRight
        }
        if edges.contains(.top) || edges.contains(.bottom) {
            return .resizeUpDown
        }
        return .arrow
    }
}

struct RectEdge: OptionSet {
    let rawValue: Int

    static let top = RectEdge(rawValue: 1 << 0)
    static let right = RectEdge(rawValue: 1 << 1)
    static let bottom = RectEdge(rawValue: 1 << 2)
    static let left = RectEdge(rawValue: 1 << 3)
}
