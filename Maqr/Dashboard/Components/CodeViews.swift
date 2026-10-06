//
//  CodeViews.swift
//  Maqr
//
//  An experience's code, drawn: a QR from the matrix MaqrDashboard encodes,
//  or an App Clip Code as the server draws it.
//

import MaqrDashboard
import SwiftUI
import WebKit

/// A QR code drawn natively — square or round modules, finders always
/// square, the badge in the middle when chosen.
struct QRCodeView: View {
    let url: String
    let style: CodeStyle

    var body: some View {
        let drawn = style.printable.style
        let matrix = QRMatrix(encoding: url)
        Canvas { context, size in
            let quiet = QRMatrix.quietZone
            guard let matrix else { return }
            let span = Double(matrix.size + quiet * 2)
            let module = min(size.width, size.height) / span
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(maqrHex: drawn.background)))

            var path = Path()
            for y in 0..<matrix.size {
                for x in 0..<matrix.size where matrix.isDark(x: x, y: y) {
                    let rect = CGRect(x: Double(x + quiet) * module, y: Double(y + quiet) * module, width: module, height: module)
                    if drawn.shape == .dot && !matrix.isFinder(x: x, y: y) {
                        path.addEllipse(in: rect)
                    } else {
                        path.addRect(rect.insetBy(dx: -0.25, dy: -0.25))
                    }
                }
            }
            context.fill(path, with: .color(Color(maqrHex: drawn.foreground)))

            if drawn.logo {
                let badge = Double(matrix.size) * QRMatrix.badgeFraction * module
                let centre = CGPoint(x: size.width / 2, y: size.height / 2)
                let ring = CGRect(x: centre.x - badge / 2 - module * 0.6, y: centre.y - badge / 2 - module * 0.6,
                                  width: badge + module * 1.2, height: badge + module * 1.2)
                context.fill(Path(ellipseIn: ring), with: .color(Color(maqrHex: drawn.background)))
                let mark = CGRect(x: centre.x - badge / 2, y: centre.y - badge / 2, width: badge, height: badge)
                context.fill(Path(ellipseIn: mark), with: .color(.maqrAccent))
                context.draw(
                    Text(verbatim: "Q").font(.system(size: badge * 0.62, weight: .heavy, design: .rounded)).foregroundStyle(.white),
                    at: centre)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel(Text("QR code for this experience"))
    }
}

/// An App Clip Code, as the server draws it (SVG), shown in a web view that
/// takes no touches.
struct AppClipCodeView: UIViewRepresentable {
    let svg: String?

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.isScrollEnabled = false
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        guard let svg, context.coordinator.shown != svg else { return }
        context.coordinator.shown = svg
        let html = """
        <html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>html,body{margin:0;background:transparent}svg{width:100vw;height:100vh;display:block}</style>
        </head><body>\(svg)</body></html>
        """
        view.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var shown: String?
    }
}

/// Whichever code the experience has, at a given size.
struct ExperienceCodeView: View {
    let url: String
    let style: CodeStyle
    /// The server-drawn App Clip Code, when the style is one.
    var appClipSVG: String?

    var body: some View {
        Group {
            if style.format == .appclip {
                ZStack {
                    if appClipSVG == nil { ProgressView() }
                    AppClipCodeView(svg: appClipSVG)
                }
                .aspectRatio(1, contentMode: .fit)
                .accessibilityLabel(Text("App Clip Code for this experience"))
            } else {
                QRCodeView(url: url, style: style)
                    .padding(6)
                    .background(Color(maqrHex: style.printable.style.background), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.separator))
            }
        }
        .animation(.smooth, value: style)
    }
}

/// Fetches the server's drawing of an App Clip Code for screens that show a
/// saved code rather than one being designed.
struct SavedCodeView: View {
    @Environment(AppModel.self) private var model
    let detail: ExperienceDetail
    @State private var svg: String?

    var body: some View {
        ExperienceCodeView(url: detail.url, style: detail.style, appClipSVG: svg)
            .task(id: detail.style) {
                guard detail.style.format == .appclip else { return }
                svg = try? await model.dashboard.client.codePreviewSVG(detail.id, style: detail.style)
            }
    }
}
