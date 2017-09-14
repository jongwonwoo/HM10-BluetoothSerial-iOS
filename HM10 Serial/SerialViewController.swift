//
//  SerialViewController.swift
//  HM10 Serial
//
//  Created by Alex on 10-08-15.
//  Copyright (c) 2015 Balancing Rock. All rights reserved.
//

import UIKit
import CoreBluetooth
import QuartzCore

/// The option to add a \n or \r or \r\n to the end of the send message
enum MessageOption: Int {
    case noLineEnding,
         newline,
         carriageReturn,
         carriageReturnAndNewline
}

/// The option to add a \n to the end of the received message (to make it more readable)
enum ReceivedMessageOption: Int {
    case none,
         newline
}

final class SerialViewController: UIViewController, UITextFieldDelegate, BluetoothSerialDelegate {

//MARK: IBOutlets
    
    @IBOutlet weak var mainTextView: UITextView!
    
    @IBOutlet weak var bottomView: UIView!
    
    @IBOutlet weak var barButton: UIBarButtonItem!
    @IBOutlet weak var navItem: UINavigationItem!


//MARK: Functions
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // init serial
        serial = BluetoothSerial(delegate: self)
        
        // UI
        mainTextView.text = ""
        reloadView()
        
        NotificationCenter.default.addObserver(self, selector: #selector(SerialViewController.reloadView), name: NSNotification.Name(rawValue: "reloadStartViewController"), object: nil)
        
        // style the bottom UIView
        bottomView.layer.masksToBounds = false
        bottomView.layer.shadowOffset = CGSize(width: 0, height: -1)
        bottomView.layer.shadowRadius = 0
        bottomView.layer.shadowOpacity = 0.5
        bottomView.layer.shadowColor = UIColor.gray.cgColor
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func reloadView() {
        // in case we're the visible view again
        serial.delegate = self
        
        if serial.isReady {
            navItem.title = serial.connectedPeripheral!.name
            barButton.title = "Disconnect"
            barButton.tintColor = UIColor.red
            barButton.isEnabled = true
        } else if serial.centralManager.state == .poweredOn {
            navItem.title = "Bluetooth Serial"
            barButton.title = "Connect"
            barButton.tintColor = view.tintColor
            barButton.isEnabled = true
        } else {
            navItem.title = "Bluetooth Serial"
            barButton.title = "Connect"
            barButton.tintColor = view.tintColor
            barButton.isEnabled = false
        }
    }
    
    func textViewScrollToBottom() {
        let range = NSMakeRange(NSString(string: mainTextView.text).length - 1, 1)
        mainTextView.scrollRangeToVisible(range)
    }
    

//MARK: BluetoothSerialDelegate
    
    func serialDidReceiveString(_ message: String) {
        // add the received text to the textView, optionally with a line break at the end
        mainTextView.text! += message
        let pref = UserDefaults.standard.integer(forKey: ReceivedMessageOptionKey)
        if pref == ReceivedMessageOption.newline.rawValue { mainTextView.text! += "\n" }
        textViewScrollToBottom()
    }
    
    func serialDidDisconnect(_ peripheral: CBPeripheral, error: NSError?) {
        reloadView()
        let hud = MBProgressHUD.showAdded(to: view, animated: true)
        hud?.mode = MBProgressHUDMode.text
        hud?.labelText = "Disconnected"
        hud?.hide(true, afterDelay: 1.0)
    }
    
    func serialDidChangeState() {
        reloadView()
        if serial.centralManager.state != .poweredOn {
            let hud = MBProgressHUD.showAdded(to: view, animated: true)
            hud?.mode = MBProgressHUDMode.text
            hud?.labelText = "Bluetooth turned off"
            hud?.hide(true, afterDelay: 1.0)
        }
    }
    
    @IBAction func directionButtonPressed(_ sender: UIButton) {
        guard let directionString = sender.titleLabel?.text else { return }
        
        switch directionString {
        case "◻︎":
            sendMessage("s")
        case "▲":
            sendMessage("f")
        case "▶︎":
            sendMessage("r")
        case "▼":
            sendMessage("b")
        case "◀︎":
            sendMessage("l")
        default:
            break
        }
    }
    
    func sendMessage(_ message: String) {
        print(message)
        
        if !serial.isReady {
            let alert = UIAlertController(title: "Not connected", message: "What am I supposed to send this to?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.default, handler: { action -> Void in self.dismiss(animated: true, completion: nil) }))
            present(alert, animated: true, completion: nil)
            
            return
        }
        
        // send the message to the bluetooth device
        // but fist, add optionally a line break or carriage return (or both) to the message
        let pref = UserDefaults.standard.integer(forKey: MessageOptionKey)
        var msg = message
        switch pref {
        case MessageOption.newline.rawValue:
            msg += "\n"
        case MessageOption.carriageReturn.rawValue:
            msg += "\r"
        case MessageOption.carriageReturnAndNewline.rawValue:
            msg += "\r\n"
        default:
            msg += ""
        }
        
        // send the message and clear the textfield
        serial.sendMessageToDevice(msg)
    }
    
    
//MARK: IBActions

    @IBAction func barButtonPressed(_ sender: AnyObject) {
        if serial.connectedPeripheral == nil {
            performSegue(withIdentifier: "ShowScanner", sender: self)
        } else {
            serial.disconnect()
            reloadView()
        }
    }
}
