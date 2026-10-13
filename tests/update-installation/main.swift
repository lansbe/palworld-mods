import Foundation

let stage = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true).resolvingSymlinksInPath()
let target = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true).resolvingSymlinksInPath()
let expected = CommandLine.arguments[3]
let package = UpdatePackage(directory: stage)
let next = try package.manifest.version
// Deliberately warm Foundation's cache, reproducing the stale-metadata regression.
let cached = Bundle(url: target)
assert(cached?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String == expected)
try package.install(over: target, expectedVersion: expected)
let installed = try UpdatePackage.metadata(target)
assert(installed["CFBundleShortVersionString"] as? String == next)
let previous = try UpdatePackage.metadata(target.deletingLastPathComponent().appendingPathComponent(".Palworld Mods.previous.app"))
assert(previous["CFBundleShortVersionString"] as? String == expected)
do {
    try package.install(over: target, expectedVersion: next)
    fatalError("An equal version must not be reinstalled")
} catch {}
let archive = stage.appendingPathComponent("package.zip")
let original = try Data(contentsOf: archive)
try Data("corrupt".utf8).write(to: archive)
do {
    try package.extract()
    fatalError("A corrupted signed archive must be rejected")
} catch {}
try original.write(to: archive)
try UpdatePackage.validate(target, version: next)
print("PASS: real signed bundle replacement, cached metadata regression, recoverable original, no downgrade and corrupt archive rejection")
