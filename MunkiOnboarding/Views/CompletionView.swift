// CompletionView.swift
// MunkiOnboarding

import SwiftUI

struct CompletionView: View {
    @Environment(MunkiMonitor.self) private var monitor

    private var b: BrandingConfig { monitor.branding }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 96))
                .foregroundStyle(Color.trendRed)
                .padding(.bottom, 24)

            Text(b.completionTitle)
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(b.completionSubtitle)
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            Divider()
                .padding(.horizontal, 160)
                .padding(.vertical, 28)

            HStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.title)
                    .foregroundStyle(Color.trendRed)
                VStack(alignment: .leading, spacing: 4) {
                    Text("FileVault Encryption")
                        .font(.headline)
                    Text(b.completionFileVaultNote)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 100)
            .frame(maxWidth: 600)

            Spacer()

            Button(b.completionLogoutText) {
                LogoutHelper.logout()
            }
            .buttonStyle(TrendButtonStyle())
            .padding(.bottom, 48)
        }
        .frame(width: 900, height: 660)
    }
}
