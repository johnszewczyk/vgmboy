import AppKit
import Metal
import MetalKit
import WebKit

/// A transparent, click-through Metal layer for the animated sidebar `>` glyphs.
/// The LCD framebuffer remains the source of truth for every other UI pixel.
@MainActor
final class ViewBoyMetalChevronOverlay: MTKView, MTKViewDelegate {
    private struct Instance {
        var rect: SIMD4<Float>
        var clip: SIMD4<Float>
        var tintProgress: SIMD4<Float>
    }

    private var commandQueue: MTLCommandQueue?
    private var pipeline: MTLRenderPipelineState?
    private var glyphTexture: MTLTexture?
    private var instanceBuffer: MTLBuffer?
    private var instanceBufferCapacity = 0
    private var instanceCount = 0
    private var glyphRows: [String] = []

    var isAvailable: Bool { pipeline != nil && commandQueue != nil }

    init(frame: NSRect) {
        super.init(frame: frame, device: MTLCreateSystemDefaultDevice())
        wantsLayer = true
        layer?.isOpaque = false
        clearColor = MTLClearColorMake(0, 0, 0, 0)
        framebufferOnly = true
        enableSetNeedsDisplay = true
        isPaused = true
        delegate = self
        guard let device else { return }
        commandQueue = device.makeCommandQueue()
        do {
            pipeline = try Self.makePipeline(device: device, pixelFormat: colorPixelFormat)
        } catch {
            NSLog("[ViewBoy] Metal chevron pipeline unavailable: %@", error.localizedDescription)
        }
    }

    required init(coder: NSCoder) {
        fatalError("ViewBoyMetalChevronOverlay does not support NSCoder")
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func updateGeometry(_ payload: [String: Any]) {
        guard isAvailable,
              let device,
              let rows = payload["rows"] as? [String],
              let tint = Self.vector(payload["tint"]),
              let rawItems = payload["items"] as? [[String: Any]] else { return }

        if rows != glyphRows {
            guard let texture = Self.makeGlyphTexture(rows: rows, device: device) else { return }
            glyphRows = rows
            glyphTexture = texture
        }

        let instances = rawItems.compactMap { item -> Instance? in
            guard let rect = Self.vector(item["rect"]),
                  let clip = Self.vector(item["clip"]) else { return nil }
            let progress = min(1, max(0, (item["progress"] as? NSNumber)?.floatValue ?? 0))
            return Instance(
                rect: rect,
                clip: clip,
                tintProgress: SIMD4(tint.x / 255, tint.y / 255, tint.z / 255, progress)
            )
        }
        instanceCount = instances.count
        upload(instances)
        needsDisplay = true
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let pipeline,
              let commandQueue,
              let texture = glyphTexture,
              let pass = currentRenderPassDescriptor,
              let drawable = currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return }

        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(texture, index: 0)
        if instanceCount > 0, let instanceBuffer {
            encoder.setVertexBuffer(instanceBuffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: instanceCount)
        }
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func upload(_ instances: [Instance]) {
        guard let device, !instances.isEmpty else { return }
        let byteCount = MemoryLayout<Instance>.stride * instances.count
        if instanceBufferCapacity < byteCount {
            let capacity = max(byteCount, max(4096, instanceBufferCapacity * 2))
            guard let buffer = device.makeBuffer(length: capacity, options: .storageModeShared) else {
                instanceCount = 0
                return
            }
            instanceBufferCapacity = capacity
            instanceBuffer = buffer
        }
        guard let instanceBuffer else { return }
        instances.withUnsafeBytes { bytes in
            if let source = bytes.baseAddress {
                instanceBuffer.contents().copyMemory(from: source, byteCount: byteCount)
            }
        }
    }

    private static func vector(_ value: Any?) -> SIMD4<Float>? {
        guard let values = value as? [NSNumber], values.count == 4 else { return nil }
        return SIMD4(values[0].floatValue, values[1].floatValue, values[2].floatValue, values[3].floatValue)
    }

    private static func makeGlyphTexture(rows: [String], device: MTLDevice) -> MTLTexture? {
        guard let firstRow = rows.first, !rows.isEmpty else { return nil }
        let width = firstRow.count
        let height = rows.count
        let size = max(width, height)
        let insetX = (size - width) / 2
        let insetY = (size - height) / 2
        var pixels = [UInt8](repeating: 0, count: size * size)
        for (rowIndex, row) in rows.enumerated() {
            guard row.count == width else { return nil }
            for (columnIndex, bit) in row.enumerated() where bit == "1" {
                pixels[(rowIndex + insetY) * size + columnIndex + insetX] = 255
            }
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Unorm,
            width: size,
            height: size,
            mipmapped: false
        )
        descriptor.usage = .shaderRead
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        pixels.withUnsafeBytes { bytes in
            guard let source = bytes.baseAddress else { return }
            texture.replace(
                region: MTLRegionMake2D(0, 0, size, size),
                mipmapLevel: 0,
                withBytes: source,
                bytesPerRow: size
            )
        }
        return texture
    }

    private static func makePipeline(device: MTLDevice, pixelFormat: MTLPixelFormat) throws -> MTLRenderPipelineState {
        let source = #"""
        #include <metal_stdlib>
        using namespace metal;

        struct ChevronInstance {
            float4 rect;
            float4 clip;
            float4 tintProgress;
        };

        struct VertexOut {
            float4 position [[position]];
            float2 uv;
            float2 pagePoint;
            float4 clip;
            float4 tintProgress;
        };

        vertex VertexOut chevronVertex(
            uint vertexID [[vertex_id]],
            uint instanceID [[instance_id]],
            constant ChevronInstance *items [[buffer(0)]]) {
            constexpr float2 corners[6] = {
                float2(0, 0), float2(1, 0), float2(0, 1),
                float2(0, 1), float2(1, 0), float2(1, 1)
            };
            ChevronInstance item = items[instanceID];
            float2 corner = corners[vertexID];
            float2 pagePoint = item.rect.xy + corner * item.rect.zw;
            // Rotate in Metal's y-up clip coordinates. A right-pointing glyph
            // therefore turns down on screen at -pi/2 when its row opens.
            float angle = -item.tintProgress.w * 1.57079632679;
            float inverseAngle = -angle;
            float cosine = cos(inverseAngle);
            float sine = sin(inverseAngle);
            float2 centered = corner - float2(0.5, 0.5);
            float2 clipCentered = float2(centered.x, -centered.y);
            float2 sourceClip = float2(cosine * clipCentered.x - sine * clipCentered.y,
                                       sine * clipCentered.x + cosine * clipCentered.y);
            float2 uv = float2(sourceClip.x, -sourceClip.y) + float2(0.5, 0.5);
            VertexOut output;
            output.position = float4(pagePoint.x * 2.0 - 1.0, 1.0 - pagePoint.y * 2.0, 0.0, 1.0);
            output.uv = uv;
            output.pagePoint = pagePoint;
            output.clip = item.clip;
            output.tintProgress = item.tintProgress;
            return output;
        }

        fragment float4 chevronFragment(
            VertexOut input [[stage_in]],
            texture2d<float> glyph [[texture(0)]]) {
            if (input.pagePoint.x < input.clip.x || input.pagePoint.y < input.clip.y ||
                input.pagePoint.x >= input.clip.x + input.clip.z ||
                input.pagePoint.y >= input.clip.y + input.clip.w) {
                discard_fragment();
            }
            constexpr sampler nearestSampler(coord::normalized, address::clamp_to_edge, filter::nearest);
            float coverage = glyph.sample(nearestSampler, input.uv).r;
            return float4(input.tintProgress.xyz, coverage);
        }
        """#
        let library = try device.makeLibrary(source: source, options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "chevronVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "chevronFragment")
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        return try device.makeRenderPipelineState(descriptor: descriptor)
    }
}

@MainActor
final class ViewBoySurfaceView: NSView {
    private let webView: WKWebView
    private let metalChevronOverlay: ViewBoyMetalChevronOverlay

    init(webView: WKWebView, metalChevronOverlay: ViewBoyMetalChevronOverlay) {
        self.webView = webView
        self.metalChevronOverlay = metalChevronOverlay
        super.init(frame: .zero)
        wantsLayer = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        metalChevronOverlay.translatesAutoresizingMaskIntoConstraints = false
        addSubview(webView)
        addSubview(metalChevronOverlay)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
            metalChevronOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            metalChevronOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            metalChevronOverlay.topAnchor.constraint(equalTo: topAnchor),
            metalChevronOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("ViewBoySurfaceView does not support NSCoder")
    }

    func updateMetalChevrons(_ payload: [String: Any]) {
        metalChevronOverlay.updateGeometry(payload)
    }
}
