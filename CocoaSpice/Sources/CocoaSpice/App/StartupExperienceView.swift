import FrontendStartupCore
import SwiftUI

struct StartupExperienceView: View {
    let appName: String
    let progress: FrontendStartupProgress

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(progress.phase == .failed ? Color.red : Color.accentColor)
                        .frame(width: 8, height: 8)
                    Text("\(appName.uppercased()) / STARTUP")
                        .font(.caption.weight(.semibold))
                        .tracking(1.1)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(elapsedLabel(at: context.date))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Text(heading)
                    .font(.title3.weight(.semibold))

                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if progress.phase == .starting {
                    ProgressView()
                        .progressViewStyle(.linear)
                } else if progress.phase == .ready {
                    ProgressView(value: 1)
                        .progressViewStyle(.linear)
                        .tint(.green)
                }

                VStack(alignment: .leading, spacing: 9) {
                    ForEach(FrontendStartupStage.allCases, id: \.self) { stage in
                        stageRow(stage)
                    }
                }

                if let failure = progress.failureMessage {
                    Label(failure, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(22)
            .frame(maxWidth: 430, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.22), radius: 28, y: 14)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(appName) startup progress")
    }

    private var heading: String {
        switch progress.phase {
        case .idle, .starting:
            progress.currentStage.heading
        case .ready:
            "\(appName) is ready"
        case .failed:
            "\(appName) could not finish starting"
        }
    }

    private var detail: String {
        switch progress.phase {
        case .idle, .starting:
            progress.currentDetail
        case .ready:
            "Your library and saved playlists are ready."
        case .failed:
            "Startup paused. Review the error below."
        }
    }

    private func elapsedLabel(at date: Date) -> String {
        switch progress.phase {
        case .ready: "Ready"
        case .failed: "Startup paused"
        case .idle, .starting: "Working \(progress.elapsedSeconds(at: date))s"
        }
    }

    private func stageRow(_ stage: FrontendStartupStage) -> some View {
        let state = progress.state(for: stage)
        return HStack(spacing: 10) {
            Group {
                switch state {
                case .pending:
                    Image(systemName: "circle")
                        .foregroundStyle(.tertiary)
                case .active:
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 13, height: 13)
                case .complete:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .failed:
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
            .frame(width: 14, height: 14)
            Text(stage.label)
                .font(.callout)
                .foregroundStyle(state == .pending ? .secondary : .primary)
        }
        .accessibilityElement(children: .combine)
    }
}
