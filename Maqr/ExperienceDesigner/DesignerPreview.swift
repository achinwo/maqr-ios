//
//  DesignerPreview.swift
//  Maqr
//

import DesignerFoundation
import ExperienceModel
import SwiftUI

/// The phone preview of one step: the schema's ``PreviewBlocks`` drawn
/// natively.
///
/// The blocks are the same ones the web designer turns into `div`s and CSS;
/// here each block's class picks a small SwiftUI shape instead. The schema
/// decides what is on the page — this only decides how a kind of block looks.
struct DesignerPreview: View {
    let document: ExperienceDocument
    let schema: ExperienceSchema
    let step: DesignerStep

    var body: some View {
        let page = schema.preview(step, document)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(step.previewTitle)
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(palette.accent.opacity(0.8))
                ForEach(Array(page.blocks.enumerated()), id: \.offset) { _, block in
                    PreviewBlockView(block: block, palette: palette)
                }
            }
            .padding()
        }
        .foregroundStyle(palette.accent)
        .background(background)
    }

    private var palette: PreviewPalette {
        PreviewPalette(
            primary: Color(designerHex: document.field(Field.colorPrimary)) ?? .yellow,
            secondary: Color(designerHex: document.field(Field.colorSecondary)) ?? .black,
            accent: Color(designerHex: document.field(Field.colorAccent)) ?? .white)
    }

    /// What the page paints behind itself, by ``BackgroundMode`` — the same
    /// precedence the web preview and the finished app use.
    @ViewBuilder private var background: some View {
        let first = Color(designerHex: document.field(Field.backgroundColor1))
        let second = Color(designerHex: document.field(Field.backgroundColor2))
        switch BackgroundMode.current(document) {
        case BackgroundMode.image:
            DesignerImage(url: document.field(Field.backgroundImageUrl))
                .overlay(palette.secondary.opacity(0.4))
        case BackgroundMode.solid:
            first ?? palette.secondary
        case BackgroundMode.gradient:
            LinearGradient(
                colors: [first ?? palette.secondary, second ?? palette.secondary],
                startPoint: .top, endPoint: .bottom)
        default:
            LinearGradient(
                colors: [palette.secondary, palette.primary.opacity(0.6)],
                startPoint: .top, endPoint: .bottom)
        }
    }
}

struct PreviewPalette {
    let primary: Color
    let secondary: Color
    let accent: Color
}

/// One block, by the first of its classes.
private struct PreviewBlockView: View {
    let block: PreviewBlock
    let palette: PreviewPalette

    private var kind: String { String(block.className.split(separator: " ").first ?? "") }
    private func leaf(_ className: String) -> PreviewLeaf? {
        block.children.first { $0.className.split(separator: " ").contains(Substring(className)) }
    }
    private func leaves(_ className: String) -> [PreviewLeaf] {
        block.children.filter { $0.className.split(separator: " ").contains(Substring(className)) }
    }

    var body: some View {
        switch kind {
        case "cd-pv-banner":
            DesignerImage(url: block.image)
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(alignment: .bottomLeading) {
                    if let caption = leaf("cd-pv-caption") {
                        Text(caption.text)
                            .font(.headline)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.black.opacity(0.45))
                            .foregroundStyle(.white)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))

        case "cd-pv-portrait-wrap":
            if let portrait = block.children.first {
                Group {
                    if portrait.image.isEmpty {
                        Text(portrait.text)
                            .font(.largeTitle.weight(.semibold))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(palette.primary.opacity(0.5))
                    } else {
                        DesignerImage(url: portrait.image)
                    }
                }
                .frame(width: 96, height: 96)
                .clipShape(Circle())
                .frame(maxWidth: .infinity)
            }

        case "cd-pv-tagline":
            Text(block.text).font(.caption).textCase(.uppercase).opacity(0.8)

        case "cd-pv-title":
            Text(block.text)
                .font(.system(.largeTitle, design: .serif))
                .foregroundStyle(palette.primary)
                .frame(maxWidth: .infinity)
                .designerTextStyle(block.style)

        case "cd-pv-welcome-wedding":
            Text(block.text)
                .frame(maxWidth: .infinity)
                .designerTextStyle(block.style)

        case "cd-pv-namecard":
            VStack(alignment: .leading, spacing: 6) {
                if let title = leaf("cd-pv-namecard-title") {
                    Text(title.text).font(.title2.weight(.semibold)).designerTextStyle(title.style)
                }
                if let text = leaf("cd-pv-namecard-text"), !text.text.isEmpty {
                    Text(text.text).designerTextStyle(text.style)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.gray.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))

        case "cd-pv-heading":
            Text(block.text).font(.headline)
        case "cd-pv-para":
            Text(block.text)
        case "cd-pv-empty":
            Text(block.text).italic().opacity(0.6)
        case "cd-pv-footnote":
            Text(block.text).font(.footnote).opacity(0.7)

        case "cd-pv-tiles":
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 8) {
                ForEach(Array(block.children.enumerated()), id: \.offset) { _, tile in
                    Text(tile.text)
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background(palette.primary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                }
            }

        case "cd-pv-tabs", "cd-pv-chips":
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(Array(block.children.enumerated()), id: \.offset) { _, item in
                        let isOn = item.className.hasSuffix("-on")
                        Text(item.text)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                isOn ? palette.primary : palette.accent.opacity(0.12), in: Capsule())
                    }
                }
            }

        case "cd-pv-notice":
            HStack(alignment: .top, spacing: 10) {
                Text(leaf("cd-pv-notice-icon")?.text ?? "")
                VStack(alignment: .leading, spacing: 2) {
                    Text(leaf("cd-pv-notice-title")?.text ?? "").font(.subheadline.weight(.semibold))
                    Text(leaf("cd-pv-notice-text")?.text ?? "").font(.subheadline)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                (block.className.contains("-warn") ? Color.orange : palette.primary).opacity(0.3),
                in: RoundedRectangle(cornerRadius: 12))

        case "cd-pv-stream", "cd-pv-row":
            HStack(spacing: 12) {
                if let thumb = leaf("cd-pv-thumb") {
                    DesignerImage(url: thumb.image)
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Text(leaf("cd-pv-stream-thumb")?.text ?? "")
                        .frame(width: 52, height: 52)
                        .background(palette.primary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(leaf(kind + "-title")?.text ?? "").font(.subheadline.weight(.semibold))
                    Text(leaf(kind + "-sub")?.text ?? "").font(.caption).opacity(0.75)
                }
            }

        case "cd-pv-moment":
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(leaf("cd-pv-moment-time")?.text ?? "")
                    .font(.caption.monospacedDigit())
                    .frame(width: 52, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(leaf("cd-pv-moment-title")?.text ?? "").font(.subheadline.weight(.semibold))
                    Text(leaf("cd-pv-moment-note")?.text ?? "").font(.caption).opacity(0.75)
                }
            }

        case "cd-pv-quote":
            VStack(alignment: .leading, spacing: 4) {
                Text(leaf("cd-pv-quote-text")?.text ?? "").italic()
                Text(leaf("cd-pv-quote-by")?.text ?? "").font(.caption).opacity(0.75)
            }
            .padding(.leading, 10)
            .overlay(alignment: .leading) { Rectangle().fill(palette.primary).frame(width: 3) }

        case "cd-pv-table":
            VStack(alignment: .leading, spacing: 4) {
                Text(leaf("cd-pv-table-title")?.text ?? "").font(.subheadline.weight(.semibold))
                ForEach(Array(leaves("cd-pv-table-name").enumerated()), id: \.offset) { _, name in
                    Text(name.text).font(.caption)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

        case "cd-pv-button-wrap":
            Text(leaf("cd-pv-button")?.text ?? "")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(palette.primary, in: Capsule())

        default:
            // A kind this layer doesn't know yet still shows its words.
            VStack(alignment: .leading) {
                if !block.text.isEmpty { Text(block.text) }
                ForEach(Array(block.children.enumerated()), id: \.offset) { _, child in
                    if !child.text.isEmpty { Text(child.text) }
                }
            }
        }
    }
}
