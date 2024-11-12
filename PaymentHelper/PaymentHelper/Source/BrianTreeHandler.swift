//
//  BrianTreeHandler.swift
//  Gofer
//
//  Created by trioangle on 22/11/19.
//  Copyright © 2019 Trioangle Technologies. All rights reserved.
//

import Foundation
import Braintree
import BraintreeDropIn


public
enum BTErrors : Error{
    case clientNotInitialized
    case clientCancelled
}


extension BTErrors : LocalizedError {
    public
    var errorDescription: String?{
        return self.localizedDescription
    }
    var localizedDescription: String{
        switch self {
        case .clientNotInitialized:
            return "Client Not Initialized"
        case .clientCancelled:
            return "Payment Cancelled"
        }
    }
}

public
protocol BrainTreeProtocol {
    
    func initalizeClient(with id : String)
    
    func authenticatePaymentUsing(_ view : UIViewController,
                                  email : String,
                                  givenName : String,
                                  surname : String,
                                  phoneNumber : String,
                                  for amount : Double,
                                  result: @escaping BrainTreeHandler.BTResult)
    func authenticatePaypalUsing(_ view : UIViewController,
                                  for amount : Double,
                                  currency: String,
                                  result: @escaping BrainTreeHandler.BTResult)
}

open
class BrainTreeHandler : NSObject {
    static var ReturnURL  : String  {
        let bundle = Bundle.main
        return bundle.bundleIdentifier ?? "comg.trioangle.gofer"
    }
    open
    class func isBrainTreeHandleURL(_ url: URL,
                                    options: [UIApplication.OpenURLOptionsKey : Any]) -> Bool{
        if url.scheme?
            .localizedCaseInsensitiveCompare(BrainTreeHandler.ReturnURL) == .orderedSame {
            return BTAppContextSwitcher.handleOpenURL(url)
        }
        return false
    }
    public
    typealias BTResult = (Result<BTPaymentMethodNonce, Error>) -> Void
    
    public
    static var `default` : BrainTreeProtocol = {
        BrainTreeHandler()
    }()
    
    var client : BTAPIClient?
    var hostView : UIViewController?
    var result : BTResult?
    var clientToken : String?
    private override init(){
        super.init()
        
    }
    
}

//MARK:- BrainTreeProtocol
extension BrainTreeHandler : BrainTreeProtocol{
    
    public func initalizeClient(with id : String){
        self.clientToken = id
        self.client = BTAPIClient(authorization: id)
        BTAppContextSwitcher.setReturnURLScheme(BrainTreeHandler.ReturnURL)
    }
    
    public func authenticatePaypalUsing(_ view: UIViewController,
                                  for amount: Double,
                                  currency: String,
                                  result: @escaping BrainTreeHandler.BTResult) {
        guard let currentClient = self.client else{
            result(.failure(BTErrors.clientNotInitialized))
            return
        }
        self.hostView = view
        self.result = result
        let paypalDriver = BTPayPalDriver(apiClient: currentClient)
        let request = BTPayPalCheckoutRequest(amount: amount.description)
        request.currencyCode = currency
        paypalDriver.tokenizePayPalAccount(with: request) { (payPalAccountNonce, error) in
            guard let paypaNonce = payPalAccountNonce else{
                result(.failure(error ?? BTErrors.clientCancelled))
                return
            }
            print(paypaNonce.email ?? "")
            print(paypaNonce.firstName ?? "")
            print(paypaNonce.nonce)
            result(.success(paypaNonce))
        }
    }
    
    public
    func authenticatePaymentUsing(_ view : UIViewController,
                                  email : String,
                                  givenName : String,
                                  surname : String,
                                  phoneNumber : String,
                                  for amount : Double,
                                  result: @escaping BrainTreeHandler.BTResult) {
        guard let currentClientToken = self.clientToken else{
            result(.failure(BTErrors.clientNotInitialized))
            return
        }
        self.hostView = view
        self.result = result
        
        
        _ = BTDropInRequest()
        let threeDSecureRequest = BTThreeDSecureRequest()
        threeDSecureRequest.amount = NSDecimalNumber(value: amount)
        threeDSecureRequest.email = email
        threeDSecureRequest.versionRequested = .version2

        let address = BTThreeDSecurePostalAddress()
        address.givenName = givenName// ASCII-printable characters required, else will throw a validation error
        address.surname = surname// ASCII-printable characters required, else will throw a validation error
        address.phoneNumber = phoneNumber


        threeDSecureRequest.billingAddress = address

//        // Optional additional information.
//        // For best results, provide as many of these elements as possible.
        
        let info = BTThreeDSecureAdditionalInformation()
        info.shippingAddress = address
        threeDSecureRequest.additionalInformation = info

        let dropInRequest = BTDropInRequest()
        dropInRequest.threeDSecureRequest = threeDSecureRequest
        
        let _dropIn = BTDropInController(authorization: currentClientToken,
                                         request: dropInRequest) { (controller, result, error) in
            if let btError = error {
                // Handle error
                
                self.result?(.failure(btError))
                self.dismissPresentedView()
            } else if (result?.isCanceled == true) {
                // Handle user cancelled flow
                
                self.result?(.failure(BTErrors.clientCancelled))
                self.dismissPresentedView()
            } else if let nonce = result?.paymentMethod{
                self.result?(.success(nonce))
                // Use the nonce returned in `result.paymentMethod`
            }
            
            controller.presentedViewController?.dismiss(animated: true,
                                                        completion: nil)
            controller.dismiss(animated: true,
                               completion: nil)
        }
        guard let dropIn = _dropIn else{return}
        view.present(dropIn, animated: true,
                     completion: nil)
    }
}
//MARK:- BTDropInViewControllerDelegate
extension BrainTreeHandler : BTDropInControllerDelegate{
    public func reloadDropInData() { }

    public func editPaymentMethods(_ sender: Any) {
        
    }
    
    func drop(_ viewController: BTDropInController,
              didSucceedWithTokenization paymentMethodNonce: BTPaymentMethodNonce) {
        viewController.presentedViewController?.dismiss(animated: true,
                                                        completion: nil)
        self.result?(.success(paymentMethodNonce))
        self.dismissPresentedView()
    }
    
    func drop(inViewControllerDidCancel viewController: BTDropInController) {
        viewController.presentedViewController?.dismiss(animated: true,
                                                        completion: nil)
        self.result?(.failure(BTErrors.clientCancelled))
        self.dismissPresentedView()
    }
    
    
}
//MARK:- UDF
extension BrainTreeHandler {
    
    @objc
    func userDidCancelPayment() {
        self.result?(.failure(BTErrors.clientCancelled))
        self.dismissPresentedView()
    }
    
    open
    func dismissPresentedView() {
        self.hostView?.dismiss(animated: true,
                               completion: nil)
    }
}

extension BrainTreeHandler : BTViewControllerPresentingDelegate{
    
    public func paymentDriver(_ driver: Any,
                       requestsPresentationOf viewController: UIViewController) {
        
    }
 
    public func paymentDriver(_ driver: Any,
                       requestsDismissalOf viewController: UIViewController) {
        
    }
}
