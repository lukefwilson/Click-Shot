//
//  UIApplication+ScreenSize.h
//  Click-Shot
//
//  Created by Luke Wilson on 6/3/14.
//  Copyright (c) 2014 Luke Wilson. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIApplication (ScreenSize)
+(CGSize) currentSize;
+(CGSize) sizeInOrientation:(UIInterfaceOrientation)orientation;
@end
