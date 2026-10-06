//
//  Theme.swift
//  Maqr
//
//  The dashboard's look: system materials and semantic colours, so light and
//  dark follow the device, with maQR blue as the one accent.
//

import MaqrDashboard
import SwiftUI

extension Color {
    /// maQR blue — the brand accent, legible on both light and dark.
    static let maqrAccent = Color(red: 36 / 255, green: 141 / 255, blue: 193 / 255)
    static let maqrLive = Color(red: 46 / 255, green: 158 / 255, blue: 91 / 255)

    /// A colour from a `#rrggbb` string; clear if it cannot be read.
    init(maqrHex hex: String) {
        if let rgb = RGB(hex: hex) {
            self.init(red: rgb.red, green: rgb.green, blue: rgb.blue)
        } else {
            self = .clear
        }
    }
}

extension Tone {
    var color: Color {
        switch self {
        case .muted: return .secondary
        case .accent: return .maqrAccent
        case .live: return .maqrLive
        case .alert: return .red
        }
    }
}

/// How the app looks: following the device unless someone chose otherwise.
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    static let storageKey = "maqr.appearance"
}

// MARK: - Small pieces

/// The wireframe's pill: LIVE, DRAFT, Showing…
struct StatusBadge: View {
    let text: String
    var tone: Tone = .muted

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .tracking(0.6)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .foregroundStyle(tone == .muted ? Color.secondary : Color.white)
            .background(tone == .muted ? AnyShapeStyle(.fill.tertiary) : AnyShapeStyle(tone.color), in: Capsule())
    }
}

/// A boxed note — quiet, an alert, or a stop.
struct NoticeCard: View {
    enum Kind { case quiet, alert, stop }

    let title: String
    var message: String?
    var kind: Kind = .quiet

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .symbolRenderingMode(.hierarchical)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                if let message { Text(message).font(.footnote).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch kind {
        case .quiet: return "info.circle.fill"
        case .alert: return "exclamationmark.circle.fill"
        case .stop: return "pause.circle.fill"
        }
    }

    private var tint: Color {
        switch kind {
        case .quiet: return .secondary
        case .alert: return .maqrAccent
        case .stop: return .orange
        }
    }

    private var background: AnyShapeStyle {
        kind == .alert ? AnyShapeStyle(Color.maqrAccent.opacity(0.12)) : AnyShapeStyle(.fill.quaternary)
    }
}

/// A status line with its badge and where the status came from.
struct StatusStrip: View {
    let badge: String
    var tone: Tone = .muted
    let line: String
    var source: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                StatusBadge(text: badge, tone: tone)
                Text(line).font(.footnote).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            if let source {
                Text(verbatim: source).font(.caption2).tracking(0.6).foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// A labelled progress bar — how much of a term is left.
struct MeterView: View {
    let label: String
    let value: String
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.subheadline.weight(.medium))
                Spacer()
                Text(value).font(.footnote).foregroundStyle(.secondary)
            }
            ProgressView(value: min(max(progress, 0), 1))
                .tint(.maqrAccent)
        }
        .accessibilityElement(children: .combine)
    }
}

/// An experience's artwork, or its category's symbol on a soft gradient.
struct ArtworkView: View {
    let url: URL?
    var symbol: String = "qrcode"

    var body: some View {
        Rectangle()
            .fill(.fill.tertiary)
            .overlay {
                AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.25))) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill().transition(.opacity)
                    default:
                        placeholder
                    }
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [Color.maqrAccent.opacity(0.22), Color.maqrAccent.opacity(0.06)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.maqrAccent.opacity(0.7))
                    .symbolRenderingMode(.hierarchical)
            }
    }
}

/// The initial in a circle — there is no avatar on the account to show.
struct InitialAvatar: View {
    let name: String
    var size: CGFloat = 38

    var body: some View {
        Text(verbatim: String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
            .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [.maqrAccent, .maqrAccent.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: Circle())
            .accessibilityHidden(true)
    }
}

/// "Offline · showing what was saved" — under any screen showing a saved copy.
struct SavedCopyNote: View {
    let updatedAt: Date?

    var body: some View {
        Label {
            if let updatedAt {
                Text("Offline · showing what was saved \(updatedAt, format: .relative(presentation: .named))")
            } else {
                Text("Offline · showing what was saved")
            }
        } icon: {
            Image(systemName: "icloud.slash")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Transitions

extension View {
    /// The source of a zoom transition, where the system supports one.
    @ViewBuilder
    func zoomSource(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    /// The destination of a zoom transition, where the system supports one.
    @ViewBuilder
    func zoomDestination(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }

    /// Cards that settle in as they scroll into view.
    func scrollSettle() -> some View {
        scrollTransition(.interactive, axis: .vertical) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1 : 0.96)
                .opacity(phase.isIdentity ? 1 : 0.7)
        }
    }
}
