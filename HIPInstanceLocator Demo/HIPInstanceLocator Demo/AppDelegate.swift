//
//  AppDelegate.swift
//  HIPInstanceLocator Demo
//
//  Created by Steve Johnson on 7/29/16.
//  Copyright © 2016 Hipmunk, Inc. All rights reserved.
//

import UIKit
import HIPInstanceLocator

let favoriteColorSingletonAntipatternInstance = FavoriteColors()

let dependenciesAssembly = HIPInstanceLocatorAssembly(assemblyBlock: {
    locator in
    locator.register(FavoriteColors.self, sharedInstance: favoriteColorSingletonAntipatternInstance)
    locator.registerFactory(FavoriteNumbers.self) {
        _ in
        return FavoriteNumbers()
    }
})

let viewControllersAssembly = HIPInstanceLocatorAssembly(assemblyBlock: {
    locator in

    // Give the root view controller a reference to the locator so it can bootstrap a HIPLocatorStoryboard
    locator.injectInstancesOf(ViewController.self) {
        locator, viewController in
        print("Injecting ViewController")
        viewController.locator = locator
    }

    // All other view controllers should not need the locator
    locator.injectInstancesOf(ColorAndNumberViewController.self) {
        locator, viewController in
        print("Injecting ColorAndNumberViewController")
        viewController.favoriteColors = locator.implicitGet()
        viewController.favoriteNumbers = locator.implicitGet()
    }
})


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        let locator = HIPInstanceLocator()
        locator.assemble(dependenciesAssembly, viewControllersAssembly)

        if let rootViewController = window?.rootViewController as? ViewController {
            locator.applyInjector(rootViewController)
        } else {
            assertionFailure("Root view controller isn't what we expected")
        }
        return true
    }
}

