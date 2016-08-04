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
    /// No shared instance or factory was registered for this type. You probably just forgot.
    case NoDependencyRegisteredForType

    /// The factory passed to `HIPInstanceLocator.registerFactory(_:factory)` did not have the expected type.
    case FactoryDidNotReturnExpectedType

    /// A dependency stored using `HIPInstanceLocator.register(_:sharedInstance)` did not have the expected type.
    case SharedInstanceWasNotOfExpectedType

    /// The stored return value of the factory passed to `HIPInstanceLocator.registerFactory(_:factory)`
    /// for the given type did not have the expected type. If you see this, there is probably a bug in the
    /// framework.
    case StoredDependencyWasNotOfExpectedType

    /// You tried to register more than one factory for the given type
    case TriedToRegisterTooManyFactories

    /// You tried to register more than one injector for the given type
    case TriedToRegisterTooManyInjectors

}

/**
 An implementation of the service locator pattern. Provides a place to register and get shared instances of classes for
 a specific context. Instances are registered using factory blocks, which are lazily instantiated on demand.
 */
@objc public class HIPInstanceLocator: NSObject {
    private var _registeredInstances: [String: _Instance] = Dictionary()
    private var _registeredInjectors: [String: _Injector] = Dictionary()
    private let _lock = NSObject()
    private let _errorCallback: (ErrorType -> ())?

    /**
     Initializes a locator instance
     - Parameter errorCallback: Block to be called when an error occurs. If you don't pass something, all errors are
        silently swallowed. You probably don't want that, but `HIPInstanceLocator` tries to be flexible with respect to
        how your tests run and what causes a crash. You'll probably want to make it an assertion failure.
     */
    public init(errorCallback: (ErrorType -> ())? = nil) {
        _errorCallback = errorCallback
        super.init()
    }

    /**
     Initializes a locator instance; the assembly block is executed immediately after initialization.
     - Parameter assemblyBlock: Assembly to be applied immediately
     - Parameter errorCallback: Block to be called when an error occurs. If you don't pass something, all errors are
        silently swallowed. You probably don't want that, but `HIPInstanceLocator` tries to be flexible with respect to
        how your tests run and what causes a crash. You'll probably want to make it an assertion failure.
     */
    public convenience init(assemblyBlock: HIPInstanceLocator -> Void, errorCallback: (ErrorType -> ())? = nil) {
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
    public func registerFactory<T>(key:T.Type, factory:HIPInstanceLocator -> T) -> Bool {
        return _setInstanceForKey("\(T.self)", instance: .Uninitialized(factory))
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
    public func register<T where T: AnyObject>(key:T.Type, sharedInstance: T) -> Bool {
        let box = _Instance.SharedBox(value: sharedInstance)
        return _setInstanceForKey("\(T.self)", instance: .Shared(box))
    }

    /**
     Gets an instance of a previously registered type. If an instance was not already created, it will be initialized. 
     If this type was not registered, this returns nil and throws a debug assert.
     
     You'll typically use this inside a `HIPInstanceLocator.injectInstancesOf(_:injector:)` block.
     
     - Note: You may want to use `HIPInstanceLocator.implicitGet()` instead for most cases.

     - Parameter _: Type of instance to get.
     
     Example
     */
    public func getInstanceOf<T>(_:T.Type) -> T! { return (try? _getWithKey("\(T.self)"))! }

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
    public func implicitGet<T>() -> T! { return getInstanceOf(T.self) }

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
     Injects `instance` using the block specified for `T` in `HIPInstanceLocator.injectInstancesOf(_:injector:)`
     */
    public func applyInjector<T>(instance: T) -> Bool {
        return _applyInjector("\(T.self)", instance: instance)
    }
}

/// MARK: - ObjC Bridging

public extension HIPInstanceLocator {
    /**
     Get an instance for a class without any fancy type inference.
    */
    @objc public func objc_getInstanceOfClass(aClass: AnyClass) -> AnyObject! {
        return (try? _getWithKey("\(aClass)"))!
    }

    /**
     Applies previously registered injector to an instance without any type inference.
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

    func _getWithKey<T>(key: String) throws -> T? {
        objc_sync_enter(_lock)
        defer { objc_sync_exit(_lock) }

        do {
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
        } catch {
            _errorCallback?(error)  // user may throw assertion error, do nothing, etc.
            if error as? LocatorError != nil {
                return nil
            } else {
                throw error
            }
        }
    }

    func _setInstanceForKey(key: String, instance: _Instance) -> Bool {
        objc_sync_enter(_lock)
        defer { objc_sync_exit(_lock) }

        guard _registeredInstances[key] == nil else {
            _errorCallback?(LocatorError.TriedToRegisterTooManyFactories)
            return false
        }
        _registeredInstances[key] = instance
        return true
    }

    func _setInjectorForKey(key: String, injector: _Injector) -> Bool {
        objc_sync_enter(_lock)
        defer { objc_sync_exit(_lock) }

        guard _registeredInjectors[key] == nil else {
            _errorCallback?(LocatorError.TriedToRegisterTooManyInjectors)
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