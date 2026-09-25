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

    private struct Uniforms {
        var viewport: SIMD2<Float>
        var pulseProgress: Float
        var pulseStrength: Float
        var isPlaying: Float
        var padding: Float = 0
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
        };

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
            float deck = 1.0 - smoothstep(0.15, 0.22, uv.y);
            float scan = 1.0 - step(1.0, fmod(floor(in.position.y), 4.0));
            float edge = pow(max(abs(uv.x - 0.5) * 2.0, abs(uv.y - 0.5) * 2.0), 5.0);
            float vignette = min(edge * 0.075, 0.075);
            float sweep = exp(-pow((uv.x - u.pulseProgress) / 0.09, 2.0))
                        * deck * u.pulseStrength;
            float lcdSheen = deck * (0.012 + u.isPlaying * 0.008);
            float darkAlpha = scan * (0.014 + deck * 0.026) + vignette;
            float lightAlpha = lcdSheen + sweep * 0.18;
            float alpha = min(darkAlpha + lightAlpha, 0.24);
            float3 darkInk = float3(0.025, 0.045, 0.038);
            float3 phosphor = float3(0.64, 0.86, 0.75);
            float3 color = mix(darkInk, phosphor,
                               lightAlpha / max(alpha, 0.001));
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
            isPlaying: isPlaying
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
}
