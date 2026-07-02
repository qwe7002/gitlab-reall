import SwiftUI
import Foundation

/// An image (optionally wrapped in a link) parsed out of a Markdown line.
struct MarkdownImage: Hashable {
    let url: URL
    let alt: String
    let link: URL?
}

/// A block Markdown node. Only the subset commonly seen in READMEs and
/// issue / merge request bodies is modelled.
enum MarkdownBlock: Hashable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case unorderedList([String])
    case orderedList([String])
    case codeBlock(String)
    case quote(String)
    case images([MarkdownImage])
    case table(header: [String], rows: [[String]])
    case rule
}

/// A lightweight block-level Markdown renderer.
///
/// SwiftUI's built-in `AttributedString(markdown:)` only styles *inline*
/// syntax, so headings, lists, tables, code fences and quotes collapse into one
/// run-on paragraph. This splits the source into blocks and renders each with
/// the appropriate layout, still using `AttributedString` for the inline
/// styling (bold / italic / links / code spans) inside every block.
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
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, level <= 2 ? 4 : 0)

        case .paragraph(let text):
            inlineText(text)
                .tint(.accentColor)
                .fixedSize(horizontal: false, vertical: true)

        case .unorderedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").foregroundStyle(.secondary)
                        inlineText(item).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .orderedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(index + 1).").foregroundStyle(.secondary).monospacedDigit()
                        inlineText(item).fixedSize(horizontal: false, vertical: true)
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
                inlineText(text)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .images(let images):
            imagesView(images)

        case .table(let header, let rows):
            tableView(header: header, rows: rows)

        case .rule:
            Divider()
        }
    }

    @ViewBuilder
    private func imagesView(_ images: [MarkdownImage]) -> some View {
        if images.count == 1, let only = images.first {
            imageView(only, maxHeight: nil)
        } else {
            FlowLayout(spacing: 8) {
                ForEach(images, id: \.self) { imageView($0, maxHeight: 30) }
            }
        }
    }

    @ViewBuilder
    private func imageView(_ image: MarkdownImage, maxHeight: CGFloat?) -> some View {
        let picture = AsyncImage(url: image.url) { phase in
            switch phase {
            case .success(let img):
                img.resizable().scaledToFit()
            case .failure:
                if !image.alt.isEmpty {
                    Text(image.alt).font(.caption).foregroundStyle(.secondary)
                } else {
                    Color.clear.frame(height: 0)
                }
            default:
                ProgressView()
            }
        }
        if let link = image.link {
            Link(destination: link) { sized(picture, maxHeight: maxHeight) }
        } else {
            sized(picture, maxHeight: maxHeight)
        }
    }

    @ViewBuilder
    private func sized(_ view: some View, maxHeight: CGFloat?) -> some View {
        if let maxHeight {
            view.frame(maxHeight: maxHeight)
        } else {
            view.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func tableView(header: [String], rows: [[String]]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    ForEach(Array(header.enumerated()), id: \.offset) { _, cell in
                        inlineText(cell).fontWeight(.semibold)
                    }
                }
                Divider().gridCellColumns(max(header.count, 1))
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            inlineText(cell)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func inlineText(_ raw: String) -> Text {
        if let attributed = try? AttributedString(
            markdown: raw,
            options: .init(
                allowsExtendedAttributes: true,
                interpretedSyntax: .inlineOnlyPreservingWhitespace,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
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

/// Splits Markdown source into `MarkdownBlock`s. Covers ATX headings,
/// paragraphs (preserving author line breaks), ordered / unordered lists,
/// fenced code blocks, block quotes, tables, standalone images / badges and
/// horizontal rules.
enum MarkdownParser {
    static func parse(_ source: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = preprocess(source).components(separatedBy: "\n")
        var paragraph: [String] = []
        var i = 0

        func flushParagraph() {
            let text = paragraph.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            paragraph.removeAll()
            guard !text.isEmpty else { return }
            blocks.append(.paragraph(text))
        }

        while i < lines.count {
            let raw = lines[i]
            let line = raw.trimmingCharacters(in: .whitespaces)

            // Fenced code block.
            if line.hasPrefix("```") || line.hasPrefix("~~~") {
                flushParagraph()
                let fence = String(line.prefix(3))
                var code: [String] = []
                i += 1
                while i < lines.count,
                      !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(fence) {
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

            // Horizontal rule (before lists so "---" isn't a bullet).
            if isRule(line) {
                flushParagraph()
                blocks.append(.rule)
                i += 1
                continue
            }

            // Table: a header row followed by a |---|---| separator.
            if line.contains("|"), i + 1 < lines.count, isTableSeparator(lines[i + 1]) {
                flushParagraph()
                let header = splitRow(line)
                i += 2
                var rows: [[String]] = []
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    guard t.contains("|"), !t.isEmpty else { break }
                    rows.append(normalize(splitRow(t), to: header.count))
                    i += 1
                }
                blocks.append(.table(header: header, rows: rows))
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
                blocks.append(.quote(quote.joined(separator: "\n")))
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

            // A line that is only image(s) / badges.
            if let images = imageLine(line) {
                flushParagraph()
                blocks.append(.images(images))
                i += 1
                continue
            }

            // Otherwise accumulate into the running paragraph.
            paragraph.append(line)
            i += 1
        }
        flushParagraph()
        return blocks
    }

    // MARK: - Preprocessing

    private static func preprocess(_ source: String) -> String {
        var out = source.replacingOccurrences(of: "\r\n", with: "\n")
        out = replacing(out, pattern: "<!--.*?-->", options: [.dotMatchesLineSeparators], with: "")
        out = replacing(out, pattern: "<br\\s*/?>", options: [.caseInsensitive], with: "\n")
        return out
    }

    private static func replacing(_ string: String,
                                  pattern: String,
                                  options: NSRegularExpression.Options,
                                  with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return string }
        let range = NSRange(string.startIndex..., in: string)
        return regex.stringByReplacingMatches(in: string, range: range, withTemplate: template)
    }

    // MARK: - Line classifiers

    private static func headingBlock(_ line: String) -> MarkdownBlock? {
        guard line.hasPrefix("#") else { return nil }
        let hashes = line.prefix { $0 == "#" }
        let level = hashes.count
        guard (1...6).contains(level) else { return nil }
        let rest = line.dropFirst(level)
        guard rest.isEmpty || rest.hasPrefix(" ") else { return nil }
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

    // MARK: - Tables

    private static func isTableSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("-"), trimmed.contains("|") else { return false }
        let cells = splitRow(trimmed)
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            let c = cell.trimmingCharacters(in: .whitespaces)
            return !c.isEmpty && c.allSatisfy { $0 == "-" || $0 == ":" }
        }
    }

    private static func splitRow(_ line: String) -> [String] {
        var s = line.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("|") { s.removeFirst() }
        if s.hasSuffix("|") { s.removeLast() }
        return s.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func normalize(_ row: [String], to count: Int) -> [String] {
        if row.count == count { return row }
        if row.count > count { return Array(row.prefix(count)) }
        return row + Array(repeating: "", count: count - row.count)
    }

    // MARK: - Images

    private static let imageRegex = try? NSRegularExpression(
        pattern: "(?:\\[)?!\\[([^\\]]*)\\]\\(([^)\\s]+)(?:\\s+\"[^\"]*\")?\\)(?:\\]\\(([^)\\s]+)(?:\\s+\"[^\"]*\")?\\))?",
        options: []
    )

    /// Returns the images on a line if the line contains nothing but images
    /// (and image links) and whitespace — e.g. a logo or a row of badges.
    private static func imageLine(_ line: String) -> [MarkdownImage]? {
        guard line.contains("!["), let regex = imageRegex else { return nil }
        let ns = line as NSString
        let matches = regex.matches(in: line, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return nil }

        // The line must be only images + whitespace.
        var remainder = line
        for match in matches.reversed() {
            if let range = Range(match.range, in: remainder) {
                remainder.replaceSubrange(range, with: "")
            }
        }
        guard remainder.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }

        var images: [MarkdownImage] = []
        for match in matches {
            let alt = group(match, 1, ns)
            let urlString = group(match, 2, ns)
            guard !urlString.isEmpty, let url = URL(string: urlString) else { continue }
            let linkString = group(match, 3, ns)
            let link = linkString.isEmpty ? nil : URL(string: linkString)
            images.append(MarkdownImage(url: url, alt: alt, link: link))
        }
        return images.isEmpty ? nil : images
    }

    private static func group(_ match: NSTextCheckingResult, _ index: Int, _ source: NSString) -> String {
        let range = match.range(at: index)
        guard range.location != NSNotFound else { return "" }
        return source.substring(with: range)
    }
}
