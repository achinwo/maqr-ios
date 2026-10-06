//
//  Cards.swift
//  Maqr
//
//  The cards the browse screens are made of.
//

import MaqrDashboard
import SwiftUI

/// The namespace cards zoom out of and screens zoom into.
extension EnvironmentValues {
    @Entry var zoomNamespace: Namespace.ID?
}

extension View {
    func zoomSource(id: String, namespace: Namespace.ID?) -> some View {
        Group {
            if let namespace { zoomSource(id: id, in: namespace) } else { self }
        }
    }

    func zoomDestination(id: String, namespace: Namespace.ID?) -> some View {
        Group {
            if let namespace { zoomDestination(id: id, in: namespace) } else { self }
        }
    }
}

/// A1's card: the artwork, the title, what it is, and Remix.
struct DesignCard: View {
    let design: Design
    var onRemix: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ArtworkView(url: design.image, symbol: design.symbol)
                .frame(height: 112)
            VStack(alignment: .leading, spacing: 4) {
                Text(design.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2, reservesSpace: true)
                    .foregroundStyle(.primary)
                Text(design.meta)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Button(action: onRemix) {
                    Label("Remix this", systemImage: "wand.and.stars")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .padding(.top, 6)
            }
            .padding(10)
        }
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// B1's row cards: smaller, side by side.
struct MiniCard: View {
    let title: String
    let meta: String
    let image: URL?
    var symbol: String = "qrcode"
    var action: (label: LocalizedStringKey, run: () -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ArtworkView(url: image, symbol: symbol)
                .frame(height: 118)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2, reservesSpace: true)
                Text(meta)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let action {
                    Button(action.label, action: action.run)
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 5)
                }
            }
            .padding(10)
        }
        .frame(width: 168)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// B1's hero: the experience coming up next, big, with its quick actions.
struct HeroCard: View {
    let experience: MyExperience

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ArtworkView(url: experience.design.image, symbol: experience.design.symbol)
                .frame(height: 232)
            LinearGradient(
                stops: [.init(color: .black.opacity(0), location: 0.3), .init(color: .black.opacity(0.85), location: 1)],
                startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    StatusBadge(text: experience.heroBadge, tone: .accent)
                    Text(experience.design.category)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Text(experience.design.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text([experience.date == nil ? nil : experience.when, experience.contents].compactMap { $0 }.joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.maqrAccent, lineWidth: 1.5))
        .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
    }
}

/// Opens an experience as guests see it: a glass capsule over artwork.
struct LaunchButton: View {
    var action: () -> Void
    @State private var taps = 0

    var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            Label("Launch", systemImage: "play.fill")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .foregroundStyle(.white)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.35)))
                .environment(\.colorScheme, .dark)
        }
        .buttonStyle(PressableCardStyle())
        .sensoryFeedback(.impact(weight: .medium), trigger: taps)
        .accessibilityHint(Text("Opens the experience as guests see it"))
    }
}

/// The four quick actions under an experience: code, print, stats, notify —
/// only the ones your role allows.
struct QuickActions: View {
    @Environment(AppModel.self) private var model
    let id: String
    let role: Role?

    var body: some View {
        HStack(spacing: 8) {
            action("QR code", "qrcode", .code(id))
            if role == nil || role.can(.print) { action("Print", "printer", .printTemplates(id)) }
            if role == nil || role.can(.analytics) { action("Stats", "chart.bar", .stats(id)) }
            if role == nil || role.can(.notify) { action("Notify", "bell.badge", .notify(id)) }
        }
    }

    private func action(_ label: LocalizedStringKey, _ symbol: String, _ route: Route) -> some View {
        // A button that pushes rather than a NavigationLink, so a list row
        // holding these does not grow a disclosure chevron per action.
        Button { model.push(route) } label: {
            VStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                Text(label)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// A filter chip.
struct Chip: View {
    let title: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background {
                    Capsule().fill(isSelected ? AnyShapeStyle(Color.maqrAccent) : AnyShapeStyle(.fill.tertiary))
                }
        }
        .buttonStyle(.plain)
        .animation(.snappy, value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A row of chips that scrolls sideways.
struct ChipRow<Item: Hashable>: View {
    let items: [Item]
    let selected: Item
    let title: (Item) -> String
    var onSelect: (Item) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Chip(title: title(item), isSelected: item == selected) { onSelect(item) }
                }
            }
            .padding(.horizontal)
        }
        .sensoryFeedback(.selection, trigger: selected)
    }
}
