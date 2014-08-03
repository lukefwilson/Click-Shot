//
//  LWTutorialViewController.h
//  Click-Shot
//
//  Created by Luke Wilson on 6/6/14.
//  Copyright (c) 2014 Luke Wilson. All rights reserved.
//

#import <UIKit/UIKit.h>
@class CameraViewController;
@protocol LWTutorialContainerViewDelegate < NSObject >

- (BOOL)swallowTouchPoint:(CGPoint)point;

@end

@interface LWTutorialViewController : UIPageViewController <UIPageViewControllerDelegate, UIPageViewControllerDataSource, LWTutorialContainerViewDelegate>
@property (nonatomic)  CAShapeLayer *maskLayer;
@property (nonatomic)  CGRect maskRect;
@property (nonatomic)  UIView *border;

@property (nonatomic)  NSInteger currentPage;
@property (nonatomic)  CameraViewController *mainController;
@property (nonatomic)  CGPoint previousTouchPoint;

@property (nonatomic)  UILabel *currentPageLabel;

-(void)setMaskRect:(CGRect)maskRect;
-(void)restartTutorial;
@end



@interface LWTutorialChildViewController : UIViewController

@property (nonatomic)  NSInteger index;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *page2TextDistanceFromTop;
- (IBAction)closeTutorial:(id)sender;

@end


@interface LWTutorialContainerView : UIView

@property (nonatomic, assign) id <LWTutorialContainerViewDelegate> delegate;

@end

