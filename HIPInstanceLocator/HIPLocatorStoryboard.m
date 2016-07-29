//
//  _HIPLocatorStoryboardBase.m
//  Hipmunk
//
//  Created by Jesus Fernandez on 3/7/16.
//  Copyright © 2016 Hipmunk. All rights reserved.
//

#import <objc/runtime.h>

#import "HIPLocatorStoryboard.h"

#import <HIPInstanceLocator/HIPInstanceLocator-Swift.h>

@implementation HIPLocatorStoryboard

+ (nonnull instancetype)storyboardWithName:(nonnull NSString *)name
                                    bundle:(nullable NSBundle *)storyboardBundleOrNil
                                   locator:(nullable HIPInstanceLocator *)locatorOrNil
{
    HIPLocatorStoryboard *result = (HIPLocatorStoryboard *)[self storyboardWithName:name bundle:storyboardBundleOrNil];
    result.locator = locatorOrNil;
    return result;
}

/**
 Note: This seems to be the base method for initializing view controllers from a storyboard.
 */
- (id)instantiateViewControllerWithIdentifier:(NSString *)identifier {
    __block UIViewController *viewController;
    [self _performWithSwizzledFactoryMethod:^{
        viewController = [super instantiateViewControllerWithIdentifier:identifier];
    }];

    if (viewController.storyboard == self) {
        [self _injectViewController:viewController];
    }

    return viewController;
}


#pragma mark - Private

/**
 Injects the a given view controller and all of its children.
 */
- (void)_injectViewController:(UIViewController *)controller {
    [self.locator objc_applyInjector:controller.class toInstance: controller];
    for (id childController in [controller childViewControllers]) {
        [self _injectViewController:childController];
    }
}

/**
 This swizzles the +storyboardWithName:bundle: class method with an implementation from the private instance method
 -_locatorStoryboardWithName:bundle:. This creates a special context in which any new storyboards that are initialized
 by instantiateViewControllerWithIdentifier: inherits the locator from this storyboard.
 */
- (void)_performWithSwizzledFactoryMethod:(void (^)(void))actionsWhileSwizzled {
    SEL factoryMethodSel = @selector(storyboardWithName:bundle:);
    Method factoryMethod = class_getClassMethod([UIStoryboard class], factoryMethodSel);

    __block id(*origImp)(id, SEL, id, id);
    IMP newImp = imp_implementationWithBlock(^(id _self, NSString *name, NSBundle *bundle){
        method_setImplementation(factoryMethod, (IMP)origImp);
        origImp = NULL;
        return [self _locatorStoryboardWithName:name bundle:bundle];
    });
    origImp = (void *)method_setImplementation(factoryMethod, newImp);

    actionsWhileSwizzled();

    if (origImp) {
        method_setImplementation(factoryMethod, (IMP)origImp);
    }
    imp_removeBlock(newImp);
}



- (nonnull instancetype)_locatorStoryboardWithName:(nonnull NSString *)name
                                            bundle:(nullable NSBundle *)storyboardBundleOrNil
{
    return [[self class] storyboardWithName:name bundle:storyboardBundleOrNil locator:self.locator];
}

@end
