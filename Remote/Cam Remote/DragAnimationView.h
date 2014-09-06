//
//  DragAnimationView.h
//  Click-Shot
//
//  Created by Luke Wilson on 7/27/14.
//  Copyright (c) 2014 Luke Wilson. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol DragAnimationViewDelegate;

@interface DragAnimationView : UIView

@property (nonatomic) NSArray *animationSteps;
@property (nonatomic) NSInteger currentAnimationStep;
@property (nonatomic) CGFloat currentAnimationStepRatio;
@property (nonatomic) CGFloat currentAnimationStepDistance;
@property (readwrite, assign) id <DragAnimationViewDelegate> delegate;


- (id)initWithFrame:(CGRect)frame animations:(NSArray *)animations;

@end


@protocol DragAnimationViewDelegate <NSObject>

@optional
-(void)dragAnimationViewTapped:(DragAnimationView *)dragAnimationView atAnimationStep:(NSInteger)animationStep;
-(void)dragAnimationView:(DragAnimationView *)dragAnimationView beganAnimationStep:(NSInteger)animationStep;
-(void)dragAnimationView:(DragAnimationView *)dragAnimationView finishedAtAnimationStep:(NSInteger)animationStep;
-(void)dragAnimationViewPressed:(DragAnimationView *)dragAnimationView;
-(void)dragAnimationViewReleased:(DragAnimationView *)dragAnimationView;
@required
-(CGFloat)dragAnimationDistanceForView:(DragAnimationView *)dragAnimationView animationStep:(NSInteger)step;

@end
