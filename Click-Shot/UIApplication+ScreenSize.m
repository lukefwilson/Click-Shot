//
//  UIApplication+ScreenSize.m
//  Click-Shot
//
//  Created by Luke Wilson on 6/3/14.
//  Copyright (c) 2014 Luke Wilson. All rights reserved.
//

#import "UIApplication+ScreenSize.h"

@implementation UIApplication (ScreenSize)
+(CGSize) currentSize {
    return [UIApplication sizeInOrientation:[UIApplication sharedApplication].statusBarOrientation];
}

+(CGSize) sizeInOrientation:(UIInterfaceOrientation)orientation {
    CGSize size = [UIScreen mainScreen].bounds.size;
    UIApplication *application = [UIApplication sharedApplication];
    if (UIInterfaceOrientationIsLandscape(orientation)) {
        size = CGSizeMake(size.height, size.width);
    }
    if (application.statusBarHidden == NO) {
        size.height -= MIN(application.statusBarFrame.size.width, application.statusBarFrame.size.height);
    }
    return size;
}

@end
