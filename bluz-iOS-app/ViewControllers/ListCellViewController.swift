//
//  ListCellViewController.swift
//  bluz-iOS-app
//
//  Created by ShangWang on 12/1/16.
//  Copyright © 2016 ShangWang. All rights reserved.
//

import UIKit

class ListCellViewController: UITableViewCell {
    @IBOutlet var deviceName: UILabel?
    @IBOutlet var deviceRSSI: UILabel?
    @IBOutlet var deviceServices: UILabel?
    @IBOutlet var cloudName: UILabel?
    @IBOutlet var cloudId: UILabel?
    @IBOutlet var logo: UIImageView?
    @IBOutlet var connectButton: UIButton?
    @IBOutlet var claimButton: UIButton?
}
