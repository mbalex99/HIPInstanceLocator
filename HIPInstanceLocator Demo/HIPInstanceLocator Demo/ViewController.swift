//
//  ViewController.swift
//  HIPInstanceLocator Demo
//
//  Created by Steve Johnson on 7/29/16.
//  Copyright © 2016 Hipmunk, Inc. All rights reserved.
//

import UIKit
import HIPInstanceLocator

class ViewController: UIViewController {
    // normally you wouldn't pass the locator around, but since it's a demo and this is the root view controller,
    // we'll put it here so it can inject other things.
    var locator: HIPInstanceLocator!

    @IBAction func engageLocatorMagic(sender: AnyObject?) {
        let storyboard = HIPLocatorStoryboard(name: "ColorsAndNumbers", bundle: nil, locator: locator)
        guard let viewController = storyboard.instantiateInitialViewController() else {
            assertionFailure("Couldn't instantiate storyboard's view controller")
            return
        }
        self.presentViewController(viewController, animated: true, completion: nil)
    }
}

