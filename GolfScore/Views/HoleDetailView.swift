import SwiftUI

struct HoleDetailView: View {
    @Environment(RoundStore.self) private var store
    let holeNumber: Int
    let onNavigate: (Int) -> Void
    let onShowScorecard: () -> Void

    @State private var strokePendingDeletion: StrokeDeletionRequest?
    @State private var strokeNoteRequest: StrokeNoteRequest?
    @State private var isShowingPuttsReminder = false
    @State private var puttsReminder = PuttsReminder()
    @State private var strokeHapticTrigger = 0

    private var hole: HoleScore {
        store.hole(number: holeNumber)
    }

    private var shouldShowSkippedHoleWarning: Bool {
        holeNumber > 1 && store.hole(number: holeNumber - 1).strokes.isEmpty
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

                        if shouldShowSkippedHoleWarning {
                            Text("No strokes recorded for the previous hole")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    Color.red.opacity(0.1),
                                    in: RoundedRectangle(cornerRadius: 12)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.red, lineWidth: 1)
                                }
                                .accessibilityIdentifier("skippedHoleWarning")
                        }
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
                                    StrokeLogRow(
                                        number: index + 1,
                                        stroke: stroke,
                                        onAddNote: {
                                            strokeNoteRequest = StrokeNoteRequest(
                                                id: stroke.id,
                                                number: index + 1,
                                                text: stroke.note ?? ""
                                            )
                                        },
                                        onDelete: {
                                            strokePendingDeletion = StrokeDeletionRequest(
                                                id: stroke.id,
                                                number: index + 1
                                            )
                                        }
                                    )
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
        .sheet(item: $strokeNoteRequest) { request in
            StrokeNoteEditor(
                strokeNumber: request.number,
                initialText: request.text,
                onSave: { text in
                    store.saveNote(text, for: request.id, in: holeNumber)
                    strokeNoteRequest = nil
                },
                onCancel: {
                    strokeNoteRequest = nil
                }
            )
            .presentationDetents([.large])
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

private struct StrokeNoteRequest: Identifiable {
    let id: UUID
    let number: Int
    let text: String
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
    let onAddNote: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Stroke \(number)")
                    .font(.body.weight(.semibold))
                Spacer(minLength: 12)
                StrokeTimestampText(date: stroke.timestamp)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)

                Button(action: onAddNote) {
                    Image(systemName: "note.text.badge.plus")
                }
                .accessibilityLabel(stroke.note == nil ? "Add Note to Stroke \(number)" : "Edit Note for Stroke \(number)")
                .accessibilityIdentifier("noteStrokeButton_\(number)")

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete Stroke \(number)")
                .accessibilityIdentifier("deleteStrokeButton_\(number)")
            }

            if let note = stroke.note, !note.isEmpty {
                Text(note)
                    .font(.body.italic())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("strokeNote_\(number)")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 14)
    }
}

private struct StrokeNoteEditor: View {
    let strokeNumber: Int
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var text: String
    @FocusState private var isTextEditorFocused: Bool

    init(
        strokeNumber: Int,
        initialText: String,
        onSave: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.strokeNumber = strokeNumber
        self.onSave = onSave
        self.onCancel = onCancel
        _text = State(initialValue: initialText)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextEditor(text: $text)
                    .focused($isTextEditorFocused)
                    .padding(8)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("Stroke Note")
                    .accessibilityIdentifier("strokeNoteTextEditor")

                Button("Clear") {
                    text = ""
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .foregroundStyle(.primary)
                .background(
                    Color(.secondarySystemFill),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .buttonStyle(.plain)
                .accessibilityIdentifier("clearStrokeNoteButton")
            }
            .padding()
            .navigationTitle("Stroke \(strokeNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .accessibilityIdentifier("cancelStrokeNoteButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(text)
                    }
                    .accessibilityIdentifier("saveStrokeNoteButton")
                }
            }
            .task {
                await Task.yield()
                isTextEditorFocused = true
            }
        }
    }
}
