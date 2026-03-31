import Foundation
import CoreLocation

struct GPXData {
    let name: String?
    let coordinates: [CLLocationCoordinate2D]
    let isTrack: Bool  // true=recorded track, false=planned route
}

class GPXParser: NSObject, XMLParserDelegate {
    private(set) var parsed: [GPXData] = []
    private var currentCoords: [CLLocationCoordinate2D] = []
    private var currentName: String?
    private var isInTrk = false, isInRte = false, inName = false
    private var charBuf = ""

    static func parse(_ data: Data) -> [GPXData] {
        let p = GPXParser()
        let xml = XMLParser(data: data)
        xml.delegate = p
        xml.parse()
        return p.parsed
    }

    func parser(_ parser: XMLParser, didStartElement el: String, namespaceURI: String?,
                qualifiedName: String?, attributes attrs: [String: String] = [:]) {
        switch el {
        case "trk":  isInTrk = true;  currentCoords = []; currentName = nil
        case "rte":  isInRte = true;  currentCoords = []; currentName = nil
        case "trkpt", "rtept", "wpt":
            if let la = attrs["lat"].flatMap(Double.init), let lo = attrs["lon"].flatMap(Double.init) {
                currentCoords.append(.init(latitude: la, longitude: lo))
            }
        case "name": inName = true; charBuf = ""
        default: break
        }
    }
    func parser(_ parser: XMLParser, foundCharacters s: String) { if inName { charBuf += s } }
    func parser(_ parser: XMLParser, didEndElement el: String, namespaceURI: String?, qualifiedName: String?) {
        switch el {
        case "name":
            inName = false
            if currentName == nil { currentName = charBuf.trimmingCharacters(in: .whitespacesAndNewlines) }
        case "trk":
            if !currentCoords.isEmpty { parsed.append(.init(name: currentName, coordinates: currentCoords, isTrack: true)) }
            isInTrk = false
        case "rte":
            if !currentCoords.isEmpty { parsed.append(.init(name: currentName, coordinates: currentCoords, isTrack: false)) }
            isInRte = false
        default: break
        }
    }
}
