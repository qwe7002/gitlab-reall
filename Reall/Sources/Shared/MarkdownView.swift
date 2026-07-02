import SwiftUI

/// A block Markdown node. Only the subset commonly seen in READMEs and
/// issue / merge request bodies is modelled.
enum MarkdownBlock: Hashable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case unorderedList([String])
    case orderedList([String])
    case codeBlock(String)
    case quote(String)
    case image(url: URL, alt: String)
    case rule
}

/// A lightweight block-level Markdown renderer.
///
/// SwiftUI's built-in `AttributedString(markdown:)` only styles *inline*
/// syntax, so headings, lists, code fences and quotes in a README collapse
/// into one run-on paragraph. This splits the source into blocks and renders
/// each with the appropriate layout, still using `AttributedString` for the
/// inline styling (bold / italic / links / code spans) inside every block.
struct MarkdownView: View {
    let blocks: [MarkdownBlock]

    init(_ markdown: String) {
        self.blocks = MarkdownParser.parse(markdown)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func view(for block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            inlineText(text)
                .font(headingFont(level))
                .fontWeight(.bold)
                .padding(.top, level <= 2 ? 4 : 0)

        case .paragraph(let text):
            inlineText(text)
                .fixedSize(horizontal: false, vertical: true)

        case .unorderedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").foregroundStyle(.secondary)
                        inlineText(item)
                    }
                }
            }

        case .orderedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(index + 1).").foregroundStyle(.secondary).monospacedDigit()
                        inlineText(item)
                    }
                }
            }

        case .codeBlock(let code):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))

        case .quote(let text):
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 3)
                inlineText(text).foregroundStyle(.secondary)
            }

        case .image(let url, let alt):
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                case .failure:
                    Text(alt.isEmpty ? "Image" : alt)
                        .font(.caption).foregroundStyle(.secondary)
                default:
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .rule:
            Divider()
        }
    }

    private func inlineText(_ raw: String) -> Text {
        if let attributed = try? AttributedString(
            markdown: raw,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attributed)
        }
        return Text(raw)
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .title
        case 2: return .title2
        case 3: return .title3
        case 4: return .headline
        default: return .subheadline
        }
    }
}

/// Splits Markdown source into `MarkdownBlock`s. Deliberately small: it covers
/// ATX headings, paragraphs, ordered / unordered lists, fenced code blocks,
/// block quotes, standalone images and horizontal rules. Tables and other
/// extended syntax fall through as paragraphs.
enum MarkdownParser {
    static func parse(_ source: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
        var paragraph: [String] = []
        var i = 0

        func flushParagraph() {
            let text = paragraph.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            paragraph.removeAll()
            guard !text.isEmpty else { return }
            if let image = standaloneImage(text) {
                blocks.append(image)
            } else {
                blocks.append(.paragraph(text))
            }
        }

        while i < lines.count {
            let raw = lines[i]
            let line = raw.trimmingCharacters(in: .whitespaces)

            // Fenced code block.
            if line.hasPrefix("```") {
                flushParagraph()
                var code: [String] = []
                i += 1
                while i < lines.count,
                      !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(lines[i])
                    i += 1
                }
                i += 1 // consume the closing fence (if present)
                blocks.append(.codeBlock(code.joined(separator: "\n")))
                continue
            }

            // Blank line ends the current paragraph.
            if line.isEmpty {
                flushParagraph()
                i += 1
                continue
            }

            // ATX heading.
            if let heading = headingBlock(line) {
                flushParagraph()
                blocks.append(heading)
                i += 1
                continue
            }

            // Horizontal rule (checked before lists so "---" isn't a bullet).
            if isRule(line) {
                flushParagraph()
                blocks.append(.rule)
                i += 1
                continue
            }

            // Block quote — consume consecutive `>` lines.
            if line.hasPrefix(">") {
                flushParagraph()
                var quote: [String] = []
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    guard t.hasPrefix(">") else { break }
                    quote.append(String(t.dropFirst()).trimmingCharacters(in: .whitespaces))
                    i += 1
                }
                blocks.append(.quote(quote.joined(separator: " ")))
                continue
            }

            // Unordered list.
            if isUnorderedItem(line) {
                flushParagraph()
                var items: [String] = []
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    guard isUnorderedItem(t) else { break }
                    items.append(listContent(t, markerLength: 2))
                    i += 1
                }
                blocks.append(.unorderedList(items))
                continue
            }

            // Ordered list.
            if isOrderedItem(line) {
                flushParagraph()
                var items: [String] = []
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    guard isOrderedItem(t) else { break }
                    items.append(orderedContent(t))
                    i += 1
                }
                blocks.append(.orderedList(items))
                continue
            }

            // Otherwise accumulate into the running paragraph.
            paragraph.append(line)
            i += 1
        }
        flushParagraph()
        return blocks
    }

    // MARK: - Line classifiers

    private static func headingBlock(_ line: String) -> MarkdownBlock? {
        guard line.hasPrefix("#") else { return nil }
        let hashes = line.prefix { $0 == "#" }
        let level = hashes.count
        guard (1...6).contains(level) else { return nil }
        let rest = line.dropFirst(level)
        guard rest.isEmpty || rest.hasPrefix(" ") else { return nil }
        // Strip any trailing closing hashes ("## Title ##").
        var text = rest.trimmingCharacters(in: .whitespaces)
        while text.hasSuffix("#") { text.removeLast() }
        return .heading(level: level, text: text.trimmingCharacters(in: .whitespaces))
    }

    private static func isRule(_ line: String) -> Bool {
        let stripped = line.replacingOccurrences(of: " ", with: "")
        guard stripped.count >= 3 else { return false }
        return stripped.allSatisfy { $0 == "-" }
            || stripped.allSatisfy { $0 == "*" }
            || stripped.allSatisfy { $0 == "_" }
    }

    private static func isUnorderedItem(_ line: String) -> Bool {
        line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ")
    }

    private static func isOrderedItem(_ line: String) -> Bool {
        let digits = line.prefix { $0.isNumber }
        guard !digits.isEmpty else { return false }
        let after = line.dropFirst(digits.count)
        guard let delimiter = after.first, delimiter == "." || delimiter == ")" else { return false }
        let rest = after.dropFirst()
        return rest.isEmpty || rest.hasPrefix(" ")
    }

    private static func listContent(_ line: String, markerLength: Int) -> String {
        var content = String(line.dropFirst(markerLength)).trimmingCharacters(in: .whitespaces)
        // Render GitHub task-list markers as symbols.
        if content.hasPrefix("[ ]") {
            content = "☐ " + content.dropFirst(3).trimmingCharacters(in: .whitespaces)
        } else if content.lowercased().hasPrefix("[x]") {
            content = "☑ " + content.dropFirst(3).trimmingCharacters(in: .whitespaces)
        }
        return content
    }

    private static func orderedContent(_ line: String) -> String {
        let digits = line.prefix { $0.isNumber }
        let after = line.dropFirst(digits.count).dropFirst() // drop the delimiter
        return after.trimmingCharacters(in: .whitespaces)
    }

    /// Matches a line that is nothing but a single image: `![alt](url)`.
    private static func standaloneImage(_ text: String) -> MarkdownBlock? {
        guard text.hasPrefix("!["),
              text.hasSuffix(")"),
              let closeBracket = text.firstIndex(of: "]") else { return nil }
        let afterBracket = text.index(after: closeBracket)
        guard afterBracket < text.endIndex, text[afterBracket] == "(" else { return nil }

        let altStart = text.index(text.startIndex, offsetBy: 2)
        let alt = String(text[altStart..<closeBracket])

        let urlStart = text.index(after: afterBracket)
        let urlPart = String(text[urlStart..<text.index(before: text.endIndex)])
        // Drop an optional title: ![alt](url "title").
        let urlString = urlPart.split(separator: " ").first.map(String.init) ?? urlPart
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespaces)) else { return nil }
        return .image(url: url, alt: alt)
    }
}
