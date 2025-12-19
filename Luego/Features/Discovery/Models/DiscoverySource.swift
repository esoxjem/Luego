import Foundation

enum DiscoverySource: String, CaseIterable, Sendable {
    case kagiSmallWeb = "kagiSmallWeb"
    case blogroll = "blogroll"
    case surpriseMe = "surpriseMe"

    static var concreteSources: [DiscoverySource] {
        [.kagiSmallWeb, .blogroll]
    }

    var displayName: String {
        switch self {
        case .kagiSmallWeb: return "Kagi Small Web"
        case .blogroll: return "Blogroll"
        case .surpriseMe: return "Surprise Me"
        }
    }

    var loadingText: String {
        switch self {
        case .kagiSmallWeb: return "Finding something interesting..."
        case .blogroll: return "Blogrolling..."
        case .surpriseMe: return "Rolling the dice..."
        }
    }

    var feedURL: URL? {
        switch self {
        case .kagiSmallWeb: return URL(string: "https://kagi.com/smallweb/opml")!
        case .blogroll: return URL(string: "https://blogroll.org/feed")!
        case .surpriseMe: return nil
        }
    }

    var descriptionText: String {
        switch self {
        case .kagiSmallWeb: return "Discover the \"small web\" through Kagi."
        case .blogroll: return "A humanly curated list of fine personal & independent blogs."
        case .surpriseMe: return "Randomly picks between sources for each discovery."
        }
    }

    var websiteURL: URL? {
        switch self {
        case .kagiSmallWeb: return URL(string: "https://blog.kagi.com/small-web")!
        case .blogroll: return URL(string: "https://blogroll.org/about-this-blogroll")!
        case .surpriseMe: return nil
        }
    }
}
