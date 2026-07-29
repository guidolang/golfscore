import SwiftUI

struct HoleDetailView: View {
    @Environment(RoundStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let holeNumber: Int

    @State private var isShowingResetConfirmation = false
    @State private var isShowingPuttsReminder = false
    @State private var puttsReminder = PuttsReminder()
    @State private var strokeHapticTrigger = 0

    private var hole: HoleScore {
        store.hole(number: holeNumber)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 16) {
                    Text(RoundStore.strokeSummary(for: hole.strokes.count))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .contentTransition(.numericText())
                        .accessibilityIdentifier("holeStrokeCount")

                    Button {
                        if store.addStroke(to: holeNumber) {
                            strokeHapticTrigger += 1
                        }
                    } label: {
                        Label("Stroke", systemImage: "plus")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.golfGreen)
                    .accessibilityLabel("Add Stroke")
                    .accessibilityIdentifier("addStrokeButton")
                    .sensoryFeedback(.impact(weight: .light), trigger: strokeHapticTrigger)
                }

                VStack(alignment: .leading, spacing: 0) {
                    Divider()

                    if hole.strokes.isEmpty {
                        ContentUnavailableView(
                            "No Strokes Yet",
                            systemImage: "figure.golf",
                            description: Text("Tap + Stroke to begin this hole.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 240)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(hole.strokes.enumerated()), id: \.element.id) { index, stroke in
                                StrokeLogRow(number: index + 1, stroke: stroke)
                                if index < hole.strokes.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                if !hole.strokes.isEmpty {
                    Button(role: .destructive) {
                        isShowingResetConfirmation = true
                    } label: {
                        Text("Reset")
                    }
                    .buttonStyle(RedOutlineButtonStyle())
                    .accessibilityIdentifier("resetHoleButton")
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .navigationTitle("Hole \(holeNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    handleBackButton()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .accessibilityIdentifier("holeBackButton")
            }
        }
        .task {
            await HoleLiveActivityController.shared.start(
                holeNumber: holeNumber,
                strokes: hole.strokes.count
            )
        }
        .onChange(of: hole.strokes.count) { _, strokes in
            Task {
                await HoleLiveActivityController.shared.update(
                    holeNumber: holeNumber,
                    strokes: strokes
                )
            }
        }
        .onDisappear {
            Task {
                await HoleLiveActivityController.shared.end(holeNumber: holeNumber)
            }
        }
        .alert("Reset Hole \(holeNumber)?", isPresented: $isShowingResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                store.resetHole(holeNumber)
            }
        } message: {
            Text("Do you want to reset this hole?")
        }
        .alert("Reminder", isPresented: $isShowingPuttsReminder) {
            Button("Close", role: .cancel) {}
        } message: {
            Text("Don't forget to record your putts")
        }
    }

    private func handleBackButton() {
        if puttsReminder.shouldShow(for: hole.strokes) {
            isShowingPuttsReminder = true
        } else {
            dismiss()
        }
    }
}

struct PuttsReminder {
    private(set) var hasShown = false

    mutating func shouldShow(
        for strokes: [StrokeRecord],
        relativeTo currentDate: Date = Date()
    ) -> Bool {
        guard !hasShown, strokes.count >= 2 else {
            return false
        }

        let previousStroke = strokes[strokes.count - 2]
        let lastStroke = strokes[strokes.count - 1]
        let secondsSinceLastStroke = currentDate.timeIntervalSince(lastStroke.timestamp)
        guard lastStroke.timestamp.timeIntervalSince(previousStroke.timestamp) > 60,
              secondsSinceLastStroke >= 0,
              secondsSinceLastStroke < 5 * 60 else {
            return false
        }

        hasShown = true
        return true
    }
}

private struct StrokeLogRow: View {
    let number: Int
    let stroke: StrokeRecord

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Stroke \(number)")
                .font(.body.weight(.semibold))
            Spacer(minLength: 12)
            StrokeTimestampText(date: stroke.timestamp)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("strokeRow_\(number)")
    }
}
