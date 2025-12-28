//
// BundleResourceHelper.swift
// Demark
//
// Created by Peter Steinberger on 12/28/2025.
//

import Foundation

/// Helper for locating JavaScript resources in various bundle configurations
enum BundleResourceHelper {
    /// Searches for a JavaScript resource across multiple bundle locations
    /// - Parameters:
    ///   - resourceName: The base name of the resource (without extension)
    ///   - extension: The file extension (default: "js")
    ///   - classForBundle: Optional class to get its bundle (useful for framework bundles)
    /// - Returns: The full path to the resource if found, nil otherwise
    static func findJavaScriptResource(
        named resourceName: String,
        extension ext: String = "js",
        classForBundle: AnyClass? = nil
    ) -> String? {
        // Build list of bundles to search
        var bundles: [Bundle] = [
            Bundle.module,
            Bundle.main,
        ]

        // Add class-specific bundle if provided
        if let classForBundle {
            bundles.append(Bundle(for: classForBundle))
        }

        // Search for resource in each bundle
        for bundle in bundles {
            // Try direct resource lookup
            if let path = bundle.path(forResource: resourceName, ofType: ext) {
                return path
            }

            // Try in Resources subdirectory (common in SPM packages)
            if let path = bundle.path(forResource: "Resources/\(resourceName)", ofType: ext) {
                return path
            }
        }

        return nil
    }
}
