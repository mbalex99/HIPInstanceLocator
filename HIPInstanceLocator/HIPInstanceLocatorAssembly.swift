//
//  HIPInstanceLocatorAssembly.swift
//  Hipmunk
//
//  Created by Jesus Fernandez on 3/8/16.
//  Copyright © 2016 Hipmunk. All rights reserved.
//

import Foundation

/** 
 Instance locator assemblies are used to encapsulate a set of locator registrations so that they may be located near
 code that uses them. Assemblies are applied to instance locators using the `assemble` method.
 
 You might want to use these if you have a high quantity of types to be injected.
 
 Example:
 
 ```swift
 let servicesAssembly = HIPInstanceLocatorAssembly() {
    locator in
    locator.registerFactory(AService.self) { return AService()) }
    locator.registerFactory(AnotherService.self) { return AnotherService() }
 }
 
 let modelsAssembly = HIPInstanceLocatorAssembly() {
    locator in
    locator.registerFactory(AModel.self) { return AModel(aService: $0.implicitGet()) }
    locator.registerFactory(AnotherModel.self) { return AnotherModel(anotherService: $0.implicitGet()) }
 }
 
 let locator = HIPInstanceLocator()
 locator.assemble(servicesAssembly, modelsAssembly)
 ```
 */
public struct HIPInstanceLocatorAssembly {
    fileprivate let _assemblyBlock: (HIPInstanceLocator) -> Void

    /** 
     Creates a new instance locator assembly with the given assembly block. The block is executed whenever this
     assembly is applied to an instance locator.
     */
    public init(assemblyBlock: @escaping (HIPInstanceLocator) -> Void) {
        _assemblyBlock = assemblyBlock
    }
}

public extension HIPInstanceLocator {
    /**
     Applies one or more assemblies to this instance locator. Each assembly is applied in order. If the same dependency
     is registered or injected more than once, then this will throw a debug assert in the same way that would happen if
     those dependencies were registered or injected outside of an assembly.
     */
    public func assemble(_ assemblies: HIPInstanceLocatorAssembly...) {
        assemblies.forEach { $0._assemblyBlock(self) }
    }
}
