//
//  ImageViewPassTouches.h
//  Click-Shot
//
//  Created by Luke Wilson on 8/5/14.
//  Copyright (c) 2014 Luke Wilson. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol ImageViewPassTouchesDelegate;


@interface ImageViewPassTouches : UIImageView

@property (nonatomic, weak) id <ImageViewPassTouchesDelegate> delegate;


@end


@protocol ImageViewPassTouchesDelegate <NSObject>

@optional

-(void) imageViewTouchesBegan:(NSSet*)touches withEvent:(UIEvent*)event;

-(void) imageViewTouchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;

-(void) imageViewTouchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;

@end

