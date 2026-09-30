import SwiftUI
import LogicCasebookEngine

/// One case in a list: number, title, size and time, and a status mark.
/// Unlocked cases push the briefing; locked ones stay readable and open the
/// purchase sheet instead.
struct CaseListRow: View {
    let gameCase: Case
    let progress: CaseProgress?
    let isUnlocked: Bool
    /// One line per case (number, title, size, status) for the paged library;
    /// the full row also shows the estimated time in a second line.
    var compact = false
    let onLockedTap: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if isUnlocked {
            NavigationLink(value: gameCase) { content }
        } else {
            Button(action: onLockedTap) { content }
                .buttonStyle(.plain)
                .accessibilityHint("購入画面を開きます")
        }
    }

    private var content: some View {
        HStack(spacing: 12) {
            Text(gameCase.number)
                .font(Theme.display(13, weight: .regular))
                .foregroundStyle(Theme.inkFaint)
                .monospacedDigit()
                .frame(width: 36, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(gameCase.titleJA)
                    .font(compact ? .callout.weight(.semibold) : .body)
                    .foregroundStyle(isUnlocked ? Theme.ink : Theme.inkSoft)
                    .lineLimit(1)
                if !compact {
                    Text(meta)
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            Spacer(minLength: 8)
            if compact, sizeClass == .regular {
                Text("\(gameCase.categories.count)×\(gameCase.primaryCategory.values.count)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Theme.inkFaint)
            }
            trailing
                .frame(minWidth: compact ? 30 : 0, alignment: .trailing)
        }
        .frame(minHeight: compact ? 46 : 44)
        .accessibilityElement(children: .combine)
    }

    private var meta: String {
        let size = "\(gameCase.categories.count)項目×\(gameCase.primaryCategory.values.count)"
        return "\(size)・約\(gameCase.estimatedMinutes)分" + (isUnlocked ? "" : "・全編版")
    }

    @ViewBuilder
    private var trailing: some View {
        if !isUnlocked {
            Image(systemName: "lock.fill").foregroundStyle(Theme.inkFaint)
        } else if progress?.status == .completed {
            if progress?.isPerfect == true {
                HankoSeal(text: "完", perfect: true, size: 26)
                    .accessibilityLabel("完全解決")
            } else {
                HankoSeal(text: "済", size: 26, tint: Theme.good)
                    .accessibilityLabel("解決済み")
            }
        } else if progress?.status == .inProgress {
            HStack(spacing: 3) {
                Circle().fill(Theme.amber).frame(width: 6, height: 6)
                Circle().fill(Theme.amber).frame(width: 6, height: 6)
                Circle().fill(Theme.border).frame(width: 6, height: 6)
            }
            .accessibilityLabel("進行中")
        }
    }
}
