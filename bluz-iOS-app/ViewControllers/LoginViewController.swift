//
//  LoginViewController.swift
//  bluz-iOS-app
//
//  Created by ShangWang on 12/17/16.
//  Copyright © 2016 ShangWang. All rights reserved.
//

import UIKit

class LoginViewController: UIViewController {
    @IBOutlet var loginButton: UIButton?
    @IBOutlet var emailAddress: UITextField?
    @IBOutlet var password: UITextField?
    @IBOutlet var errorLabel: UILabel?
    @IBOutlet var successLabel: UILabel?

    override func viewDidLoad() {
        super.viewDidLoad()
        errorLabel?.isHidden = true
        successLabel?.isHidden = true
        password?.isSecureTextEntry = true;
        
        loginButton!.addTarget(self, action: #selector(LoginViewController.loginButtonPressed(_:)), for: .touchUpInside)
    }
    
    func loginButtonPressed(_ sender: UIButton!) {
        errorLabel!.isHidden = true
        SparkCloud.sharedInstance().login(withUser: emailAddress?.text, password: password?.text) { (error:NSError?) -> Void in
            if let _ = error {
                NSLog("Wrong credentials or no internet connectivity, please try again")
                NSLog("Error: " + error.debugDescription)
                self.errorLabel?.isHidden = false
            }
            else {
                NSLog("Logged in")
                self.successLabel?.isHidden = false
                self.loginButton?.isEnabled = false
            }
        }
    }
}
