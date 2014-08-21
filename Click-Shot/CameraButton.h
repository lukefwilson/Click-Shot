//
//  CameraButton.h
//  Remote Shot
//
//  Created by Luke Wilson on 4/3/14.
//  Copyright (c) 2014 Luke Wilson. All rights reserved.
//

#import <UIKit/UIKit.h>

@class CameraViewController;
@interface CameraButton : UIView

//@property (nonatomic, strong) UITouch *primaryTouch;
@property (nonatomic, strong) CameraViewController *cameraController;
@property (nonatomic) BOOL isAnimatingButton;

@property (nonatomic) CGPoint originalCenterPosition;

@property (nonatomic, weak) IBOutlet UIImageView *outerButtonImage;
@property (nonatomic, weak) IBOutlet UIImageView *buttonImage;
@property (nonatomic, strong) NSMutableArray *rings;
@property (nonatomic, strong) CAShapeLayer *soundTimerRing;
@property (nonatomic) BOOL isDraggable;
@property (nonatomic) BOOL isDragging;
@property (nonatomic) BOOL isHighlighted;
@property (nonatomic) BOOL enabled;

@property (nonatomic, strong) NSTimer *cameraTimer;
@property (nonatomic, strong) CABasicAnimation *ringMoveAnimation;

@property (nonatomic) int timerDuration;
@property (nonatomic) int prevDuration; // for not recreating the button image too many times

@property (nonatomic, strong) NSString *cameraButtonString;

-(UIImage *)currentPlainCameraButtonImage;

-(void)updateCameraButtonImageForCurrentCameraMode;
- (void)initialize;
-(void)updateCameraButtonWithText:(NSString *)text;
-(void)animateSoundRingForDuration:(float)soundDuration;

@end
