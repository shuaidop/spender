import Foundation
import PDFKit

enum PDFTextExtractor {
    static func extractText(from url: URL) throws -> String {
        guard let document = PDFDocument(url: url) else {
            throw ParserError.extractionFailed("Could not open PDF at \(url.path)")
        }

        var fullText = ""
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            if let pageText = page.string {
                fullText += pageText + "\n---PAGE_BREAK---\n"
            }
        }

        guard !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ParserError.extractionFailed("PDF contains no extractable text.")
        }

        return fullText
    }

    static func extractTextPerPage(from url: URL) throws -> [String] {
        guard let document = PDFDocument(url: url) else {
            throw ParserError.extractionFailed("Could not open PDF at \(url.path)")
        }

        var pages: [String] = []
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i),
                  let text = page.string else {
                pages.append("")
                continue
            }
            pages.append(text)
        }
        return pages
    }
}
