//
//  Font.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 10/12/25.
//

import SwiftUI

extension Font {
    static func monocraft(relativeTo style: TextStyle = .body, size: CGFloat = 18.0, weight: Font.Weight = .regular) -> Font {
        Font.custom("Monocraft", size: size, relativeTo: style)
            .weight(weight)
    }
}