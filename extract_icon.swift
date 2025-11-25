#!/usr/bin/env swift

import Foundation
import AppKit

// Get command line arguments
guard CommandLine.arguments.count == 3 else {
    fputs("Usage: extract_icon.swift <source_app_path> <output_icns_path>\n", stderr)
    exit(1)
}

let sourceAppPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]

// Get the app icon
let workspace = NSWorkspace.shared
let icon = workspace.icon(forFile: sourceAppPath)

// Create temporary iconset directory
let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
let iconsetPath = tempDir.appendingPathComponent("icon.iconset")

do {
    try FileManager.default.createDirectory(at: iconsetPath, withIntermediateDirectories: true)
    
    // Generate different icon sizes
    let sizes: [(Int, String)] = [
        (16, "16x16"),
        (32, "16x16@2x"),
        (32, "32x32"),
        (64, "32x32@2x"),
        (128, "128x128"),
        (256, "128x128@2x"),
        (256, "256x256"),
        (512, "256x256@2x"),
        (512, "512x512"),
        (1024, "512x512@2x")
    ]
    
    for (size, name) in sizes {
        let resizedIcon = icon.copy() as! NSImage
        resizedIcon.size = NSSize(width: size, height: size)
        
        // Get PNG representation
        guard let tiffData = resizedIcon.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            continue
        }
        
        let pngPath = iconsetPath.appendingPathComponent("icon_\(name).png")
        try pngData.write(to: pngPath)
    }
    
    // Convert iconset to icns using iconutil
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["-c", "icns", iconsetPath.path, "-o", outputPath]
    
    try process.run()
    process.waitUntilExit()
    
    // Clean up
    try? FileManager.default.removeItem(at: tempDir)
    
    exit(process.terminationStatus)
    
} catch {
    fputs("Error: \(error.localizedDescription)\n", stderr)
    try? FileManager.default.removeItem(at: tempDir)
    exit(1)
}
