import Foundation

@MainActor
enum HTMLFixtures {
    static let validOpenGraphHTML = """
    <!DOCTYPE html>
    <html>
    <head>
        <meta property="og:title" content="OpenGraph Title">
        <meta property="og:image" content="https://example.com/og-image.jpg">
        <meta property="og:description" content="OpenGraph description text">
        <meta property="article:published_time" content="2024-01-15T10:30:00Z">
        <title>HTML Title</title>
    </head>
    <body>
        <article>
            <p>This is the main article content that should be extracted. It contains enough text to pass the minimum content length validation of 200 characters. The article discusses various topics and provides valuable information to readers.</p>
        </article>
    </body>
    </html>
    """

    static let standardMetaTagsHTML = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Standard HTML Title</title>
        <meta name="description" content="Standard meta description">
    </head>
    <body>
        <main>
            <p>This is the main content area. It contains sufficient text to meet the minimum content requirements. The page provides useful information about the topic being discussed and should be extracted properly by the content parser.</p>
        </main>
    </body>
    </html>
    """

    static let minimalHTML = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Minimal Page</title>
    </head>
    <body>
        <p>Short content</p>
    </body>
    </html>
    """

    static let htmlWithImages = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Page With Images</title>
    </head>
    <body>
        <article>
            <img src="/images/small-icon.png" width="50" height="50">
            <img src="https://example.com/large-image.jpg" width="800" height="600">
            <p>Article content with images. This paragraph contains enough text to satisfy the minimum content length requirement. It discusses various topics related to the images shown above.</p>
        </article>
    </body>
    </html>
    """

    static let htmlWithRelativeURLs = """
    <!DOCTYPE html>
    <html>
    <head>
        <meta property="og:image" content="/images/og-image.jpg">
        <title>Page With Relative URLs</title>
    </head>
    <body>
        <article>
            <img src="/images/article-image.jpg">
            <a href="/other-page">Link to other page</a>
            <p>Content with relative URLs that need to be resolved against the base URL. This content should be long enough to pass validation and be properly extracted by the parser.</p>
        </article>
    </body>
    </html>
    """

    static let htmlWithMultipleDateFormats = """
    <!DOCTYPE html>
    <html>
    <head>
        <meta property="article:published_time" content="2024-06-15T14:30:00+00:00">
        <title>Date Formats Test</title>
    </head>
    <body>
        <article>
            <time datetime="2024-06-15">June 15, 2024</time>
            <p>Article content for testing date extraction. This text provides context about when the article was published and should be long enough to meet the content length requirements.</p>
        </article>
    </body>
    </html>
    """

    static let htmlWithNavigationAndAds = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Page With Navigation</title>
    </head>
    <body>
        <nav>
            <a href="/">Home</a>
            <a href="/about">About</a>
        </nav>
        <header>Site Header</header>
        <div class="advertisement">Buy our product!</div>
        <article>
            <p>This is the actual article content that should be extracted after removing navigation, header, and advertisement elements. The content parser should filter out unwanted elements.</p>
        </article>
        <footer>Copyright 2024</footer>
    </body>
    </html>
    """

    static let malformedHTML = """
    <html>
    <head>
        <title>Malformed Page
    </head>
    <body>
        <p>Unclosed paragraph
        <div>Nested incorrectly</p></div>
    </body>
    """

    static let emptyHTML = """
    <!DOCTYPE html>
    <html>
    <head></head>
    <body></body>
    </html>
    """
}
