import SwiftUI

struct HoleDetailView: View {
    @Environment(RoundStore.self) private var store
    let holeNumber: Int

    @State private var isShowingResetConfirmation = false
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
                    .disabled(hole.strokes.count >= RoundStore.maximumStrokesPerHole)
                    .accessibilityLabel("Add Stroke")
                    .accessibilityIdentifier("addStrokeButton")
                    .sensoryFeedback(.impact(weight: .light), trigger: strokeHapticTrigger)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
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
                                Divider()
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                Button(role: .destructive) {
                    isShowingResetConfirmation = true
                } label: {
                    Text("Reset")
                }
                .buttonStyle(RedOutlineButtonStyle())
                .accessibilityIdentifier("resetHoleButton")
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .navigationTitle("Hole \(holeNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
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
