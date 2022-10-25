//
//  VideoDocument.swift
//  TimeWarpEditor
//
//  Created by Joseph Pagliaro on 3/17/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import Foundation
import SwiftUI
import AVFoundation

/*
 VideoDocument is used by fileExporter to save time warped video to a location user can choose.
 */
class VideoDocument : FileDocument {

    var filename:String?
    var url:URL?
    
    static var readableContentTypes: [UTType] { [UTType.movie, UTType.quickTimeMovie, UTType.mpeg4Movie] }
    
    init(url:URL, filename:String? = nil) {
        self.url = url
        self.filename = url.deletingPathExtension().lastPathComponent
        if let filename = filename {
            self.filename = filename
        }
    }
    
    required init(configuration: ReadConfiguration) throws {
        
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let url = self.url
        else {
            throw CocoaError(.fileWriteUnknown)
        }
        let fileWrapper = try FileWrapper(url: url)
        return fileWrapper
    }
}
