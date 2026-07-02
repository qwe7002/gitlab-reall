import SwiftUI

/// Circular avatar that loads remotely with a colored initials fallback.
struct AvatarView: View {
    let url: URL?
    let fallbackText: String
    var size: CGFloat = 36

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color(.separator).opacity(0.4), lineWidth: 0.5))
    }

    private var placeholder: some View {
        ZStack {
            Theme.labelColor(for: fallbackText).opacity(0.85)
            Text(initials)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private var initials: String {
        let parts = fallbackText.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }
}

/// Small colored capsule used for issue/MR state and CI status.
struct StatusBadge: View {
    let text: String
    let systemImage: String?
    let color: Color

    init(_ text: String, systemImage: String? = nil, color: Color) {
        self.text = text
        self.systemImage = systemImage
        self.color = color
    }

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage) }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .foregroundStyle(color)
        .background(color.opacity(0.15), in: Capsule())
    }
}

/// GitLab-style label chip.
struct LabelChip: View {
    let name: String

    var body: some View {
        Text(name)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .foregroundStyle(Theme.labelColor(for: name))
            .background(Theme.labelColor(for: name).opacity(0.15), in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.labelColor(for: name).opacity(0.4), lineWidth: 0.5))
    }
}

/// Wrapping row of label chips.
struct LabelFlow: View {
    let labels: [String]
    var body: some View {
        if !labels.isEmpty {
            FlowLayout(spacing: 6) {
                ForEach(labels, id: \.self) { LabelChip(name: $0) }
            }
        }
    }
}

/// Full-screen empty/error state.
struct MessageStateView: View {
    let systemImage: String
    let title: String
    var message: String?
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let retry {
                Button("Try Again", action: retry)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Relative date label, e.g. "3h ago".
struct RelativeDateText: View {
    let date: Date?
    var prefix: String = ""

    var body: some View {
        if let date {
            Text(prefix + date.formatted(.relative(presentation: .named)))
        }
    }
}

/// Simple flow layout for chips (iOS 16+ Layout).
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [CGFloat] = [0]
        var x: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                totalHeight += rowHeight + spacing
                rows.append(0)
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
