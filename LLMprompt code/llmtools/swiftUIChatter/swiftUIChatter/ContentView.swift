//
//  ContentView.swift
//  swiftUIChatter
//
//  Created by Karthik Jonnalagadda on 10/7/25.
//

import SwiftUI
import Observation

struct SubmitButton: View {
    @Binding var scrollProxy: ScrollViewProxy?
    @Environment(ChattViewModel.self) private var vm
    
    @State private var isSending = false

    var body: some View {
        Button {
            isSending = true
            Task (priority: .background){
                if let appID = vm.appID {
                    await ChattStore.shared.llmTools(
                        appID: appID,
                        chatt: Chatt(username: vm.model,
                                     message: vm.message, timestamp: Date().ISO8601Format()),
                        errMsg: Bindable(vm).errMsg)
                }
                vm.message = ""
                    isSending = false
                    vm.showError = !vm.errMsg.isEmpty
                    Task (priority: .userInitiated) {
                        withAnimation {
                            scrollProxy?.scrollTo(ChattStore.shared.chatts.last?.id, anchor: .bottom)
                        }
                    }
            }
        } label: {
            if isSending {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                    .padding(10)
            } else {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(vm.message.isEmpty ? .gray : .yellow)
                    .padding(10)
            }
        }
        .disabled(isSending || vm.message.isEmpty)
        .background(Color(isSending || vm.message.isEmpty ? .secondarySystemBackground : .systemBlue))
        .clipShape(Circle())
        .padding(.trailing)
    }
}

struct ContentView: View {
    @Environment(ChattViewModel.self) private var vm
    @State private var scrollProxy: ScrollViewProxy?
    @FocusState private var messageInFocus: Bool // tap background to dismiss kbd
    
    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ChattScrollView()
                    .onAppear {
                        scrollProxy = proxy
                    }
            }
            HStack (alignment: .bottom) {
                TextField(vm.instruction, text: Bindable(vm).message)
                    .focused($messageInFocus) // to dismiss keyboard
                    .textFieldStyle(.roundedBorder)
                    .cornerRadius(20)
                    .shadow(radius: 2)
                    .background(Color(.clear))
                    .border(Color(.clear))

                SubmitButton(scrollProxy: $scrollProxy)
            }
            .padding(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 0))
        }
        .contentShape(.rect)
        .onTapGesture {
            messageInFocus.toggle()
        }

        .navigationTitle("llmPrompt")
        .navigationBarTitleDisplayMode(.inline)
        .alert("LLM Error", isPresented: Bindable(vm).showError) {
            Button("OK") {
                vm.errMsg = ""
            }
        } message: {
            Text(vm.errMsg)
        }

    }
}
