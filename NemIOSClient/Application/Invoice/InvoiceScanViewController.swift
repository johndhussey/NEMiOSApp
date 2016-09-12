//
//  InvoiceScanViewController.swift
//
//  This file is covered by the LICENSE file in the root of this project.
//  Copyright (c) 2016 NEM
//

import UIKit
import AddressBook
import AddressBookUI

class InvoiceScanViewController: UIViewController, QRCodeScannerDelegate, AddCustomContactDelegate
{
    @IBOutlet weak var qrScaner: QRCodeScannerView!
    
    private var _tempController: UIViewController? = nil
    private var _isInited = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        State.fromVC = SegueToScanQR

        qrScaner.delegate = self
    }
    override func viewDidAppear(animated: Bool) {
        if !_isInited {
            _isInited = true
            qrScaner.scanQRCode(qrScaner.frame.width , height: qrScaner.frame.height )
        }
//        State.currentVC = SegueToScanQR
    }

    func detectedQRCode(withCaptureResult text: String) {
        let base64String :String = text
        if base64String != "Empty scan" {
            let jsonData :NSData = text.dataUsingEncoding(NSUTF8StringEncoding)!
            var jsonStructure :NSDictionary? = nil

            jsonStructure = (try? NSJSONSerialization.JSONObjectWithData(jsonData, options: .MutableLeaves)) as? NSDictionary

            if jsonStructure == nil {
                qrScaner.captureSession.startRunning()
                return 
            }
            
            
            if let version = jsonStructure!.objectForKey(QRKeys.Version.rawValue) as? Int {
                if version != QR_VERSION {
                    failedDetectingQRCode(withError: "WRONG_QR_VERSION".localized())
                    self.qrScaner.captureSession.startRunning()
                    
                    return
                }
            } else {
                failedDetectingQRCode(withError: "WRONG_QR_VERSION".localized())
                self.qrScaner.captureSession.startRunning()
                return
            }
            
            switch (jsonStructure!.objectForKey(QRKeys.DataType.rawValue) as! Int) {
            case QRType.UserData.rawValue:
                
                let friendDictionary :NSDictionary = jsonStructure!.objectForKey(QRKeys.Data.rawValue) as! NSDictionary
                
//                if (AddressBookManager.isAllowed ?? false) {
//                    addFriend(friendDictionary)
//                }
//                else {
//                    failedDetectingQRCode(withError: "CONTACTS_IS_UNAVAILABLE".localized())
//                }
                
            case QRType.Invoice.rawValue:
                
                let invoiceDictionary :NSDictionary = jsonStructure!.objectForKey(QRKeys.Data.rawValue) as! NSDictionary
                
                performInvoice(invoiceDictionary)
                
            case QRType.AccountData.rawValue:
                jsonStructure = jsonStructure!.objectForKey(QRKeys.Data.rawValue) as? NSDictionary
                
                if jsonStructure != nil {
                    let privateKey_AES = jsonStructure!.objectForKey(QRKeys.PrivateKey.rawValue) as! String
                    let login = jsonStructure!.objectForKey(QRKeys.Name.rawValue) as! String
                    let salt = jsonStructure!.objectForKey(QRKeys.Salt.rawValue) as! String
                    let saltBytes = salt.asByteArray()
                    let saltData = NSData(bytes: saltBytes, length: saltBytes.count)
                    
//                    State.nextVC = SegueToLoginVC
                    State.importAccountData = {
                        (password) -> Bool in
                        
                        guard let passwordHash :NSData? = try? HashManager.generateAesKeyForString(password, salt:saltData, roundCount:2000) else {return false}
                        guard let privateKey :String = HashManager.AES256Decrypt(privateKey_AES, key: passwordHash!.toHexString()) else {return false}
                        guard let normalizedKey = privateKey.nemKeyNormalized() else { return false }
                        
                        if let name = Validate.account(privateKey: normalizedKey) {
                            let alert = UIAlertView(title: "VALIDATION".localized(), message: String(format: "VIDATION_ACCOUNT_EXIST".localized(), arguments:[name]), delegate: self, cancelButtonTitle: "OK".localized())
                            alert.show()
                            
                            return true
                        }
                        
                        WalletGenerator().createWallet(login, privateKey: normalizedKey)
                        
                        return true
                    }
                    
//                    if (self.delegate as? AbstractViewController)?.delegate != nil && (self.delegate as! AbstractViewController).delegate!.respondsToSelector(#selector(MainVCDelegate.pageSelected(_:))) {
//                        ((self.delegate as! AbstractViewController).delegate as! MainVCDelegate).pageSelected(SegueToPasswordValidation)
//                    }
                }
            default :
                qrScaner.captureSession.startRunning()
                break
            }
        }
    }
    
    func failedDetectingQRCode(withError errorMessage: String) {

        let alert :UIAlertController = UIAlertController(title: "INFO".localized(), message: errorMessage, preferredStyle: UIAlertControllerStyle.Alert)
        
        alert.addAction(UIAlertAction(title: "OK".localized(), style: UIAlertActionStyle.Default, handler: { (action) -> Void in
            alert.dismissViewControllerAnimated(true, completion: nil)
        }))
        
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    final func detectedQR(notification: NSNotification) {
            }
    
    final func performInvoice(invoiceDictionary :NSDictionary) {
        var invoice :InvoiceData = InvoiceData()
        
        invoice.address = invoiceDictionary.objectForKey(QRKeys.Address.rawValue) as! String
        invoice.name = invoiceDictionary.objectForKey(QRKeys.Name.rawValue) as! String
        invoice.amount = invoiceDictionary.objectForKey(QRKeys.Amount.rawValue) as! Double / 1000000
        invoice.message = invoiceDictionary.objectForKey(QRKeys.Message.rawValue) as! String
        
        State.invoice = invoice
        
        if State.invoice != nil {
//            let navDelegate = (self.delegate as? InvoiceViewController)?.delegate as? MainVCDelegate
//            if navDelegate != nil  {
//                navDelegate!.pageSelected(SegueToSendTransaction)
//            }
            
            performSegueWithIdentifier("showTransactionSendViewController", sender: nil)
        }

    }
    
    final func addFriend(friendDictionary :NSDictionary) {
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        let contactCustomVC :AddressBookAddContactViewController =  storyboard.instantiateViewControllerWithIdentifier("AddressBookAddContactViewController") as! AddressBookAddContactViewController
        contactCustomVC.view.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height)
        contactCustomVC.view.layer.opacity = 0
//        contactCustomVC.delegate = self
        
        contactCustomVC.firstName.text = friendDictionary.objectForKey(QRKeys.Name.rawValue) as? String
        contactCustomVC.lastName.text = friendDictionary.objectForKey("surname") as? String
        contactCustomVC.address.text = friendDictionary.objectForKey(QRKeys.Address.rawValue) as? String
        _tempController = contactCustomVC
        
        self.view.addSubview(contactCustomVC.view)
        
        UIView.animateWithDuration(0.5, animations: { () -> Void in
            contactCustomVC.view.layer.opacity = 1
            }, completion: nil)

    }
  
    // MARK: -  AddCustomContactDelegate

    func contactAdded(successfuly: Bool, sendTransaction :Bool) {
        if successfuly {
//            let navDelegate = (self.delegate as? InvoiceViewController)?.delegate as? MainVCDelegate
//            if navDelegate != nil  {
//                if sendTransaction {
//                    let correspondent :Correspondent = Correspondent()
//                    
//                    for email in AddressBookViewController.newContact!.emailAddresses{
//                        if email.label == "NEM" {
//                            correspondent.address = (email.value as? String) ?? " "
//                            correspondent.name = correspondent.address.nemName()
//                        }
//                    }
//                    State.currentContact = correspondent
//                }
//                navDelegate!.pageSelected(sendTransaction ? SegueToSendTransaction : SegueToAddressBook)
//            }
        }
    }
    
    func popUpClosed(successfuly :Bool) {
        qrScaner.captureSession.startRunning()
    }
    
    func contactChanged(successfuly: Bool, sendTransaction :Bool) {

    }
}
