// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import SwiftUI

struct TunnelDetailsView: View {
    @ObservedObject var model: TunnelViewModel

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Settings")) {
                    TextInputView(title: "Username", text: $model.username)
                    TextInputView(title: "Password", text: $model.password)
                    TextInputView(title: "Server", text: $model.server)
                    Button(action: model.buttonSaveTapped) { Text("Save") }
                        .foregroundColor(Color.blue)
                }
                Section(header: Text("Status")) {
                    Toggle(isOn: $model.isEnabled, label: { Text("Enabled") })
                    if model.isEnabled {
                        Text("Status: ") + Text(model.status).bold()
                        if model.isStarted {
                            Button(action: model.buttonStopTapped) { Text("Stop") }
                                .foregroundColor(Color.orange)
                        } else {
                            Button(action: model.buttonStartTapped) { Text("Start") }
                                .foregroundColor(Color.blue)
                        }
                    }
                }
                Section {
                    ButtonRemoveProfile(model: model)
                }
            }
            .disabled(model.isLoading)
            .alert(isPresented: $model.isShowingError) {
                Alert(
                    title: Text(self.model.errorTitle),
                    message: Text(self.model.errorMessage),
                    dismissButton: .cancel()
                )
            }
            .navigationBarItems(trailing:
                Spinner(isAnimating: $model.isLoading, color: .label, style: .medium)
            )
            .navigationBarTitle("VPN Status")
        }
    }
}

private struct TextInputView: View {
    let title: String
    let text: Binding<String>

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.callout)
            TextField(title, text: text)
                .multilineTextAlignment(.trailing)
                .foregroundColor(Color.gray)
        }
    }
}

private struct ButtonRemoveProfile: View {
    let model: TunnelViewModel

    @State private var isConfirmationPresented = false

    var body: some View {
        Button(action: {
            self.isConfirmationPresented = true
        }) {
            Text("Remove Profile")
        }
        .foregroundColor(.red)
        .alert(isPresented: $isConfirmationPresented) {
            Alert(
                title: Text("Are you sure you want to remove the profile?"),
                primaryButton: .destructive(Text("Remove profile"), action: {
                    self.isConfirmationPresented = false
                    self.model.buttonRemoveProfileTapped()
                }),
                secondaryButton: .cancel()
            )
        }
    }
}

struct TunnelView_Previews: PreviewProvider {
    static var previews: some View {
        TunnelDetailsView(model: .init(tunnel: .init()))
    }
}
