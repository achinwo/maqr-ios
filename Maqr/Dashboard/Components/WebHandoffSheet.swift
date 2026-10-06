//
//  WebHandoffSheet.swift
//  Maqr
//
//  The web dashboard inside the app, already signed in — for checkout and
//  card details, which stay on the web.
//

import MaqrDashboard
import SwiftUI
import WebKit

struct WebHandoffSheet: View {
    let handoff: WebHandoff
    /// Called as the sheet closes, so the screen behind can refresh what the
    /// web may have changed.
    var onClose: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            HandoffWebView(handoff: handoff, isLoading: $isLoading)
                .ignoresSafeArea(edges: .bottom)
                .overlay { if isLoading { ProgressView().controlSize(.large) } }
                .navigationTitle(handoff.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Link(destination: handoff.url) {
                            Image(systemName: "safari")
                        }
                        .accessibilityLabel(Text("Open in Safari"))
                    }
                }
        }
        .onDisappear(perform: onClose)
    }
}

private struct HandoffWebView: UIViewRepresentable {
    let handoff: WebHandoff
    @Binding var isLoading: Bool

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        if let script = handoff.bootstrapScript {
            configuration.userContentController.addUserScript(
                WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.load(URLRequest(url: handoff.url))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(isLoading: $isLoading) }

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool

        init(isLoading: Binding<Bool>) {
            _isLoading = isLoading
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
            isLoading = false
        }
    }
}

/// The system share sheet, for a downloaded file.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// A file to share, as an identifiable sheet item.
struct SharedFile: Identifiable {
    let url: URL
    var id: URL { url }
}
