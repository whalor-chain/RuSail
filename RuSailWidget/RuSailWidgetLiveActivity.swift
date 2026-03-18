//
//  RuSailWidgetLiveActivity.swift
//  RuSailWidget
//
//  Created by Станислава Гункер on 08.03.2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct RuSailWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct RuSailWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RuSailWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension RuSailWidgetAttributes {
    fileprivate static var preview: RuSailWidgetAttributes {
        RuSailWidgetAttributes(name: "World")
    }
}

extension RuSailWidgetAttributes.ContentState {
    fileprivate static var smiley: RuSailWidgetAttributes.ContentState {
        RuSailWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: RuSailWidgetAttributes.ContentState {
         RuSailWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: RuSailWidgetAttributes.preview) {
   RuSailWidgetLiveActivity()
} contentStates: {
    RuSailWidgetAttributes.ContentState.smiley
    RuSailWidgetAttributes.ContentState.starEyes
}
