//
//  ImageViewPassTouches.m
//  Click-Shot
//
//  Created by Luke Wilson on 8/5/14.
//  Copyright (c) 2014 Luke Wilson. All rights reserved.
//

#import "ImageViewPassTouches.h"

@implementation ImageViewPassTouches

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void) touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event {
    NSLog(@"BEGAN");
    [self.delegate imageViewTouchesBegan:touches withEvent:event];
}

-(void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    NSLog(@"MOVED");

    [self.delegate imageViewTouchesMoved:touches withEvent:event];
}

-(void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    NSLog(@"ENDED");

    [self.delegate imageViewTouchesEnded:touches withEvent:event];
}

-(void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    NSLog(@"CANCEL");

    [self touchesEnded:touches withEvent:event];
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
