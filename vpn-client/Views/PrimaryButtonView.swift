// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import SwiftUI

struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    @Binding var isLoading: Bool

    var body: some View {
        Button(action: self.action) {
            ZStack {
                Spinner(isAnimating: .constant(true), style: .medium)
                Text(title)
            }
        }
            .padding()
            .foregroundColor(Color.white)
            .background(Color.blue)
            .cornerRadius(8)
    }
}

struct PrimaryButtonView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PrimaryButton(title: "Action", action: {}, isLoading: .constant(false))
                .previewLayout(.fixed(width: 300, height: 80))

            PrimaryButton(title: "Action", action: {}, isLoading: .constant(false))
                .previewLayout(.fixed(width: 300, height: 80))
                .environment(\.colorScheme, .dark)

            PrimaryButton(title: "Action", action: {}, isLoading: .constant(true))
                .previewLayout(.fixed(width: 300, height: 80))
        }
    }
}
