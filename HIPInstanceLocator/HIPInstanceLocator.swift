//
//  HIPInstanceLocator.swift
//  Hipmunk
//
//  Created by Jesus Fernandez on 3/1/16.
//  Copyright © 2016 Hipmunk. All rights reserved.
//

import Foundation

/**
 Exceptions that may be thrown by `HIPInstanceLocator`.
 */
public enum LocatorError : ErrorType {
    case StoredDependencyWasNotOfExpectedType
    case FactoryDidNotReturnExpectedType
    case SharedInstanceWasNotOfExpectedType
    case NoDependencyRegisteredForType
}

/**
 An implementation of the service locator pattern. Provides a place to register and get shared instances of classes for
 a specific context. Instances are registered using factory blocks, which are lazily instantiated on demand.
 */
@objc public class HIPInstanceLocator: NSObject {
    private var _registeredInstances: [String: _Instance] = Dictionary()
    private var _registeredInjectors: [String: _Injector] = Dictionary()
    private let _lock = NSObject()

    /**
     Initializes a locator instance; the assembly block is executed immediately after initialization.
     */
    public convenience init(assemblyBlock:HIPInstanceLocator -> Void) {
        self.init()
        assemblyBlock(self)
    }

    /**
     Register an factory method for the specified type. The factory block is called the first time `get()` is called
     for this type. Subsequent calls to `get()` return cached instances.
     - Return:
         - `true` if the factory method was successfully registered.
     */
    public func registerFactory<T>(key:T.Type, factory:HIPInstanceLocator -> T) -> Bool {
        return _setInstanceForKey("\(T.self)", instance: .Uninitialized(factory))
    }

    /**
     Register an existing shared instance for the specified type. Instances registered this way are assumed to be
     retained elsewhere, so the locator will only hold a weak reference to it.
     - Return:
         - `true` if the shared instance was successfully registered.
     - Note: The shared instance must be a class instance.
     */
    public func register<T>(key:T.Type, sharedInstance: T) -> Bool {
        guard let sharedObject = sharedInstance as? AnyObject else { return false }
        let box = _Instance.SharedBox(value: sharedObject)
        return _setInstanceForKey("\(T.self)", instance: .Shared(box))
    }

    /**
     Registers an injector method for the specified type. The injector method is called once for each instance created
     by the instance locator. The injector is also used for objects initialized in storyboards.
     */
    public func injectInstancesOf<T>(key: T.Type, injector:((HIPInstanceLocator, T) -> Void)) -> Bool {
        return _setInjectorForKey("\(T.self)") {
            /// Wrapping the injector function in this way seems to be necessary for downcasting to _Injector for
            /// storage in the injector dictionary in a way that the compiler is okay with.
            locator, anyInstance in
            guard let instance = anyInstance as? T else { return }
            injector(locator, instance)
        }
    }

    /**
     Gets an instance of a previously registered type. If an instance was not already created, it will be initialized. 
     If this type was not registered, this returns nil and throws a debug assert.
     - Parameters:
        - _: Type of instance to get.
     */
    public func getInstanceOf<T>(_:T.Type) -> T! { return try? _getWithKey("\(T.self)") }

    /**
     Implicitly gets an instance of a previously registered type. If an instance was not already created, it will be 
     initialized. If this type was not registered, this returns nil and throws a debug assert.
     Use this method when the return type can be inferred, such as initializer or method parameters.
     */
    public func implicitGet<T>() -> T! { return try? _getWithKey("\(T.self)") }
}

/// MARK: - ObjC Bridging

public extension HIPInstanceLocator {
    /**
     Get an instance for a class.
    */
    @objc public func objc_getInstanceOfClass(aClass: AnyClass) -> AnyObject! {
        return try? _getWithKey("\(aClass)")
    }

    /**
     Applies previously registered injector to an instance.
     */
    @objc public func objc_applyInjector(aClass: AnyClass, toInstance instance: AnyObject) -> Bool {
        return _applyInjector("\(aClass)", instance: instance)
    }
}

/// MARK: - Internals

private extension HIPInstanceLocator {
    private enum _Instance {
        private struct SharedBox {
            weak var value: AnyObject?
        }
        case Uninitialized(HIPInstanceLocator -> Any)
        case Initialized(Any)
        case Shared(SharedBox)
    }
    private typealias _Injector = (HIPInstanceLocator, Any) -> (Void)

    func _getWithKey<T>(key: String) throws -> T! {
        objc_sync_enter(_lock)
        defer { objc_sync_exit(_lock) }

        switch _registeredInstances[key] {
            case .Some(.Initialized(let instance)):
                guard let definiteInstance = instance as? T else {
                    throw LocatorError.StoredDependencyWasNotOfExpectedType
                }
                return definiteInstance
            case .Some(.Uninitialized(let factory)):
                guard let instance = factory(self) as? T else {
                    throw LocatorError.FactoryDidNotReturnExpectedType
                }
                _registeredInstances[key] = .Initialized(instance)
                _registeredInjectors[key]?(self, instance)
                return instance
            case .Some(.Shared(let box)):
                guard let definiteInstance = box.value as? T else {
                    throw LocatorError.SharedInstanceWasNotOfExpectedType
                }
                return definiteInstance
            case .None:
                throw LocatorError.NoDependencyRegisteredForType
        }
    }

    func _setInstanceForKey(key: String, instance: _Instance) -> Bool {
        objc_sync_enter(_lock)
        defer { objc_sync_exit(_lock) }

        guard _registeredInstances[key] == nil else {
//            assertionFailure("Attempted to register a dependency when one already exists for type: \(key)")
            return false
        }
        _registeredInstances[key] = instance
        return true
    }

    func _setInjectorForKey(key: String, injector: _Injector) -> Bool {
        objc_sync_enter(_lock)
        defer { objc_sync_exit(_lock) }

        guard _registeredInjectors[key] == nil else {
//            assertionFailure("Attempted to register an injector when one already exists for type: \(key)")
            return false
        }
        _registeredInjectors[key] = injector
        return true
    }

    func _applyInjector<T>(key: String, instance: T) -> Bool {
        objc_sync_enter(_lock)
        defer { objc_sync_exit(_lock) }

        guard let injector = _registeredInjectors[key] else { return false }
        injector(self, instance)
        return true
    }
}