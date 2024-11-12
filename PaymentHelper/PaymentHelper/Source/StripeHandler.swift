//
//  StripeHandler.swift
//  Gofer
//
//  Created by trioangle on 21/11/19.
//  Copyright © 2019 Trioangle Technologies. All rights reserved.
//

import Foundation
import Stripe

open
class StripeHandler : NSObject {
    
    class public func initStripeModule(key: String) {
        STPAPIClient.shared.publishableKey = key
    }
    class public func isStripeHandleURL(_ url : URL) -> Bool{
        return StripeAPI.handleURLCallback(with: url)
    }
    let client = STPAPIClient.shared
    private let viewController : UIViewController
    public
    init(_ viewController : UIViewController) {
        self.viewController = viewController
    }
    ///create token for given card with 3dSecureValidation
    public
    func setUpCard(
        textField: STPPaymentCardTextField,
        secret : String,
        completion: @escaping (Result<String, Error>) -> Void) {
        let paymentMethodParams =  STPPaymentMethodParams(
            card: textField.cardParams,
            billingDetails: nil,
            metadata: nil
        )
        let setup = STPSetupIntentConfirmParams(clientSecret: secret)
        setup.paymentMethodParams = paymentMethodParams
        STPPaymentHandler
            .shared()
            .confirmSetupIntent(setup,
                                with: self)
            { (actionStatus,intent, error) in
                switch actionStatus{
                case .succeeded:
                    if let _intent = intent{
                        completion(.success(_intent.stripeID))
                    }
                case .failed,.canceled:
                    if let _error = error{
                        completion(.failure(_error))
                    }
                @unknown default:
                    break
                }
        }
    
    }
    ///confirms payment for the given token with 3dSecureValidation
    public
    func confirmPayment(for token : String,
                        completion : @escaping (Result<String,Error>)->()){
        let intent = STPPaymentIntentParams(clientSecret: token)
        STPPaymentHandler
        .shared()
            .confirmPayment(intent,
                            with: self)
        { (actionStatus,intent, error) in
            switch actionStatus{
            case .succeeded:
                if let _intent = intent{
                    completion(.success(_intent.stripeId))
                }
            case .failed,.canceled:
                if let _error = error{
                    completion(.failure(_error))
                }
            @unknown default:
                break
            }
            
        }
    }
}
extension StripeHandler : STPAuthenticationContext{
    public
    func authenticationPresentingViewController() -> UIViewController {
        return self.viewController
    }
}
