import SwiftUI
import SwiftData
import LogicCasebookEngine

/// The case library (docs/logic-casebook-locked-process-flow.md, section
/// 4.2). All four difficulty levels are visible from first launch. Each level
/// is split into volumes of 10 cases, so a volume fits one screen without
/// scrolling: a pager (previous, next, or pick any volume) sits under the
/// level switch, and each level opens on the volume of the case the player
/// last played. Lives inside the shell's per-tab `NavigationStack`, so it
/// declares destinations but no stack.
public struct CaseLibraryView: View {
    static let casesPerVolume = 10

    @EnvironmentObject private var entitlements: EntitlementStore
    @Query(sort: \CaseProgress.lastPlayedAt, order: .reverse) private var records: [CaseProgress]
    @State private var tier: Difficulty = .beginner
    /// `nil` follows the player's position; set once they page manually.
    @State private var chosenVolume: Int?
    @State private var showingPurchase = false

    public init() {}

    public var body: some View {
        let progress = Dictionary(records.map { ($0.caseID, $0) }, uniquingKeysWith: { first, _ in first })
        let cases = CaseCatalog.byDifficulty[tier] ?? []
        let volumeCount = max(1, (cases.count + Self.casesPerVolume - 1) / Self.casesPerVolume)
        let nextIndex = cases.firstIndex { isUnlocked($0) && progress[$0.caseID]?.status != .completed }
        let anchor = lastPlayedIndex(in: cases, progress: progress) ?? nextIndex ?? 0
        let volume = min(chosenVolume ?? anchor / Self.casesPerVolume, volumeCount - 1)
        let page = Array(cases.dropFirst(volume * Self.casesPerVolume).prefix(Self.casesPerVolume))
        let solved = cases.filter { progress[$0.caseID]?.status == .completed }.count
        let lockedInPage = page.filter { !isUnlocked($0) }.count

        ScrollView {
            VStack(spacing: 10) {
                if let resume = continueCase() {
                    NavigationLink(value: resume) { ContinueBar(gameCase: resume) }
                        .buttonStyle(.plain)
                }

                Picker("難易度", selection: $tier) {
                    ForEach(Difficulty.allCases, id: \.self) { Text($0.labelJA).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: tier) { chosenVolume = nil }

                VolumePager(
                    cases: cases,
                    volume: volume,
                    volumeCount: volumeCount,
                    solved: solved,
                    progress: progress,
                    isUnlocked: isUnlocked,
                    select: { chosenVolume = $0 }
                )

                shortcutRow(nextIndex: nextIndex, volume: volume, lockedInPage: lockedInPage, freeInPage: page.count - lockedInPage)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 380), spacing: 0)], spacing: 0) {
                    ForEach(page) { gameCase in
                        row(gameCase, progress: progress)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 2)
                            .background(Theme.surface)
                            .overlay(alignment: .bottom) { Divider().padding(.leading, 14) }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .navigationTitle("事件簿")
        .navigationDestination(for: Case.self) { CaseBriefingView(gameCase: $0) }
        .sheet(isPresented: $showingPurchase) { PurchaseSheetView() }
    }

    @ViewBuilder
    private func shortcutRow(nextIndex: Int?, volume: Int, lockedInPage: Int, freeInPage: Int) -> some View {
        let nextVolume = nextIndex.map { $0 / Self.casesPerVolume }
        let showNext = nextVolume != nil && nextVolume != volume
        let showBuy = lockedInPage > 0 && !entitlements.isFullUnlockPurchased
        if showNext || showBuy {
            HStack {
                if showNext, let nextVolume {
                    Button {
                        chosenVolume = nextVolume
                    } label: {
                        Label("次の未解決へ（第\(nextVolume + 1)巻）", systemImage: "chevron.right")
                            .labelStyle(TrailingIconLabelStyle())
                    }
                }
                Spacer()
                if showBuy {
                    let price = entitlements.fullUnlockProduct?.displayPrice ?? "¥1,800"
                    Button(freeInPage > 0 ? "残り\(lockedInPage)件は \(price) で解放" : "\(price) で解放") {
                        showingPurchase = true
                    }
                }
            }
            .font(.footnote.weight(.bold))
            .foregroundStyle(Theme.accent)
        }
    }

    private func row(_ gameCase: Case, progress: [String: CaseProgress]) -> some View {
        CaseListRow(
            gameCase: gameCase,
            progress: progress[gameCase.caseID],
            isUnlocked: isUnlocked(gameCase),
            compact: true,
            onLockedTap: { showingPurchase = true }
        )
    }

    private func isUnlocked(_ gameCase: Case) -> Bool {
        gameCase.isFree || entitlements.isFullUnlockPurchased
    }

    private func lastPlayedIndex(in cases: [Case], progress: [String: CaseProgress]) -> Int? {
        // `records` is newest first, so the first record inside this level is the last one played.
        for record in records {
            if let index = cases.firstIndex(where: { $0.caseID == record.caseID }) { return index }
        }
        return nil
    }

    private func continueCase() -> Case? {
        guard let record = records.first(where: { $0.status == .inProgress }) else { return nil }
        return CaseCatalog.byID[record.caseID]
    }
}

/// The volume pager: previous and next arrows (44pt) around a picker showing
/// the current volume, its case numbers and the player's solved count.
private struct VolumePager: View {
    let cases: [Case]
    let volume: Int
    let volumeCount: Int
    let solved: Int
    let progress: [String: CaseProgress]
    let isUnlocked: (Case) -> Bool
    let select: (Int) -> Void

    private let per = CaseLibraryView.casesPerVolume

    var body: some View {
        HStack(spacing: 6) {
            arrow("chevron.left", label: "前の巻", enabled: volume > 0) { select(volume - 1) }

            Menu {
                Picker("巻を選ぶ", selection: Binding(get: { volume }, set: select)) {
                    ForEach(0..<volumeCount, id: \.self) { index in
                        Text((isFinished(index) ? "✓ " : "") + "第\(index + 1)巻 ・ \(range(index))").tag(index)
                    }
                }
            } label: {
                VStack(spacing: 1) {
                    Text("第\(volume + 1)巻 ・ \(range(volume))")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                    Text("解決 \(solved) / \(cases.count)")
                        .font(.caption2)
                        .foregroundStyle(Theme.inkSoft)
                }
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.border, lineWidth: 1))
            }
            .accessibilityLabel("巻を選ぶ")
            .accessibilityValue("第\(volume + 1)巻、\(range(volume))")

            arrow("chevron.right", label: "次の巻", enabled: volume < volumeCount - 1) { select(volume + 1) }
        }
    }

    private func arrow(_ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
        }
        .disabled(!enabled)
        .foregroundStyle(enabled ? Theme.accent : Theme.inkFaint)
        .accessibilityLabel(label)
    }

    private func slice(_ index: Int) -> ArraySlice<Case> {
        cases.dropFirst(index * per).prefix(per)
    }

    private func range(_ index: Int) -> String {
        let items = slice(index)
        guard let first = items.first, let last = items.last else { return "" }
        return "\(Int(first.number) ?? 0)–\(Int(last.number) ?? 0)"
    }

    private func isFinished(_ index: Int) -> Bool {
        slice(index).allSatisfy { progress[$0.caseID]?.status == .completed || !isUnlocked($0) }
            && slice(index).contains { isUnlocked($0) }
    }
}

/// A slim "continue" bar: one line, so it costs little vertical space.
private struct ContinueBar: View {
    let gameCase: Case

    var body: some View {
        HStack(spacing: 8) {
            Text("続きから")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.accent)
            Text(gameCase.titleJA)
                .font(Theme.display(15))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.inkFaint)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityHint("前回の続きを開きます")
    }
}

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon.imageScale(.small)
        }
    }
}
