import Foundation
import JavaScriptCore

protocol LuegoParserDataSourceProtocol: Sendable {
    func parse(html: String, url: URL) async -> ParserResult?
    var isReady: Bool { get }
}

@MainActor
final class LuegoParserDataSource: LuegoParserDataSourceProtocol {
    private var jsContext: JSContext?
    private let sdkManager: LuegoSDKManagerProtocol

    private let polyfills = """
    var setTimeout = function(fn, delay) { fn(); };
    var clearTimeout = function() {};
    var setInterval = function(fn, delay) { fn(); };
    var clearInterval = function() {};
    var console = {
        log: function() {},
        warn: function() {},
        error: function() {}
    };
    """

    init(sdkManager: LuegoSDKManagerProtocol) {
        self.sdkManager = sdkManager
    }

    var isReady: Bool {
        sdkManager.isSDKAvailable()
    }

    func parse(html: String, url: URL) async -> ParserResult? {
        if jsContext == nil && sdkManager.isSDKAvailable() {
            initializeContext()
        }

        guard let context = jsContext else {
            #if DEBUG
            print("[LuegoParser] JSContext not initialized")
            #endif
            return nil
        }

        return executeParser(context: context, html: html, url: url)
    }

    private func initializeContext() {
        guard let bundles = sdkManager.loadBundles() else {
            #if DEBUG
            print("[LuegoParser] Failed to load bundles")
            #endif
            return
        }

        guard let context = JSContext() else {
            #if DEBUG
            print("[LuegoParser] Failed to create JSContext")
            #endif
            return
        }

        context.exceptionHandler = { _, exception in
            #if DEBUG
            let errorMessage = exception?.toString() ?? "Unknown JS error"
            print("[LuegoParser] JS Exception: \(errorMessage)")
            #endif
        }

        context.evaluateScript(polyfills)

        let bundleOrder = ["linkedom", "readability", "turndown", "parser"]
        for name in bundleOrder {
            guard let script = bundles[name] else {
                #if DEBUG
                print("[LuegoParser] Missing bundle: \(name)")
                #endif
                return
            }
            context.evaluateScript(script)
        }

        let check = context.evaluateScript("typeof LuegoParser")
        guard check?.toString() == "object" else {
            #if DEBUG
            print("[LuegoParser] LuegoParser object not found")
            #endif
            return
        }

        self.jsContext = context

        #if DEBUG
        print("[LuegoParser] Initialized successfully")
        #endif
    }

    private func executeParser(context: JSContext, html: String, url: URL) -> ParserResult? {
        guard let htmlJSON = encodeAsJSONString(html),
              let urlString = encodeAsJSONString(url.absoluteString) else {
            #if DEBUG
            print("[LuegoParser] Failed to encode parameters")
            #endif
            return nil
        }

        let rulesJSON = loadRulesJSON()
        let script = "LuegoParser.parse(\(htmlJSON), \(urlString), \(rulesJSON));"

        guard let result = context.evaluateScript(script),
              !result.isUndefined,
              !result.isNull else {
            #if DEBUG
            print("[LuegoParser] Parser returned undefined/null")
            #endif
            return nil
        }

        return parseJSResult(result)
    }

    private func encodeAsJSONString(_ string: String) -> String? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: [string], options: []),
              let jsonArray = String(data: jsonData, encoding: .utf8) else {
            return nil
        }
        return String(jsonArray.dropFirst().dropLast())
    }

    private func loadRulesJSON() -> String {
        guard let rulesData = sdkManager.loadRules(),
              let rulesString = String(data: rulesData, encoding: .utf8) else {
            return "{}"
        }
        return rulesString
    }

    private func parseJSResult(_ result: JSValue) -> ParserResult? {
        let success = result.objectForKeyedSubscript("success")?.toBool() ?? false

        if success {
            let content = result.objectForKeyedSubscript("content")?.toString()
            let metadata = extractMetadata(from: result)
            return ParserResult(success: true, content: content, metadata: metadata, error: nil)
        } else {
            let error = result.objectForKeyedSubscript("error")?.toString()
            #if DEBUG
            print("[LuegoParser] Parsing failed: \(error ?? "unknown error")")
            #endif
            return ParserResult(success: false, content: nil, metadata: nil, error: error)
        }
    }

    private func extractMetadata(from result: JSValue) -> ParserMetadata? {
        guard let metadataValue = result.objectForKeyedSubscript("metadata"),
              !metadataValue.isUndefined,
              !metadataValue.isNull else {
            return nil
        }

        let title = metadataValue.objectForKeyedSubscript("title")?.toString()
        let author = metadataValue.objectForKeyedSubscript("author")?.toString()
        let publishedDate = metadataValue.objectForKeyedSubscript("publishedDate")?.toString()
        let excerpt = metadataValue.objectForKeyedSubscript("excerpt")?.toString()
        let siteName = metadataValue.objectForKeyedSubscript("siteName")?.toString()
        let thumbnail = metadataValue.objectForKeyedSubscript("thumbnail")?.toString()

        return ParserMetadata(
            title: normalizeJSString(title),
            author: normalizeJSString(author),
            publishedDate: normalizeJSString(publishedDate),
            excerpt: normalizeJSString(excerpt),
            siteName: normalizeJSString(siteName),
            thumbnail: normalizeJSString(thumbnail)
        )
    }

    private func normalizeJSString(_ value: String?) -> String? {
        guard let value = value, value != "undefined", value != "null", !value.isEmpty else {
            return nil
        }
        return value
    }
}
