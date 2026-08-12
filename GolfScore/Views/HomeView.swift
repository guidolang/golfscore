import SwiftUI
import CoreTransferable
import UniformTypeIdentifiers

enum AppPreferenceKeys {
    static let selectedHoleNumber = "golfscore.selectedHoleNumber"
}

struct HomeView: View {
    @AppStorage(AppPreferenceKeys.selectedHoleNumber) private var selectedHoleNumber = 1
    @State private var navigationPath: [Int]
    @State private var isShowingScorecard = false

    private var currentHoleNumber: Int {
        navigationPath.last ?? 1
    }

    init() {
        let savedHoleNumber = UserDefaults.standard.integer(
            forKey: AppPreferenceKeys.selectedHoleNumber
        )
        let initialHoleNumber = RoundState.holeNumbers.contains(savedHoleNumber)
            ? savedHoleNumber
            : 1
        _navigationPath = State(initialValue: Self.path(to: initialHoleNumber))
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            holeDetail(for: 1)
                .navigationDestination(for: Int.self) { holeNumber in
                    holeDetail(for: holeNumber)
                }
        }
        .sheet(isPresented: $isShowingScorecard) {
            ScorecardView { holeNumber in
                navigate(to: holeNumber)
                isShowingScorecard = false
            } onReset: {
                navigate(to: 1)
                isShowingScorecard = false
            }
            .presentationDetents([.large])
        }
        .onAppear {
            if selectedHoleNumber != currentHoleNumber {
                selectedHoleNumber = currentHoleNumber
            }
        }
        .onChange(of: navigationPath) { _, path in
            selectedHoleNumber = path.last ?? 1
        }
    }

    private func navigate(to holeNumber: Int) {
        guard RoundState.holeNumbers.contains(holeNumber) else {
            return
        }

        if holeNumber == currentHoleNumber + 1 {
            navigationPath.append(holeNumber)
        } else if holeNumber == currentHoleNumber - 1, !navigationPath.isEmpty {
            navigationPath.removeLast()
        } else {
            navigationPath = Self.path(to: holeNumber)
        }
    }

    private func holeDetail(for holeNumber: Int) -> some View {
        HoleDetailView(
            holeNumber: holeNumber,
            onNavigate: navigate,
            onShowScorecard: {
                isShowingScorecard = true
            }
        )
    }

    private static func path(to holeNumber: Int) -> [Int] {
        holeNumber > 1 ? Array(2...holeNumber) : []
    }
}

private struct ScorecardView: View {
    @Environment(RoundStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var isShowingResetConfirmation = false
    let onSelectHole: (Int) -> Void
    let onReset: () -> Void

    private var frontNine: [HoleScore] {
        Array(store.round.holes.prefix(9))
    }

    private var backNine: [HoleScore] {
        Array(store.round.holes.dropFirst(9))
    }

    private var scorecardRowInsets: EdgeInsets {
        EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 32)
    }

    var body: some View {
        NavigationStack {
            List {
                scoreSection(
                    title: "Front 9",
                    holes: frontNine,
                    totalTitle: "Total Front 9"
                )

                scoreSection(
                    title: "Back 9",
                    holes: backNine,
                    totalTitle: "Total Back 9"
                )

                Section {
                    totalRow(title: "Grand Total", total: store.totalStrokes)
                        .listRowInsets(scorecardRowInsets)
                        .accessibilityIdentifier("grandTotalRow")
                }

                Section {
                    ShareLink(
                        item: ScorecardCSVDocument(round: store.round),
                        preview: SharePreview("Scorecard CSV", image: Image(systemName: "tablecells"))
                    ) {
                        Text("Export")
                    }
                    .accessibilityIdentifier("shareScorecardButton")

                    Button(role: .destructive) {
                        isShowingResetConfirmation = true
                    } label: {
                        Text("Reset")
                    }
                    .accessibilityIdentifier("resetAllButton")
                }
            }
            .navigationTitle("Scorecard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Close", systemImage: "xmark")
                    }
                    .accessibilityIdentifier("closeScorecardButton")
                }
            }
            .alert("Reset All Holes?", isPresented: $isShowingResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    store.resetAll()
                    onReset()
                }
            } message: {
                Text("Do you want to reset all holes?")
            }
        }
    }

    private func scoreSection(
        title: String,
        holes: [HoleScore],
        totalTitle: String
    ) -> some View {
        Section(title) {
            ForEach(holes) { hole in
                HStack {
                    Button("Hole \(hole.id)") {
                        onSelectHole(hole.id)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.blue)
                    .accessibilityIdentifier("scorecardHole_\(hole.id)")

                    Spacer()

                    Text("\(hole.strokes.count)")
                        .foregroundStyle(hole.strokes.isEmpty ? Color.secondary : Color.primary)
                        .accessibilityIdentifier("scorecardHoleCount_\(hole.id)")
                }
                .listRowInsets(scorecardRowInsets)
            }

            totalRow(
                title: totalTitle,
                total: holes.reduce(0) { $0 + $1.strokes.count }
            )
            .listRowInsets(scorecardRowInsets)
            .accessibilityIdentifier(totalTitle == "Total Front 9" ? "frontNineTotalRow" : "backNineTotalRow")
        }
    }

    private func totalRow(title: String, total: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(total)")
        }
        .fontWeight(.semibold)
        .accessibilityElement(children: .combine)
    }
}

struct ScorecardCSVDocument: Transferable {
    let contents: Data
    let filename: String

    init(
        round: RoundState,
        date: Date = Date(),
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        contents = Data(RoundStore.scorecardCSV(for: round, timeZone: timeZone).utf8)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        filename = "GolfScore-\(formatter.string(from: date)).csv"
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { document in
            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(document.filename)
            try document.contents.write(to: fileURL, options: .atomic)
            return SentTransferredFile(fileURL)
        }
    }
}

struct GreenOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.golfGreen)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.golfGreen, lineWidth: 1.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.65 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

extension Color {
    static let golfGreen = Color(red: 0.05, green: 0.45, blue: 0.22)
}

#Preview {
    HomeView()
        .environment(RoundStore())
}
