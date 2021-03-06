//
//  Track.swift
//  iOsMo
//
//  Created by Alexey Sirotkin on 16.04.17.
//  Copyright © 2017 Alexey Sirotkin. All rights reserved.
//

import Foundation
import MapKit

open class Track: Equatable {
    var u: Int
    var groupId: Int = 0
    var type: String = "0"
    var descr: String = ""
    var km: String = ""
    var color: String = "#ffffff"
    var name: String = ""
    var url: String = ""
    var size: Int = 0
    var start: Date?
    var finish: Date?
    
    init (json: Dictionary<String, AnyObject>) {
        self.u = json["u"] as? Int ??  Int(json["u"] as? String ?? "0")!
        self.size = json["size"] as? Int ??  Int(json["size"] as? String ?? "0")!
        self.name = json["name"] as? String ?? ""
        self.descr = (json["description"] as? String ?? "")
        self.color = json["color"] as? String ?? "#ffffff"
        self.url = json["url"] as? String ?? ""
        self.type = json["type"] as? String ?? ("\(json["type"] as? Int ?? 0)")
    }
    
    init (track: History) {
        self.u = track.u
        self.groupId = 0
        self.color = "#0000ff"
        self.km = "\(track.distantion / 1000.0)"
        self.name = track.name
        self.url = track.gpx_optimal
        self.start = track.start
        self.finish = track.end
    }
    
    open func getTrackData() -> XML? {
        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true);
        let filename = "\(groupId)-\(u).gpx"
        let path =  "\(paths[0])/channelsgpx/"
        let file: FileHandle? = FileHandle(forReadingAtPath: "\(path)\(filename)")
        if file != nil {
            // Read all the data
            let data = file?.readDataToEndOfFile()
            
            // Close the file
            file?.closeFile()
            
            let xml = XML(data: data!)
            return xml;
        } else {
            return nil
        }
        
    }
    
    public static func == (left: Track, right: Track) -> Bool {
        return left.u == right.u
    }
}
