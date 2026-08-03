//
//  Data+LittleEndian.swift
//  Loop
//
//  Created by Florian Maxl on 02.08.26.
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation

extension Data {

    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndianValue = value.littleEndian

        Swift.withUnsafeBytes(of: &littleEndianValue) { bytes in
            append(contentsOf: bytes)
        }
    }
}
