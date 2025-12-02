// This file should be loaded AFTER linkedom-polyfill.js and turndown.js
// It creates the convertHTMLToMarkdown convenience function

(function() {
    function convertHTMLToMarkdown(html, options) {
        options = options || {};
        try {
            if (typeof parseHTML !== 'function') {
                return { success: false, error: 'linkedom not loaded. Load linkedom-polyfill.js first.' };
            }
            
            if (typeof TurndownService !== 'function') {
                return { success: false, error: 'Turndown not loaded. Load turndown.js first.' };
            }
            
            // Wrap in full HTML structure to ensure proper parsing
            var wrappedHtml = '<!DOCTYPE html><html><body>' + html + '</body></html>';
            var doc = parseHTML(wrappedHtml);
            
            // Configure Turndown with defaults
            var config = {
                headingStyle: options.headingStyle || 'atx',
                codeBlockStyle: options.codeBlockStyle || 'fenced',
                bulletListMarker: options.bulletListMarker || '-',
                emDelimiter: options.emDelimiter || '*',
                strongDelimiter: options.strongDelimiter || '**'
            };
            
            var turndownService = new TurndownService(config);
            
            // Strip script, style, noscript, and svg tags
            turndownService.addRule('removeScripts', {
                filter: ['script', 'style', 'noscript', 'svg'],
                replacement: function() { return ''; }
            });
            
            // Convert using innerHTML
            var markdown = turndownService.turndown(doc.document.body.innerHTML);
            return { success: true, markdown: markdown };
        } catch (error) {
            return { success: false, error: error.message };
        }
    }
    
    // Expose globally
    globalThis.convertHTMLToMarkdown = convertHTMLToMarkdown;
})();
