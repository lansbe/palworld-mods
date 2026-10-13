import Foundation
import AppKit
import Darwin

// Short-lived, unprivileged installer. It never terminates the game or requests elevation.
let arguments = CommandLine.arguments
guard arguments.count == 6, let parent = Int32(arguments[4]), parent > 1 else { exit(64) }
let stage = URL(fileURLWithPath: arguments[1], isDirectory: true)
let target = URL(fileURLWithPath: arguments[2], isDirectory: true)
let root = URL(fileURLWithPath: arguments[3], isDirectory: true)
let version = arguments[5]
let deadline = Date().addingTimeInterval(120)
while kill(parent, 0) == 0 && Date() < deadline { Thread.sleep(forTimeInterval: 0.2) }
guard kill(parent, 0) != 0 else { exit(75) }
let lock = open(root.appendingPathComponent("launcher.lock").path, O_CREAT | O_RDWR | O_CLOEXEC, 0o600)
guard lock >= 0, flock(lock, LOCK_EX | LOCK_NB) == 0 else { exit(75) }
defer { close(lock) }
guard NSRunningApplication.runningApplications(withBundleIdentifier: "com.pocketpair.palworld.mac").isEmpty else { exit(75) }
do {
    let package = UpdatePackage(directory: stage)
    try package.install(over: target, expectedVersion: version)
    try UpdateFiles.write(Data("installed\n".utf8), to: root.appendingPathComponent("update-result.txt"))
    exit(0)
} catch {
    try? UpdateFiles.write(Data("failed\n".utf8), to: root.appendingPathComponent("update-result.txt"))
    let diagnostic = "installer failure: \(String(describing: type(of: error))) code=\((error as NSError).code)\n"
    try? UpdateFiles.write(Data(diagnostic.utf8), to: root.appendingPathComponent("update-error.txt"))
    exit(1)
}
