import Foundation
import MetaManCore

public enum ScannerInspectionError: LocalizedError {
    case unsupportedRoute(String)
    case missingRequiredAdapter(pluginID: String, extensionName: String)
    case missingDependency(String)
    case library(String)
    case malformedFile(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedRoute(let route):
            return "No scanner inspector is registered for \(route)."
        case .missingRequiredAdapter(let pluginID, let extensionName):
            return "Required \(pluginID) structure adapter is unavailable for .\(extensionName); the source was not flattened into a false single track."
        case .missingDependency(let name):
            return "Required MDX dependency is missing: \(name)."
        case .library(let message):
            return message
        case .malformedFile(let message):
            return message
        }
    }
}

public struct BuiltInFormatInspector: ScanFormatHandler {
    public let descriptor: ScannerPluginDescriptor

    public init(descriptor: ScannerPluginDescriptor) {
        self.descriptor = descriptor
    }

    public func inspect(fileURL: URL, route: ScannerRoute) async throws -> ScanInspection {
        switch route.pluginID {
        case "spc-direct":
            return try SPCInspector.inspect(fileURL: fileURL, route: route)
        case "ay-direct":
            return try AYInspector.inspect(fileURL: fileURL, route: route)
        case "sap-direct":
            return try SAPInspector.inspect(fileURL: fileURL, route: route)
        case "hes-direct":
            return try HESInspector.inspect(fileURL: fileURL, route: route)
        case "kss-direct":
            return try KSSInspector.inspect(fileURL: fileURL, route: route)
        case "game-music-direct", "nsfe-direct":
            return try GameMusicMetadataInspector.inspect(fileURL: fileURL, route: route)
        case "gsf-direct":
            let document: MetadataDocument
            do {
                document = try MetaManCore.read(fileURL: fileURL)
            } catch let error as MetadataReadError {
                throw ScannerInspectionError.malformedFile(error.localizedDescription)
            } catch {
                throw ScannerInspectionError.library(
                    "Could not read GSF source \(fileURL.lastPathComponent): \(error.localizedDescription)"
                )
            }
            let metadata = ScannerMetadata(metadataDocument: document, includeDateAndEncodedByInComment: false)
            return ScanInspection(route: route, tracks: [ScanTrackMetadata(trackIndex: 0, trackCount: 1, metadata: metadata)])
        case "qsf-direct", "qsf-mini-direct":
            let document: MetadataDocument
            do {
                document = try MetaManCore.read(fileURL: fileURL)
            } catch let error as MetadataReadError {
                throw ScannerInspectionError.malformedFile(error.localizedDescription)
            } catch {
                throw ScannerInspectionError.library(
                    "Could not read QSF source \(fileURL.lastPathComponent): \(error.localizedDescription)"
                )
            }
            let metadata = ScannerMetadata(metadataDocument: document, includeDateAndEncodedByInComment: false)
            return ScanInspection(route: route, tracks: [ScanTrackMetadata(trackIndex: 0, trackCount: 1, metadata: metadata)])
        case "ape-direct":
            let document: MetadataDocument
            do {
                document = try MetaManCore.read(fileURL: fileURL)
            } catch let error as MetadataReadError {
                throw ScannerInspectionError.malformedFile(error.localizedDescription)
            } catch {
                throw ScannerInspectionError.library(
                    "Could not read APE source \(fileURL.lastPathComponent): \(error.localizedDescription)"
                )
            }
            let metadata = ScannerMetadata(
                metadataDocument: document,
                includeDateAndEncodedByInComment: false
            )
            return ScanInspection(route: route, tracks: [ScanTrackMetadata(trackIndex: 0, trackCount: 1, metadata: metadata)])
        case "adx-direct":
            let document: MetadataDocument
            do {
                document = try MetaManCore.read(fileURL: fileURL)
            } catch let error as MetadataReadError {
                throw ScannerInspectionError.malformedFile(error.localizedDescription)
            } catch {
                throw ScannerInspectionError.library(
                    "Could not read ADX source \(fileURL.lastPathComponent): \(error.localizedDescription)"
                )
            }
            let metadata = ScannerMetadata(metadataDocument: document, includeDateAndEncodedByInComment: false)
            return ScanInspection(route: route, tracks: [ScanTrackMetadata(trackIndex: 0, trackCount: 1, metadata: metadata)])
        case "at3-direct":
            let document: MetadataDocument
            do {
                document = try MetaManCore.read(fileURL: fileURL)
            } catch let error as MetadataReadError {
                throw ScannerInspectionError.malformedFile(error.localizedDescription)
            } catch {
                throw ScannerInspectionError.library(
                    "Could not read RIFF ATRAC3 source \(fileURL.lastPathComponent): \(error.localizedDescription)"
                )
            }
            let metadata = ScannerMetadata(metadataDocument: document, includeDateAndEncodedByInComment: false)
            return ScanInspection(route: route, tracks: [ScanTrackMetadata(trackIndex: 0, trackCount: 1, metadata: metadata)])
        case "aus-direct":
            let document: MetadataDocument
            do {
                document = try MetaManCore.read(fileURL: fileURL)
            } catch let error as MetadataReadError {
                throw ScannerInspectionError.malformedFile(error.localizedDescription)
            } catch {
                throw ScannerInspectionError.library(
                    "Could not read Atomic Planet AUS source \(fileURL.lastPathComponent): \(error.localizedDescription)"
                )
            }
            let metadata = ScannerMetadata(metadataDocument: document, includeDateAndEncodedByInComment: false)
            return ScanInspection(route: route, tracks: [ScanTrackMetadata(trackIndex: 0, trackCount: 1, metadata: metadata)])
        case "sony-msf-direct":
            let document: MetadataDocument
            do {
                document = try MetaManCore.read(fileURL: fileURL)
            } catch let error as MetadataReadError {
                throw ScannerInspectionError.malformedFile(error.localizedDescription)
            } catch {
                throw ScannerInspectionError.library(
                    "Could not read Sony MSF source \(fileURL.lastPathComponent): \(error.localizedDescription)"
                )
            }
            let metadata = ScannerMetadata(metadataDocument: document, includeDateAndEncodedByInComment: false)
            return ScanInspection(route: route, tracks: [ScanTrackMetadata(trackIndex: 0, trackCount: 1, metadata: metadata)])
        case "svag-direct":
            let document: MetadataDocument
            do {
                document = try MetaManCore.read(fileURL: fileURL)
            } catch let error as MetadataReadError {
                throw ScannerInspectionError.malformedFile(error.localizedDescription)
            } catch {
                throw ScannerInspectionError.library(
                    "Could not read SVAG source \(fileURL.lastPathComponent): \(error.localizedDescription)"
                )
            }
            let metadata = ScannerMetadata(metadataDocument: document, includeDateAndEncodedByInComment: false)
            return ScanInspection(route: route, tracks: [ScanTrackMetadata(trackIndex: 0, trackCount: 1, metadata: metadata)])
        case "xmd-direct":
            let document: MetadataDocument
            do {
                document = try MetaManCore.read(fileURL: fileURL)
            } catch let error as MetadataReadError {
                throw ScannerInspectionError.malformedFile(error.localizedDescription)
            } catch {
                throw ScannerInspectionError.library(
                    "Could not read Konami XMD source \(fileURL.lastPathComponent): \(error.localizedDescription)"
                )
            }
            let metadata = ScannerMetadata(metadataDocument: document, includeDateAndEncodedByInComment: false)
            return ScanInspection(route: route, tracks: [ScanTrackMetadata(trackIndex: 0, trackCount: 1, metadata: metadata)])
        case "sshd-direct":
            let document: MetadataDocument
            do {
                document = try MetaManCore.read(fileURL: fileURL)
            } catch let error as MetadataReadError {
                throw ScannerInspectionError.malformedFile(error.localizedDescription)
            } catch {
                throw ScannerInspectionError.library(
                    "Could not read Sony SSHD/ADS source \(fileURL.lastPathComponent): \(error.localizedDescription)"
                )
            }
            let metadata = ScannerMetadata(metadataDocument: document, includeDateAndEncodedByInComment: false)
            return ScanInspection(route: route, tracks: [ScanTrackMetadata(trackIndex: 0, trackCount: 1, metadata: metadata)])
        case "mib-direct":
            let document: MetadataDocument
            do {
                document = try MetaManCore.read(fileURL: fileURL)
            } catch let error as MetadataReadError {
                throw ScannerInspectionError.malformedFile(error.localizedDescription)
            } catch {
                throw ScannerInspectionError.library(
                    "Could not read headerless MIB source \(fileURL.lastPathComponent): \(error.localizedDescription)"
                )
            }
            let metadata = ScannerMetadata(metadataDocument: document, includeDateAndEncodedByInComment: false)
            return ScanInspection(route: route, tracks: [ScanTrackMetadata(trackIndex: 0, trackCount: 1, metadata: metadata)])
        case "adp-direct":
            let document: MetadataDocument
            do {
                document = try MetaManCore.read(fileURL: fileURL)
            } catch let error as MetadataReadError {
                throw ScannerInspectionError.malformedFile(error.localizedDescription)
            } catch {
                throw ScannerInspectionError.library(
                    "Could not read ADP source \(fileURL.lastPathComponent): \(error.localizedDescription)"
                )
            }
            let metadata = ScannerMetadata(metadataDocument: document, includeDateAndEncodedByInComment: false)
            return ScanInspection(route: route, tracks: [ScanTrackMetadata(trackIndex: 0, trackCount: 1, metadata: metadata)])
        case "ahx-direct":
            let document: MetadataDocument
            do {
                document = try MetaManCore.read(fileURL: fileURL)
            } catch let error as MetadataReadError {
                throw ScannerInspectionError.malformedFile(error.localizedDescription)
            } catch {
                throw ScannerInspectionError.library(
                    "Could not read AHX source \(fileURL.lastPathComponent): \(error.localizedDescription)"
                )
            }
            let metadata = ScannerMetadata(metadataDocument: document, includeDateAndEncodedByInComment: false)
            return ScanInspection(route: route, tracks: [ScanTrackMetadata(trackIndex: 0, trackCount: 1, metadata: metadata)])
        case "dvi-direct":
            let document: MetadataDocument
            do {
                document = try MetaManCore.read(fileURL: fileURL)
            } catch let error as MetadataReadError {
                throw ScannerInspectionError.malformedFile(error.localizedDescription)
            } catch {
                throw ScannerInspectionError.library(
                    "Could not read Konami DVI source \(fileURL.lastPathComponent): \(error.localizedDescription)"
                )
            }
            let metadata = ScannerMetadata(metadataDocument: document, includeDateAndEncodedByInComment: false)
            return ScanInspection(route: route, tracks: [ScanTrackMetadata(trackIndex: 0, trackCount: 1, metadata: metadata)])
        case "bink-audio-direct":
            let result: MetadataReadResult
            do {
                result = try MetaManCore.readResult(fileURL: fileURL)
            } catch let error as MetadataReadError {
                throw ScannerInspectionError.malformedFile(error.localizedDescription)
            } catch {
                throw ScannerInspectionError.library(
                    "Could not read Bink audio source \(fileURL.lastPathComponent): \(error.localizedDescription)"
                )
            }
            let tracks = result.tracks.enumerated().map { index, track in
                ScanTrackMetadata(
                    trackIndex: index,
                    trackCount: result.tracks.count,
                    metadata: ScannerMetadata(
                        metadataDocument: track.document,
                        includeDateAndEncodedByInComment: false
                    )
                )
            }
            return ScanInspection(route: route, tracks: tracks)
        case "dsp-direct":
            let document: MetadataDocument
            do {
                document = try MetaManCore.read(fileURL: fileURL)
            } catch let error as MetadataReadError {
                throw ScannerInspectionError.malformedFile(error.localizedDescription)
            } catch {
                throw ScannerInspectionError.library(
                    "Could not read Nintendo DSP source \(fileURL.lastPathComponent): \(error.localizedDescription)"
                )
            }
            let metadata = ScannerMetadata(metadataDocument: document, includeDateAndEncodedByInComment: false)
            return ScanInspection(route: route, tracks: [ScanTrackMetadata(trackIndex: 0, trackCount: 1, metadata: metadata)])
        case "agsc-direct":
            let result: MetadataReadResult
            do {
                result = try MetaManCore.readResult(fileURL: fileURL)
            } catch let error as MetadataReadError {
                throw ScannerInspectionError.malformedFile(error.localizedDescription)
            } catch {
                throw ScannerInspectionError.library(
                    "Could not read Retro Studios AGSC source \(fileURL.lastPathComponent): \(error.localizedDescription)"
                )
            }
            let tracks = result.tracks.enumerated().map { index, track in
                ScanTrackMetadata(
                    trackIndex: index,
                    trackCount: result.tracks.count,
                    metadata: ScannerMetadata(
                        metadataDocument: track.document,
                        includeDateAndEncodedByInComment: false
                    )
                )
            }
            return ScanInspection(route: route, tracks: tracks)
        case "genh-direct":
            let document: MetadataDocument
            do {
                document = try MetaManCore.read(fileURL: fileURL)
            } catch let error as MetadataReadError {
                throw ScannerInspectionError.malformedFile(error.localizedDescription)
            } catch {
                throw ScannerInspectionError.library(
                    "Could not read GENH source \(fileURL.lastPathComponent): \(error.localizedDescription)"
                )
            }
            let metadata = ScannerMetadata(metadataDocument: document, includeDateAndEncodedByInComment: false)
            return ScanInspection(route: route, tracks: [ScanTrackMetadata(trackIndex: 0, trackCount: 1, metadata: metadata)])
        case "nds-strm-direct":
            let document: MetadataDocument
            do {
                document = try MetaManCore.read(fileURL: fileURL)
            } catch let error as MetadataReadError {
                throw ScannerInspectionError.malformedFile(error.localizedDescription)
            } catch {
                throw ScannerInspectionError.library(
                    "Could not read Nintendo DS STRM source \(fileURL.lastPathComponent): \(error.localizedDescription)"
                )
            }
            let metadata = ScannerMetadata(metadataDocument: document, includeDateAndEncodedByInComment: false)
            return ScanInspection(route: route, tracks: [ScanTrackMetadata(trackIndex: 0, trackCount: 1, metadata: metadata)])
        case "xa-direct":
            let result: MetadataReadResult
            do {
                result = try MetaManCore.readResult(fileURL: fileURL)
            } catch let error as MetadataReadError {
                throw ScannerInspectionError.malformedFile(error.localizedDescription)
            } catch {
                throw ScannerInspectionError.library(
                    "Could not read Sony XA source \(fileURL.lastPathComponent): \(error.localizedDescription)"
                )
            }
            let tracks = result.tracks.enumerated().map { index, track in
                ScanTrackMetadata(
                    trackIndex: index,
                    trackCount: result.tracks.count,
                    metadata: ScannerMetadata(
                        metadataDocument: track.document,
                        includeDateAndEncodedByInComment: false
                    )
                )
            }
            return ScanInspection(route: route, tracks: tracks)
        case "highly-theoretical", "lazyusf", "twosf", "play-psf1", "play-psf2":
            let metadata: ScannerMetadata?
            do {
                metadata = ScannerMetadata(
                    metadataDocument: try MetaManCore.read(fileURL: fileURL),
                    includeDateAndEncodedByInComment: false
                )
            } catch is MetadataReadError {
                // The previous footer reader admitted the structurally-known
                // source with empty metadata when its PSF signature was absent.
                metadata = nil
            }
            return ScanInspection(route: route, tracks: [ScanTrackMetadata(trackIndex: 0, trackCount: 1, metadata: metadata)])
        case "vgm-direct", "s98-direct":
            let document: MetadataDocument
            do {
                document = try MetaManCore.read(fileURL: fileURL)
            } catch let error as MetadataReadError {
                throw ScannerInspectionError.malformedFile(error.localizedDescription)
            }
            let metadata = ScannerMetadata(
                metadataDocument: document,
                includeDateAndEncodedByInComment: route.pluginID == "s98-direct"
            )
            return ScanInspection(route: route, tracks: [ScanTrackMetadata(trackIndex: 0, trackCount: 1, metadata: metadata)])
        case "libvgm":
            // GYM remains structure-known without a complete metadata adapter.
            return ScanInspection(route: route, tracks: [ScanTrackMetadata(trackIndex: 0, trackCount: 1, metadata: nil)])
        case "sndh-direct":
            return try SNDHInspector.inspect(fileURL: fileURL, route: route)
        case "standard-audio":
            let document: MetadataDocument
            do {
                document = try MetaManCore.read(fileURL: fileURL)
            } catch let error as MetadataReadError {
                throw ScannerInspectionError.malformedFile(error.localizedDescription)
            }
            let metadata = ScannerMetadata(
                metadataDocument: document,
                includeDateAndEncodedByInComment: false
            )
            return ScanInspection(route: route, tracks: [ScanTrackMetadata(trackIndex: 0, trackCount: 1, metadata: metadata)])
        case "openmpt":
            if fileURL.pathExtension.caseInsensitiveCompare("mod") == .orderedSame {
                do {
                    let document = try MetaManCore.read(fileURL: fileURL)
                    let metadata = ScannerMetadata(
                        metadataDocument: document,
                        includeDateAndEncodedByInComment: false
                    )
                    return ScanInspection(
                        route: route,
                        tracks: [ScanTrackMetadata(trackIndex: 0, trackCount: 1, metadata: metadata)]
                    )
                } catch MetadataReadError.unsupportedFormat(_) {
                    return ScanInspection(route: route, tracks: [ScanTrackMetadata(trackIndex: 0, trackCount: 1, metadata: nil)])
                } catch let error as MetadataReadError {
                    throw ScannerInspectionError.malformedFile(error.localizedDescription)
                }
            }
            return ScanInspection(route: route, tracks: [ScanTrackMetadata(trackIndex: 0, trackCount: 1, metadata: nil)])
        case "sid":
            let result: MetadataReadResult
            do {
                result = try MetaManCore.readResult(fileURL: fileURL)
            } catch let error as MetadataReadError {
                throw ScannerInspectionError.malformedFile(error.localizedDescription)
            }
            let tracks = result.tracks.enumerated().map { ordinal, track in
                ScanTrackMetadata(
                    trackIndex: track.sourceTrackIndex ?? ordinal,
                    trackCount: result.tracks.count,
                    metadata: ScannerMetadata(
                        metadataDocument: track.document,
                        includeDateAndEncodedByInComment: false
                    )
                )
            }
            return ScanInspection(route: route, tracks: tracks)
        default:
            if route.structurePolicy != .knownSingle {
                throw ScannerInspectionError.missingRequiredAdapter(
                    pluginID: route.pluginID,
                    extensionName: route.formatExtension
                )
            }
            throw ScannerInspectionError.unsupportedRoute(route.pluginID)
        }
    }
}

private enum GameMusicMetadataInspector {
    static func inspect(fileURL: URL, route: ScannerRoute) throws -> ScanInspection {
        let result: MetadataReadResult
        do {
            result = try MetaManCore.readResult(fileURL: fileURL)
        } catch let error as MetadataReadError {
            throw ScannerInspectionError.malformedFile(error.localizedDescription)
        } catch {
            throw ScannerInspectionError.library(
                "Could not read \(route.formatExtension.uppercased()) source \(fileURL.lastPathComponent): \(error.localizedDescription)"
            )
        }

        let tracks = result.tracks.enumerated().map { visibleIndex, track in
            ScanTrackMetadata(
                trackIndex: visibleIndex,
                trackCount: result.tracks.count,
                metadata: ScannerMetadata(
                    metadataDocument: track.document,
                    includeDateAndEncodedByInComment: false
                )
            )
        }
        return ScanInspection(route: route, tracks: tracks)
    }
}

private enum SNDHInspector {
    static func inspect(fileURL: URL, route: ScannerRoute) throws -> ScanInspection {
        let result = try MetaManCore.readResult(fileURL: fileURL)
        let tracks = result.tracks.enumerated().map { index, track in
            let document = track.document
            let length = max(0, document.timing?.playLengthMs ?? 0)
            let metadata = ScannerMetadata(
                game: "",
                song: document.fields.title ?? "",
                system: document.fields.system ?? "Atari ST",
                author: document.fields.artist ?? "",
                comment: document.fields.year ?? "",
                introLengthMs: 0,
                loopLengthMs: 0,
                playLengthMs: length,
                fadeLengthMs: 0
            )
            return ScanTrackMetadata(
                trackIndex: index,
                trackCount: result.tracks.count,
                metadata: metadata
            )
        }
        return ScanInspection(route: route, tracks: tracks)
    }
}

public enum BuiltInFormatInspectors {
    public static let registry = ScanPluginHandlerRegistry(
            handlers: BuiltInScannerPlugins.registry.descriptors.map { descriptor -> any ScanFormatHandler in
                if descriptor.pluginID == "vgmstream"
                    || descriptor.pluginID == "vgmstream-txtp"
                    || descriptor.pluginID == "vgmstream-hd-bank" {
                    return VGMStreamCLIInspector(descriptor: descriptor)
                }
                if descriptor.pluginID == "mdx" {
                    return MDXCLIInspector(descriptor: descriptor)
                }
                if descriptor.pluginID == "amiga-uade" {
                    return AmigaCLIInspector(descriptor: descriptor)
                }
                return BuiltInFormatInspector(descriptor: descriptor)
            }
    )
}

private enum SPCInspector {
    static func inspect(fileURL: URL, route: ScannerRoute) throws -> ScanInspection {
        let document: MetadataDocument
        do {
            document = try MetaManCore.read(fileURL: fileURL)
        } catch let error as MetadataReadError {
            throw ScannerInspectionError.malformedFile(error.localizedDescription)
        }
        let metadata = ScannerMetadata(metadataDocument: document, includeDateAndEncodedByInComment: false)
        return ScanInspection(
            route: route,
            tracks: [ScanTrackMetadata(trackIndex: 0, trackCount: 1, metadata: metadata)]
        )
    }
}

private enum AYInspector {
    static func inspect(fileURL: URL, route: ScannerRoute) throws -> ScanInspection {
        let result: MetadataReadResult
        do {
            result = try MetaManCore.readResult(fileURL: fileURL)
        } catch let error as MetadataReadError {
            throw ScannerInspectionError.malformedFile(error.localizedDescription)
        } catch {
            throw ScannerInspectionError.library(
                "Could not read AY source \(fileURL.lastPathComponent): \(error.localizedDescription)"
            )
        }

        let tracks = result.tracks.enumerated().map { ordinal, track in
            ScanTrackMetadata(
                trackIndex: track.sourceTrackIndex ?? ordinal,
                trackCount: result.tracks.count,
                metadata: ScannerMetadata(
                    metadataDocument: track.document,
                    includeDateAndEncodedByInComment: false
                )
            )
        }
        return ScanInspection(route: route, tracks: tracks)
    }
}

private enum SAPInspector {
    static func inspect(fileURL: URL, route: ScannerRoute) throws -> ScanInspection {
        let result: MetadataReadResult
        do {
            result = try MetaManCore.readResult(fileURL: fileURL)
        } catch let error as MetadataReadError {
            throw ScannerInspectionError.malformedFile(error.localizedDescription)
        } catch {
            throw ScannerInspectionError.library(
                "Could not read SAP source \(fileURL.lastPathComponent): \(error.localizedDescription)"
            )
        }

        let tracks = result.tracks.enumerated().map { ordinal, track in
            ScanTrackMetadata(
                trackIndex: track.sourceTrackIndex ?? ordinal,
                trackCount: result.tracks.count,
                metadata: ScannerMetadata(
                    metadataDocument: track.document,
                    includeDateAndEncodedByInComment: false
                )
            )
        }
        return ScanInspection(route: route, tracks: tracks)
    }
}

private enum HESInspector {
    static func inspect(fileURL: URL, route: ScannerRoute) throws -> ScanInspection {
        let result: MetadataReadResult
        do {
            result = try MetaManCore.readResult(fileURL: fileURL)
        } catch let error as MetadataReadError {
            throw ScannerInspectionError.malformedFile(error.localizedDescription)
        } catch {
            throw ScannerInspectionError.library(
                "Could not read HES source \(fileURL.lastPathComponent): \(error.localizedDescription)"
            )
        }

        let tracks = result.tracks.enumerated().map { index, track in
            let document = track.document
            let metadata: ScannerMetadata
            if document.technicalFacts["hasPlaylist"] == "false" {
                let fields = document.fields
                metadata = ScannerMetadata(
                    game: fields.game ?? "",
                    song: fields.title ?? "",
                    system: fields.system ?? "",
                    author: fields.artist ?? "",
                    comment: fields.comment ?? "",
                    introLengthMs: 0,
                    loopLengthMs: 0,
                    playLengthMs: 0,
                    fadeLengthMs: 0
                )
            } else {
                metadata = ScannerMetadata(metadataDocument: document, includeDateAndEncodedByInComment: false)
            }
            return ScanTrackMetadata(trackIndex: index, trackCount: result.tracks.count, metadata: metadata)
        }
        return ScanInspection(route: route, tracks: tracks)
    }
}

private enum KSSInspector {
    static func inspect(fileURL: URL, route: ScannerRoute) throws -> ScanInspection {
        let result: MetadataReadResult
        do {
            result = try MetaManCore.readResult(fileURL: fileURL)
        } catch let error as MetadataReadError {
            throw ScannerInspectionError.malformedFile(error.localizedDescription)
        } catch {
            throw ScannerInspectionError.library(
                "Could not read KSS source \(fileURL.lastPathComponent): \(error.localizedDescription)"
            )
        }

        guard let document = result.tracks.first?.document else {
            throw ScannerInspectionError.malformedFile("KSS reader returned no compatibility slots.")
        }
        let fields = document.fields
        let metadata = ScannerMetadata(
            game: fields.game ?? "",
            song: fields.title ?? "",
            system: fields.system ?? "",
            author: fields.artist ?? "",
            comment: fields.comment ?? "",
            introLengthMs: document.timing?.introLengthMs ?? -1,
            loopLengthMs: document.timing?.loopLengthMs ?? -1,
            playLengthMs: document.timing?.playLengthMs ?? 150_000,
            fadeLengthMs: document.timing?.fadeLengthMs ?? -1
        )
        let tracks = result.tracks.enumerated().map { index, _ in
            return ScanTrackMetadata(
                trackIndex: index,
                trackCount: result.tracks.count,
                metadata: metadata
            )
        }
        return ScanInspection(route: route, tracks: tracks)
    }
}
