import Cocoa

extension NSColor {
    var hexString: String {
        guard let rgbColor = usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int(rgbColor.redComponent * 255)
        let g = Int(rgbColor.greenComponent * 255)
        let b = Int(rgbColor.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

enum AnnotationTool: Int {
    case freehand = 0
    case rectangle = 1
    case circle = 2
    case arrow = 3
    case line = 4
}

struct AnnotationPath {
    var tool: AnnotationTool
    var points: [NSPoint]
    var color: NSColor
    var strokeWidth: CGFloat
    var timestamp: TimeInterval
}

class AnnotationOverlayWindow: NSWindow {
    init() {
        guard let screen = NSScreen.main else {
            super.init(contentRect: NSRect(x: 0, y: 0, width: 1920, height: 1080),
                       styleMask: .borderless, backing: .buffered, defer: false)
            return
        }
        
        let visibleFrame = screen.visibleFrame
        
        super.init(
            contentRect: visibleFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        self.level = .floating
        self.backgroundColor = NSColor.black.withAlphaComponent(0.01)
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        self.isReleasedWhenClosed = false
    }
}

protocol AnnotationOverlayDelegate: AnyObject {
    func annotationDidStart()
    func annotationDidEnd(paths: [AnnotationPath], snapshot: NSImage?)
}

class AnnotationDrawingView: NSView {
    weak var delegate: AnnotationOverlayDelegate?
    
    var currentTool: AnnotationTool = .freehand
    var currentColor: NSColor = .systemRed
    var currentStrokeWidth: CGFloat = 4.0
    
    private var paths: [AnnotationPath] = []
    private var currentPath: AnnotationPath?
    private var startPoint: NSPoint = .zero
    private var annotationStartTime: TimeInterval = 0
    
    override var acceptsFirstResponder: Bool { true }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()
        
        for path in paths {
            drawPath(path)
        }
        
        if let current = currentPath {
            drawPath(current)
        }
    }
    
    private func drawPath(_ path: AnnotationPath) {
        path.color.setStroke()
        
        let bezierPath = NSBezierPath()
        bezierPath.lineWidth = path.strokeWidth
        bezierPath.lineCapStyle = .round
        bezierPath.lineJoinStyle = .round
        
        switch path.tool {
        case .freehand:
            guard path.points.count > 0 else { return }
            bezierPath.move(to: path.points[0])
            for point in path.points.dropFirst() {
                bezierPath.line(to: point)
            }
            bezierPath.stroke()
            
        case .rectangle:
            guard path.points.count >= 2 else { return }
            let start = path.points[0]
            let end = path.points[path.points.count - 1]
            let rect = NSRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            )
            bezierPath.appendRect(rect)
            bezierPath.stroke()
            
        case .circle:
            guard path.points.count >= 2 else { return }
            let start = path.points[0]
            let end = path.points[path.points.count - 1]
            let rect = NSRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            )
            bezierPath.appendOval(in: rect)
            bezierPath.stroke()
            
        case .arrow:
            guard path.points.count >= 2 else { return }
            let start = path.points[0]
            let end = path.points[path.points.count - 1]
            drawArrow(from: start, to: end, path: bezierPath, strokeWidth: path.strokeWidth)
            bezierPath.stroke()
            
        case .line:
            guard path.points.count >= 2 else { return }
            let start = path.points[0]
            let end = path.points[path.points.count - 1]
            bezierPath.move(to: start)
            bezierPath.line(to: end)
            bezierPath.stroke()
        }
    }
    
    private func drawArrow(from start: NSPoint, to end: NSPoint, path: NSBezierPath, strokeWidth: CGFloat) {
        path.move(to: start)
        path.line(to: end)
        
        let arrowLength: CGFloat = 20 + strokeWidth * 2
        let arrowAngle: CGFloat = .pi / 6
        
        let dx = end.x - start.x
        let dy = end.y - start.y
        let angle = atan2(dy, dx)
        
        let arrowPoint1 = NSPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let arrowPoint2 = NSPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )
        
        path.move(to: end)
        path.line(to: arrowPoint1)
        path.move(to: end)
        path.line(to: arrowPoint2)
    }
    
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        startPoint = point
        
        if paths.isEmpty {
            annotationStartTime = Date().timeIntervalSince1970 * 1000
            delegate?.annotationDidStart()
        }
        
        currentPath = AnnotationPath(
            tool: currentTool,
            points: [point],
            color: currentColor,
            strokeWidth: currentStrokeWidth,
            timestamp: Date().timeIntervalSince1970 * 1000
        )
        
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        
        if currentTool == .freehand {
            currentPath?.points.append(point)
        } else {
            if currentPath?.points.count == 1 {
                currentPath?.points.append(point)
            } else {
                currentPath?.points[1] = point
            }
        }
        
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        if let path = currentPath, path.points.count > 0 {
            paths.append(path)
        }
        currentPath = nil
        needsDisplay = true
    }
    
    func clearAll() {
        paths.removeAll()
        currentPath = nil
        needsDisplay = true
    }
    
    func undo() {
        if !paths.isEmpty {
            paths.removeLast()
            needsDisplay = true
        }
    }
    
    func captureSnapshot() -> NSImage? {
        let image = NSImage(size: bounds.size)
        image.lockFocus()
        draw(bounds)
        image.unlockFocus()
        return image
    }
    
    func getAnnotationPaths() -> [AnnotationPath] {
        return paths
    }
    
    func getAnnotationStartTime() -> TimeInterval {
        return annotationStartTime
    }
}

class AnnotationToolbar: NSPanel {
    weak var drawingView: AnnotationDrawingView?
    var onClose: (() -> Void)?
    
    private var toolButtons: [NSButton] = []
    private var colorWells: [NSButton] = []
    private var selectedToolIndex = 0
    private var selectedColorIndex = 0
    
    private let tools: [(AnnotationTool, String, String)] = [
        (.freehand, "✏️", "Freehand (F)"),
        (.rectangle, "▢", "Rectangle (R)"),
        (.circle, "○", "Circle (C)"),
        (.arrow, "➔", "Arrow (A)"),
        (.line, "╱", "Line (L)")
    ]
    
    private let colors: [NSColor] = [.systemRed, .systemOrange, .systemYellow, .systemGreen, .systemBlue, .white]
    
    init() {
        super.init(
            contentRect: NSRect(x: 100, y: 100, width: 100, height: 60),
            styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.title = "Annotation Tools"
        self.level = .mainMenu + 1
        self.isReleasedWhenClosed = false
        self.becomesKeyOnlyIfNeeded = true
        self.hidesOnDeactivate = false
        self.delegate = self
        
        setupToolbar()
        centerOnScreen()
    }
    
    private func centerOnScreen() {
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - frame.width / 2
            let y = screenFrame.maxY - 80
            setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
    
    private func setupToolbar() {
        var x: CGFloat = 10
        
        let containerView = NSView()
        
        for (index, (_, icon, tooltip)) in tools.enumerated() {
            let button = NSButton(frame: NSRect(x: x, y: 15, width: 40, height: 30))
            button.title = icon
            button.bezelStyle = .rounded
            button.setButtonType(.toggle)
            button.toolTip = tooltip
            button.tag = index
            button.target = self
            button.action = #selector(toolButtonClicked(_:))
            button.state = index == 0 ? .on : .off
            containerView.addSubview(button)
            toolButtons.append(button)
            x += 44
        }
        
        let separator1 = NSBox(frame: NSRect(x: x + 5, y: 10, width: 1, height: 40))
        separator1.boxType = .separator
        containerView.addSubview(separator1)
        x += 15
        
        for (index, color) in colors.enumerated() {
            let button = NSButton(frame: NSRect(x: x, y: 15, width: 30, height: 30))
            button.title = ""
            button.bezelStyle = .rounded
            button.isBordered = true
            button.wantsLayer = true
            button.layer?.backgroundColor = color.cgColor
            button.layer?.cornerRadius = 4
            button.tag = index
            button.target = self
            button.action = #selector(colorButtonClicked(_:))
            
            if index == 0 {
                button.layer?.borderWidth = 3
                button.layer?.borderColor = NSColor.white.cgColor
            }
            
            containerView.addSubview(button)
            colorWells.append(button)
            x += 34
        }
        
        let separator2 = NSBox(frame: NSRect(x: x + 5, y: 10, width: 1, height: 40))
        separator2.boxType = .separator
        containerView.addSubview(separator2)
        x += 15
        
        let undoButton = NSButton(frame: NSRect(x: x, y: 15, width: 50, height: 30))
        undoButton.title = "Undo"
        undoButton.bezelStyle = .rounded
        undoButton.target = self
        undoButton.action = #selector(undoClicked(_:))
        containerView.addSubview(undoButton)
        x += 55
        
        let clearButton = NSButton(frame: NSRect(x: x, y: 15, width: 50, height: 30))
        clearButton.title = "Clear"
        clearButton.bezelStyle = .rounded
        clearButton.target = self
        clearButton.action = #selector(clearClicked(_:))
        containerView.addSubview(clearButton)
        x += 55
        
        let doneButton = NSButton(frame: NSRect(x: x, y: 15, width: 60, height: 30))
        doneButton.title = "Done"
        doneButton.bezelStyle = .rounded
        doneButton.keyEquivalent = "\u{1b}"
        doneButton.target = self
        doneButton.action = #selector(doneClicked(_:))
        containerView.addSubview(doneButton)
        x += 70
        
        let totalWidth = x
        containerView.frame = NSRect(x: 0, y: 0, width: totalWidth, height: 60)
        self.setContentSize(NSSize(width: totalWidth, height: 60))
        self.contentView = containerView
    }
    
    @objc private func toolButtonClicked(_ sender: NSButton) {
        let index = sender.tag
        selectedToolIndex = index
        
        for (i, button) in toolButtons.enumerated() {
            button.state = i == index ? .on : .off
        }
        
        if let tool = AnnotationTool(rawValue: index) {
            drawingView?.currentTool = tool
            print("🎨 Tool selected: \(tool)")
        }
    }
    
    @objc private func colorButtonClicked(_ sender: NSButton) {
        let index = sender.tag
        selectedColorIndex = index
        
        for (i, button) in colorWells.enumerated() {
            button.layer?.borderWidth = i == index ? 3 : 0
            button.layer?.borderColor = NSColor.white.cgColor
        }
        
        let color = colors[index]
        drawingView?.currentColor = color
        print("🎨 Color selected: \(color)")
    }
    
    @objc private func undoClicked(_ sender: NSButton) {
        drawingView?.undo()
    }
    
    @objc private func clearClicked(_ sender: NSButton) {
        drawingView?.clearAll()
    }
    
    @objc private func doneClicked(_ sender: NSButton) {
        onClose?()
    }
    
    override func keyDown(with event: NSEvent) {
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "f":
            selectTool(0)
        case "r":
            selectTool(1)
        case "c":
            selectTool(2)
        case "a":
            selectTool(3)
        case "l":
            selectTool(4)
        case "z" where event.modifierFlags.contains(.command):
            drawingView?.undo()
        default:
            super.keyDown(with: event)
        }
    }
    
    private func selectTool(_ index: Int) {
        guard index < toolButtons.count else { return }
        toolButtonClicked(toolButtons[index])
    }
}

extension AnnotationToolbar: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}
