import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct GolfScoreWidgetBundle: WidgetBundle {
    var body: some Widget {
        GolfScoreLiveActivity()
    }
}

struct GolfScoreLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HoleActivityAttributes.self) { context in
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hole \(context.attributes.holeNumber)")
                        .font(.headline)
                    Text(strokeSummary(context.state.strokes))
                        .font(.title2.bold())
                }

                Spacer(minLength: 8)

                addStrokeButton(context: context)
            }
            .padding()
            .foregroundStyle(Color.black)
            .activityBackgroundTint(Color.white)
            .activitySystemActionForegroundColor(Color.black)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Hole \(context.attributes.holeNumber)")
                        .font(.headline)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(strokeSummary(context.state.strokes))
                        .font(.headline)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    addStrokeButton(context: context)
                }
            } compactLeading: {
                Text("H\(context.attributes.holeNumber)")
            } compactTrailing: {
                Text("\(context.state.strokes)")
            } minimal: {
                Image(systemName: "figure.golf")
            }
            .keylineTint(golfGreen)
        }
    }

    private func addStrokeButton(
        context: ActivityViewContext<HoleActivityAttributes>
    ) -> some View {
        Button(intent: AddStrokeIntent(
            holeNumber: context.attributes.holeNumber,
            activityID: context.activityID
        )) {
            Label("Stroke", systemImage: "plus")
                .font(.headline)
                .foregroundStyle(Color.white)
                .frame(minWidth: 96)
        }
        .buttonStyle(.borderedProminent)
        .tint(golfGreen)
        .disabled(context.state.strokes >= ScoreRules.maximumStrokesPerHole)
    }

    private func strokeSummary(_ count: Int) -> String {
        "\(count) \(count == 1 ? "Stroke" : "Strokes")"
    }

    private var golfGreen: Color {
        Color(red: 0.05, green: 0.45, blue: 0.22)
    }
}
