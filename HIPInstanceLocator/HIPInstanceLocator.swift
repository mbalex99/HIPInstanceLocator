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
public enum LocatorError : Error {
    /// No shared instance or factory was registered for this type. You probably just forgot.
    case noDependencyRegisteredForType

    /// The factory passed to `HIPInstanceLocator.registerFactory(_:factory)` did not have the expected type.
    case factoryDidNotReturnExpectedType

    /// A dependency stored using `HIPInstanceLocator.register(_:sharedInstance)` did not have the expected type.
    case sharedInstanceWasNotOfExpectedType

    /// The stored return value of the factory passed to `HIPInstanceLocator.registerFactory(_:factory)`
    /// for the given type did not have the expected type. If you see this, there is probably a bug in the
    /// framework.
    case storedDependencyWasNotOfExpectedType

    /// You tried to register more than one factory for the given type
    case triedToRegisterTooManyFactories

    /// You tried to register more than one injector for the given type
    case triedToRegisterTooManyInjectors

}

private let DEFAULT_ERROR_CALLBACK = {
    (e: Error) in assertionFailure("\(e)")
}

/**
 An implementation of the service locator pattern. Provides a place to register and get shared instances of classes for
 a specific context. Instances are registered using factory blocks, which are lazily instantiated on demand.
 */
@objc open class HIPInstanceLocator: NSObject {
    fileprivate var _registeredInstances: [String: _Instance] = Dictionary()
    fileprivate var _registeredInjectors: [String: _Injector] = Dictionary()
    fileprivate let _lock = NSObject()
    fileprivate let _errorCallback: ((Error) -> ())

    /**
     Initializes a locator instance

     - Parameter errorCallback: Block to be called when an error occurs. If you leave it alone, it will be an assertion
                                failure.
     */
    public init(errorCallback: @escaping ((Error) -> ()) = DEFAULT_ERROR_CALLBACK) {
        _errorCallback = errorCallback
        super.init()
    }

    /**
     Initializes a locator instance; the assembly block is executed immediately after initialization.

     - Parameter assemblyBlock: Assembly to be applied immediately

     - Parameter errorCallback: Block to be called when an error occurs. If you leave it alone, it will be an assertion
                                failure.
     */
    public convenience init(assemblyBlock: (HIPInstanceLocator) -> Void, errorCallback: @escaping ((Error) -> ()) = DEFAULT_ERROR_CALLBACK) {
        self.init(errorCallback: errorCallback)
        assemblyBlock(self)
    }

    /**
     Register an factory method for the specified type. The factory block is called the first time `get()` is called
     for this type. Subsequent calls to `get()` return cached instances.
     
     Example:
     
     
     ```swift
     locator.registerFactory(MyClass.self) {
        locator in
        return MyClass()
     }
     ```

     - Returns: `true` if the factory method was successfully registered, otherwise `false`

     */
    open func registerFactory<T>(_ key:T.Type, factory:@escaping (HIPInstanceLocator) -> T) -> Bool {
        return _setInstanceForKey("\(T.self)", instance: .uninitialized(factory))
    }

    /**
     Register an existing shared instance for the specified type. Instances registered this way are assumed to be
     retained elsewhere, so the locator will only hold a weak reference to it. Because the locator holds a weak
     reference, this method may only be used with class types.

     - Note: The shared instance must be a class instance.
     
     
     Example:
     
     ```swift
     let mySingleton = SingletonClass()
     locator.register(SingletonClass.self, mySingleton)  // stores a weak ref
     ```

     - Returns: `true` if the shared instance was successfully registered, otherwise `false`
     */
    open func register<T>(_ key:T.Type, sharedInstance: T) -> Bool where T: AnyObject {
        let box = _Instance.SharedBox(value: sharedInstance)
        return _setInstanceForKey("\(T.self)", instance: .shared(box))
    }

    /**
     Gets an instance of a previously registered type. If an instance was not already created, it will be initialized. 
     If this type was not registered, this returns nil and throws a debug assert.
     
     You'll typically use this inside a `HIPInstanceLocator.injectInstancesOf(_:injector:)` block.
     
     - Note: You may want to use `HIPInstanceLocator.implicitGet()` instead for most cases.

     - Parameter _: Type of instance to get.
     
     Example
     */
    open func getInstanceOf<T>(_:T.Type) -> T! { return try! _getWithKey("\(T.self)") }

    /**
     Implicitly gets an instance of a previously registered type. If an instance was not already created, it will be 
     initialized. If this type was not registered, this returns nil and throws a debug assert.
     Use this method when the return type can be inferred, such as initializer or method parameters.
     
     This method is made possible by Swift's type inference. The left side of the assignment expression typically
     has an explicit type, so you can just say "give me whatever I'm asking for."

     You'll typically use this inside a `HIPInstanceLocator.injectInstancesOf(_:injector:)` block.
     
     Example:
     
     ```swift
     let standardBackground = UIColor.redColor()
     locator.injectInstancesOf(MyViewController.self) {
        locator, viewController in in
        viewController.myColor = locator.implicitGet()  // magic!
     }
     ```
     */
    open func implicitGet<T>() -> T! { return getInstanceOf(T.self) }

    /**
     Registers an injector method for the specified type. The injector method is called once for each instance created
     by the instance locator. The injector is also used for objects initialized in storyboards.
     
     Example:
     
     ```swift
     locator.injectInstancesOf(MyViewController.self) {
        locator, viewController in
        viewController.someDependency = locator.implicitGet()
     }
     ```

     - Returns: `true` if the instance was injected, otherwise `false`
     */
    open func injectInstancesOf<T>(_ key: T.Type, injector:@escaping ((HIPInstanceLocator, T) -> Void)) -> Bool {
        return _setInjectorForKey("\(T.self)") {
            /// Wrapping the injector function in this way seems to be necessary for downcasting to _Injector for
            /// storage in the injector dictionary in a way that the compiler is okay with.
            locator, anyInstance in
            guard let instance = anyInstance as? T else { return }
            injector(locator, instance)
        }
    }

    /**
     Injects `instance` using the block specified for `T` in `HIPInstanceLocator.injectInstancesOf(_:injector:)`
     */
    open func applyInjector<T>(_ instance: T) -> Bool {
        return _applyInjector("\(T.self)", instance: instance)
    }
}

/// MARK: - ObjC Bridging

public extension HIPInstanceLocator {
    /**
     Get an instance for a class without any fancy type inference.
    */
    @objc public func objc_getInstanceOfClass(_ aClass: AnyClass) -> AnyObject! {
        return try! _getWithKey("\(aClass)")
    }

    /**
     Applies previously registered injector to an instance without any type inference.
     */
    @objc public func objc_applyInjector(_ aClass: AnyClass, toInstance instance: AnyObject) -> Bool {
        return _applyInjector("\(aClass)", instance: instance)
    }
}

/// MARK: - Internals

private extension HIPInstanceLocator {
    enum _Instance {
        fileprivate struct SharedBox {
            weak var value: AnyObject?
        }
        case uninitialized((HIPInstanceLocator) -> Any)
        case initialized(Any)
        case shared(SharedBox)
    }
    typealias _Injector = (HIPInstanceLocator, Any) -> (Void)

    func _getWithKey<T>(_ key: String) throws -> T? {
        objc_sync_enter(_lock)
        defer { objc_sync_exit(_lock) }

        do {
            switch _registeredInstances[key] {
                case .some(.initialized(let instance)):
                    guard let definiteInstance = instance as? T else {
                        throw LocatorError.storedDependencyWasNotOfExpectedType
                    }
                    return definiteInstance
                case .some(.uninitialized(let factory)):
                    guard let instance = factory(self) as? T else {
                        throw LocatorError.factoryDidNotReturnExpectedType
                    }
                    _registeredInstances[key] = .initialized(instance)
                    _registeredInjectors[key]?(self, instance)
                    return instance
                case .some(.shared(let box)):
                    guard let definiteInstance = box.value as? T else {
                        throw LocatorError.sharedInstanceWasNotOfExpectedType
                    }
                    return definiteInstance
                case .none:
                    throw LocatorError.noDependencyRegisteredForType
            }
        } catch {
            _errorCallback(error)  // user may throw assertion error, do nothing, etc.
            if error is LocatorError {
                return nil
            } else {
                throw error
            }
        }
    }

    func _setInstanceForKey(_ key: String, instance: _Instance) -> Bool {
        objc_sync_enter(_lock)
        defer { objc_sync_exit(_lock) }

        guard _registeredInstances[key] == nil else {
            _errorCallback(LocatorError.triedToRegisterTooManyFactories)
            return false
        }
        _registeredInstances[key] = instance
        return true
    }

    func _setInjectorForKey(_ key: String, injector: @escaping _Injector) -> Bool {
        objc_sync_enter(_lock)
        defer { objc_sync_exit(_lock) }

        guard _registeredInjectors[key] == nil else {
            _errorCallback(LocatorError.triedToRegisterTooManyInjectors)
            return false
        }
        _registeredInjectors[key] = injector
        return true
    }

    func _applyInjector<T>(_ key: String, instance: T) -> Bool {
        objc_sync_enter(_lock)
        defer { objc_sync_exit(_lock) }

        guard let injector = _registeredInjectors[key] else { return false }
        injector(self, instance)
        return true
    }
}
