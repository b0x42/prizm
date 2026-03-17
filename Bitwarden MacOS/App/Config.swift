//
//  Config.swift
//  Bitwarden MacOS
//
//  Created by Benjamin Burzan on 16.03.26.
//

import Foundation

enum Config {
    static let clientName = "desktop"
    static let deviceType = 7
}

/// Gates verbose debug logging throughout the Data layer.
///
/// Enable by adding `--debug-mode` to the Xcode scheme's Run → Arguments section,
/// or by passing it on the command line when launching from Terminal.
///
/// **Never enable in production builds** — debug output may contain sensitive field
/// names, cipher counts, and HTTP response structure (though never key material or tokens).
enum DebugConfig {
    // nonisolated(unsafe): safe because this is a let constant initialised once at process
    // startup from CommandLine.arguments and never mutated. Avoids the Swift 6
    // @MainActor isolation error when accessed from non-main actors.
    nonisolated(unsafe) static let isEnabled: Bool = CommandLine.arguments.contains("--debug-mode")
}
