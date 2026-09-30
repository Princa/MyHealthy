import SwiftUI

/// Rounded white (or dark grey) card used across the app.
struct Card<Content: View>: View {
    var spacing: CGFloat = 12
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
    }
}

/// Small uppercase heading above a grouped card.
struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

struct StatusChip: View {
    enum Tone { case good, warn, neutral }

    let text: String
    var tone: Tone = .neutral
    var systemImage: String?

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
            }
            Text(text)
        }
        .font(.footnote.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .foregroundStyle(foreground)
        .background(background, in: Capsule())
    }

    private var foreground: Color {
        switch tone {
        case .good: return Palette.good
        case .warn: return Palette.warn
        case .neutral: return .secondary
        }
    }

    private var background: Color {
        switch tone {
        case .good: return Palette.goodSoft
        case .warn: return Palette.warnSoft
        case .neutral: return Palette.chipBackground
        }
    }

    /// "Within target" / "Above target" chip for a reading.
    static func forReading(_ value: BPValue, target: BPTarget, suffix: String = "") -> StatusChip {
        if target.isWithin(value) {
            return StatusChip(text: "Within target" + suffix, tone: .good, systemImage: "checkmark")
        }
        return StatusChip(text: "Above target" + suffix, tone: .warn, systemImage: "arrow.up")
    }
}

/// "128/82" with the systolic number in blue and the diastolic number in orange.
struct BPValueText: View {
    let value: BPValue
    var size: CGFloat = 60

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(verbatim: "\(value.systolic)")
                .foregroundStyle(Palette.systolic)
            Text(verbatim: "/")
                .foregroundStyle(Palette.slash)
                .fontWeight(.medium)
            Text(verbatim: "\(value.diastolic)")
                .foregroundStyle(Palette.diastolicText)
        }
        .font(.bpNumber(size))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value.systolic) over \(value.diastolic)")
    }
}

struct AvatarView: View {
    let initial: String
    let colorIndex: Int
    var size: CGFloat = 48

    var body: some View {
        let colors = Palette.avatar(colorIndex)
        Text(initial.isEmpty ? "?" : initial)
            .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
            .foregroundStyle(colors.foreground)
            .frame(width: size, height: size)
            .background(colors.background, in: Circle())
            .accessibilityHidden(true)
    }
}

struct MedicationTile: View {
    let purpose: String
    var size: CGFloat = 44

    var body: some View {
        let colors = Palette.medicationTile(purpose: purpose)
        Image(systemName: "pills")
            .font(.system(size: size * 0.45, weight: .regular))
            .foregroundStyle(colors.foreground)
            .frame(width: size, height: size)
            .background(colors.background, in: RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StyledButton(configuration: configuration, background: Palette.fill, foreground: .white)
    }
}

struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StyledButton(configuration: configuration, background: Palette.tintSoft, foreground: Palette.tint)
    }
}

private struct StyledButton: View {
    let configuration: ButtonStyleConfiguration
    let background: Color
    let foreground: Color
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
    }
}

/// A selectable capsule, used for reading tags and report options.
struct ToggleChip: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Text(title)
                .font(.subheadline.weight(isOn ? .semibold : .regular))
                .padding(.horizontal, 12)
                .frame(minHeight: 34)
                .foregroundStyle(isOn ? Color.white : Color.primary)
                .background {
                    Capsule().fill(isOn ? Palette.fill : Color.clear)
                }
                .overlay {
                    Capsule().strokeBorder(isOn ? Color.clear : Palette.separator, lineWidth: 1)
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Wraps children onto new lines when they run out of width.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width
            widest = max(widest, x)
            x += spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 34))
                .foregroundStyle(Palette.tint)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
    }
}

/// A row with a label on the left and a value on the right, for cards.
struct ValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
            Spacer(minLength: 8)
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(.vertical, 12)
    }
}

/// Legend dot + label used under charts.
struct LegendItem: View {
    let color: Color
    let label: String
    var dashed = false

    var body: some View {
        HStack(spacing: 6) {
            if dashed {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 14, height: 2)
                    .overlay {
                        Rectangle()
                            .stroke(color, style: StrokeStyle(lineWidth: 2, dash: [3, 2]))
                    }
            } else {
                Circle().fill(color).frame(width: 10, height: 10)
            }
            Text(label)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
