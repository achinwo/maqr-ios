//
//  TemplatePicker.swift
//  Maqr
//
//  Where a new experience starts: a template from `GET /api/templates` —
//  "Wedding", "Brand page", "Recipe", "Menu", "Blank", and later the
//  author's own. Replaces the per-type picker; a template is a row in the
//  database, so a new kind of page appears here without a release.
//

import MaqrDashboard
import SwiftUI

struct TemplatePicker: View {
    let host: ExperienceDesignerHost
    let choose: (TemplateSummary) -> Void

    @State private var templates: [TemplateSummary] = []
    @State private var failure: String?
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What are you making?").font(.largeTitle.bold())
                    Text("Start from a template. Every section can be changed, hidden or added to as you go.")
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 6)

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                } else if let failure {
                    ContentUnavailableView {
                        Label("Templates didn't load", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(failure)
                    } actions: {
                        Button("Try again") { Task { await load() } }.buttonStyle(.borderedProminent)
                    }
                }

                ForEach(templates) { template in
                    Button { choose(template) } label: { TemplateCard(template: template) }
                        .buttonStyle(PressableCardStyle())
                }
            }
            .padding(20)
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        failure = nil
        do {
            templates = try await host.templates()
        } catch {
            failure = error.localizedDescription
        }
        isLoading = false
    }
}

private struct TemplateCard: View {
    let template: TemplateSummary

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: Self.symbol(template))
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Self.tint(template).gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(template.name).font(.headline).foregroundStyle(.primary)
                    if let badge = template.badge, !badge.isEmpty {
                        Text(badge.uppercased()).font(.caption2.weight(.bold)).padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.tint.opacity(0.15), in: Capsule())
                    }
                }
                if let tagline = template.tagline, !tagline.isEmpty {
                    Text(tagline).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                }
                if let category = template.category, !category.isEmpty {
                    Text(category).font(.caption).foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// The template's icon, read as an SF Symbol where it names one this
    /// system has; a code's own symbol otherwise.
    static func symbol(_ template: TemplateSummary) -> String {
        if let icon = template.icon, UIImage(systemName: icon) != nil { return icon }
        switch template.code {
        case "wedding": return "heart.circle.fill"
        case "brand": return "sparkles"
        case "recipe": return "fork.knife.circle.fill"
        case "menu": return "takeoutbag.and.cup.and.straw.fill"
        default: return "square.grid.2x2.fill"
        }
    }

    static func tint(_ template: TemplateSummary) -> Color {
        switch template.code {
        case "wedding": return .pink
        case "brand": return .indigo
        case "recipe": return .orange
        case "menu": return .green
        default: return .maqrAccent
        }
    }
}

/// A card that sinks a little under a finger.
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}
