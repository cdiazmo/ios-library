import Foundation
import SwiftUI
import Combine

@available(iOS 13.0.0, tvOS 13.0, *)
struct RadioInputController : View {
    let model: RadioInputControllerModel
    let constraints: ViewConstraints
    
    @State private var cancellable: AnyCancellable?
    @EnvironmentObject var parentFormState: FormState
    @State var radioInputState: RadioInputState = RadioInputState()


    var body: some View {
        ViewFactory.createView(model: self.model.view, constraints: constraints)
            .constraints(constraints)
            .background(model.backgroundColor)
            .border(model.border)
            .environmentObject(radioInputState)
            .onAppear {
                self.cancellable = self.radioInputState.$selectedItem.sink { incoming in
                    let isValid = incoming != nil || self.model.isRequired == false
                    let data = FormInputData(isValid: isValid, value: .radio(incoming))
                    self.parentFormState.updateFormInput(self.model.identifier, data: data)
                }
            }
    }
}