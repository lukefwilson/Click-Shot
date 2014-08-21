//
//  MoveableImageView.m
//  Remote Shot
//
//  Created by Luke Wilson on 3/20/14.
//  Copyright (c) 2014 Luke Wilson. All rights reserved.
//

#import "MoveableImageView.h"
#import "CameraViewController.h"

#define kFocusViewTag 1
#define kExposeViewTag 2
#define kViewHalfSize 35

@implementation MoveableImageView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void) touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event {
}

-(void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    if (!self.parentViewController.settingsMenuIsOpen) {
        CGPoint touchLocation = [[touches anyObject] locationInView:self.parentViewController.view];
        self.center = touchLocation;
        [self fixIfOffscreen];
    }
}

-(void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (!self.parentViewController.settingsMenuIsOpen) {
        CGPoint touchLocation = [[touches anyObject] locationInView:self.parentViewController.view];
        self.center = touchLocation;
        if (self.tag == kExposeViewTag) {
            [self.parentViewController setExposureDevicePointWithTouchLocation:touchLocation];
        } else if (self.tag == kFocusViewTag){
            [self.parentViewController setFocusDevicePointWithTouchLocation:touchLocation];
        }
        [self fixIfOffscreen];
    }
}

-(void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}

-(void)fixIfOffscreen {
    if (self.frame.origin.x < self.parentViewController.tappablePreviewRect.origin.x) {
        self.center = CGPointMake(kViewHalfSize+self.parentViewController.tappablePreviewRect.origin.x, self.center.y);
    } else if (self.frame.origin.x+self.frame.size.width > self.parentViewController.tappablePreviewRect.origin.x+self.parentViewController.tappablePreviewRect.size.width) {
        self.center = CGPointMake(self.parentViewController.tappablePreviewRect.origin.x+self.parentViewController.tappablePreviewRect.size.width-kViewHalfSize, self.center.y);
    }
    if (self.frame.origin.y < self.parentViewController.tappablePreviewRect.origin.y) {
        self.center = CGPointMake(self.center.x, kViewHalfSize+self.parentViewController.tappablePreviewRect.origin.y);
    } else if (self.frame.origin.y+self.frame.size.height > self.parentViewController.tappablePreviewRect.origin.y+self.parentViewController.tappablePreviewRect.size.height) {
        self.center = CGPointMake(self.center.x, self.parentViewController.tappablePreviewRect.origin.y+self.parentViewController.tappablePreviewRect.size.height-kViewHalfSize);
    }
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
