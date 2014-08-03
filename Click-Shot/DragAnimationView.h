//
//  DragAnimationView.h
//  Click-Shot
//
//  Created by Luke Wilson on 7/27/14.
//  Copyright (c) 2014 Luke Wilson. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DragAnimationView : UIView

@property (nonatomic) NSArray *animationSteps;
@property (nonatomic) NSInteger currentAnimationStep;
@property (nonatomic) CGFloat currentAnimationStepRatio;
@property (nonatomic) CGFloat currentAnimationStepDistance;


- (id)initWithFrame:(CGRect)frame animations:(NSArray *)animations;

@end
