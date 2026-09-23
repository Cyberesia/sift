import Foundation

/// Local stand-in for Refgarden's style checkboxes.
/// Filters the library by words already on the asset (name, labels). No network.
public enum VisualDirection: String, CaseIterable, Identifiable, Sendable {
    case cinematic
    case typography
    case chrome
    case botanical
    case analog
    case minimal
    case surreal
    case scientific
    case screens
    case people
    case outdoors
    case places
    case food
    case animals
    case devices
    case night
    case video

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .cinematic: "Cinematic"
        case .typography: "Typography"
        case .chrome: "Chrome"
        case .botanical: "Botanical"
        case .analog: "Analog"
        case .minimal: "Minimal"
        case .surreal: "Surreal"
        case .scientific: "Scientific"
        case .screens: "Screens"
        case .people: "People"
        case .outdoors: "Outdoors"
        case .places: "Places"
        case .food: "Food"
        case .animals: "Animals"
        case .devices: "Devices"
        case .night: "Night"
        case .video: "Video"
        }
    }

    public var detail: String {
        switch self {
        case .cinematic: "Atmospheric photography, dramatic light and wide compositions"
        case .typography: "Posters, expressive lettering and editorial graphics"
        case .chrome: "Reflective metal, silver objects and polished surfaces"
        case .botanical: "Plants, organic forms and botanical studies"
        case .analog: "Film photography, grain, archival paper and tactile print"
        case .minimal: "Simple shapes, restrained color and negative space"
        case .surreal: "Unexpected scale, dreamlike forms and strange juxtapositions"
        case .scientific: "Diagrams, specimens, technical drawings and instrument imagery"
        case .screens: "Screenshots, interfaces, and documents captured from a screen"
        case .people: "Faces, portraits, adults, and children"
        case .outdoors: "Sky, landscape, grass, and outdoor scenes"
        case .places: "Rooms, streets, buildings, and architecture"
        case .food: "Meals, drinks, and table settings"
        case .animals: "Cats, dogs, birds, and other animals"
        case .devices: "Computers, phones, and other machines"
        case .night: "Night, neon, and low light"
        case .video: "Video files in the catalog"
        }
    }

    var keywords: [String] {
        switch self {
        case .cinematic: ["cinematic", "dramatic", "sunset", "portrait", "landscape", "sky"]
        case .typography: ["poster", "letter", "sign", "typography", "writing", "printed_page"]
        case .chrome: ["metal", "silver", "chrome", "car", "steel", "reflection"]
        case .botanical: ["plant", "flower", "leaf", "tree", "garden", "botanical", "fern", "grass"]
        case .analog: ["film", "grain", "vintage", "analog", "polaroid"]
        case .minimal: ["minimal", "geometric", "abstract"]
        case .surreal: ["surreal", "dream", "nebula", "collage"]
        case .scientific: ["diagram", "map", "chart", "microscope", "specimen", "instrument"]
        case .screens: ["screenshot", "screen", "interface", "computer"]
        case .people: ["people", "person", "adult", "child", "face", "portrait"]
        case .outdoors: ["outdoor", "landscape", "sky", "grass", "nature", "mountain", "beach"]
        case .places: ["building", "structure", "indoor", "room", "street", "city", "architecture"]
        case .food: ["food", "drink", "tableware", "meal", "fruit", "utensil"]
        case .animals: ["animal", "cat", "dog", "bird", "feline", "mammal", "pet"]
        case .devices: ["computer", "phone", "machine", "electronics", "consumer_electronics", "device"]
        case .night: ["night", "neon", "dark"]
        case .video: []
        }
    }
}

public enum VisualDirectionFilter {
    public static func matches(
        fileName: String,
        categories: [String],
        personName: String?,
        directions: Set<VisualDirection>,
        animals: [String] = [],
        faceCount: Int = 0,
        kind: MediaKind? = nil
    ) -> Bool {
        guard !directions.isEmpty else { return true }
        let haystack = ([fileName, personName ?? ""] + categories + animals)
            .joined(separator: " ")
        return directions.contains { direction in
            if direction == .video { return kind == .video }
            if direction == .people, faceCount > 0 { return true }
            return direction.keywords.contains { SearchTermMatcher.containsTerm($0, in: haystack) }
        }
    }
}
