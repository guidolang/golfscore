import SwiftUI

struct HoleDetailView: View {
    @Environment(RoundStore.self) private var store
    let holeNumber: Int
    let onNavigate: (Int) -> Void
    let onShowScorecard: () -> Void

    @State private var strokePendingDeletion: StrokeDeletionRequest?
    @State private var isShowingPuttsReminder = false
    @State private var isShowingSkippedHoleReminder = false
    @State private var puttsReminder = PuttsReminder()
    @State private var strokeHapticTrigger = 0

    private var hole: HoleScore {
        store.hole(number: holeNumber)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 16) {
                        Text(RoundStore.strokeSummary(for: hole.strokes.count))
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .contentTransition(.numericText())
                            .accessibilityIdentifier("holeStrokeCount")

                        Button {
                            let isFirstStroke = hole.strokes.isEmpty
                            if store.addStroke(to: holeNumber) {
                                strokeHapticTrigger += 1
                                if isFirstStroke,
                                   holeNumber > 1,
                                   store.hole(number: holeNumber - 1).strokes.isEmpty {
                                    isShowingSkippedHoleReminder = true
                                }
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
                                description: Text("Tap + Stroke to record a stroke for this hole.")
                            )
                            .frame(maxWidth: .infinity, minHeight: 240)
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(hole.strokes.enumerated()), id: \.element.id) { index, stroke in
                                    StrokeLogRow(number: index + 1, stroke: stroke) {
                                        strokePendingDeletion = StrokeDeletionRequest(
                                            id: stroke.id,
                                            number: index + 1
                                        )
                                    }
                                    if index < hole.strokes.count - 1 {
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                    Spacer(minLength: 20)

                    Button {
                        onShowScorecard()
                    } label: {
                        Text("Show Scorecard")
                    }
                    .buttonStyle(GreenOutlineButtonStyle())
                    .accessibilityIdentifier("showScorecardButton")
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(minHeight: geometry.size.height, alignment: .top)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .navigationTitle("Hole \(holeNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            if holeNumber > 1 {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        handleNavigation(to: holeNumber - 1)
                    } label: {
                        Label("Previous", systemImage: "chevron.left")
                    }
                    .accessibilityIdentifier("holeBackButton")
                }
            }

            if holeNumber < RoundState.holeNumbers.count {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        handleNavigation(to: holeNumber + 1)
                    } label: {
                        Label("Next", systemImage: "chevron.right")
                    }
                    .accessibilityIdentifier("holeNextButton")
                }
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
        .alert(item: $strokePendingDeletion) { request in
            Alert(
                title: Text("Delete Stroke \(request.number)?"),
                message: Text("Do you want to delete this stroke?"),
                primaryButton: .cancel(),
                secondaryButton: .destructive(Text("Delete")) {
                    store.deleteStroke(from: holeNumber, id: request.id)
                }
            )
        }
        .alert("Skipped Hole", isPresented: $isShowingSkippedHoleReminder) {
            Button("Close", role: .cancel) {}
        } message: {
            Text("You didn't record any strokes for the previous hole.")
        }
        .alert("Reminder", isPresented: $isShowingPuttsReminder) {
            Button("Close", role: .cancel) {}
        } message: {
            Text("Don't forget to record your putts")
        }
    }

    private func handleNavigation(to holeNumber: Int) {
        if puttsReminder.shouldShow(for: hole.strokes) {
            isShowingPuttsReminder = true
        } else {
            onNavigate(holeNumber)
        }
    }
}

private struct StrokeDeletionRequest: Identifiable {
    let id: UUID
    let number: Int
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
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Stroke \(number)")
                .font(.body.weight(.semibold))
            Spacer(minLength: 12)
            StrokeTimestampText(date: stroke.timestamp)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .accessibilityLabel("Delete Stroke \(number)")
            .accessibilityIdentifier("deleteStrokeButton_\(number)")
        }
        .padding(.horizontal)
        .padding(.vertical, 14)
    }
}
