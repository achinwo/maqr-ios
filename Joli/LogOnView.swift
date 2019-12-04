//
//  SignInView.swift
//  Joli
//
//  Created by Anthony Chinwo on 09/11/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliApi

// MARK: - SignUpView
struct SignUpView: View {
    
    @Environment(\.presentationMode) var presentation
    @State var userName: String = ""
     
    var body: some View {
        Form {
            Section(header: Text("Personal information")) {
                TextField("type something...", text: self.$userName)
            }

            Section {
                Button("Sign Up") {
                    self.presentation.wrappedValue.dismiss()
                }
            }
        }.navigationBarTitle(Text("Sign Up"))
    }
    
}

class LoginViewModel: ObservableObject {
    
    @Published var email: String = "hawa@gmail.net"
    @Published var password: String = "Password@"
    
    func performLogin() {
        logger.info("[LoginViewModel] logging in!")
    }
}

struct ActivityIndicator: UIViewRepresentable {

    typealias UIView = UIActivityIndicatorView
    var isAnimating: Bool
    fileprivate var configuration = { (indicator: UIView) in }

    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIView { UIView() }
    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<Self>) {
        isAnimating ? uiView.startAnimating() : uiView.stopAnimating()
        configuration(uiView)
    }
}

extension View where Self == ActivityIndicator {
    func configure(_ configuration: @escaping (Self.UIView) -> Void) -> Self {
        Self.init(isAnimating: self.isAnimating, configuration: configuration)
    }
}

// MARK: - SignInView
struct SignInView: View {
    
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var loginViewModel: LoginViewModel
    @State var submissionInProgress = false
    
    var presentationMode: Binding<PresentationMode>?
    
    init(presentationMode: Binding<PresentationMode>? = nil){
        self.presentationMode = presentationMode
    }
    
    var body: some View {
        
        return VStack() {
            VStack(alignment: .center) {
              
                Image("AppIcon").resizable().aspectRatio(contentMode: ContentMode.fit)
                    .frame(width: CGFloat(74.0), height: CGFloat(74.0))
                    .padding(Edge.Set.bottom, 20)
                
                Text(verbatim: "Login").bold().font(.title)
                
                Text(verbatim: "Explore the world of Swift UI")
                    .font(.subheadline)
                    .padding(EdgeInsets(top: CGFloat(0), leading: CGFloat(0), bottom: CGFloat(70.0), trailing: CGFloat(0)))
                
                TextField("Email", text: $loginViewModel.email)
                    .padding()
                    //.background(Color.white)//("flash-white"))
                    .cornerRadius(4.0)
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: CGFloat(15.0), trailing: 0))
        
                SecureField("Password", text: $loginViewModel.password) {
                    // submit the password
                    }
                .padding()
                .background(Color.white)//("flash-white"))
                .cornerRadius(4.0)
                .padding(.bottom, 10)
                
                HStack() {
                    Spacer()
                    
                    //NavigationLink(destination: DashboardView()) {
                    Text("Forgot Password?").font(.system(size: 15))
                    //}
                    
                }.padding(.bottom, 40)
               
                Button(action: submit) {
                    HStack(alignment: .center) {
                        Spacer()
                        
                        if self.submissionInProgress {
                            ActivityIndicator(isAnimating: self.submissionInProgress) { (indicator: UIActivityIndicatorView) in
                                indicator.color = .white
                                indicator.hidesWhenStopped = true
                                //Any other UIActivityIndicatorView property you like
                            }
                        }
                        
                        Text("Login").foregroundColor(Color.white).bold()
                        Spacer()
                    }
                }.padding()
                    .background(Color.green)
                    .cornerRadius(CGFloat(4.0))
                
            }.padding()
        }
        .padding()
    }
        
    func gesture(){
        logger.debug("Gesture happened!")
    }
    
    func submit() {
        self.submissionInProgress = true
        //loginViewModel.performLogin()
        
        appState.api.authenticate(email:loginViewModel.email, password: loginViewModel.password)
            .then() { auth in
                self.appState.auth = auth
                logger.debug("[LogOnView] got auth: \(String(describing: auth))")
                self.presentationMode?.wrappedValue.dismiss()
        }.always(){
            self.submissionInProgress = false
        }
        
    }
    
}

// MARK: - LogOnView
struct LogOnView: View {
    
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var appState: AppState
    @State var activityIdx = 0
    @State var offsetY: CGFloat = CGFloat(0)
    
    private var completionHandler: ((Bool) -> ())?
    
    init(completionHandler: ((Bool) -> ())? = nil){
        self.completionHandler = completionHandler
    }
    
    var body: some View {
        let onEnded = { (val: DragGesture.Value) in
            logger.debug("Gesture ended: \(val.translation.width)")
            guard abs(val.translation.height) < abs(val.translation.width) else { return }
            
            if self.activityIdx == 0 && val.translation.width < 50 {
                withAnimation(){
                    self.activityIdx = 1
                }
            } else if self.activityIdx == 1 && val.translation.width > 50 {
                withAnimation(){
                    self.activityIdx = 0
                }
            }
        }
        
        let onChanged = { (val: DragGesture.Value) in UIApplication.shared.endEditing(true)}
        let gesture = DragGesture().onChanged(onChanged).onEnded(onEnded)
        
        return GeometryReader() { geometry in
            VStack(alignment: .leading) {
                Picker(selection: self.$activityIdx, label: Text("Select Activity")) {
                    ForEach(0...1, id: \.self) { i in
                        Text(["Sign In", "Sign Up"][i]).tag(i).font(.largeTitle)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                if self.activityIdx == 0 {
                    SignInView(presentationMode: self.presentationMode).environmentObject(LoginViewModel())
                    .keyboardAwarePadding()
                } else {
                    SignUpView()
                    .keyboardAwarePadding()
                }
            }
            .animation(.spring())
            .offset(x: 0, y: self.appState.keyboardHeight == 0 ? 0 : geometry.size.height / 3 * -1)
            .simultaneousGesture(gesture)
            .navigationBarTitle("Account", displayMode: .large)
            .navigationBarItems(trailing: Button(action: {
                logger.info("Close Logon screen!")
                //self.completionHandler?(true)
                self.presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark")
                .padding()
            })
        }
        
    }
    
}

struct SignInView_Previews: PreviewProvider {
    static var previews: some View {
        SignInView()
    }
}
