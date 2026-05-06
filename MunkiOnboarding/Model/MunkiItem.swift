// MunkiItem.swift
// MunkiOnboarding

import Foundation

struct MunkiItem: Identifiable, Sendable, Equatable {
    var id: String { name }
    let name: String
    let displayName: String
    let version: String
    let installerItem: String
    let restartAction: String
    var installed: Bool
    var note: String?
}

enum InstallState: Sendable, Equatable {
    case pending
    case downloading
    case downloaded
    case installing
    case succeeded
    case failed(String)
}

enum OnboardingPhase: Sendable {
    case welcome
    case optionalSelection
    case provisioning
    case complete
}

struct MunkiStatusUpdate: Sendable {
    let message: String
    let detail: String
    let percent: Double
    let stopVisible: Bool
    let stopEnabled: Bool
    let command: String
    let pid: Int32
}
