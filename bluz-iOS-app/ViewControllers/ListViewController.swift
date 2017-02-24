//
//  ListViewController.swift
//  bluz-iOS-app
//
//  Created by ShangWang on 11/27/16.
//  Copyright © 2016 ShangWang. All rights reserved.
//

import UIKit

class ListViewController: UITableViewController {
    @IBOutlet var scanButton: UIButton?
    @IBOutlet var loginButton: UIButton?
    @IBOutlet var navBar: UINavigationItem?
    
    var bleManager: BLEManager!
    var scanTimer: Timer!
    
    var scanning = false;

    override func viewDidLoad() {
        super.viewDidLoad()
            
        scanButton!.addTarget(self, action: #selector(ListViewController.scanButtonPressed(_:)), for: .touchUpInside)
        loginButton!.addTarget(self, action: #selector(ListViewController.loginButtonPressed(_:)), for: .touchUpInside)
        
        bleManager = BLEManager()
        bleManager.registerCallback(bleManagerCallback)
        self.startScanning()
        
        UIApplication.shared().isIdleTimerDisabled = true
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if SparkCloud.sharedInstance().isLoggedIn {
            loginButton!.setTitle("Logout", for: UIControlState())
        } else {
            loginButton!.setTitle("Login", for: UIControlState())
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return bleManager.peripheralCount()
    }
    
    func startScanning() {
        scanning = true
        scanButton!.setTitle("Scanning...", for: UIControlState())
        scanButton!.isEnabled = false
        bleManager.clearScanResults()
        self.tableView.reloadData()
        self.startScanningWithTimer()
        let _ = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(ListViewController.stopScanning), userInfo: nil, repeats: false)
    }
    
    func startScanningWithTimer() {
        bleManager.startScanning()
        scanTimer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(ListViewController.restartScanning), userInfo: nil, repeats: false)
    }
    
    func restartScanning() {
        if scanning {
            bleManager.stopScanning();
            startScanningWithTimer();
        }
    }
    
    func stopScanning() {
        if let _ = self.scanTimer {
            self.scanTimer.invalidate()
        }
        scanning = false
        scanButton!.setTitle("Scan", for: UIControlState())
        scanButton!.isEnabled = true
        bleManager.stopScanning()
    }
    
    func scanButtonPressed(_ sender: UIButton!) {
        self.startScanning()
    }
    
    func loginButtonPressed(_ sender: UIButton!) {
        if SparkCloud.sharedInstance().isLoggedIn {
            SparkCloud.sharedInstance().logout()
            loginButton!.setTitle("Login", for: UIControlState())
        } else {
            performSegue(withIdentifier: "showLoginSegue", sender: nil)
        }
    }
    
    func connectButtonPressed(_ sender: UIButton!) {
        if let peripheral = bleManager.peripheralAtIndex(sender.tag) {
            if (peripheral.state == BLEDeviceState.connected) {
                bleManager.disconnectPeripheral(peripheral)
                sender.isEnabled = false;
                sender.setTitle("Disconnecting...", for: UIControlState())
            } else {
                bleManager.connectPeripheral(peripheral)
                sender.isEnabled = false;
                sender.setTitle("Connecting...", for: UIControlState())
            }
        }
    }
    
    func claimButtonPressed(_ sender: UIButton!) {
        sender.isEnabled = false
        if let peripheral = bleManager.peripheralAtIndex(sender.tag) {
            SparkCloud.sharedInstance().claimDevice(peripheral.cloudId as String, completion: { (error:NSError?) -> Void in
                if let _ = error {
                    NSLog("Unable to claim device")
                    NSLog("Error: " + error.debugDescription)
                }
                else {
                    sender.isHidden = true
                    NSLog("Claimed")
                    peripheral.isClaimed = true
                }
            })
        }
    }
    
    func bleManagerCallback(_ event: BLEManager.BLEManagerEvent, peripheral: BLEDeviceInfo) {
        switch (event)
        {
            case BLEManager.BLEManagerEvent.deviceUpdated:
                let row = bleManager.indexOfPeripheral(peripheral)
                let indexPath = IndexPath(row: row!, section:0)
                self.tableView.reloadRows(at: [indexPath], with: UITableViewRowAnimation.none)
                break;
            case BLEManager.BLEManagerEvent.deviceDiscovered:
//                self.tableView.reloadData()
                let row = bleManager.indexOfPeripheral(peripheral)
                let indexPath = IndexPath(row: row!, section:0)
                self.tableView.insertRows(at: [indexPath], with: UITableViewRowAnimation.left)
                break;
            case BLEManager.BLEManagerEvent.deviceConnected:
                let row = bleManager.indexOfPeripheral(peripheral)
                let indexPath = IndexPath(row: row!, section:0)
                self.tableView.cellForRow(at: indexPath)
                if let cell: ListCellViewController = self.tableView.cellForRow(at: indexPath) as? ListCellViewController {
                    cell.connectButton!.isEnabled = true
                    cell.connectButton!.setTitle("Disconnect", for: UIControlState())
//                    cell.connectButton!.backgroundColor = UIColor(red: 209, green: 54, blue: 0, alpha: 1)
                }
                break;
            case BLEManager.BLEManagerEvent.deviceDisconnected:
                let row = bleManager.indexOfPeripheral(peripheral)
                let indexPath = IndexPath(row: row!, section:0)
                if let cell: ListCellViewController = self.tableView.cellForRow(at: indexPath) as? ListCellViewController {
                    cell.connectButton!.setTitle("Connect", for: UIControlState())
                    cell.connectButton!.isEnabled = true
//                    cell.connectButton!.backgroundColor = UIColor(red: 45, green: 145, blue: 93, alpha: 1)
                }
                break;
            case BLEManager.BLEManagerEvent.bleRadioChange:
                break;
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: ListCellViewController = tableView.dequeueReusableCell(withIdentifier: "BLECell", for: indexPath) as! ListCellViewController
        
        if let peripheral = bleManager.peripheralAtIndex((indexPath as NSIndexPath).row) {
            cell.claimButton!.isEnabled = false
            cell.claimButton!.isHidden = true
            
            cell.selectionStyle = UITableViewCellSelectionStyle.none
            cell.deviceName!.text = peripheral.peripheral!.name
            cell.deviceRSSI!.text = "RSSI: " + (peripheral.rssi.intValue > 0 ? "?" : peripheral.rssi.stringValue)
            cell.deviceServices!.text = String(peripheral.numberOfServices()) + " Services"
            
            cell.cloudId!.text = peripheral.cloudId as String
            cell.cloudName!.text = peripheral.cloudName as String
            
            if peripheral.isBluzCompatible() {
                cell.logo?.image = UIImage(named: "bluz_hw")
                cell.connectButton!.isHidden = false
                cell.connectButton!.isEnabled = true
                
                cell.connectButton!.tag = (indexPath as NSIndexPath).row
                cell.connectButton!.addTarget(self, action: #selector(ListViewController.connectButtonPressed(_:)), for: .touchUpInside)
                
                if (peripheral.state == BLEDeviceState.connected) {
                    cell.connectButton!.setTitle("Disconnect", for: UIControlState())
//                    cell.connectButton!.backgroundColor = UIColor(red: 209, green: 54, blue: 0, alpha: 1)
                    
                    if peripheral.cloudId != "" && !peripheral.isClaimed {
                        cell.claimButton!.tag = (indexPath as NSIndexPath).row
                        cell.claimButton!.isEnabled = true
                        cell.claimButton!.isHidden = false
                        cell.claimButton!.addTarget(self, action: #selector(ListViewController.claimButtonPressed(_:)), for: .touchUpInside)
                    }
                    
                } else {
                    cell.connectButton!.setTitle("Connect", for: UIControlState())
//                    cell.connectButton!.backgroundColor = UIColor(red: 45, green: 145, blue: 93, alpha: 1)
                }
                
            } else {
                cell.logo?.image = UIImage(named: "Bluetooth_Logo")
                cell.connectButton!.isHidden = true
                cell.connectButton!.isEnabled = false
            }
        }
        
        // Configure the cell...
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120;
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            // Delete the row from the data source
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
