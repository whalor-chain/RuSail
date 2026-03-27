//
//  RuSailWidgetBundle.swift
//  RuSailWidget
//
//  Created by Станислава Гункер on 08.03.2026.
//

import WidgetKit
import SwiftUI

@main
struct RuSailWidgetBundle: WidgetBundle {
    var body: some Widget {
        RuSailWidget()
        RuSailWidgetLiveActivity()
    }
}
