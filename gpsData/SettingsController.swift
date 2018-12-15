//
//  SettingsController.swift
//  gpsData
//
//  Created by Taimir Aguacil on 14.12.18.
//  Copyright © 2018 Taimir Aguacil. All rights reserved.
//

import UIKit
import CoreLocation
import os.log

extension UITextField {
    func addDoneCancelToolbar(onDone: (target: Any, action: Selector)? = nil, onCancel: (target: Any, action: Selector)? = nil) {
        let onCancel = onCancel ?? (target: self, action: #selector(cancelButtonTapped))
        let onDone = onDone ?? (target: self, action: #selector(doneButtonTapped))
        
        let toolbar: UIToolbar = UIToolbar()
        toolbar.barStyle = .default
        toolbar.items = [
            UIBarButtonItem(title: "Cancel", style: .plain, target: onCancel.target, action: onCancel.action),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil),
            UIBarButtonItem(title: "Done", style: .done, target: onDone.target, action: onDone.action)
        ]
        toolbar.sizeToFit()
        
        self.inputAccessoryView = toolbar
    }
    
    // Default actions:
    @objc func doneButtonTapped() { self.resignFirstResponder() }
    @objc func cancelButtonTapped() { self.resignFirstResponder() }
}

class SettingsController: UIViewController, UITextFieldDelegate, UINavigationControllerDelegate {

    // MARK: Properties
    var iterations:Int?
    var locationVector : [CLLocation]?
    
    @IBOutlet weak var iterTextField: UITextField! {
        didSet { iterTextField?.addDoneCancelToolbar(onCancel: (target: self, action: #selector(onCancelTextField))) }
    }
    @IBOutlet weak var applyButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        iterTextField.delegate = self
        // Enable the Apply button only if all fields have valid content.
        updateSaveButtonState()
    }
    
    //MARK: UITextFieldDelegate
    @objc func onCancelTextField() {
        iterTextField.text=""
        iterTextField.resignFirstResponder()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Hide the keyboard
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        updateSaveButtonState()
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        updateSaveButtonState()
    }
    
    // MARK: - Navigation
    @IBAction func cancelButton(_ sender: Any) {
        let tmpController :UIViewController! = self.presentingViewController
        
        self.dismiss(animated: true, completion: {()->Void in
            tmpController.dismiss(animated: true, completion: nil)
        })
    }
    
    @IBAction func setDefault(_ sender: UIButton) {
        iterTextField.text="512"
    }
    
    
    // This method lets you configure a view controller before it's presented.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for : segue , sender: sender)
        // Configure the destination view controller only when the save button is pressed.
        /*guard let button = sender as? UIButton, button === applyButton else {
            os_log("The apply button was not pressed, cancelling", log: OSLog.default, type: .debug)
            return
        }*/
        
        switch(segue.identifier ?? "") {
        case "showReconstruct":
        iterations = Int(iterTextField.text!)
        guard let routeViewController = segue.destination as? RouteViewController else {
            fatalError("Unexpected destination: \(segue.destination)")
        }
        
        routeViewController.locationVector = locationVector
        if let CS = CompressSensing(inputLocationVector: locationVector!)
        {
            os_log("Computation starts...", log: OSLog.default, type: .debug)
            CS.setParam(maxIter: self.iterations!)
            routeViewController.est_coord = CS.compute()
        }
        default:
            fatalError("Unexpected Segue Identifier; \(String(describing: segue.identifier))")
        }
    }
    
    
    //MARK: Private Methods
    private func updateSaveButtonState() {
        // Disable the Save button if the text field is empty.
        let text = iterTextField.text ?? ""
        applyButton.isEnabled = !text.isEmpty
    }

}
