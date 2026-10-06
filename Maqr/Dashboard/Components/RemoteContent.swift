//
//  RemoteContent.swift
//  Maqr
//
//  The three states every screen has: still loading, couldn't load, and
//  showing something — possibly a saved copy while offline.
//

import MaqrDashboard
import SwiftUI

/// Draws a ``Remote`` value: a spinner first time, a retry if it failed with
/// nothing to show, and the content otherwise.
struct RemoteContent<Value, Content: View>: View {
    let remote: Remote<Value>
    var failureTitle: LocalizedStringKey = "Couldn't load this"
    var retry: () async -> Void
    @ViewBuilder var content: (Value) -> Content

    var body: some View {
        if let value = remote.value {
            content(value)
        } else if let failure = remote.failure {
            FailureView(title: failureTitle, error: failure, retry: retry)
        } else {
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 60)
        }
    }
}

/// "Couldn't load" with the reason and a way to try again.
struct FailureView: View {
    let title: LocalizedStringKey
    let error: DashboardError
    var retry: () async -> Void

    var body: some View {
        ContentUnavailableView {
            Label(error.isOffline ? "You're offline" : title,
                  systemImage: error.isOffline ? "wifi.slash" : "exclamationmark.triangle")
        } description: {
            Text(error.message)
        } actions: {
            Button("Try again") { Task { await retry() } }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension View {
    /// The saved-copy note above a list's content while offline.
    func savedCopyBanner<Value>(_ remote: Remote<Value>) -> some View {
        safeAreaInset(edge: .top, spacing: 0) {
            if remote.isStale {
                SavedCopyNote(updatedAt: remote.updatedAt)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(.bar)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: remote.isStale)
    }
}
