//
//  LocationTableViewCell.swift
//  gpsData
//
//  Created by Taimir Aguacil on 10.08.18.
//  Copyright © 2018 Taimir Aguacil. All rights reserved.
//

import UIKit

class LocationTableViewCell: UITableViewCell {

    @IBOutlet weak var acqVal: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
