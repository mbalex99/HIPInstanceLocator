//
//  TestLocatorStoryboard.swift
//  Hipmunk
//
//  Created by Jesus Fernandez on 3/8/16.
//  Copyright © 2016 Hipmunk. All rights reserved.
//

import UIKit
import XCTest
@testable import HIPInstanceLocator

private class TestLocatorStoryboardDependency {
}

class TestLocatorStoryboardViewController: UIViewController {
    private var innerInstance: TestLocatorStoryboardDependency!
}

/**
 This test is a little weird, since I'm using a Swift test case to test an ObjC implementation, but that's cause
 the injector doesn't have an ObjC registration API
 */
class TestLocatorStoryboard: XCTestCase {
    func testLocatorStoryboard() {
        let locator = HIPInstanceLocator()
        locator.registerFactory(TestLocatorStoryboardDependency.self) { _ in return TestLocatorStoryboardDependency() }
        locator.injectInstancesOf(TestLocatorStoryboardViewController.self) {
            $1.innerInstance = $0.implicitGet()
        }

        let bundle = NSBundle(forClass: TestLocatorStoryboard.self)
        let storyboard = HIPLocatorStoryboard(name: "TestLocatorStoryboard", bundle: bundle, locator: locator)

        let viewController =
            storyboard.instantiateViewControllerWithIdentifier("TestLocatorStoryboardViewController")
                as? TestLocatorStoryboardViewController

        XCTAssertNotNil(viewController)
        XCTAssertNotNil(viewController?.innerInstance)
    }
}