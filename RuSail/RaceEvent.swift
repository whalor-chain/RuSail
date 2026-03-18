//
//  RaceEvent.swift
//  RuSail
//
//  Created by Станислава Гункер on 08.03.2026.
//
import Foundation

struct RaceEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let startDate: String
    let endDate: String
    let classes: [String]
    let discipline: String
    let location: String
    let month: Int
}
