/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Button view.
@available(iOS 13.0.0, tvOS 13.0, *)
struct LabelButton : View {
    
    /// Button model.
    let model: LabelButtonModel
    
    /// View constriants.
    let constraints: ViewConstraints
    
    var body: some View {
        Button(action: {
            print("Button action")
        }) {
            Label(model: self.model.label, constraints: constraints)
                .padding()
                .frame(width: constraints.width, height: constraints.height)
                .background(self.model.backgroundColor)
                .border(self.model.border)

        }.constraints(constraints)
    }
}