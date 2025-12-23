import Testing
import Foundation
@testable import Luego

@Suite("DiscoverySource Tests")
struct DiscoverySourceTests {
    @Test("concreteSources excludes surpriseMe")
    func concreteSourcesExcludesSurpriseMe() {
        let sources = DiscoverySource.concreteSources

        #expect(!sources.contains(.surpriseMe))
        #expect(sources.contains(.kagiSmallWeb))
        #expect(sources.contains(.blogroll))
    }

    @Test("concreteSources has correct count")
    func concreteSourcesCount() {
        let sources = DiscoverySource.concreteSources

        #expect(sources.count == 2)
    }

    @Test("displayName returns correct string for kagiSmallWeb")
    func displayNameKagi() {
        #expect(DiscoverySource.kagiSmallWeb.displayName == "Kagi Small Web")
    }

    @Test("displayName returns correct string for blogroll")
    func displayNameBlogroll() {
        #expect(DiscoverySource.blogroll.displayName == "Blogroll")
    }

    @Test("displayName returns correct string for surpriseMe")
    func displayNameSurpriseMe() {
        #expect(DiscoverySource.surpriseMe.displayName == "Surprise Me")
    }

    @Test("loadingText returns correct string for kagiSmallWeb")
    func loadingTextKagi() {
        #expect(DiscoverySource.kagiSmallWeb.loadingText == "Finding something interesting...")
    }

    @Test("loadingText returns correct string for blogroll")
    func loadingTextBlogroll() {
        #expect(DiscoverySource.blogroll.loadingText == "Blogrolling...")
    }

    @Test("loadingText returns correct string for surpriseMe")
    func loadingTextSurpriseMe() {
        #expect(DiscoverySource.surpriseMe.loadingText == "Rolling the dice...")
    }

    @Test("feedURL returns URL for kagiSmallWeb")
    func feedURLKagi() {
        #expect(DiscoverySource.kagiSmallWeb.feedURL != nil)
        #expect(DiscoverySource.kagiSmallWeb.feedURL?.absoluteString == "https://kagi.com/smallweb/opml")
    }

    @Test("feedURL returns URL for blogroll")
    func feedURLBlogroll() {
        #expect(DiscoverySource.blogroll.feedURL != nil)
        #expect(DiscoverySource.blogroll.feedURL?.absoluteString == "https://blogroll.org/feed")
    }

    @Test("feedURL returns nil for surpriseMe")
    func feedURLSurpriseMe() {
        #expect(DiscoverySource.surpriseMe.feedURL == nil)
    }

    @Test("websiteURL returns URL for kagiSmallWeb")
    func websiteURLKagi() {
        #expect(DiscoverySource.kagiSmallWeb.websiteURL != nil)
    }

    @Test("websiteURL returns URL for blogroll")
    func websiteURLBlogroll() {
        #expect(DiscoverySource.blogroll.websiteURL != nil)
    }

    @Test("websiteURL returns nil for surpriseMe")
    func websiteURLSurpriseMe() {
        #expect(DiscoverySource.surpriseMe.websiteURL == nil)
    }

    @Test("descriptionText is non-empty for all cases")
    func descriptionTextNonEmpty() {
        for source in DiscoverySource.allCases {
            #expect(!source.descriptionText.isEmpty)
        }
    }

    @Test("rawValue roundtrips correctly")
    func rawValueRoundtrip() {
        for source in DiscoverySource.allCases {
            let recreated = DiscoverySource(rawValue: source.rawValue)
            #expect(recreated == source)
        }
    }
}
