//
//  SocialLoginHandler.swift
//  SocialLogins
//
//  Created by Trioangle on 25/10/21.
//

import Foundation
import GoogleSignIn
import FBSDKLoginKit
import CloudKit
import UIKit

open
class SocialLoginsHandler : NSObject {
    
    //---------------------------------------------
    // MARK: - Shared Variable
    //---------------------------------------------
    
    public static let shared = SocialLoginsHandler()
    
    //---------------------------------------------
    // MARK: - Local Variable
    //---------------------------------------------
    
    private let fbLoginManager : LoginManager = LoginManager()
    
    //---------------------------------------------
    // MARK: - Google Login
    //---------------------------------------------
    
    public
    func handleGoogle(url: URL) -> Bool {
        let handled = GIDSignIn.sharedInstance.handle(url)
        return handled
    }
    
    public
    func doGoogleLogin(VC: UIViewController,
                       clientID : String,
                       completion: @escaping (Result<GIDGoogleUser,Error>) -> Void) {
        
        //MARK: As per the New Update in the Library We need to add GIDClientID in the info Plist itself.
        
        GIDSignIn.sharedInstance.signIn(withPresenting: VC) {
            user, error in
            if error != nil || user == nil {
                guard let error = error else { return }
                completion(.failure(error))
            } else {
                guard let user = user else { return }
                completion(.success(user.user))
            }
        }
        
//        let config : GIDConfiguration = GIDConfiguration(clientID: clientID)
//        GIDSignIn.sharedInstance.signIn(with: config,
//                                        presenting: VC) { user, error in
//            if error != nil || user == nil {
//                guard let error = error else { return }
//                completion(.failure(error))
//            } else {
//                guard let user = user else { return }
//                completion(.success(user))
//            }
//        }
    }
    public
    func doGoogleHasProfile() -> Bool {
        guard let hasImage = GIDSignIn.sharedInstance.currentUser?.profile?.hasImage else { return false }
        return hasImage
    }
    
    public
    func doGoogleSignOut() {
        GIDSignIn.sharedInstance.signOut()
    }
    
    public
    func doGogleRelogin(completion: @escaping (Result<GIDGoogleUser,Error>) -> Void) {
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
            if error != nil || user == nil {
                // Show the app's signed-out state.
                guard let error = error else { return }
                completion(.failure(error))
            } else {
                guard let user = user else { return }
                completion(.success(user))
                // Show the app's signed-in state.
            }
        }
    }
    
    //---------------------------------------------
    // MARK: - Facebook Login
    //---------------------------------------------
    
    public
    func doFacebookLogin(permissions: [String],
                         ViewController : UIViewController,
                         completion : @escaping (Result<LoginManagerLoginResult,Error>) -> Void) {
        self.fbLoginManager.logIn(permissions: permissions,
                                  from: ViewController) { loginResult, error in
            if let result = loginResult ,
               error == nil {
                completion(.success(result))
            } else {
                guard let error = error else { return }
                completion(.failure(error))
            }
        }
    }
    
    public
    func doFacebookLogout() {
        self.fbLoginManager.logOut()
    }
    
    public
    func doGetFacebookUserDetails(graphPath: String,
                                  parameters: [String: Any],
                                  completion : @escaping (Result<(FacebookResult),Error>) -> Void) {
        if let token = AccessToken.current,
           !token.isExpired {
            GraphRequest(graphPath: graphPath,
                         parameters: parameters)
                .start { connetion, result, error in
                    if let result = result,
                       let resultDict = result as? [String : Any],
                       error == nil,
                       let connetion = connetion {
                        completion(.success(FacebookResult(connetion: connetion,
                                                           accessToken: token.tokenString,
                                                           userDetails: resultDict)))
                    } else {
                        guard let error = error else { return }
                        completion(.failure(error))
                    }
                }
        } else { print("Token is Missing") }
    }
    
    public
    func activateFacebookActivities() {
        AppEvents.shared.activateApp()
    }
    
    public
    func handleFacebook(application: UIApplication,
                        url: URL,
                        sourceApplication: String?,
                        annotation: Any) -> Bool {
        let handled = ApplicationDelegate.shared.application(application,
                                                             open: url as URL,
                                                             sourceApplication: sourceApplication,
                                                             annotation: annotation)
        return handled
    }
    
    public
    func handleFacebookDidFinish(application: UIApplication,
                                 options: [UIApplication.LaunchOptionsKey : Any]?){
        ApplicationDelegate.shared
            .application(application,
                         didFinishLaunchingWithOptions: options)
    }
    
    public
    func handleFacebookOptions(application: UIApplication,
                               url: URL,
                               options: [UIApplication.OpenURLOptionsKey : Any]) -> Bool {
        let handled = ApplicationDelegate.shared
            .application(application,
                         open: url,
                         options: options)
        return handled
    }
}

extension LoginManagerLoginResult {
    public
    func doFacebookImagePermissionCheck() -> Bool {
        return self.grantedPermissions.contains("public_profile")
    }
}

public
class FacebookResult : FacebookUserResult {
    public var connetion: GraphRequestConnecting
    public var accessToken: String
    public var userDetails: [String : Any]
    
    init(connetion: GraphRequestConnecting,
         accessToken : String,
         userDetails : [String : Any]) {
        self.connetion   = connetion
        self.accessToken = accessToken
        self.userDetails = userDetails
    }
}

public
protocol FacebookUserResult {
    var connetion: GraphRequestConnecting { get }
    var accessToken : String { get }
    var userDetails : [String : Any] { get }
}
