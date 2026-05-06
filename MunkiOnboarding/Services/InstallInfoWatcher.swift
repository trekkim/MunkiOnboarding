// InstallInfoWatcher.swift
// MunkiOnboarding

import Foundation

// Watches InstallInfo.plist for changes using DispatchSource (kqueue-based).
// Munki writes the file atomically (temp + rename), so .rename fires, not .write.
// The caller must restart the watcher after each event because the inode changes.
final class InstallInfoWatcher: @unchecked Sendable {
    private var source: DispatchSourceFileSystemObject?
    private var fd: Int32 = -1

    func start(path: String, onChange: @escaping @Sendable () -> Void) {
        stop()
        fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        src.setEventHandler {
            onChange()
        }
        src.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.fd >= 0 {
                close(self.fd)
                self.fd = -1
            }
        }
        src.resume()
        source = src
    }

    func stop() {
        source?.cancel()
        source = nil
    }
}
