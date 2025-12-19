import Foundation

enum DiscoverySource: String, CaseIterable, Sendable {
    case kagiSmallWeb = "kagiSmallWeb"
    case blogroll = "blogroll"

    var displayName: String {
        switch self {
        case .kagiSmallWeb: return "Kagi Small Web"
        case .blogroll: return "Blogroll"
        }
    }

    var loadingText: String {
        switch self {
        case .kagiSmallWeb: return "Finding something interesting..."
        case .blogroll: return "Blogrolling..."
        }
    }

    var feedURL: URL {
        switch self {
        case .kagiSmallWeb: return URL(string: "https://kagi.com/smallweb/opml")!
        case .blogroll: return URL(string: "https://blogroll.org/feed")!
        }
    }

    var descriptionText: String {
        switch self {
        case .kagiSmallWeb: return "Discover the \"small web\" through Kagi."
        case .blogroll: return "A humanly curated list of fine personal & independent blogs."
        }
    }

    var websiteURL: URL {
        switch self {
        case .kagiSmallWeb: return URL(string: "https://blog.kagi.com/small-web")!
        case .blogroll: return URL(string: "https://blogroll.org/about-this-blogroll")!
        }
    }
}
