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
}

@MainActor
private final class ViewBoyPhosphorOverlayView: NSView {
    private let metalView: MTKView?
    private let renderer: ViewBoyPhosphorRenderer?

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
        }
    }
}

@MainActor
private final class ViewBoyPhosphorRenderer: NSObject, MTKViewDelegate {
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState

    init?(device: MTLDevice) {
        guard let commandQueue = device.makeCommandQueue() else { return nil }

        let source = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexOut {
            float4 position [[position]];
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

        fragment float4 fragment_main(VertexOut in [[stage_in]]) {
            // One dark display row every four device pixels. The transparent
            // pass leaves the browser UI and its geometry untouched.
            float row = fmod(floor(in.position.y), 4.0);
            float alpha = row < 1.0 ? 0.10 : 0.0;
            return float4(0.03, 0.12, 0.20, alpha);
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
            descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
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
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}
