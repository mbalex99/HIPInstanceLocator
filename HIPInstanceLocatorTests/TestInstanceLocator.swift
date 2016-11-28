//
//  TestInstanceLocator.swift
//  Hipmunk
//
//  Created by Jesus Fernandez on 3/2/16.
//  Copyright © 2016 Hipmunk. All rights reserved.
//

import XCTest
@testable import HIPInstanceLocator

private class TestClass {
    let innerValue: String
    init(innerValue: String = "DEFAULT"){
        self.innerValue = innerValue
    }
}

@objc private protocol TestDependable { }
private class TestDependent: TestDependable {
    let innerInstance: TestClass

    init(innerInstance: TestClass) {
        self.innerInstance = innerInstance
    }
}

private class TestInjected {
    var innerInstance: TestClass!
}

class TestInstanceLocator: XCTestCase {
    var instanceLocator: HIPInstanceLocator!

    var lastError: Error?

    override func setUp() {
        instanceLocator = HIPInstanceLocator(errorCallback: {[weak self] e in self?.lastError = e})
    }

    func testAlwaysReturnsTheSameRegisteredInstance() {
        instanceLocator.registerFactory(TestClass.self) { _ in return TestClass() }

        let instance1 = instanceLocator.getInstanceOf(TestClass.self)
        let instance2: TestClass = instanceLocator.implicitGet()

        XCTAssert(instance1 === instance2)
    }

    func testFailsToReturnIfNotRegistered() {
        XCTAssertNil(instanceLocator.getInstanceOf(TestClass.self))
        switch lastError! {
        case LocatorError.noDependencyRegisteredForType: break
        default: XCTFail("Error was not of expected type")
        }
    }

    func testFailsToRegisterIfAlreadyRegistered() {
        instanceLocator.registerFactory(TestClass.self) { _ in return TestClass() }
        XCTAssertFalse(instanceLocator.registerFactory(TestClass.self) { _ in return TestClass(innerValue: "FAIL") })
        switch lastError! {
        case LocatorError.triedToRegisterTooManyFactories: break
        default: XCTFail("Error was not of expected type")
        }

        let instance = instanceLocator.getInstanceOf(TestClass.self)
        XCTAssertEqual(instance.innerValue, "DEFAULT")
    }

    func testAlwaysReturnsTheSameRegisteredInstance_Multithreaded() {
        instanceLocator.registerFactory(TestClass.self) { _ in return TestClass() }

        var instances = [TestClass]()
        let instancesQueue = DispatchQueue(label: "com.hipmunk.testInstanceLocator.instancesQueue", attributes: [])
        let iterationQueue = DispatchQueue(label: "com.hipmunk.testInstanceLocator.iterationQueue", attributes: DispatchQueue.Attributes.concurrent)

        let expectation = self.expectation(description: "finished iterations")
        DispatchQueue.concurrentPerform(iterations: 10) {
            [weak self] index in
            guard let instance: TestClass = self?.instanceLocator.implicitGet() else { return }
            instancesQueue.async {
                instances.append(instance)
                if index == 9 {
                    expectation.fulfill()
                }
            }
        }

        waitForExpectations(timeout: 1.0, handler: nil)
        let areAllInstancesEqual = instances.reduce(true) { return $0 && $1 === instances[0] }
        XCTAssert(areAllInstancesEqual)
    }

    func testInternalDependenciesAreCreatedOnDemand() {
        instanceLocator.registerFactory(TestClass.self) { _ in return TestClass() }
        instanceLocator.registerFactory(TestDependent.self) { return TestDependent(innerInstance: $0.implicitGet()) }

        let dependent = instanceLocator.getInstanceOf(TestDependent.self)
        let instance = instanceLocator.getInstanceOf(TestClass.self)

        XCTAssert(dependent.innerInstance === instance)
    }

/// MARK: - ObjC bridging

    func testBridgedAPIReturnsSameInstanceAsSwiftAPI_Class() {
        instanceLocator.registerFactory(TestClass.self) { _ in return TestClass() }

        let swiftInstance: TestClass = instanceLocator.implicitGet()
        let objCInstance = instanceLocator.objc_getInstanceOfClass(TestClass.self)

        XCTAssert(swiftInstance === objCInstance)
    }

/// MARK: - Injection

    func testInjectorIsRunAfterFactoryInitialization() {
        instanceLocator.registerFactory(TestClass.self) { _ in return TestClass() }
        instanceLocator.registerFactory(TestInjected.self) { _ in return TestInjected() }
        instanceLocator.injectInstancesOf(TestInjected.self) {
            $1.innerInstance = $0.implicitGet()
        }

        let injected = instanceLocator.getInstanceOf(TestInjected.self)
        XCTAssertNotNil(injected.innerInstance)
    }

    func testFailsToSetInjectorIfOneIsAlreadySet() {
        instanceLocator.registerFactory(TestInjected.self) { _ in return TestInjected() }
        instanceLocator.injectInstancesOf(TestInjected.self) { $1.innerInstance = TestClass() }

        XCTAssertFalse(instanceLocator.injectInstancesOf(TestInjected.self) {
            $1.innerInstance = TestClass(innerValue: "FAIL")
        })
        switch lastError! {
        case LocatorError.triedToRegisterTooManyInjectors: break
        default: XCTFail("Error was not of expected type")
        }

        let instance = instanceLocator.getInstanceOf(TestInjected.self)
        XCTAssertEqual(instance.innerInstance.innerValue, "DEFAULT")
    }

/// MARK: - Shared Instances

    func testSharedInstances() {
        let sharedClass = TestClass()
        instanceLocator.register(TestClass.self, sharedInstance: sharedClass)
        XCTAssert(sharedClass === instanceLocator.getInstanceOf(TestClass.self))
    }

    func testSharedInstances_AreNotRetainedByTheLocator() {
        var sharedClass: TestClass? = TestClass()
        instanceLocator.register(TestClass.self, sharedInstance: sharedClass!)
        sharedClass = nil

        XCTAssertNil(instanceLocator.getInstanceOf(TestClass.self))
    }

    func testFailsToRegisterSharedInstanceIfFactoryWasRegistered() {
        let sharedClass = TestClass()
        instanceLocator.registerFactory(TestClass.self) { _ in return TestClass() }
        XCTAssertFalse(instanceLocator.register(TestClass.self, sharedInstance: sharedClass))
        switch lastError! {
        case LocatorError.triedToRegisterTooManyFactories: break
        default: XCTFail("Error was not of expected type")
        }
        XCTAssert(sharedClass !== instanceLocator.getInstanceOf(TestClass.self))
    }

}
