# HIPInstanceLocator

![Swift 2.2](https://img.shields.io/badge/Swift-2.2-orange.svg?style=flat)

[Docs (you may already be here)](http://hipmunk.github.io/HIPInstanceLocator/)

This is a small dependency injection framework. It's like
[Swinject](https://github.com/Swinject/Swinject), but with fewer features,
different method names, and a different implementation of auto-injecting
storyboards. At Hipmunk we use it to support our Model-View-ViewModel (MVVM)
architecture.

You might find that Swinject is a better fit for you, but we decided to publish
this framework anyway because:

* It's very small; you can learn from it by reading it
* We use it and are happy with it
* We tried to use Swinject instead but its auto-injecting storyboard implementation
  seemed to be buggy
* It introduces the idea of an *assembly*: a conceptual grouping of dependency
  declarations.

If you'd like to use `HIPInstanceLocator` but aren't satisfied with its level
of documentation, please open an issue on GitHub or vote for an existing one.

## Auto-Injecting Storyboards (`HIPLocatorStoryboard`)

This framework has one class that isn't listed in the sidebar because it's
an Objective-C class: `HIPLocatorStoryboard`. If you instantiate a storyboard
as a `HIPLocatorStoryboard`, then any view controllers inside it may have its
dependencies injected using blocks specified by
`locator.injectInstancesOf(T, factory:)`.

Usage:

1. Add `<HIPInstanceLocator/HIPInstanceLocator.h>` to your bridging header.
   `HIPLocatorStoryboard` is an Objective-C class, and it needs to be bridged
   over to Swift. Unfortunately, frameworks don't support briding headers, so
   this can't be done automatically yet.

2. For the storyboard whose view controllers you want to inject, register
   dependency injection blocks on your locator:

    ```swift
    let locator = HIPInstanceLocator()
    locator.injectInstancesOf(MyViewController.self) {
      locator, viewController in
      print("Injecting MyViewController")
      viewController.someDependency = locator.implicitGet()
    }
    ```

3. Instantiate the storyboard:

    ```swift
    let storyboard = HIPLocatorStoryboard(name: "MyStoryboard", bundle: nil, locator: locator)
    let viewController = storyboard.instantiateInitialViewController()!
    // should have printed "Injecting MyViewController"
    presentViewController(viewController, animated: true, completion: nil)
    ```

Any view controllers instantiated by this storyboard are automatically injected.
Additionally, any storyboard references also result in `HIPLocatorStoryboard`
instances. So you don't need to worry about doing all your segues and presentations
in code to use dependency injection!

## Contributors

* [jfrndz](http://github.com/jfrndz)
* [irskep](http://github.com/irskep)
