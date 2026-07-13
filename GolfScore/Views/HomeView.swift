import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            ScorecardPageView()
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct ScorecardPageView: View {
    @Environment(RoundStore.self) private var store

    @State private var isShowingAllHoles = false
    @State private var isShowingResetConfirmation = false

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 16),
        count: 3
    )

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(visibleHoles) { hole in
                        NavigationLink {
                            HoleDetailView(holeNumber: hole.id)
                        } label: {
                            HoleButton(hole: hole)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("holeButton_\(hole.id)")
                        .accessibilityLabel("Hole \(hole.id), \(RoundStore.strokeSummary(for: hole.strokes.count))")
                    }
                }

                totalHeader

                holeCountToggle

                resetButton
            }
            .padding(.horizontal)
            .padding(.top, 44)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .alert("Reset All Holes?", isPresented: $isShowingResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                store.resetAll()
            }
        } message: {
            Text("Do you want to reset all holes?")
        }
    }

    private var visibleHoles: [HoleScore] {
        Array(store.round.holes.prefix(isShowingAllHoles ? 18 : 9))
    }

    private var totalHeader: some View {
        VStack(spacing: 0) {
            Text("\(store.totalStrokes)")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(Color.primary)
                .contentTransition(.numericText())

            Text("Total Strokes")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(store.totalStrokes) Total Strokes")
        .accessibilityIdentifier("totalStrokesCount")
    }

    private var holeCountToggle: some View {
        Button {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                isShowingAllHoles.toggle()
            }
        } label: {
            Text(isShowingAllHoles ? "Show 9 Holes" : "Show 18 Holes")
                .contentTransition(.identity)
        }
        .buttonStyle(GreenOutlineButtonStyle())
        .accessibilityIdentifier("holeCountToggleButton")
    }

    private var resetButton: some View {
        Button(role: .destructive) {
            isShowingResetConfirmation = true
        } label: {
            Text("Reset")
        }
        .buttonStyle(RedOutlineButtonStyle())
        .accessibilityIdentifier("resetAllButton")
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

struct RedOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.red, lineWidth: 1.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.65 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct HoleButton: View {
    let hole: HoleScore

    private var hasStrokes: Bool {
        !hole.strokes.isEmpty
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(hasStrokes ? Color.golfGreen : Color.white)
            Circle()
                .stroke(Color.golfGreen, lineWidth: 3)

            VStack(spacing: 0) {
                Text("\(hole.id)")
                    .font(.system(.title, design: .rounded, weight: .bold))
                Text("(\(hole.strokes.count))")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(hasStrokes ? Color.white : Color.golfGreen)
        }
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Circle())
    }
}

extension Color {
    static let golfGreen = Color(red: 0.05, green: 0.45, blue: 0.22)
}

#Preview {
    HomeView()
        .environment(RoundStore())
}
