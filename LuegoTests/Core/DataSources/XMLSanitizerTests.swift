import Testing
import Foundation
@testable import Luego

@Suite("XMLSanitizer Tests")
struct XMLSanitizerTests {
    @Test("sanitizingXMLAmpersands escapes bare ampersands")
    func sanitizesBareAmpersands() {
        let input = "Tom & Jerry".data(using: .utf8)!

        let output = input.sanitizingXMLAmpersands()
        let result = String(data: output, encoding: .utf8)!

        #expect(result == "Tom &amp; Jerry")
    }

    @Test("sanitizingXMLAmpersands preserves &amp;")
    func preservesAmpEntity() {
        let input = "Fish &amp; Chips".data(using: .utf8)!

        let output = input.sanitizingXMLAmpersands()
        let result = String(data: output, encoding: .utf8)!

        #expect(result == "Fish &amp; Chips")
    }

    @Test("sanitizingXMLAmpersands preserves &lt;")
    func preservesLtEntity() {
        let input = "5 &lt; 10".data(using: .utf8)!

        let output = input.sanitizingXMLAmpersands()
        let result = String(data: output, encoding: .utf8)!

        #expect(result == "5 &lt; 10")
    }

    @Test("sanitizingXMLAmpersands preserves &gt;")
    func preservesGtEntity() {
        let input = "10 &gt; 5".data(using: .utf8)!

        let output = input.sanitizingXMLAmpersands()
        let result = String(data: output, encoding: .utf8)!

        #expect(result == "10 &gt; 5")
    }

    @Test("sanitizingXMLAmpersands preserves &quot;")
    func preservesQuotEntity() {
        let input = "He said &quot;hello&quot;".data(using: .utf8)!

        let output = input.sanitizingXMLAmpersands()
        let result = String(data: output, encoding: .utf8)!

        #expect(result == "He said &quot;hello&quot;")
    }

    @Test("sanitizingXMLAmpersands preserves &apos;")
    func preservesAposEntity() {
        let input = "It&apos;s fine".data(using: .utf8)!

        let output = input.sanitizingXMLAmpersands()
        let result = String(data: output, encoding: .utf8)!

        #expect(result == "It&apos;s fine")
    }

    @Test("sanitizingXMLAmpersands preserves numeric entities")
    func preservesNumericEntities() {
        let input = "&#123; test".data(using: .utf8)!

        let output = input.sanitizingXMLAmpersands()
        let result = String(data: output, encoding: .utf8)!

        #expect(result == "&#123; test")
    }

    @Test("sanitizingXMLAmpersands preserves hex entities")
    func preservesHexEntities() {
        let input = "&#x1F600; emoji".data(using: .utf8)!

        let output = input.sanitizingXMLAmpersands()
        let result = String(data: output, encoding: .utf8)!

        #expect(result == "&#x1F600; emoji")
    }

    @Test("sanitizingXMLAmpersands handles multiple bare ampersands")
    func handlesMultipleBareAmpersands() {
        let input = "A & B & C".data(using: .utf8)!

        let output = input.sanitizingXMLAmpersands()
        let result = String(data: output, encoding: .utf8)!

        #expect(result == "A &amp; B &amp; C")
    }

    @Test("sanitizingXMLAmpersands handles mixed content")
    func handlesMixedContent() {
        let input = "Tom & Jerry said &quot;hello&quot; & goodbye".data(using: .utf8)!

        let output = input.sanitizingXMLAmpersands()
        let result = String(data: output, encoding: .utf8)!

        #expect(result == "Tom &amp; Jerry said &quot;hello&quot; &amp; goodbye")
    }

    @Test("sanitizingXMLAmpersands returns original for empty data")
    func returnsOriginalForEmpty() {
        let input = Data()

        let output = input.sanitizingXMLAmpersands()

        #expect(output == input)
    }

    @Test("sanitizingXMLAmpersands handles no ampersands")
    func handlesNoAmpersands() {
        let input = "Hello World".data(using: .utf8)!

        let output = input.sanitizingXMLAmpersands()
        let result = String(data: output, encoding: .utf8)!

        #expect(result == "Hello World")
    }
}
