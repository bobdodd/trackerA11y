import Cocoa

enum AnnotationType: String, Codable {
    case rectangle
    case ellipse
    case arrow
    case line
    case text
    case highlight
    case blur
    case callout
}

struct AnnotationStyle: Codable {
    var strokeColor: CodableColor
    var fillColor: CodableColor?
    var strokeWidth: CGFloat
    var opacity: CGFloat
    var fontSize: CGFloat?
    var fontName: String?
    var cornerRadius: CGFloat
    
    init(
        strokeColor: NSColor = .systemRed,
        fillColor: NSColor? = nil,
        strokeWidth: CGFloat = 3,
        opacity: CGFloat = 1.0,
        fontSize: CGFloat? = nil,
        fontName: String? = nil,
        cornerRadius: CGFloat = 0
    ) {
        self.strokeColor = CodableColor(strokeColor)
        self.fillColor = fillColor.map { CodableColor($0) }
        self.strokeWidth = strokeWidth
        self.opacity = opacity
        self.fontSize = fontSize
        self.fontName = fontName
        self.cornerRadius = cornerRadius
    }
    
    static var defaultShape: AnnotationStyle {
        AnnotationStyle(strokeColor: .systemRed, strokeWidth: 3)
    }
    
    static var defaultText: AnnotationStyle {
        AnnotationStyle(strokeColor: .white, fillColor: .systemRed, strokeWidth: 0, fontSize: 24, fontName: "Helvetica Neue")
    }
    
    static var defaultHighlight: AnnotationStyle {
        AnnotationStyle(strokeColor: .clear, fillColor: .systemYellow, strokeWidth: 0, opacity: 0.4)
    }
    
    static var defaultBlur: AnnotationStyle {
        AnnotationStyle(strokeColor: .clear, fillColor: .black, strokeWidth: 0, opacity: 0.8)
    }
    
    static var defaultCallout: AnnotationStyle {
        AnnotationStyle(strokeColor: .systemRed, fillColor: .white, strokeWidth: 3, fontSize: 16, fontName: "Helvetica Neue", cornerRadius: 8)
    }
}

struct CodableColor: Codable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat
    
    init(_ color: NSColor) {
        let converted = color.usingColorSpace(.deviceRGB) ?? color
        self.red = converted.redComponent
        self.green = converted.greenComponent
        self.blue = converted.blueComponent
        self.alpha = converted.alphaComponent
    }
    
    var nsColor: NSColor {
        NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

struct Annotation: Codable, Identifiable {
    var id: String
    var type: AnnotationType
    var startTime: Double
    var duration: Double
    var rect: CodableRect
    var style: AnnotationStyle
    var text: String?
    var arrowStart: CodablePoint?
    var arrowEnd: CodablePoint?
    
    var endTime: Double {
        startTime + duration
    }
    
    init(
        id: String = UUID().uuidString,
        type: AnnotationType,
        startTime: Double,
        duration: Double = 3_000_000,
        rect: NSRect,
        style: AnnotationStyle? = nil,
        text: String? = nil,
        arrowStart: NSPoint? = nil,
        arrowEnd: NSPoint? = nil
    ) {
        self.id = id
        self.type = type
        self.startTime = startTime
        self.duration = duration
        self.rect = CodableRect(rect)
        self.text = text
        self.arrowStart = arrowStart.map { CodablePoint($0) }
        self.arrowEnd = arrowEnd.map { CodablePoint($0) }
        
        switch type {
        case .rectangle, .ellipse, .line:
            self.style = style ?? .defaultShape
        case .arrow:
            self.style = style ?? .defaultShape
        case .text:
            self.style = style ?? .defaultText
        case .highlight:
            self.style = style ?? .defaultHighlight
        case .blur:
            self.style = style ?? .defaultBlur
        case .callout:
            self.style = style ?? .defaultCallout
        }
    }
    
    func isVisible(at timestamp: Double) -> Bool {
        timestamp >= startTime && timestamp < endTime
    }
}

struct CodableRect: Codable {
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    
    init(_ rect: NSRect) {
        self.x = rect.origin.x
        self.y = rect.origin.y
        self.width = rect.size.width
        self.height = rect.size.height
    }
    
    var nsRect: NSRect {
        NSRect(x: x, y: y, width: width, height: height)
    }
}

struct CodablePoint: Codable {
    var x: CGFloat
    var y: CGFloat
    
    init(_ point: NSPoint) {
        self.x = point.x
        self.y = point.y
    }
    
    var nsPoint: NSPoint {
        NSPoint(x: x, y: y)
    }
}

class AnnotationManager {
    private var annotations: [Annotation] = []
    private let sessionPath: String
    private let annotationsFile: String
    
    init(sessionPath: String) {
        self.sessionPath = sessionPath
        self.annotationsFile = "\(sessionPath)/annotations.json"
        loadAnnotations()
    }
    
    func loadAnnotations() {
        guard FileManager.default.fileExists(atPath: annotationsFile) else { return }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: annotationsFile))
            annotations = try JSONDecoder().decode([Annotation].self, from: data)
        } catch {
            print("Failed to load annotations: \(error)")
        }
    }
    
    func saveAnnotations() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(annotations)
            try data.write(to: URL(fileURLWithPath: annotationsFile))
        } catch {
            print("Failed to save annotations: \(error)")
        }
    }
    
    func addAnnotation(_ annotation: Annotation) {
        annotations.append(annotation)
        saveAnnotations()
    }
    
    func updateAnnotation(_ annotation: Annotation) {
        if let index = annotations.firstIndex(where: { $0.id == annotation.id }) {
            annotations[index] = annotation
            saveAnnotations()
        }
    }
    
    func deleteAnnotation(id: String) {
        annotations.removeAll { $0.id == id }
        saveAnnotations()
    }
    
    func getAnnotation(id: String) -> Annotation? {
        annotations.first { $0.id == id }
    }
    
    func getAllAnnotations() -> [Annotation] {
        annotations
    }
    
    func getVisibleAnnotations(at timestamp: Double) -> [Annotation] {
        annotations.filter { $0.isVisible(at: timestamp) }
    }
    
    func getAnnotationsSortedByTime() -> [Annotation] {
        annotations.sorted { $0.startTime < $1.startTime }
    }
}

protocol VideoAnnotationOverlayDelegate: AnyObject {
    func annotationOverlay(_ overlay: VideoAnnotationOverlayView, didSelectAnnotation annotation: Annotation?)
    func annotationOverlay(_ overlay: VideoAnnotationOverlayView, didCreateAnnotation annotation: Annotation)
    func annotationOverlay(_ overlay: VideoAnnotationOverlayView, didUpdateAnnotation annotation: Annotation)
}

class VideoAnnotationOverlayView: NSView, NSTextViewDelegate {
    weak var delegate: VideoAnnotationOverlayDelegate?
    
    private var annotations: [Annotation] = []
    private var currentTimestamp: Double = 0
    private var selectedAnnotationId: String?
    
    var isEditMode: Bool = false
    var pendingAnnotationType: AnnotationType?
    var currentColor: NSColor = .systemRed
    private var dragStartPoint: NSPoint?
    private var currentDragRect: NSRect?
    private var isCreatingAnnotation: Bool = false
    
    private var isDraggingAnnotation: Bool = false
    private var isResizingAnnotation: Bool = false
    private var draggedAnnotation: Annotation?
    private var resizeHandle: ResizeHandle = .none
    private var annotationDragOffset: NSPoint = .zero
    
    private var textEditView: NSTextView?
    private var editingAnnotationId: String?
    
    enum ResizeHandle {
        case none, topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
    }
    
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
    
    override var acceptsFirstResponder: Bool {
        return isEditMode && pendingAnnotationType != nil
    }
    
    func setAnnotations(_ annotations: [Annotation]) {
        self.annotations = annotations
        needsDisplay = true
    }
    
    func setCurrentTimestamp(_ timestamp: Double) {
        self.currentTimestamp = timestamp
        needsDisplay = true
    }
    
    func selectAnnotation(id: String?) {
        selectedAnnotationId = id
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()
        
        let visibleAnnotations = annotations.filter { $0.isVisible(at: currentTimestamp) }
        
        for annotation in visibleAnnotations {
            drawAnnotation(annotation)
        }
        
        if isCreatingAnnotation, let rect = currentDragRect {
            drawCreationPreview(rect: rect)
        }
    }
    
    private func drawAnnotation(_ annotation: Annotation) {
        let rect = annotation.rect.nsRect
        let isSelected = annotation.id == selectedAnnotationId
        let style = annotation.style
        
        let strokeColor = style.strokeColor.nsColor.withAlphaComponent(style.opacity)
        let fillColor = style.fillColor?.nsColor.withAlphaComponent(style.opacity)
        
        switch annotation.type {
        case .rectangle:
            drawRectangle(rect: rect, strokeColor: strokeColor, fillColor: fillColor, strokeWidth: style.strokeWidth, cornerRadius: style.cornerRadius, isSelected: isSelected)
            
        case .ellipse:
            drawEllipse(rect: rect, strokeColor: strokeColor, fillColor: fillColor, strokeWidth: style.strokeWidth, isSelected: isSelected)
            
        case .arrow:
            if let start = annotation.arrowStart?.nsPoint, let end = annotation.arrowEnd?.nsPoint {
                drawArrow(from: start, to: end, color: strokeColor, strokeWidth: style.strokeWidth, isSelected: isSelected)
            }
            
        case .line:
            if let start = annotation.arrowStart?.nsPoint, let end = annotation.arrowEnd?.nsPoint {
                drawLine(from: start, to: end, color: strokeColor, strokeWidth: style.strokeWidth, isSelected: isSelected)
            }
            
        case .text:
            drawText(text: annotation.text ?? "", rect: rect, style: style, isSelected: isSelected)
            
        case .highlight:
            drawHighlight(rect: rect, color: fillColor ?? .systemYellow, isSelected: isSelected)
            
        case .blur:
            drawBlur(rect: rect, isSelected: isSelected)
            
        case .callout:
            drawCallout(text: annotation.text ?? "", rect: rect, style: style, isSelected: isSelected)
        }
        
        if isSelected {
            drawSelectionHandles(rect: rect)
        }
    }
    
    private func drawRectangle(rect: NSRect, strokeColor: NSColor, fillColor: NSColor?, strokeWidth: CGFloat, cornerRadius: CGFloat, isSelected: Bool) {
        let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        
        if let fill = fillColor {
            fill.setFill()
            path.fill()
        }
        
        strokeColor.setStroke()
        path.lineWidth = strokeWidth
        path.stroke()
    }
    
    private func drawEllipse(rect: NSRect, strokeColor: NSColor, fillColor: NSColor?, strokeWidth: CGFloat, isSelected: Bool) {
        let path = NSBezierPath(ovalIn: rect)
        
        if let fill = fillColor {
            fill.setFill()
            path.fill()
        }
        
        strokeColor.setStroke()
        path.lineWidth = strokeWidth
        path.stroke()
    }
    
    private func drawArrow(from start: NSPoint, to end: NSPoint, color: NSColor, strokeWidth: CGFloat, isSelected: Bool) {
        let path = NSBezierPath()
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
        
        color.setStroke()
        path.lineWidth = strokeWidth
        path.lineCapStyle = .round
        path.stroke()
    }
    
    private func drawLine(from start: NSPoint, to end: NSPoint, color: NSColor, strokeWidth: CGFloat, isSelected: Bool) {
        let path = NSBezierPath()
        path.move(to: start)
        path.line(to: end)
        
        color.setStroke()
        path.lineWidth = strokeWidth
        path.lineCapStyle = .round
        path.stroke()
    }
    
    private func drawText(text: String, rect: NSRect, style: AnnotationStyle, isSelected: Bool) {
        let fontSize = style.fontSize ?? 24
        let fontName = style.fontName ?? "Helvetica Neue"
        let font = NSFont(name: fontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: style.strokeColor.nsColor,
            .paragraphStyle: paragraphStyle
        ]
        
        if let fill = style.fillColor?.nsColor {
            fill.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
        }
        
        let textRect = rect.insetBy(dx: 8, dy: 4)
        text.draw(in: textRect, withAttributes: attributes)
    }
    
    private func drawHighlight(rect: NSRect, color: NSColor, isSelected: Bool) {
        color.withAlphaComponent(0.4).setFill()
        NSBezierPath(rect: rect).fill()
    }
    
    private func drawBlur(rect: NSRect, isSelected: Bool) {
        NSColor.black.withAlphaComponent(0.8).setFill()
        NSBezierPath(rect: rect).fill()
    }
    
    private func drawCallout(text: String, rect: NSRect, style: AnnotationStyle, isSelected: Bool) {
        let path = NSBezierPath(roundedRect: rect, xRadius: style.cornerRadius, yRadius: style.cornerRadius)
        
        if let fill = style.fillColor?.nsColor {
            fill.setFill()
            path.fill()
        }
        
        style.strokeColor.nsColor.setStroke()
        path.lineWidth = style.strokeWidth
        path.stroke()
        
        let fontSize = style.fontSize ?? 16
        let fontName = style.fontName ?? "Helvetica Neue"
        let font = NSFont(name: fontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraphStyle
        ]
        
        let textRect = rect.insetBy(dx: 12, dy: 8)
        text.draw(in: textRect, withAttributes: attributes)
    }
    
    private func drawSelectionHandles(rect: NSRect) {
        let handleSize: CGFloat = 8
        let handleColor = NSColor.systemBlue
        
        let handles = [
            NSPoint(x: rect.minX, y: rect.minY),
            NSPoint(x: rect.midX, y: rect.minY),
            NSPoint(x: rect.maxX, y: rect.minY),
            NSPoint(x: rect.maxX, y: rect.midY),
            NSPoint(x: rect.maxX, y: rect.maxY),
            NSPoint(x: rect.midX, y: rect.maxY),
            NSPoint(x: rect.minX, y: rect.maxY),
            NSPoint(x: rect.minX, y: rect.midY)
        ]
        
        for handle in handles {
            let handleRect = NSRect(
                x: handle.x - handleSize / 2,
                y: handle.y - handleSize / 2,
                width: handleSize,
                height: handleSize
            )
            handleColor.setFill()
            NSBezierPath(ovalIn: handleRect).fill()
            NSColor.white.setStroke()
            let path = NSBezierPath(ovalIn: handleRect)
            path.lineWidth = 1
            path.stroke()
        }
    }
    
    private func drawCreationPreview(rect: NSRect) {
        NSColor.systemBlue.withAlphaComponent(0.3).setFill()
        NSBezierPath(rect: rect).fill()
        
        NSColor.systemBlue.setStroke()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = 2
        path.setLineDash([5, 5], count: 2, phase: 0)
        path.stroke()
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        if isCreatingAnnotation || isDraggingAnnotation || isResizingAnnotation {
            return super.hitTest(point)
        }
        
        if isEditMode && pendingAnnotationType != nil {
            return super.hitTest(point)
        }
        
        let localPoint = convert(point, from: superview)
        
        if let selected = annotations.first(where: { $0.id == selectedAnnotationId && $0.isVisible(at: currentTimestamp) }) {
            if hitTestResizeHandle(at: localPoint, for: selected) != .none {
                return super.hitTest(point)
            }
        }
        
        if hitTestAnnotation(at: localPoint) != nil {
            return super.hitTest(point)
        }
        
        return nil
    }
    
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        
        if textEditView != nil {
            finishTextEditing()
        }
        
        if isEditMode && pendingAnnotationType != nil {
            dragStartPoint = point
            isCreatingAnnotation = true
            currentDragRect = NSRect(origin: point, size: .zero)
            needsDisplay = true
            return
        }
        
        if event.clickCount == 2 {
            if let annotation = hitTestAnnotation(at: point) {
                if annotation.type == .text || annotation.type == .callout {
                    startTextEditing(annotation: annotation)
                    return
                }
            }
        }
        
        if let selected = annotations.first(where: { $0.id == selectedAnnotationId && $0.isVisible(at: currentTimestamp) }) {
            let handle = hitTestResizeHandle(at: point, for: selected)
            if handle != .none {
                isResizingAnnotation = true
                draggedAnnotation = selected
                resizeHandle = handle
                dragStartPoint = point
                setCursorForHandle(handle)
                return
            }
        }
        
        if let annotation = hitTestAnnotation(at: point) {
            selectedAnnotationId = annotation.id
            delegate?.annotationOverlay(self, didSelectAnnotation: annotation)
            
            isDraggingAnnotation = true
            draggedAnnotation = annotation
            annotationDragOffset = NSPoint(
                x: point.x - annotation.rect.nsRect.origin.x,
                y: point.y - annotation.rect.nsRect.origin.y
            )
            NSCursor.closedHand.push()
        } else {
            selectedAnnotationId = nil
            delegate?.annotationOverlay(self, didSelectAnnotation: nil)
        }
        needsDisplay = true
    }
    
    private func startTextEditing(annotation: Annotation) {
        editingAnnotationId = annotation.id
        selectedAnnotationId = annotation.id
        
        let rect = annotation.rect.nsRect
        let insetRect = rect.insetBy(dx: 8, dy: 4)
        
        let textView = NSTextView(frame: insetRect)
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = annotation.style.fillColor?.nsColor ?? .white
        textView.textColor = annotation.type == .text ? .white : .black
        textView.font = NSFont(name: annotation.style.fontName ?? "Helvetica Neue", size: annotation.style.fontSize ?? 16)
        textView.string = annotation.text ?? ""
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.delegate = self
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: insetRect.width, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 4, height: 4)
        
        addSubview(textView)
        
        textEditView = textView
        window?.makeFirstResponder(textView)
        textView.selectAll(nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: NSText.didChangeNotification, object: textView)
        
        needsDisplay = true
    }
    
    @objc func textDidChange(_ notification: Notification) {
        guard let textView = textEditView,
              let annotationId = editingAnnotationId,
              let index = annotations.firstIndex(where: { $0.id == annotationId }) else { return }
        
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        let usedRect = textView.layoutManager?.usedRect(for: textView.textContainer!) ?? .zero
        let newHeight = max(usedRect.height + 16, 30)
        
        var annotation = annotations[index]
        annotation.text = textView.string
        let currentRect = annotation.rect.nsRect
        
        if newHeight > currentRect.height - 8 {
            let newRect = NSRect(x: currentRect.origin.x, y: currentRect.origin.y, width: currentRect.width, height: newHeight + 16)
            annotation.rect = CodableRect(newRect)
            
            var textFrame = textView.frame
            textFrame.size.height = newHeight
            textView.frame = textFrame
        }
        
        annotations[index] = annotation
        delegate?.annotationOverlay(self, didUpdateAnnotation: annotation)
        needsDisplay = true
    }
    
    private func finishTextEditing() {
        guard let textView = textEditView, let annotationId = editingAnnotationId else { return }
        
        NotificationCenter.default.removeObserver(self, name: NSText.didChangeNotification, object: textView)
        
        let newText = textView.string
        
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        let usedRect = textView.layoutManager?.usedRect(for: textView.textContainer!) ?? .zero
        let finalHeight = max(usedRect.height + 16, 30)
        
        if let index = annotations.firstIndex(where: { $0.id == annotationId }) {
            var annotation = annotations[index]
            annotation.text = newText
            
            let currentRect = annotation.rect.nsRect
            let newRect = NSRect(x: currentRect.origin.x, y: currentRect.origin.y, width: currentRect.width, height: finalHeight + 16)
            annotation.rect = CodableRect(newRect)
            
            annotations[index] = annotation
            delegate?.annotationOverlay(self, didUpdateAnnotation: annotation)
        }
        
        textView.removeFromSuperview()
        textEditView = nil
        editingAnnotationId = nil
        needsDisplay = true
    }
    
    func textDidEndEditing(_ notification: Notification) {
        finishTextEditing()
    }
    
    override func mouseDragged(with event: NSEvent) {
        let currentPoint = convert(event.locationInWindow, from: nil)
        
        if isCreatingAnnotation, let startPoint = dragStartPoint {
            currentDragRect = NSRect(
                x: min(startPoint.x, currentPoint.x),
                y: min(startPoint.y, currentPoint.y),
                width: abs(currentPoint.x - startPoint.x),
                height: abs(currentPoint.y - startPoint.y)
            )
            needsDisplay = true
            return
        }
        
        if isDraggingAnnotation, var annotation = draggedAnnotation {
            let newOrigin = NSPoint(
                x: max(0, min(bounds.width - annotation.rect.width, currentPoint.x - annotationDragOffset.x)),
                y: max(0, min(bounds.height - annotation.rect.height, currentPoint.y - annotationDragOffset.y))
            )
            annotation.rect = CodableRect(NSRect(origin: newOrigin, size: annotation.rect.nsRect.size))
            
            if let index = annotations.firstIndex(where: { $0.id == annotation.id }) {
                annotations[index] = annotation
                draggedAnnotation = annotation
            }
            needsDisplay = true
            return
        }
        
        if isResizingAnnotation, var annotation = draggedAnnotation, let startPoint = dragStartPoint {
            let delta = NSPoint(x: currentPoint.x - startPoint.x, y: currentPoint.y - startPoint.y)
            var rect = annotation.rect.nsRect
            
            switch resizeHandle {
            case .topLeft:
                rect.origin.x += delta.x
                rect.size.width -= delta.x
                rect.size.height += delta.y
            case .top:
                rect.size.height += delta.y
            case .topRight:
                rect.size.width += delta.x
                rect.size.height += delta.y
            case .right:
                rect.size.width += delta.x
            case .bottomRight:
                rect.origin.y += delta.y
                rect.size.width += delta.x
                rect.size.height -= delta.y
            case .bottom:
                rect.origin.y += delta.y
                rect.size.height -= delta.y
            case .bottomLeft:
                rect.origin.x += delta.x
                rect.origin.y += delta.y
                rect.size.width -= delta.x
                rect.size.height -= delta.y
            case .left:
                rect.origin.x += delta.x
                rect.size.width -= delta.x
            case .none:
                break
            }
            
            if rect.width >= 20 && rect.height >= 20 {
                annotation.rect = CodableRect(rect)
                if let index = annotations.firstIndex(where: { $0.id == annotation.id }) {
                    annotations[index] = annotation
                    draggedAnnotation = annotation
                }
                dragStartPoint = currentPoint
            }
            needsDisplay = true
            return
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        if isDraggingAnnotation, let annotation = draggedAnnotation {
            NSCursor.pop()
            delegate?.annotationOverlay(self, didUpdateAnnotation: annotation)
            isDraggingAnnotation = false
            draggedAnnotation = nil
            return
        }
        
        if isResizingAnnotation, let annotation = draggedAnnotation {
            NSCursor.pop()
            delegate?.annotationOverlay(self, didUpdateAnnotation: annotation)
            isResizingAnnotation = false
            draggedAnnotation = nil
            resizeHandle = .none
            dragStartPoint = nil
            return
        }
        
        guard isCreatingAnnotation, let rect = currentDragRect, let type = pendingAnnotationType else {
            isCreatingAnnotation = false
            dragStartPoint = nil
            currentDragRect = nil
            return
        }
        
        if rect.width > 10 && rect.height > 10 {
            var style: AnnotationStyle
            switch type {
            case .highlight:
                style = AnnotationStyle(strokeColor: .clear, fillColor: currentColor, strokeWidth: 0, opacity: 0.4)
            case .text:
                style = AnnotationStyle(strokeColor: .white, fillColor: currentColor, strokeWidth: 0, fontSize: 24, fontName: "Helvetica Neue")
            case .callout:
                style = AnnotationStyle(strokeColor: currentColor, fillColor: .white, strokeWidth: 3, fontSize: 16, fontName: "Helvetica Neue", cornerRadius: 8)
            default:
                style = AnnotationStyle(strokeColor: currentColor, strokeWidth: 3)
            }
            
            var annotation = Annotation(
                type: type,
                startTime: currentTimestamp,
                duration: 3_000_000,
                rect: rect,
                style: style
            )
            
            if type == .arrow || type == .line {
                annotation.arrowStart = CodablePoint(NSPoint(x: rect.minX, y: rect.minY))
                annotation.arrowEnd = CodablePoint(NSPoint(x: rect.maxX, y: rect.maxY))
            }
            
            delegate?.annotationOverlay(self, didCreateAnnotation: annotation)
        }
        
        isCreatingAnnotation = false
        dragStartPoint = nil
        currentDragRect = nil
        pendingAnnotationType = nil
        needsDisplay = true
    }
    
    private func hitTestResizeHandle(at point: NSPoint, for annotation: Annotation) -> ResizeHandle {
        let rect = annotation.rect.nsRect
        let handleSize: CGFloat = 10
        
        let handles: [(ResizeHandle, NSRect)] = [
            (.topLeft, NSRect(x: rect.minX - handleSize/2, y: rect.maxY - handleSize/2, width: handleSize, height: handleSize)),
            (.top, NSRect(x: rect.midX - handleSize/2, y: rect.maxY - handleSize/2, width: handleSize, height: handleSize)),
            (.topRight, NSRect(x: rect.maxX - handleSize/2, y: rect.maxY - handleSize/2, width: handleSize, height: handleSize)),
            (.right, NSRect(x: rect.maxX - handleSize/2, y: rect.midY - handleSize/2, width: handleSize, height: handleSize)),
            (.bottomRight, NSRect(x: rect.maxX - handleSize/2, y: rect.minY - handleSize/2, width: handleSize, height: handleSize)),
            (.bottom, NSRect(x: rect.midX - handleSize/2, y: rect.minY - handleSize/2, width: handleSize, height: handleSize)),
            (.bottomLeft, NSRect(x: rect.minX - handleSize/2, y: rect.minY - handleSize/2, width: handleSize, height: handleSize)),
            (.left, NSRect(x: rect.minX - handleSize/2, y: rect.midY - handleSize/2, width: handleSize, height: handleSize))
        ]
        
        for (handle, handleRect) in handles {
            if handleRect.contains(point) {
                return handle
            }
        }
        return .none
    }
    
    private func setCursorForHandle(_ handle: ResizeHandle) {
        switch handle {
        case .topLeft, .bottomRight:
            NSCursor(image: NSCursor.crosshair.image, hotSpot: NSPoint(x: 8, y: 8)).push()
        case .topRight, .bottomLeft:
            NSCursor(image: NSCursor.crosshair.image, hotSpot: NSPoint(x: 8, y: 8)).push()
        case .top, .bottom:
            NSCursor.resizeUpDown.push()
        case .left, .right:
            NSCursor.resizeLeftRight.push()
        case .none:
            break
        }
    }
    
    private func hitTestAnnotation(at point: NSPoint) -> Annotation? {
        let visibleAnnotations = annotations.filter { $0.isVisible(at: currentTimestamp) }
        
        for annotation in visibleAnnotations.reversed() {
            if annotation.rect.nsRect.contains(point) {
                return annotation
            }
        }
        return nil
    }
}
