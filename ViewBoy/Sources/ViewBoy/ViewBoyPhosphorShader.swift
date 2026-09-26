import AppKit
import WebKit
@preconcurrency import Metal
@preconcurrency import MetalKit

/// Hosts the working WebKit UI and a transparent, non-interactive Metal pass.
/// The browser remains the source of truth for layout, text, scrolling, and
/// hit-testing; the shader only changes the final optical presentation.
@MainActor
final class ViewBoySurfaceView: NSView {
    private let webView: WKWebView
    private let phosphorOverlay: ViewBoyPhosphorOverlayView

    init(webView: WKWebView) {
        self.webView = webView
        self.phosphorOverlay = ViewBoyPhosphorOverlayView(frame: .zero)
        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        webView.frame = bounds
        webView.autoresizingMask = [.width, .height]
        addSubview(webView)

        phosphorOverlay.frame = bounds
        phosphorOverlay.autoresizingMask = [.width, .height]
        addSubview(phosphorOverlay, positioned: .above, relativeTo: webView)
    }

    required init?(coder: NSCoder) {
        fatalError("ViewBoySurfaceView does not support NSCoder")
    }

    func updatePlaybackVisual(transportState: String, generation: Int) {
        phosphorOverlay.updatePlaybackVisual(transportState: transportState, generation: generation)
    }

    func updateMaterialGeometry(_ geometry: [String: Any]) {
        phosphorOverlay.updateMaterialGeometry(geometry)
    }
}

@MainActor
private final class ViewBoyPhosphorOverlayView: NSView {
    private let metalView: MTKView?
    private let renderer: ViewBoyPhosphorRenderer?
    private var pulseTimer: Timer?
    private var pulseStart: CFTimeInterval = 0
    private var lastTransportState: String?
    private var lastGeneration: Int?
    private let pulseDuration: CFTimeInterval = 0.46

    override init(frame frameRect: NSRect) {
        if let device = MTLCreateSystemDefaultDevice(),
           let renderer = ViewBoyPhosphorRenderer(device: device) {
            let metalView = MTKView(frame: .zero, device: device)
            metalView.colorPixelFormat = .bgra8Unorm
            metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            metalView.framebufferOnly = true
            metalView.enableSetNeedsDisplay = true
            metalView.isPaused = true
            metalView.wantsLayer = true
            metalView.layer?.isOpaque = false
            self.metalView = metalView
            self.renderer = renderer
        } else {
            self.metalView = nil
            self.renderer = nil
        }

        super.init(frame: frameRect)
        wantsLayer = true
        layer?.isOpaque = false
        layer?.backgroundColor = NSColor.clear.cgColor

        if let metalView, let renderer {
            metalView.frame = bounds
            metalView.autoresizingMask = [.width, .height]
            metalView.delegate = renderer
            addSubview(metalView)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("ViewBoyPhosphorOverlayView does not support NSCoder")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            metalView?.setNeedsDisplay(bounds)
        } else {
            pulseTimer?.invalidate()
            pulseTimer = nil
        }
    }

    override func layout() {
        super.layout()
        metalView?.setNeedsDisplay(bounds)
    }

    func updatePlaybackVisual(transportState: String, generation: Int) {
        let changed = transportState != lastTransportState || generation != lastGeneration
        lastTransportState = transportState
        lastGeneration = generation
        guard changed else { return }
        renderer?.setPlaying(transportState == "playing")

        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
              window?.isVisible == true else {
            pulseTimer?.invalidate()
            pulseTimer = nil
            renderer?.setPulse(progress: 0, strength: 0)
            metalView?.setNeedsDisplay(bounds)
            return
        }

        pulseStart = CACurrentMediaTime()
        pulseTimer?.invalidate()
        pulseTimer = Timer.scheduledTimer(
            timeInterval: 1.0 / 30.0,
            target: self,
            selector: #selector(advancePulse),
            userInfo: nil,
            repeats: true
        )
        pulseTimer?.tolerance = 0.005
        advancePulse()
    }

    func updateMaterialGeometry(_ geometry: [String: Any]) {
        renderer?.setGeometry(geometry)
        metalView?.setNeedsDisplay(bounds)
    }

    @objc private func advancePulse() {
        let fraction = min(1, (CACurrentMediaTime() - pulseStart) / pulseDuration)
        renderer?.setPulse(
            progress: Float(-0.12 + fraction * 1.24),
            strength: Float((1 - fraction) * (1 - fraction))
        )
        metalView?.setNeedsDisplay(bounds)
        if fraction >= 1 {
            pulseTimer?.invalidate()
            pulseTimer = nil
        }
    }
}

@MainActor
private final class ViewBoyPhosphorRenderer: NSObject, MTKViewDelegate {
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private var pulseProgress: Float = 0
    private var pulseStrength: Float = 0
    private var isPlaying: Float = 0
    private var deckRect = SIMD4<Float>(repeating: 0)
    private var bezelRect = SIMD4<Float>(repeating: 0)
    private var screenRect = SIMD4<Float>(repeating: 0)
    private var ledRect = SIMD4<Float>(repeating: 0)

    private struct Uniforms {
        var viewport: SIMD2<Float>
        var pulseProgress: Float
        var pulseStrength: Float
        var isPlaying: Float
        var padding: Float = 0
        var deckRect: SIMD4<Float>
        var bezelRect: SIMD4<Float>
        var screenRect: SIMD4<Float>
        var ledRect: SIMD4<Float>
    }

    init?(device: MTLDevice) {
        guard let commandQueue = device.makeCommandQueue() else { return nil }

        let source = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexOut {
            float4 position [[position]];
        };

        struct Uniforms {
            float2 viewport;
            float pulseProgress;
            float pulseStrength;
            float isPlaying;
            float padding;
            float4 deckRect;
            float4 bezelRect;
            float4 screenRect;
            float4 ledRect;
        };

        float inRect(float2 p, float4 r) {
            if (r.z <= 0.0 || r.w <= 0.0) return 0.0;
            float2 a = smoothstep(r.xy, r.xy + float2(0.002), p);
            float2 b = 1.0 - smoothstep(r.xy + r.zw - float2(0.002), r.xy + r.zw, p);
            return a.x * a.y * b.x * b.y;
        }

        float grain(float2 p) {
            return fract(sin(dot(floor(p), float2(12.9898, 78.233))) * 43758.5453);
        }

        vertex VertexOut vertex_main(uint vertexID [[vertex_id]]) {
            const float2 corners[4] = {
                float2(-1.0, -1.0), float2(1.0, -1.0),
                float2(-1.0,  1.0), float2(1.0,  1.0)
            };
            VertexOut out;
            out.position = float4(corners[vertexID], 0.0, 1.0);
            return out;
        }

        fragment float4 fragment_main(VertexOut in [[stage_in]],
                                      constant Uniforms &u [[buffer(0)]]) {
            float2 uv = in.position.xy / max(u.viewport, float2(1.0));
            float deck = inRect(uv, u.deckRect);
            float bezel = inRect(uv, u.bezelRect);
            float lcd = inRect(uv, u.screenRect);
            float shell = max(0.0, deck - bezel);
            float matte = max(0.0, bezel - lcd);
            float micro = grain(in.position.xy * 0.72);
            float brushed = grain(float2(in.position.x * 0.18, in.position.y * 0.045));
            float shellShade = shell * (0.013 + micro * 0.028 + brushed * 0.009);
            float matteShade = matte * (0.033 + micro * 0.021);
            float scan = 1.0 - step(1.0, fmod(floor(in.position.y), 4.0));
            float lcdShade = lcd * (scan * 0.014 + micro * 0.01);
            float2 glassUV = (uv - u.screenRect.xy) / max(u.screenRect.zw, float2(0.001));
            float glassSheen = lcd * exp(-pow((glassUV.x - 0.22 - glassUV.y * 0.23) / 0.17, 2.0)) * 0.045;
            float sweep = lcd * exp(-pow((glassUV.x - u.pulseProgress) / 0.09, 2.0))
                        * u.pulseStrength * 0.20;
            float2 ledCenter = u.ledRect.xy + u.ledRect.zw * 0.5;
            float ledDistance = length((uv - ledCenter) * u.viewport);
            float ledGlow = u.ledRect.z > 0.0
                ? exp(-pow(ledDistance / 15.0, 2.0)) * (0.034 + u.isPlaying * 0.13) : 0.0;
            float darkAlpha = shellShade + matteShade + lcdShade;
            float lightAlpha = glassSheen + sweep + ledGlow;
            float alpha = min(darkAlpha + lightAlpha, 0.27);
            float3 darkInk = float3(0.11, 0.14, 0.16);
            float3 lightInk = mix(float3(0.80, 0.86, 0.72), float3(0.98, 0.25, 0.27),
                                  ledGlow / max(lightAlpha, 0.001));
            float3 color = mix(darkInk, lightInk, lightAlpha / max(alpha, 0.001));
            return float4(color, alpha);
        }
        """

        do {
            let library = try device.makeLibrary(source: source, options: nil)
            guard let vertex = library.makeFunction(name: "vertex_main"),
                  let fragment = library.makeFunction(name: "fragment_main") else { return nil }
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertex
            descriptor.fragmentFunction = fragment
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            self.pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            return nil
        }

        self.commandQueue = commandQueue
        super.init()
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let pass = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return }

        encoder.setRenderPipelineState(pipelineState)
        var uniforms = Uniforms(
            viewport: SIMD2(Float(view.drawableSize.width), Float(view.drawableSize.height)),
            pulseProgress: pulseProgress,
            pulseStrength: pulseStrength,
            isPlaying: isPlaying,
            deckRect: deckRect,
            bezelRect: bezelRect,
            screenRect: screenRect,
            ledRect: ledRect
        )
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func setPulse(progress: Float, strength: Float) {
        pulseProgress = progress
        pulseStrength = strength
    }

    func setPlaying(_ playing: Bool) {
        isPlaying = playing ? 1 : 0
    }

    func setGeometry(_ geometry: [String: Any]) {
        func rect(_ key: String) -> SIMD4<Float> {
            guard let values = geometry[key] as? [NSNumber], values.count == 4 else {
                return SIMD4<Float>(repeating: 0)
            }
            return SIMD4(Float(values[0].doubleValue), Float(values[1].doubleValue),
                         Float(values[2].doubleValue), Float(values[3].doubleValue))
        }
        deckRect = rect("deck")
        bezelRect = rect("bezel")
        screenRect = rect("screen")
        ledRect = rect("led")
    }
}
