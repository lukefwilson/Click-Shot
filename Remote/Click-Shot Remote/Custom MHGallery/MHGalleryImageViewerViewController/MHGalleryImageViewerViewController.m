//
//  MHGalleryImageViewerViewController.m
//  MHVideoPhotoGallery
//
//  Created by Mario Hahn on 27.12.13.
//  Copyright (c) 2013 Mario Hahn. All rights reserved.
//

#import "MHGalleryImageViewerViewController.h"
#import "MHOverviewController.h"
#import "MHTransitionShowShareView.h"
#import "MHTransitionShowOverView.h"
#import "MHGallerySharedManagerPrivate.h"
#import "SAVideoRangeSlider.h"
#import "MBProgressHUD.h"
#import "UIApplication+ScreenSize.h"


@implementation MHPinchGestureRecognizer
@end

@interface MHGalleryImageViewerViewController()
@property (nonatomic, strong) UIActivityViewController *activityViewController;
@property (nonatomic, strong) UIBarButtonItem          *mergeBarButton;
@property (nonatomic, strong) UIBarButtonItem          *leftBarButton;
@property (nonatomic, strong) UIBarButtonItem          *rightBarButton;
@property (nonatomic, strong) UIBarButtonItem          *playStopBarButton;
@property (nonatomic, strong) UIBarButtonItem          *trimBarButton;

@property (nonatomic, strong) NSMutableArray *videoGalleryItems;
@property (nonatomic, strong) MBProgressHUD *hud;
@property (nonatomic, strong) AVAssetExportSession *trimExportSession;

@end

@implementation MHGalleryImageViewerViewController

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self updateVideoGalleryItems];
    self.navigationController.delegate = self;
}

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    
    [self setNeedsStatusBarAppearanceUpdate];
    
    
    [UIApplication.sharedApplication setStatusBarStyle:self.galleryViewController.preferredStatusBarStyleMH
                                              animated:YES];
    
    if (![self.descriptionViewBackground isDescendantOfView:self.view]) {
        [self.view addSubview:self.descriptionViewBackground];
    }
    if (![self.descriptionView isDescendantOfView:self.view]) {
        [self.view addSubview:self.descriptionView];
    }
    if (![self.toolbar isDescendantOfView:self.view]) {
        [self.view addSubview:self.toolbar];
    }
    [self.pageViewController.view.subviews.firstObject setFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
    
}

- (UIStatusBarStyle)preferredStatusBarStyle{
    return  self.galleryViewController.preferredStatusBarStyleMH;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.navigationController.delegate == self) {
        self.navigationController.delegate = nil;
    }
}

-(void)donePressed{
    MHImageViewController *imageViewer = self.pageViewController.viewControllers.firstObject;
    if (imageViewer.videoPlayer) {
        [imageViewer removeAllMoviePlayerViewsAndNotifications];
    }
    MHTransitionDismissMHGallery *dismissTransiton = [MHTransitionDismissMHGallery new];
    dismissTransiton.orientationTransformBeforeDismiss = [(NSNumber *)[self.navigationController.view valueForKeyPath:@"layer.transform.rotation.z"] floatValue];
    imageViewer.interactiveTransition = dismissTransiton;
    
    if (self.galleryViewController && self.galleryViewController.finishedCallback) {
        self.galleryViewController.finishedCallback(self.pageIndex,imageViewer.imageView.image,dismissTransiton,self.viewModeForBarStyle);
    }
}

-(MHGalleryViewMode)viewModeForBarStyle{
    if (self.isHiddingToolBarAndNavigationBar) {
        return MHGalleryViewModeImageViewerNavigationBarHidden;
    }
    return MHGalleryViewModeImageViewerNavigationBarShown;
}

-(void)viewDidLoad{
    [super viewDidLoad];
    
    [self updateVideoGalleryItems];

    self.UICustomization          = self.galleryViewController.UICustomization;
    self.transitionCustomization  = self.galleryViewController.transitionCustomization;
    
    if (!self.UICustomization.showOverView) {
        self.navigationItem.hidesBackButton = YES;
    }else{
        if (self.galleryViewController.UICustomization.backButtonState == MHBackButtonStateWithoutBackArrow) {
            UIBarButtonItem *backBarButton = [UIBarButtonItem.alloc initWithImage:MHTemplateImage(@"ic_square")
                                                                            style:UIBarButtonItemStyleBordered
                                                                           target:self
                                                                           action:@selector(backButtonAction)];
            self.navigationItem.hidesBackButton = YES;
            self.navigationItem.leftBarButtonItem = backBarButton;
        }
    }
    
    UIBarButtonItem *doneBarButton =  [UIBarButtonItem.alloc initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                  target:self
                                                                                  action:@selector(donePressed)];
    
    self.navigationItem.rightBarButtonItem = doneBarButton;
    
    self.view.backgroundColor = [self.UICustomization MHGalleryBackgroundColorForViewMode:MHGalleryViewModeImageViewerNavigationBarShown];
    
    
    self.pageViewController = [UIPageViewController.alloc initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
                                                            navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                                                                          options:@{ UIPageViewControllerOptionInterPageSpacingKey : @30.f }];
    self.pageViewController.delegate = self;
    self.pageViewController.dataSource = self;
    self.pageViewController.automaticallyAdjustsScrollViewInsets =NO;
    
    MHGalleryItem *item = [self itemForIndex:self.pageIndex];
    
    MHImageViewController *imageViewController =[MHImageViewController imageViewControllerForMHMediaItem:item viewController:self];
    imageViewController.pageIndex = self.pageIndex;
    [self.pageViewController setViewControllers:@[imageViewController]
                                      direction:UIPageViewControllerNavigationDirectionForward
                                       animated:NO
                                     completion:nil];
    
    
    [self addChildViewController:self.pageViewController];
    [self.pageViewController didMoveToParentViewController:self];
    [self.view addSubview:self.pageViewController.view];
    
    self.toolbar = [UIToolbar.alloc initWithFrame:CGRectMake(0, self.view.frame.size.height-44, self.view.frame.size.width, 44)];
    if(self.currentOrientation == UIInterfaceOrientationLandscapeLeft || self.currentOrientation == UIInterfaceOrientationLandscapeRight){
        if (self.view.bounds.size.height > self.view.bounds.size.width) {
            self.toolbar.frame = CGRectMake(0, self.view.frame.size.width-44, self.view.frame.size.height, 44);
        }
    }
    
    self.toolbar.tintColor = self.UICustomization.barButtonsTintColor;
    self.toolbar.tag = 307;
    self.toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleBottomMargin;
    
    self.playStopBarButton = [UIBarButtonItem.alloc initWithImage:MHGalleryImage(@"play")
                                                            style:UIBarButtonItemStyleBordered
                                                           target:self
                                                           action:@selector(playStopButtonPressed)];
    self.playStopBarButton.width = 30;

    self.leftBarButton = [UIBarButtonItem.alloc initWithImage:MHGalleryImage(@"left_arrow")
                                                        style:UIBarButtonItemStyleBordered
                                                       target:self
                                                       action:@selector(leftPressed:)];
    self.leftBarButton.width = 30;

    self.rightBarButton = [UIBarButtonItem.alloc initWithImage:MHGalleryImage(@"right_arrow")
                                                         style:UIBarButtonItemStyleBordered
                                                        target:self
                                                        action:@selector(rightPressed:)];
    self.rightBarButton.width = 30;

    self.mergeBarButton = [[UIBarButtonItem alloc] initWithTitle:@"Merge" style:UIBarButtonItemStyleBordered target:self action:@selector(mergePressed)];
    self.mergeBarButton.width = 30;

    self.trimBarButton = [[UIBarButtonItem alloc] initWithTitle:@"Trim" style:UIBarButtonItemStyleBordered target:self action:@selector(trimPressed)];
    self.trimBarButton.width = 30;
    self.trimBarButton.enabled = NO;
    
//    if (self.UICustomization.hideShare) {
//        self.mergeBarButton = [UIBarButtonItem.alloc initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
//                                                                          target:self
//                                                                          action:nil];
//    }
    
    [self updateToolBarForItem:item];
    
    if (self.pageIndex == 0) {
        self.leftBarButton.enabled =NO;
    }
    if(self.pageIndex == self.numberOfGalleryItems-1){
        self.rightBarButton.enabled =NO;
    }
    
    self.descriptionViewBackground = [UIToolbar.alloc initWithFrame:CGRectZero];
    self.descriptionView = [UITextView.alloc initWithFrame:CGRectZero];
    self.descriptionView.backgroundColor = [UIColor clearColor];
    self.descriptionView.font = [UIFont systemFontOfSize:15];
    self.descriptionView.text = item.description;
    self.descriptionView.textColor = [UIColor blackColor];
    self.descriptionView.scrollEnabled = NO;
    self.descriptionView.userInteractionEnabled = NO;
    
    
    self.toolbar.barTintColor = self.UICustomization.barTintColor;
    self.toolbar.barStyle = self.UICustomization.barStyle;
    self.descriptionViewBackground.barTintColor = self.UICustomization.barTintColor;
    self.descriptionViewBackground.barStyle = self.UICustomization.barStyle;
    
    CGSize size = [self.descriptionView sizeThatFits:CGSizeMake(self.view.frame.size.width-20, MAXFLOAT)];
    
    self.descriptionView.frame = CGRectMake(10, self.view.frame.size.height -size.height-44, self.view.frame.size.width-20, size.height);
    if (self.descriptionView.text.length >0) {
        self.descriptionViewBackground.frame = CGRectMake(0, self.view.frame.size.height -size.height-44, self.view.frame.size.width, size.height);
    }else{
        self.descriptionViewBackground.hidden =YES;
    }
    
    [(UIScrollView*)self.pageViewController.view.subviews[0] setDelegate:self];
    [(UIGestureRecognizer*)[[self.pageViewController.view.subviews[0] gestureRecognizers] firstObject] setDelegate:self];
    
    [self updateTitleForIndex:self.pageIndex];
}
-(void)backButtonAction{
    [self.navigationController popToRootViewControllerAnimated:YES];
    
}


-(void)updateVideoGalleryItems {
    self.videoGalleryItems = [NSMutableArray new];
    for (int i = 0; i < [self.galleryItems count]; i++) {
        MHGalleryItem *item = [self.galleryItems objectAtIndex:i];
        if (item.galleryType == MHGalleryTypeVideo) [self.videoGalleryItems addObject:item];
    }
}

-(UIInterfaceOrientation)currentOrientation{
    return UIApplication.sharedApplication.statusBarOrientation;
}

-(NSInteger)numberOfGalleryItems{
    return [self.galleryViewController.dataSource numberOfItemsInGallery:self.galleryViewController];
}

-(MHGalleryItem*)itemForIndex:(NSInteger)index{
    if (index < 0) index = 0;
    return [self.galleryViewController.dataSource itemForIndex:index];
}

-(MHGalleryController*)galleryViewController{
    if ([self.navigationController isKindOfClass:MHGalleryController.class]) {
        return (MHGalleryController*)self.navigationController;
    }
    return nil;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if ([touch.view isKindOfClass:UIButton.class]) {
        if (touch.view.tag != 508) {
            return YES;
        }
    }
    return ([touch.view isKindOfClass:UIControl.class] == NO);
}

-(void)changeToPlayButton{
    self.playStopBarButton.image = MHGalleryImage(@"play");
}

-(void)changeToPauseButton{
    self.playStopBarButton.image = MHGalleryImage(@"pause");
}

-(void)playStopButtonPressed{
    for (MHImageViewController *imageViewController in self.pageViewController.viewControllers) {
        if (imageViewController.pageIndex == self.pageIndex) {
            if (imageViewController.isPlayingVideo) {
                [imageViewController stopMovie];
                [self changeToPlayButton];
            }else{
                [imageViewController playButtonPressed];
            }
        }
    }
}

-(void)updateDescriptionLabelForIndex:(NSInteger)index{
    if (index < self.numberOfGalleryItems) {
        MHGalleryItem *item = [self itemForIndex:index];
        self.descriptionView.text = item.description;
        
        if (item.attributedString) {
            self.descriptionView.attributedText = item.attributedString;
        }
        CGSize size = [self.descriptionView sizeThatFits:CGSizeMake(self.view.frame.size.width-20, MAXFLOAT)];
        
        self.descriptionView.frame = CGRectMake(10, self.view.frame.size.height -size.height-44, self.view.frame.size.width-20, size.height);
        if (self.descriptionView.text.length >0) {
            self.descriptionViewBackground.hidden =NO;
            self.descriptionViewBackground.frame = CGRectMake(0, self.view.frame.size.height -size.height-44, self.view.frame.size.width, size.height);
        }else{
            self.descriptionViewBackground.hidden =YES;
        }
    }
}

-(void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView{
    self.userScrolls = NO;
    [self updateTitleAndDescriptionForScrollView:scrollView];
}

-(void)scrollViewWillBeginDragging:(UIScrollView *)scrollView{
    self.userScrolls = YES;
}

-(void)scrollViewDidScroll:(UIScrollView *)scrollView{
    [self updateTitleAndDescriptionForScrollView:scrollView];
}

-(void)updateTitleAndDescriptionForScrollView:(UIScrollView*)scrollView{
    NSInteger pageIndex = self.pageIndex;
    if (scrollView.contentOffset.x > (self.view.frame.size.width+self.view.frame.size.width/2)) {
        pageIndex++;
    }
    if (scrollView.contentOffset.x < self.view.frame.size.width/2) {
        pageIndex--;
    }
    [self updateDescriptionLabelForIndex:pageIndex];
    [self updateTitleForIndex:pageIndex];
}

-(void)updateTitleForIndex:(NSInteger)pageIndex{
    NSString *localizedString  = MHGalleryLocalizedString(@"imagedetail.title.current");
    self.navigationItem.title = [NSString stringWithFormat:localizedString,@(pageIndex+1),@(self.numberOfGalleryItems)];
}


-(void)pageViewController:(UIPageViewController *)pageViewController
       didFinishAnimating:(BOOL)finished
  previousViewControllers:(NSArray *)previousViewControllers
      transitionCompleted:(BOOL)completed{
    
    self.pageIndex = [pageViewController.viewControllers.firstObject pageIndex];
    [self showCurrentIndex:self.pageIndex];
    
    if (finished) {
        for (MHImageViewController *imageViewController in previousViewControllers) {
            [self removeVideoPlayerForVC:imageViewController];
        }
    }
    if (completed) {
        [self updateToolBarForItem:[self itemForIndex:self.pageIndex]];
    }
}



-(void)removeVideoPlayerForVC:(MHImageViewController*)vc{
    if (vc.pageIndex != self.pageIndex) {
        if (vc.videoPlayer) {
            if (vc.item.galleryType == MHGalleryTypeVideo) {
                if (vc.isPlayingVideo) {
                    [vc stopMovie];
                }
            }
        }
    }
}

-(void)updateToolBarForItem:(MHGalleryItem*)item{
    
    UIBarButtonItem *flex = [UIBarButtonItem.alloc initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                        target:self
                                                                        action:nil];
    
    UIBarButtonItem *fixed = [UIBarButtonItem.alloc initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                                                         target:self
                                                                         action:nil];
    fixed.width = 30;
    
    if (item.galleryType == MHGalleryTypeVideo) {
        [self changeToPlayButton];
        self.toolbar.items = @[self.mergeBarButton,flex,self.leftBarButton,flex,self.playStopBarButton,flex,self.rightBarButton,flex,self.trimBarButton];
    } else{
        self.toolbar.items =@[fixed,flex,self.leftBarButton,flex, fixed, flex, self.rightBarButton,flex,fixed];
    }
}



- (id<UIViewControllerInteractiveTransitioning>)navigationController:(UINavigationController *)navigationController
                         interactionControllerForAnimationController:(id<UIViewControllerAnimatedTransitioning>)animationController {
    if ([animationController isKindOfClass:MHTransitionShowOverView.class]) {
        MHImageViewController *imageViewController = self.pageViewController.viewControllers.firstObject;
        return imageViewController.interactiveOverView;
    } else {
        return nil;
    }
}

- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController
                                  animationControllerForOperation:(UINavigationControllerOperation)operation
                                               fromViewController:(UIViewController *)fromVC
                                                 toViewController:(UIViewController *)toVC {
    
    MHImageViewController *theCurrentViewController = self.pageViewController.viewControllers.firstObject;
    if (theCurrentViewController.videoPlayer) {
        [theCurrentViewController removeAllMoviePlayerViewsAndNotifications];
    }
    
    if ([toVC isKindOfClass:MHShareViewController.class]) {
        MHTransitionShowShareView *present = MHTransitionShowShareView.new;
        present.present = YES;
        return present;
    }
    if ([toVC isKindOfClass:MHOverviewController.class]) {
        return MHTransitionShowOverView.new;
    }
    return nil;
}

-(void)leftPressed:(id)sender{
    self.rightBarButton.enabled = YES;
    
    MHImageViewController *theCurrentViewController = self.pageViewController.viewControllers.firstObject;
    NSUInteger indexPage = theCurrentViewController.pageIndex;
    MHImageViewController *imageViewController =[MHImageViewController imageViewControllerForMHMediaItem:[self itemForIndex:indexPage-1] viewController:self];
    imageViewController.pageIndex = indexPage-1;
    
    if (indexPage-1 == 0) {
        self.leftBarButton.enabled = NO;
    }
    
    __weak typeof(self) weakSelf = self;
    
    [self.pageViewController setViewControllers:@[imageViewController] direction:UIPageViewControllerNavigationDirectionReverse animated:YES completion:^(BOOL finished) {
        weakSelf.pageIndex = imageViewController.pageIndex;
        [weakSelf updateToolBarForItem:[weakSelf itemForIndex:weakSelf.pageIndex]];
        [weakSelf showCurrentIndex:weakSelf.pageIndex];
    }];
}

-(void)rightPressed:(id)sender{
    self.leftBarButton.enabled =YES;
    
    MHImageViewController *theCurrentViewController = self.pageViewController.viewControllers.firstObject;
    NSUInteger indexPage = theCurrentViewController.pageIndex;
    MHImageViewController *imageViewController =[MHImageViewController imageViewControllerForMHMediaItem:[self itemForIndex:indexPage+1] viewController:self];
    imageViewController.pageIndex = indexPage+1;
    
    if (indexPage+1 == self.numberOfGalleryItems-1) {
        self.rightBarButton.enabled = NO;
    }
    __weak typeof(self) weakSelf = self;
    
    [self.pageViewController setViewControllers:@[imageViewController] direction:UIPageViewControllerNavigationDirectionForward animated:YES completion:^(BOOL finished) {
        weakSelf.pageIndex = imageViewController.pageIndex;
        [weakSelf updateToolBarForItem:[weakSelf itemForIndex:weakSelf.pageIndex]];
        [weakSelf showCurrentIndex:weakSelf.pageIndex];
    }];
}


-(void)mergePressed{
    
    [[[UIAlertView alloc] initWithTitle:@"Muahahahah!"
                                message:@"This feature is only available in the main Click-Shot app"
                               delegate:self
                      cancelButtonTitle:@"It's only $1.99"
                      otherButtonTitles:nil] show];
    
//    MHShareViewController *merge = [MHShareViewController new];
//    
//    MHGalleryItem *selectedVideo = [self.galleryItems objectAtIndex:self.pageIndex];
//    
//    merge.pageIndex = [self.videoGalleryItems indexOfObject:selectedVideo];
//    if (merge.pageIndex == NSNotFound) return;
//    merge.galleryItems = self.videoGalleryItems;
//    [self.navigationController pushViewController:merge
//                                         animated:YES];
//
}

// adds new gallery item to front of gallery
-(void)addItemWithPathStringToGalleryItems:(NSString *)path {
    MHGalleryItem *trimmedVideo = [[MHGalleryItem alloc] initWithURL:path galleryType:MHGalleryTypeVideo];
    NSMutableArray *temp = [NSMutableArray arrayWithArray:self.galleryItems];
    [temp insertObject:trimmedVideo atIndex:0];
    self.galleryItems = [NSArray arrayWithArray:temp];
    [self galleryViewController].galleryItems = self.galleryItems;
}


-(void)showCurrentIndex:(NSInteger)currentIndex{
    if ([self.galleryViewController.galleryDelegate respondsToSelector:@selector(galleryController:didShowIndex:)]) {
        [self.galleryViewController.galleryDelegate galleryController:self.galleryViewController
                                                         didShowIndex:currentIndex];
    }
    
}

- (UIViewController *)pageViewController:(UIPageViewController *)pvc viewControllerBeforeViewController:(MHImageViewController *)vc{
    
    NSInteger indexPage = vc.pageIndex;
    
    if (self.numberOfGalleryItems !=1 && self.numberOfGalleryItems-1 != indexPage) {
        self.leftBarButton.enabled =YES;
        self.rightBarButton.enabled =YES;
    }
    
    [self removeVideoPlayerForVC:vc];
    
    if (indexPage ==0) {
        self.leftBarButton.enabled = NO;
        MHImageViewController *imageViewController =[MHImageViewController imageViewControllerForMHMediaItem:nil viewController:self];
        imageViewController.pageIndex = 0;
        return imageViewController;
    }
    MHImageViewController *imageViewController =[MHImageViewController imageViewControllerForMHMediaItem:[self itemForIndex:indexPage-1] viewController:self];
    imageViewController.pageIndex = indexPage-1;
    
    return imageViewController;
}

-(MHImageViewController*)imageViewControllerWithItem:(MHGalleryItem*)item pageIndex:(NSInteger)pageIndex{
    MHImageViewController *imageViewController =[MHImageViewController imageViewControllerForMHMediaItem:[self itemForIndex:pageIndex] viewController:self];
    imageViewController.pageIndex  = pageIndex;
    return imageViewController;
}
- (UIViewController *)pageViewController:(UIPageViewController *)pvc viewControllerAfterViewController:(MHImageViewController *)vc{
    
    
    NSInteger indexPage = vc.pageIndex;
    
    if (self.numberOfGalleryItems !=1 && indexPage !=0) {
        self.leftBarButton.enabled = YES;
        self.rightBarButton.enabled = YES;
    }
    [self removeVideoPlayerForVC:vc];
    
    if (indexPage ==self.numberOfGalleryItems-1) {
        self.rightBarButton.enabled = NO;
        MHImageViewController *imageViewController =[MHImageViewController imageViewControllerForMHMediaItem:nil viewController:self];
        imageViewController.pageIndex = self.numberOfGalleryItems-1;
        return imageViewController;
    }
    MHImageViewController *imageViewController =[MHImageViewController imageViewControllerForMHMediaItem:[self itemForIndex:indexPage+1] viewController:self];
    imageViewController.pageIndex  = indexPage+1;
    return imageViewController;
}

-(void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration{
    self.toolbar.frame = CGRectMake(0, self.view.frame.size.height-44, self.view.frame.size.width, 44);
    self.pageViewController.view.bounds = self.view.bounds;
    [self.pageViewController.view.subviews.firstObject setFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height) ];
    
}

#pragma mark - Trimming

-(void)trimPressed {
    MHImageViewController *currentViewController = self.pageViewController.viewControllers.firstObject;
    NSLog(@"start %f - end %f", currentViewController.startTime, currentViewController.endTime);
    self.hud = [[MBProgressHUD alloc] initWithView:self.view.window];
    self.hud.labelText = @"Trimming";
    self.hud.mode = MBProgressHUDModeDeterminate;
    self.hud.minSize = CGSizeMake(150, 150);
    [self.hud show:YES];
    [self.view.window addSubview:self.hud];
    
    
    AVAsset *asset = [AVAsset assetWithURL:currentViewController.videoPlayerAsset.URL];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *outputString = paths[0];
    NSFileManager *manager = [NSFileManager defaultManager];
    [manager createDirectoryAtPath:outputString withIntermediateDirectories:YES attributes:nil error:nil];
    outputString = [outputString stringByAppendingPathComponent:@"output.MOV"];
    
    [self trimVideo:[NSURL fileURLWithPath:outputString] assetObject:asset startTime:currentViewController.startTime endTime:currentViewController.endTime];
    
}

- (void)trimVideo:(NSURL *)outputURL assetObject:(AVAsset *)asset startTime:(CGFloat)startTime endTime:(CGFloat)endTime
{
    
    NSArray *compatiblePresets = [AVAssetExportSession exportPresetsCompatibleWithAsset:asset];
    if ([compatiblePresets containsObject:AVAssetExportPresetHighestQuality]) {
        
        self.trimExportSession = [[AVAssetExportSession alloc]
                                  initWithAsset:asset presetName:AVAssetExportPresetHighestQuality];
        if ([[NSFileManager defaultManager] fileExistsAtPath:outputURL.absoluteString])
            [[NSFileManager defaultManager] removeItemAtPath:outputURL.absoluteString error:nil];
        
        self.trimExportSession.outputURL = outputURL;
        //provide outputFileType acording to video format extension
        self.trimExportSession.outputFileType = AVFileTypeQuickTimeMovie;
        
        CMTime start = CMTimeMakeWithSeconds(startTime, asset.duration.timescale);
        CMTime duration = CMTimeMakeWithSeconds(endTime-startTime, asset.duration.timescale);
        CMTimeRange range = CMTimeRangeMake(start, duration);
        self.trimExportSession.timeRange = range;
        [NSTimer scheduledTimerWithTimeInterval:.05 target:self selector:@selector(updateExportHUDProgress:) userInfo:nil repeats:YES]; // start progess timer
        
        [self.trimExportSession exportAsynchronouslyWithCompletionHandler:^{
            
            switch ([self.trimExportSession status]) {
                case AVAssetExportSessionStatusFailed: case AVAssetExportSessionStatusUnknown: case AVAssetExportSessionStatusWaiting: case AVAssetExportSessionStatusExporting: {
                    NSLog(@"Export failed: %@", [[self.trimExportSession error] localizedDescription]);
                    NSError *removeError =nil;
                    [NSFileManager.defaultManager removeItemAtURL:[self.trimExportSession outputURL] error:&removeError];
                    [self dismissHUDWithError:@"Unable to trim video"];
                    break;
                }
                case AVAssetExportSessionStatusCancelled: {
                    NSLog(@"Export canceled");
                    [self dismissHUDWithError:@"Trimming cancelled"];
                    break;
                }
                default: { // success
                    NSLog(@"Triming Completed");
                    self.hud.mode = MBProgressHUDModeIndeterminate;
                    self.hud.labelText = @"Saving";
                    ALAssetsLibrary* library = ALAssetsLibrary.new;
                    [library writeVideoAtPathToSavedPhotosAlbum:[self.trimExportSession outputURL]
                                                completionBlock:^(NSURL *assetURL, NSError *error){
                                                    if (error || !assetURL) {
                                                        [self dismissHUDWithError:@"Unable to save to library"];
                                                    } else {
                                                        [self addItemWithPathStringToGalleryItems:assetURL.absoluteString];
                                                        [self dismissHUDWithSuccess];
                                                        [self jumpToFront];
                                                        [self updateVideoGalleryItems];
                                                    }
                                                    [NSFileManager.defaultManager removeItemAtURL:[self.trimExportSession outputURL] error:nil];
                                                }];
                    
                    break;
                }
            }
        }];
    } else {
        [self dismissHUDWithError:@"Trimming cancelled"];
    }
}

-(void)updateExportHUDProgress:(NSTimer *)timer {
    float progress = self.trimExportSession.progress;
    self.hud.progress = progress;
    if (progress > .99) [timer invalidate];
}

-(void) dismissHUDWithSuccess {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = [UIImage imageNamed:@"check.png"];
        UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
        self.hud.customView = imageView;
        self.hud.mode = MBProgressHUDModeCustomView;
        self.hud.labelText = @"Completed";
        [self.hud hide:YES afterDelay:1];
    });
}

-(void) dismissHUDWithError:(NSString *)detailString {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = [UIImage imageNamed:@"cross.png"];
        UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
        self.hud.customView = imageView;
        self.hud.mode = MBProgressHUDModeCustomView;
        self.hud.labelText = @"Error";
        self.hud.detailsLabelText = detailString;
        [self.hud hide:YES afterDelay:1];
    });
}

-(void)jumpToFront {
    MHImageViewController *imageViewController =[MHImageViewController imageViewControllerForMHMediaItem:[self itemForIndex:0] viewController:self];
    imageViewController.pageIndex = 0;
    
    self.leftBarButton.enabled = NO;
    
    // reset pageviewcontroller to dodge caching bug
    self.pageViewController.dataSource = nil;
    self.pageViewController.dataSource = self;
    
    self.pageIndex = imageViewController.pageIndex;
    [self updateToolBarForItem:[self itemForIndex:self.pageIndex]];
    [self showCurrentIndex:self.pageIndex];
    [self.pageViewController setViewControllers:@[imageViewController] direction:UIPageViewControllerNavigationDirectionReverse animated:YES completion:^(BOOL finished) {
        
    }];
}


@end

@interface MHImageViewController () <SAVideoRangeSliderDelegate>
@property (nonatomic, strong) UIButton                 *videoPlayerClearButton;
@property (nonatomic, strong) NSTimer                  *movieTimer;
@property (nonatomic, strong) NSTimer                  *movieDownloadedTimer;
@property (nonatomic, strong) UIPanGestureRecognizer   *pan;
@property (nonatomic, strong) MHPinchGestureRecognizer *pinch;

@property (nonatomic, strong) SAVideoRangeSlider *videoRangeSlider;
@property (nonatomic) CGFloat videoDuration;


@property (nonatomic)         CGPoint                  pointToCenterAfterResize;
@property (nonatomic)         CGFloat                  scaleToRestoreAfterResize;
@property (nonatomic)         CGPoint                  startPoint;
@property (nonatomic)         CGPoint                  lastPoint;
@property (nonatomic)         CGPoint                  lastPointPop;
@property (nonatomic)         BOOL                     shouldPlayVideo;

@end

@implementation MHImageViewController


+(MHImageViewController *)imageViewControllerForMHMediaItem:(MHGalleryItem*)item
                                             viewController:(MHGalleryImageViewerViewController*)viewController{
    if (item) {
        return [self.alloc initWithMHMediaItem:item
                                viewController:viewController];
    }
    return nil;
}
-(CGFloat)checkProgressValue:(CGFloat)progress{
    CGFloat progressChecked =progress;
    if (progressChecked <0) {
        progressChecked = -progressChecked;
    }
    if (progressChecked >=1) {
        progressChecked =0.99;
    }
    return progressChecked;
}

-(void)userDidPinch:(UIPinchGestureRecognizer*)recognizer{
    
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        if (recognizer.scale <1) {
            self.imageView.frame = self.scrollView.frame;
            
            self.lastPointPop = [recognizer locationInView:self.view];
            self.interactiveOverView = [MHTransitionShowOverView new];
            [self.navigationController popViewControllerAnimated:YES];
        }else{
            recognizer.cancelsTouchesInView = YES;
        }
        
    }else if (recognizer.state == UIGestureRecognizerStateChanged) {
        
        if (recognizer.numberOfTouches <2) {
            recognizer.enabled =NO;
            recognizer.enabled =YES;
        }
        
        CGPoint point = [recognizer locationInView:self.view];
        self.interactiveOverView.scale = recognizer.scale;
        self.interactiveOverView.changedPoint = CGPointMake(self.lastPointPop.x - point.x, self.lastPointPop.y - point.y) ;
        [self.interactiveOverView updateInteractiveTransition:1-recognizer.scale];
        self.lastPointPop = point;
    }else if (recognizer.state == UIGestureRecognizerStateEnded || recognizer.state == UIGestureRecognizerStateCancelled) {
        if (recognizer.scale < 0.65) {
            [self.interactiveOverView finishInteractiveTransition];
        }else{
            [self.interactiveOverView cancelInteractiveTransition];
        }
        self.interactiveOverView = nil;
    }
}

-(void)userDidPan:(UIPanGestureRecognizer*)recognizer{
    
    BOOL userScrolls = self.viewController.userScrolls;
    if (self.viewController.transitionCustomization.dismissWithScrollGestureOnFirstAndLastImage) {
        if (!self.interactiveTransition) {
            if (self.viewController.numberOfGalleryItems ==1) {
                userScrolls = NO;
                self.viewController.userScrolls = NO;
            }else{
                if (self.pageIndex ==0) {
                    if ([recognizer translationInView:self.view].x >=0) {
                        userScrolls =NO;
                        self.viewController.userScrolls = NO;
                    }else{
                        recognizer.cancelsTouchesInView = YES;
                        recognizer.enabled =NO;
                        recognizer.enabled =YES;
                    }
                }
                if ((self.pageIndex == self.viewController.numberOfGalleryItems-1)) {
                    if ([recognizer translationInView:self.view].x <=0) {
                        userScrolls =NO;
                        self.viewController.userScrolls = NO;
                    }else{
                        recognizer.cancelsTouchesInView = YES;
                        recognizer.enabled =NO;
                        recognizer.enabled =YES;
                    }
                }
            }
        }else{
            userScrolls = NO;
        }
    }
    
    if (!userScrolls || recognizer.state == UIGestureRecognizerStateEnded || recognizer.state == UIGestureRecognizerStateCancelled) {
        CGFloat progressY = (self.startPoint.y - [recognizer translationInView:self.view].y)/(self.view.frame.size.height/2);
        progressY = [self checkProgressValue:progressY];
        CGFloat progressX = (self.startPoint.x - [recognizer translationInView:self.view].x)/(self.view.frame.size.width/2);
        progressX = [self checkProgressValue:progressX];
        
        if (recognizer.state == UIGestureRecognizerStateBegan) {
            self.startPoint = [recognizer translationInView:self.view];
        }else if (recognizer.state == UIGestureRecognizerStateChanged) {
            if (!self.interactiveTransition ) {
                self.startPoint = [recognizer translationInView:self.view];
                self.lastPoint = [recognizer translationInView:self.view];
                self.interactiveTransition = [MHTransitionDismissMHGallery new];
                self.interactiveTransition.orientationTransformBeforeDismiss = [(NSNumber *)[self.navigationController.view valueForKeyPath:@"layer.transform.rotation.z"] floatValue];
                self.interactiveTransition.interactive = YES;
                
                if (self.viewController.galleryViewController && self.viewController.galleryViewController.finishedCallback) {
                    self.viewController.galleryViewController.finishedCallback(self.pageIndex,self.imageView.image,self.interactiveTransition,self.viewController.viewModeForBarStyle);
                }
                
            }else{
                CGPoint currentPoint = [recognizer translationInView:self.view];
                
                if (self.viewController.transitionCustomization.fixXValueForDismiss) {
                    self.interactiveTransition.changedPoint = CGPointMake(self.startPoint.x, self.lastPoint.y-currentPoint.y);
                }else{
                    self.interactiveTransition.changedPoint = CGPointMake(self.lastPoint.x-currentPoint.x, self.lastPoint.y-currentPoint.y);
                }
                progressY = [self checkProgressValue:progressY];
                progressX = [self checkProgressValue:progressX];
                
                if (!self.viewController.transitionCustomization.fixXValueForDismiss) {
                    if (progressX> progressY) {
                        progressY = progressX;
                    }
                }
                
                [self.interactiveTransition updateInteractiveTransition:progressY];
                self.lastPoint = [recognizer translationInView:self.view];
            }
            
        }else if (recognizer.state == UIGestureRecognizerStateEnded || recognizer.state == UIGestureRecognizerStateCancelled) {
            if (self.interactiveTransition) {
                CGFloat velocityY = [recognizer velocityInView:self.view].y;
                if (velocityY <0) {
                    velocityY = -velocityY;
                }
                if (!self.viewController.transitionCustomization.fixXValueForDismiss) {
                    if (progressX> progressY) {
                        progressY = progressX;
                    }
                }
                
                if (progressY > 0.35 || velocityY >700) {
                    MHStatusBar().alpha =1;
                    [self.interactiveTransition finishInteractiveTransition];
                }else {
                    [self setNeedsStatusBarAppearanceUpdate];
                    [self.interactiveTransition cancelInteractiveTransition];
                }
                self.interactiveTransition = nil;
            }
        }
    }
}


- (id)initWithMHMediaItem:(MHGalleryItem*)mediaItem
           viewController:(MHGalleryImageViewerViewController*)viewController{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        
        __weak typeof(self) weakSelf = self;
        
        
        self.viewController = viewController;
        
        self.view.backgroundColor = [UIColor blackColor];
        
        self.item = mediaItem;
        
        self.scrollView = [UIScrollView.alloc initWithFrame:self.view.bounds];
        self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth |UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleBottomMargin;
        self.scrollView.delegate = self;
        self.scrollView.tag = 406;
        self.scrollView.maximumZoomScale = 3;
        self.scrollView.minimumZoomScale = 1;
        self.scrollView.userInteractionEnabled = YES;
        [self.view addSubview:self.scrollView];
        
        
        self.imageView = [UIImageView.alloc initWithFrame:self.view.bounds];
        self.imageView.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth |UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleBottomMargin;
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
        self.imageView.clipsToBounds = YES;
        self.imageView.tag = 506;
        [self.scrollView addSubview:self.imageView];
        
        self.pinch = [MHPinchGestureRecognizer.alloc initWithTarget:self action:@selector(userDidPinch:)];
        self.pinch.delegate = self;
        
        self.pan = [UIPanGestureRecognizer.alloc initWithTarget:self action:@selector(userDidPan:)];
        UITapGestureRecognizer *doubleTap = [UITapGestureRecognizer.alloc initWithTarget:self action:@selector(handleDoubleTap:)];
        doubleTap.numberOfTapsRequired =2;
        
        UITapGestureRecognizer *imageTap =[UITapGestureRecognizer.alloc initWithTarget:self action:@selector(handelImageTap:)];
        imageTap.numberOfTapsRequired =1;
        
        [self.imageView addGestureRecognizer:doubleTap];
        
        self.pan.delegate = self;
        
        if(self.viewController.transitionCustomization.interactiveDismiss){
            [self.imageView addGestureRecognizer:self.pan];
            self.pan.maximumNumberOfTouches =1;
            self.pan.delaysTouchesBegan = YES;
        }
        if (self.viewController.UICustomization.showOverView) {
            [self.scrollView addGestureRecognizer:self.pinch];
        }
        
        [self.view addGestureRecognizer:imageTap];
        
        self.act = [UIActivityIndicatorView.alloc initWithFrame:self.view.bounds];
        [self.act startAnimating];
        self.act.hidesWhenStopped = YES;
        self.act.tag = 507;
        self.act.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
        [self.scrollView addSubview:self.act];
        if (self.item.galleryType != MHGalleryTypeImage) {
            [self addVideoClearButton];
            [self addPlayButtonToView];
            
            self.videoPlayerAsset = [AVURLAsset assetWithURL:[NSURL URLWithString:self.item.URLString]];
            self.videoRangeSlider = [[SAVideoRangeSlider alloc] initWithFrame:CGRectMake(0, 44, [UIApplication currentSize].width, 44) videoAsset:self.videoPlayerAsset];
            self.videoRangeSlider.delegate = self;
            self.videoRangeSlider.alpha = 0;
            self.videoRangeSlider.minGap = 50;
            
            [self.view addSubview:self.videoRangeSlider];

            self.startTime = 0;
            self.endTime = CMTimeGetSeconds(self.videoPlayerAsset.duration);
            
            self.scrollView.maximumZoomScale = 1; // don't allow zoom in on videos
            self.scrollView.minimumZoomScale = 1;
        }
        
        self.imageView.userInteractionEnabled = YES;
        
        [imageTap requireGestureRecognizerToFail: doubleTap];
        
        
        
        if (self.item.galleryType == MHGalleryTypeImage) {
            [self.imageView setImageForMHGalleryItem:self.item imageType:MHImageTypeFull successBlock:^(UIImage *image, NSError *error) {
                if (!image) {
                    weakSelf.scrollView.maximumZoomScale  =1;
                    [weakSelf changeToErrorImage];
                }
                [weakSelf.act stopAnimating];
            }];
        }else{
            [MHGallerySharedManager.sharedManager startDownloadingThumbImage:self.item.URLString
                                                                successBlock:^(UIImage *image,NSUInteger videoDuration,NSError *error) {
                                                                    if (!error) {
                                                                        [weakSelf handleGeneratedThumb:image
                                                                                         videoDuration:videoDuration
                                                                                             urlString:self.item.URLString];
                                                                    }else{
                                                                        [weakSelf changeToErrorImage];
                                                                    }
                                                                    [weakSelf.act stopAnimating];
                                                                }];
        }
    }
    
    return self;
}

-(void)setImageForImageViewWithImage:(UIImage*)image error:(NSError*)error{
    if (!image) {
        self.scrollView.maximumZoomScale  = 1;
        [self changeToErrorImage];
    }else{
        self.imageView.image = image;
    }
    [self.act stopAnimating];
}

-(void)changeToErrorImage{
    self.imageView.image = MHGalleryImage(@"error");
}

-(void)changePlayButtonToUnPlay{
    [self.playButton setImage:MHGalleryImage(@"unplay")
                     forState:UIControlStateNormal];
}

-(void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self stopMovie];
}

-(void)handleGeneratedThumb:(UIImage*)image
              videoDuration:(NSInteger)videoDuration
                  urlString:(NSString*)urlString{
    
    self.imageView.image = image;
    [self.act stopAnimating];
}

-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer{
    if (self.interactiveOverView) {
        if ([gestureRecognizer isKindOfClass:MHPinchGestureRecognizer.class]) {
            return YES;
        }
        return NO;
    }
    if (self.interactiveTransition) {
        if ([gestureRecognizer isEqual:self.pan]) {
            return YES;
        }
        return NO;
    }
    if (self.viewController.transitionCustomization.dismissWithScrollGestureOnFirstAndLastImage) {
        if ((self.pageIndex ==0 || self.pageIndex == self.viewController.numberOfGalleryItems -1)) {
            if ([gestureRecognizer isKindOfClass:UIPanGestureRecognizer.class]|| [otherGestureRecognizer isKindOfClass:NSClassFromString(@"UIScrollViewDelayedTouchesBeganGestureRecognizer")] ) {
                return YES;
            }
        }
    }
    return NO;
}
-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch{
    
    if (self.interactiveOverView) {
        if ([gestureRecognizer isKindOfClass:MHPinchGestureRecognizer.class]) {
            return YES;
        }else{
            return NO;
        }
    }else{
        if ([gestureRecognizer isKindOfClass:MHPinchGestureRecognizer.class]) {
            if ([gestureRecognizer isKindOfClass:MHPinchGestureRecognizer.class] && self.scrollView.zoomScale ==1) {
                return YES;
            }else{
                return NO;
            }
        }
    }
    if (self.viewController.isUserScrolling) {
        if ([gestureRecognizer isEqual:self.pan]) {
            return NO;
        }
    }
    if ([gestureRecognizer isEqual:self.pan] && self.scrollView.zoomScale !=1) {
        return NO;
    }
    if (self.interactiveTransition) {
        if ([gestureRecognizer isEqual:self.pan]) {
            return YES;
        }
        return NO;
    }
    if (self.viewController.transitionCustomization.dismissWithScrollGestureOnFirstAndLastImage) {
        if ((self.pageIndex ==0 || self.pageIndex == self.viewController.numberOfGalleryItems -1) && [gestureRecognizer isKindOfClass:UIPanGestureRecognizer.class]) {
            return YES;
        }
    }
    
    return YES;
}


-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer{
    
    if (self.interactiveOverView || self.interactiveTransition) {
        return NO;
    }
    if ([otherGestureRecognizer isKindOfClass:NSClassFromString(@"UIScrollViewDelayedTouchesBeganGestureRecognizer")]|| [otherGestureRecognizer isKindOfClass:NSClassFromString(@"UIScrollViewPanGestureRecognizer")] ) {
        return YES;
    }
    if ([gestureRecognizer isKindOfClass:MHPinchGestureRecognizer.class]) {
        return YES;
    }
    if (self.viewController.transitionCustomization.dismissWithScrollGestureOnFirstAndLastImage) {
        if ((self.pageIndex ==0 || self.pageIndex == self.viewController.numberOfGalleryItems -1) && [gestureRecognizer isKindOfClass:UIPanGestureRecognizer.class]) {
            return YES;
        }
    }
    return NO;
}


-(MHGalleryViewMode)currentViewMode{
    if (self.viewController.isHiddingToolBarAndNavigationBar) {
        return MHGalleryViewModeImageViewerNavigationBarHidden;
    }
    return MHGalleryViewModeImageViewerNavigationBarShown;
}

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    self.scrollView.backgroundColor = [self.viewController.UICustomization MHGalleryBackgroundColorForViewMode:[self currentViewMode]];
    if (self.viewController.isHiddingToolBarAndNavigationBar) {
        self.act.color = [UIColor whiteColor];
        if (self.item.galleryType == MHGalleryTypeVideo) self.videoRangeSlider.alpha = 0;
    } else {
        if (self.item.galleryType == MHGalleryTypeVideo) self.videoRangeSlider.alpha = 1;
        self.act.color = [UIColor whiteColor];
    }
    if (self.item.galleryType == MHGalleryTypeVideo) {
        CGSize screenSize = [UIApplication currentSize];
        [self.videoRangeSlider updateFrame:CGRectMake(self.videoRangeSlider.frame.origin.x, self.navigationController.navigationBar.frame.size.height, screenSize.width, self.videoRangeSlider.frame.size.height)];
        if (self.videoPlayer) {
            float currentTime = CMTimeGetSeconds(self.videoPlayer.currentTime);
            [self.videoRangeSlider updateScrubberWithCurrentPlayTime:currentTime];
            [self seekToTime:currentTime];
            [self preparePlayerToPlay];
            [self updateTrimButton];
            self.videoPlayerLayer.frame = CGRectMake(0, 0, screenSize.width, screenSize.height);
        }
    }
    self.playButton.frame = CGRectMake([UIApplication currentSize].width/2-36, [UIApplication currentSize].height/2-36, 72, 72);
//    self.scrollView.contentSize = CGSizeMake(self.view.bounds.size.width*self.scrollView.zoomScale, self.view.bounds.size.height*self.scrollView.zoomScale);
//    self.imageView.frame = CGRectMake(0,0 , self.scrollView.contentSize.width,self.scrollView.contentSize.height);
}

-(void)changeUIForViewMode:(MHGalleryViewMode)viewMode{
    float alpha =0;
    if (viewMode == MHGalleryViewModeImageViewerNavigationBarShown) {
        alpha =1;
    }
    self.scrollView.backgroundColor = [self.viewController.UICustomization MHGalleryBackgroundColorForViewMode:viewMode];
    self.viewController.pageViewController.view.backgroundColor = [self.viewController.UICustomization MHGalleryBackgroundColorForViewMode:viewMode];
    
    self.navigationController.navigationBar.alpha =alpha;
    self.viewController.toolbar.alpha =alpha;
    
    self.viewController.descriptionView.alpha =alpha;
    self.viewController.descriptionViewBackground.alpha =alpha;
    MHStatusBar().alpha =alpha;
    self.videoRangeSlider.alpha = alpha;
    
}

-(void)handelImageTap:(UIGestureRecognizer *)gestureRecognizer{
    if (!self.viewController.isHiddingToolBarAndNavigationBar) {
        [UIView animateWithDuration:0.3 animations:^{
            
            if (self.videoRangeSlider) {
                self.videoRangeSlider.alpha =0;
            }
            [self changeUIForViewMode:MHGalleryViewModeImageViewerNavigationBarHidden];
        } completion:^(BOOL finished) {
            
            self.viewController.hiddingToolBarAndNavigationBar = YES;
            self.navigationController.navigationBar.hidden  =YES;
            self.viewController.toolbar.hidden =YES;
        }];
    }else{
        self.navigationController.navigationBar.hidden = NO;
        self.viewController.toolbar.hidden = NO;
        
        [UIView animateWithDuration:0.3 animations:^{
            [self changeUIForViewMode:MHGalleryViewModeImageViewerNavigationBarShown];
            if (self.videoRangeSlider) {
                if (self.item.galleryType == MHGalleryTypeVideo) {
                    self.videoRangeSlider.alpha =1;
                }
            }
        } completion:^(BOOL finished) {
            self.viewController.hiddingToolBarAndNavigationBar = NO;
        }];
        
    }
}

- (void)handleDoubleTap:(UIGestureRecognizer *)gestureRecognizer {
    if (([self.imageView.image isEqual:MHGalleryImage(@"error")]) || (self.item.galleryType == MHGalleryTypeVideo)) {
        return;
    }
    
    if (self.scrollView.zoomScale >1) {
        [self.scrollView setZoomScale:1 animated:YES];
        return;
    }
    [self centerImageView];
    
    CGRect zoomRect;
    CGFloat newZoomScale = (self.scrollView.maximumZoomScale);
    CGPoint touchPoint = [gestureRecognizer locationInView:gestureRecognizer.view];
    
    zoomRect.size.height = [self.imageView frame].size.height / newZoomScale;
    zoomRect.size.width  = [self.imageView frame].size.width  / newZoomScale;
    
    touchPoint = [self.scrollView convertPoint:touchPoint fromView:self.imageView];
    
    zoomRect.origin.x    = touchPoint.x - ((zoomRect.size.width / 2.0));
    zoomRect.origin.y    = touchPoint.y - ((zoomRect.size.height / 2.0));
    
    [self.scrollView zoomToRect:zoomRect animated:YES];
}


-(UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView{
    return [scrollView.subviews firstObject];
}

- (void)prepareToResize{
    CGPoint boundsCenter = CGPointMake(CGRectGetMidX(self.scrollView.bounds), CGRectGetMidY(self.scrollView.bounds));
    self.pointToCenterAfterResize = [self.scrollView convertPoint:boundsCenter toView:self.imageView];
    self.scaleToRestoreAfterResize = self.scrollView.zoomScale;
}
- (void)recoverFromResizing{
    self.scrollView.zoomScale = MIN(self.scrollView.maximumZoomScale, MAX(self.scrollView.minimumZoomScale, _scaleToRestoreAfterResize));
    CGPoint boundsCenter = [self.scrollView convertPoint:self.pointToCenterAfterResize fromView:self.imageView];
    CGPoint offset = CGPointMake(boundsCenter.x - self.scrollView.bounds.size.width / 2.0,
                                 boundsCenter.y - self.scrollView.bounds.size.height / 2.0);
    CGPoint maxOffset = [self maximumContentOffset];
    CGPoint minOffset = [self minimumContentOffset];
    offset.x = MAX(minOffset.x, MIN(maxOffset.x, offset.x));
    offset.y = MAX(minOffset.y, MIN(maxOffset.y, offset.y));
    self.scrollView.contentOffset = offset;
}



- (CGPoint)maximumContentOffset{
    CGSize contentSize = self.scrollView.contentSize;
    CGSize boundsSize = self.scrollView.bounds.size;
    return CGPointMake(contentSize.width - boundsSize.width, contentSize.height - boundsSize.height);
}

- (CGPoint)minimumContentOffset{
    return CGPointZero;
}

-(void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                        duration:(NSTimeInterval)duration{
    self.playButton.frame = CGRectMake(self.viewController.view.frame.size.width/2-36, self.viewController.view.frame.size.height/2-36, 72, 72);
    self.scrollView.contentSize = CGSizeMake(self.view.bounds.size.width*self.scrollView.zoomScale, self.view.bounds.size.height*self.scrollView.zoomScale);
    self.imageView.frame =CGRectMake(0,0 , self.scrollView.contentSize.width,self.scrollView.contentSize.height);
    CGSize futureSize = [UIApplication sizeInOrientation:toInterfaceOrientation];
    if (self.item.galleryType == MHGalleryTypeVideo) {
        CGSize screenSize = [UIApplication sizeInOrientation:toInterfaceOrientation];
//        NSLog(@"%@", NSStringFromCGSize(screenSize));
        [self.videoRangeSlider updateFrame:CGRectMake(self.videoRangeSlider.frame.origin.x, self.navigationController.navigationBar.frame.size.height, futureSize.width, self.videoRangeSlider.frame.size.height)];
        self.videoPlayerLayer.frame = CGRectMake(0, 0, futureSize.width, futureSize.height);
        if (self.videoPlayer) {
            self.imageView.hidden = YES;
        }
    }
}

-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation{
    [self prepareToResize];
    [self recoverFromResizing];
    [self centerImageView];
}

-(void)centerImageView{
    if(self.imageView.image){
        CGRect frame  = AVMakeRectWithAspectRatioInsideRect(self.imageView.image.size,CGRectMake(0, 0, self.scrollView.contentSize.width, self.scrollView.contentSize.height));
        
        if (self.scrollView.contentSize.width==0 && self.scrollView.contentSize.height==0) {
            frame = AVMakeRectWithAspectRatioInsideRect(self.imageView.image.size,self.scrollView.bounds);
        }
        
        CGSize boundsSize = self.scrollView.bounds.size;
        
        CGRect frameToCenter = CGRectMake(0,0 , frame.size.width, frame.size.height);
        
        if (frameToCenter.size.width < boundsSize.width){
            frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2;
        }else{
            frameToCenter.origin.x = 0;
        }if (frameToCenter.size.height < boundsSize.height){
            frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2;
        }else{
            frameToCenter.origin.y = 0;
        }
        self.imageView.frame = frameToCenter;
    }
}
-(void)scrollViewDidZoom:(UIScrollView *)scrollView{
    [self centerImageView];
}

//-(void)scrollViewDidScroll:(UIScrollView *)scrollView{
//    
//}

-(void)updateTrimButton {
    if (self.startTime != 0 || self.endTime != self.videoDuration) {
        self.viewController.trimBarButton.enabled = YES;
    } else {
        self.viewController.trimBarButton.enabled = NO;
    }
}

-(void)didReceiveMemoryWarning{
    [super didReceiveMemoryWarning];
}

#pragma mark - Video Player

-(void)stopMovie{
    [self stopTimer];
    self.playingVideo = NO;
    [self.videoPlayer pause];
    
    [self.view bringSubviewToFront:self.playButton];
    self.playButton.hidden = NO;
    [self.view bringSubviewToFront:self.videoRangeSlider];
    [self.viewController changeToPlayButton];
}


-(void)setupPlayer {
    self.videoDuration = CMTimeGetSeconds(self.videoPlayerAsset.duration);
    if (self.endTime == 0) self.endTime = self.videoDuration;
    self.playingVideo = NO;
    self.videoPlayerItem = [[AVPlayerItem alloc] initWithAsset:self.videoPlayerAsset];
    self.videoPlayer = [[AVPlayer alloc] initWithPlayerItem:self.videoPlayerItem];
    self.videoPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:self.videoPlayer];
    CGSize screenSize = [UIApplication currentSize];
    [self.videoPlayerLayer setFrame:CGRectMake(0, 0, screenSize.width, screenSize.height)];
    [self.videoPlayer seekToTime:CMTimeMakeWithSeconds(self.startTime, 600) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    [self.view.layer addSublayer:self.videoPlayerLayer];
    [self preparePlayerToPlay];
}

-(void)movieTimerUpdated:(NSTimer*)timer {
    Float64 currentTime = CMTimeGetSeconds(self.videoPlayer.currentTime);
    if (currentTime >= self.endTime) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self stopMovie]; // also stops timer
            
            [self.videoPlayer seekToTime:CMTimeMakeWithSeconds(self.startTime, 600) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
            [self.videoRangeSlider updateScrubberWithCurrentPlayTime:self.startTime];
        });
    } else {
        [self.videoRangeSlider updateScrubberWithCurrentPlayTime:currentTime];
    }
    
}

-(void)addPlayButtonToView{
    if (self.playButton) {
        [self.playButton removeFromSuperview];
    }
    self.playButton = [UIButton.alloc initWithFrame:self.viewController.view.bounds];
    self.playButton.frame = CGRectMake(self.viewController.view.frame.size.width/2-36, self.viewController.view.frame.size.height/2-36, 72, 72);
    [self.playButton setImage:MHGalleryImage(@"playButton") forState:UIControlStateNormal];
    self.playButton.tag = 508;
    self.playButton.frame = CGRectMake(self.viewController.view.frame.size.width/2-36, self.viewController.view.frame.size.height/2-36, 72, 72);
    self.playButton.hidden = NO;
    [self.playButton addTarget:self action:@selector(playButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.playButton];
}

-(void)addVideoClearButton {
    if (self.videoPlayerClearButton) [self.videoPlayerClearButton removeFromSuperview];
    self.videoPlayerClearButton = [UIButton.alloc initWithFrame:self.view.bounds];
    [self.videoPlayerClearButton addTarget:self action:@selector(handelImageTap:) forControlEvents:UIControlEventTouchUpInside];
    self.videoPlayerClearButton.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.videoPlayerClearButton];
}


-(void)removeAllMoviePlayerViewsAndNotifications{
    [self stopMovie];
    [self.videoPlayerLayer removeFromSuperlayer];
    self.videoPlayer = nil;
    self.videoPlayerItem = nil;
    self.videoPlayerLayer = nil;
    self.videoPlayerAsset = nil;
    [self.videoRangeSlider removeFromSuperview];
    self.videoRangeSlider = nil;
    
    [self addPlayButtonToView];
    self.playButton.hidden = NO;
    self.playButton.frame = CGRectMake(self.viewController.view.frame.size.width/2-36, self.viewController.view.frame.size.height/2-36, 72, 72);
    [self.videoPlayerClearButton removeFromSuperview];
    [self.viewController changeToPlayButton];
    self.imageView.hidden = NO;
}


-(void)stopTimer{
    [self.movieTimer invalidate];
    self.movieTimer = nil;
}

- (void) bringSublayerToFront:(CALayer *)layer {
    [layer removeFromSuperlayer];
    [self.view.layer addSublayer:layer];
}

-(void)preparePlayerToPlay {
    self.videoPlayerLayer.hidden = NO;
    
    [self.view bringSubviewToFront:self.scrollView];
    [self bringSublayerToFront:self.videoPlayerLayer];
    [self.view addSubview:self.videoPlayerClearButton];
    [self.view bringSubviewToFront:self.videoRangeSlider];
    [self.view bringSubviewToFront:self.playButton];
    
    if(self.viewController.transitionCustomization.interactiveDismiss){
        [self.videoPlayerClearButton addGestureRecognizer:self.pan];
    }
}

-(void)playButtonPressed{
    if (!self.playingVideo) {
        if (!self.videoPlayer)
            [self setupPlayer];
        else
            [self preparePlayerToPlay];
        
        self.playButton.hidden = YES;
        self.playingVideo = YES;
        
        [self.videoPlayer play];
        [self.viewController changeToPauseButton];
        
        if (!self.movieTimer) {
            self.movieTimer = [NSTimer timerWithTimeInterval:0.03f
                                                      target:self
                                                    selector:@selector(movieTimerUpdated:)
                                                    userInfo:nil
                                                     repeats:YES];
            [NSRunLoop.currentRunLoop addTimer:self.movieTimer forMode:NSRunLoopCommonModes];
        }
    }else{
        [self stopMovie];
    }
}


#pragma mark - SAVideoRangeSliderDelegate

-(void)videoRange:(SAVideoRangeSlider *)videoRange didChangeStartTime:(CGFloat)startTime endTime:(CGFloat)endTime {
    if (!self.videoPlayer) [self setupPlayer];
    self.startTime = startTime;
    self.endTime = endTime;
    [self updateTrimButton];
}

-(void)videoRange:(SAVideoRangeSlider *)videoRange didChangeStartTime:(CGFloat)startTime  {
    if (!self.videoPlayer) [self setupPlayer];
    self.startTime = startTime;
    [self updateTrimButton];
}

-(void)videoRange:(SAVideoRangeSlider *)videoRange didChangeEndTime:(CGFloat)endTime {
    if (!self.videoPlayer) [self setupPlayer];
    self.endTime = endTime;
    [self updateTrimButton];
    
}


-(void)videoRange:(SAVideoRangeSlider *)videoRange didChangeScrubberTimePosition:(CGFloat)scrubberTimePostion {
    if (!self.videoPlayer) [self setupPlayer];
    [self seekToTime:scrubberTimePostion];
}

-(void)seekToTime:(CGFloat)time {
    if (self.videoPlayer) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self stopMovie];
            [self.videoPlayer seekToTime:CMTimeMakeWithSeconds(time, 600) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
        });
    }
}
@end

