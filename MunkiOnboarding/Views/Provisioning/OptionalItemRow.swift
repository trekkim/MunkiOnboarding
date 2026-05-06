// OptionalItemRow.swift
// MunkiOnboarding

import SwiftUI

struct OptionalItemRow: View {
    let item: MunkiItem
    let isSelected: Bool
    var brandingIconsDir: String? = nil
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ItemIconView(itemName: item.name, brandingIconsDir: brandingIconsDir)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                if !item.version.isEmpty {
                    Text(item.version)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .tint(Color(nsColor: .systemGreen))
            .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isSelected ? Color.trendRed.opacity(0.06) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
