import SwiftUI

/// A collapsible description section that shows a preview with "Show More" for long content.
struct ExpandableDescription<Content: View>: View {
    let episode: Episode
    @ViewBuilder let content: () -> Content

    @State private var isExpanded = false
    @State private var isTruncated = false

    /// Max height before collapsing (roughly 6 lines of body text).
    private let collapsedHeight: CGFloat = 130

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Description", systemImage: "doc.text")
                .font(.headline)

            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: 0) {
                    content()
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: isExpanded ? nil : collapsedHeight, alignment: .top)
                .clipped()
                .background(
                    // Measure actual height to determine if truncation needed.
                    GeometryReader { geo in
                        Color.clear.onAppear {
                            isTruncated = geo.size.height >= collapsedHeight
                        }
                    }
                )

                // Fade-out gradient when collapsed.
                if !isExpanded && isTruncated {
                    LinearGradient(
                        colors: [.clear, Color(.systemBackground)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .allowsHitTesting(false)
                }
            }

            if isTruncated {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "Show Less" : "Show More")
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
