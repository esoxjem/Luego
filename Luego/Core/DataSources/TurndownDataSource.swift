import Foundation
import JavaScriptCore

final class TurndownDataSource: @unchecked Sendable {
    private var jsContext: JSContext?

    init() {
        initializeJavaScriptContext()
    }

    private func initializeJavaScriptContext() {
        guard let context = JSContext() else { return }

        context.exceptionHandler = { _, exception in
            print("Turndown JS Exception: \(exception?.toString() ?? "unknown")")
        }

        let polyfills = """
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

        context.evaluateScript(polyfills)

        let scripts: [(name: String, ext: String)] = [
            ("linkedom-polyfill.min", "js"),
            ("turndown", "js"),
            ("turndown-wrapper", "js")
        ]

        var loadedAll = true
        for script in scripts {
            guard let path = Bundle.main.path(forResource: script.name, ofType: script.ext),
                  let js = try? String(contentsOfFile: path, encoding: .utf8) else {
                print("Turndown: Failed to load \(script.name).\(script.ext)")
                loadedAll = false
                break
            }
            context.evaluateScript(js)
        }

        guard loadedAll else {
            print("Turndown: Failed to load all required scripts")
            return
        }

        let checkFunction = context.evaluateScript("typeof convertHTMLToMarkdown")
        print("Turndown: convertHTMLToMarkdown type = \(checkFunction?.toString() ?? "undefined")")

        self.jsContext = context
    }

    func convert(_ html: String) -> String? {
        guard let context = jsContext else {
            print("Turndown: JSContext not initialized")
            return nil
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: [html], options: []),
              let jsonArray = String(data: jsonData, encoding: .utf8) else {
            print("Turndown: Failed to JSON encode HTML")
            return nil
        }

        let jsonString = String(jsonArray.dropFirst().dropLast())

        let script = "convertHTMLToMarkdown(\(jsonString));"

        guard let result = context.evaluateScript(script),
              !result.isUndefined,
              !result.isNull else {
            print("Turndown: Conversion returned undefined/null")
            return nil
        }

        guard let successValue = result.objectForKeyedSubscript("success"),
              successValue.toBool() == true,
              let markdownValue = result.objectForKeyedSubscript("markdown") else {
            if let errorValue = result.objectForKeyedSubscript("error") {
                print("Turndown: Conversion failed - \(errorValue.toString() ?? "unknown error")")
            }
            return nil
        }

        return markdownValue.toString()
    }
}
