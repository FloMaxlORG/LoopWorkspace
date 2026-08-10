//
//  LoopLiveData+Trend.swift
//  Loop
//
//  Created by Florian Maxl on 06.08.26.
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

extension LoopLiveData.Trend {

    static func from(_ trend: GlucoseTrend?) -> Self {

        guard let trend else {
            return .unknown
        }

        switch trend {

        case .downDownDown:
            return .doubleDown

        case .downDown:
            return .singleDown

        case .down:
            return .fortyFiveDown

        case .flat:
            return .flat

        case .up:
            return .fortyFiveUp

        case .upUp:
            return .singleUp

        case .upUpUp:
            return .doubleUp
        }
    }
}
