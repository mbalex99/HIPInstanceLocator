//
//  ColorAndNumberViewController.swift
//  HIPInstanceLocator Demo
//
//  Created by Steve Johnson on 7/29/16.
//  Copyright © 2016 Hipmunk, Inc. All rights reserved.
//

import Foundation
import UIKit


class ColorAndNumberViewController: UIViewController {
    var favoriteColors: FavoriteColors!
    var favoriteNumbers: FavoriteNumbers!

    @IBOutlet var colorView1: UIView!
    @IBOutlet var colorView2: UIView!
    @IBOutlet var colorView3: UIView!
    var colorViews: [UIView] {
        return [self.colorView1, self.colorView2, self.colorView3]
    }

    @IBOutlet var numbersLabel: UILabel!

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        for (i, color) in favoriteColors.colors.enumerate() {
            colorViews[i].backgroundColor = color
        }
        let favoriteNumbersString = favoriteNumbers.numbers.map({"\($0)"}).joinWithSeparator(", ")
        numbersLabel.text = "Your favorite numbers are: \(favoriteNumbersString)"
    }
}