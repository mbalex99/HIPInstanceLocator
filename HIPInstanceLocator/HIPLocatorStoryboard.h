//
//  _HIPLocatorStoryboardBase.h
//  Hipmunk
//
//  Created by Jesus Fernandez on 3/7/16.
//  Copyright © 2016 Hipmunk. All rights reserved.
//

#import <UIKit/UIKit.h>

@class HIPInstanceLocator;

/**
 A storyboard that uses an instance locator to inject dependencies to the view controllers it initalizes. This is
 implemented as a Obj-C class since UIStoryboard's +storyboardWithName:bundle is not inheritable.
 This implementation borrows heavily from BlindsidedStoryboard: https://github.com/briancroom/BlindsidedStoryboard
 */
@interface HIPLocatorStoryboard : UIStoryboard

/**
 Returns a new storyboard for the name bundle and instance locator. If an instance locator is passed in, the same
 instance will be used for any other storyboards initialized from this storyboard.
 */
+ (nonnull instancetype)storyboardWithName:(nonnull NSString *)name
                                    bundle:(nullable NSBundle *)storyboardBundleOrNil
                                   locator:(nullable HIPInstanceLocator *)locatorOrNil;

@property (nonatomic, retain, nullable) HIPInstanceLocator *locator;

@end
