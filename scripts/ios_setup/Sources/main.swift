import Foundation
import PathKit
import XcodeProj

enum SetupError: Error { case invalid(String) }
func readPlist(_ path: String) throws -> [String: Any] {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    guard let value = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
        throw SetupError.invalid("Invalid plist: \(path)")
    }
    return value
}
func writePlist(_ value: [String: Any], _ path: String) throws {
    let data = try PropertyListSerialization.data(fromPropertyList: value, format: .xml, options: 0)
    try data.write(to: URL(fileURLWithPath: path), options: .atomic)
}

do {
    let env = ProcessInfo.processInfo.environment
    let bundle = env["IOS_BUNDLE_ID"] ?? "com.digitalsolutionsai.prono4"
    guard bundle == "com.digitalsolutionsai.prono4" else { throw SetupError.invalid("Unexpected App Store bundle") }
    let firebase = try readPlist("ios/Runner/GoogleService-Info.plist")
    guard firebase["BUNDLE_ID"] as? String == bundle,
          firebase["PROJECT_ID"] as? String == "mundial2026-ibab-01",
          firebase["GOOGLE_APP_ID"] as? String == "1:531137173785:ios:886307ce184d24e38b4d88" else {
        throw SetupError.invalid("Firebase does not match the existing App Store application")
    }
    guard let client = firebase["CLIENT_ID"] as? String, !client.isEmpty,
          let reverse = firebase["REVERSED_CLIENT_ID"] as? String, !reverse.isEmpty,
          let admob = env["ADMOB_IOS_APP_ID"], !admob.isEmpty else {
        throw SetupError.invalid("Missing Google sign-in or AdMob configuration")
    }
    var info = try readPlist("ios/Runner/Info.plist")
    info["CFBundleDisplayName"] = "PRONO4"
    info["GADApplicationIdentifier"] = admob
    info["ITSAppUsesNonExemptEncryption"] = false
    info["NSCameraUsageDescription"] = "PRONO4 utilise la caméra uniquement lorsque vous choisissez une photo de profil."
    info["NSPhotoLibraryUsageDescription"] = "PRONO4 accède à vos photos uniquement lorsque vous choisissez une photo de profil."
    info["NSUserTrackingUsageDescription"] = "Votre autorisation permet à PRONO4 de proposer des publicités plus pertinentes."
    info["UIBackgroundModes"] = ["remote-notification"]
    info["UISupportedInterfaceOrientations~ipad"] = ["UIInterfaceOrientationPortrait", "UIInterfaceOrientationPortraitUpsideDown", "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"]
    info["GIDClientID"] = client
    info["GIDServerClientID"] = "531137173785-tltuheu808j5t8j5qd51a1a79qak2upl.apps.googleusercontent.com"
    var urlTypes = info["CFBundleURLTypes"] as? [[String: Any]] ?? []
    if !urlTypes.contains(where: { ($0["CFBundleURLSchemes"] as? [String] ?? []).contains(reverse) }) {
        urlTypes.append(["CFBundleTypeRole": "Editor", "CFBundleURLSchemes": [reverse]])
    }
    info["CFBundleURLTypes"] = urlTypes
    try writePlist(info, "ios/Runner/Info.plist")

    let entitlementPath = "ios/Runner/Runner.entitlements"
    var entitlements = FileManager.default.fileExists(atPath: entitlementPath) ? try readPlist(entitlementPath) : [:]
    entitlements["aps-environment"] = "production"
    entitlements["com.apple.developer.applesignin"] = ["Default"]
    try writePlist(entitlements, entitlementPath)

    let projectPath = Path("ios/Runner.xcodeproj")
    let project = try XcodeProj(path: projectPath)
    guard let root = try project.pbxproj.rootProject(),
          let runner = project.pbxproj.nativeTargets.first(where: { $0.name == "Runner" }) else {
        throw SetupError.invalid("Runner target missing")
    }
    for configuration in project.pbxproj.buildConfigurations {
        configuration.buildSettings["IPHONEOS_DEPLOYMENT_TARGET"] = "15.0"
    }
    for target in project.pbxproj.nativeTargets {
        for configuration in target.buildConfigurationList?.buildConfigurations ?? [] {
            configuration.buildSettings["PRODUCT_BUNDLE_IDENTIFIER"] = target.name == "Runner" ? bundle : bundle + "." + target.name
            if target.name == "Runner" {
                configuration.buildSettings["DEVELOPMENT_TEAM"] = "G6T4NT9XZ9"
                configuration.buildSettings["TARGETED_DEVICE_FAMILY"] = "1,2"
                configuration.buildSettings["CODE_SIGN_ENTITLEMENTS"] = "Runner/Runner.entitlements"
                var flags: [String]
                if let existing = configuration.buildSettings["OTHER_LDFLAGS"] as? [String] { flags = existing }
                else if let existing = configuration.buildSettings["OTHER_LDFLAGS"] as? String { flags = [existing] }
                else { flags = ["$(inherited)"] }
                if !flags.contains(where: { $0.contains("-ObjC") }) { flags.append("-ObjC") }
                configuration.buildSettings["OTHER_LDFLAGS"] = flags
            }
        }
    }
    guard let group = root.mainGroup?.children.first(where: { $0.path == "Runner" }) as? PBXGroup ?? root.mainGroup,
          let resources = runner.buildPhases.first(where: { $0.buildPhase == .resources }) as? PBXResourcesBuildPhase else {
        throw SetupError.invalid("Runner resources missing")
    }
    let reference = try group.children.compactMap { $0 as? PBXFileReference }.first(where: { $0.path == "GoogleService-Info.plist" })
        ?? group.addFile(at: Path("ios/Runner/GoogleService-Info.plist"), sourceRoot: projectPath.parent())
    _ = try resources.add(file: reference)
    try project.write(path: projectPath)
    print("PRONO4 App Store identity, Firebase resource, Google callback, Apple entitlement and linker flags verified.")
} catch {
    fputs("PRONO4 iOS setup failed: \(error)\n", stderr)
    exit(1)
}
