//
//  DesignerTypePicker.swift
//  Maqr
//

import ExperienceModel
import MaqrDashboard
import SwiftUI

/// The designer's first question — what is being made — as a card per type,
/// each with the dashboard's symbol for it and the steps it will walk through.
struct DesignerTypePicker: View {
    let onChoose: (ExperienceSchema) -> Void

    @State private var hasAppeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Pick a starting point. You can preview every step before anything is saved.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)

                ForEach(Array(ExperienceSchema.all.enumerated()), id: \.element.type) { index, schema in
                    Button {
                        onChoose(schema)
                    } label: {
                        TypeCard(schema: schema, isAnimating: hasAppeared)
                    }
                    .buttonStyle(PressableCardStyle())
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 24)
                    .animation(.spring(duration: 0.5, bounce: 0.25).delay(Double(index) * 0.07), value: hasAppeared)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("New experience")
        .onAppear { hasAppeared = true }
    }
}

private struct TypeCard: View {
    let schema: ExperienceSchema
    let isAnimating: Bool

    var body: some View {
        let tint = schema.tint
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: Catalog.symbol(forType: schema.type))
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
                .symbolEffect(.bounce, value: isAnimating)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(colors: [tint, tint.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: tint.opacity(0.35), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 6) {
                Text(schema.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(schema.tagline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("^[\(schema.steps.count) step](inflect: true)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .padding(.top, 2)
                Text(schema.steps.map(\.shortTitle).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
            .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(alignment: .topTrailing) {
                    // A faint wash of the type's colour, so each card reads as its own.
                    RadialGradient(colors: [tint.opacity(0.16), .clear], center: .topTrailing, startRadius: 0, endRadius: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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

extension ExperienceSchema {
    /// What a person calls the type, where the badge is a shout.
    var displayName: LocalizedStringKey {
        switch type {
        case ExperienceType.wedding: return "Wedding"
        case ExperienceType.brand: return "Brand promo"
        case ExperienceType.mealbox: return "Meal box"
        default: return LocalizedStringKey(badge.capitalized)
        }
    }

    /// The type's own colour, for its card and the designer's chrome.
    var tint: Color {
        switch type {
        case ExperienceType.wedding: return .pink
        case ExperienceType.brand: return .indigo
        case ExperienceType.mealbox: return .orange
        default: return .maqrAccent
        }
    }
}
