//
//  CameraViewController.m
//  Remote Shot
//
//  Created by Luke Wilson on 3/18/14.
//  Copyright (c) 2014 Luke Wilson. All rights reserved.
//

#import "CameraRemoteViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <QuartzCore/QuartzCore.h>
#import "CSRMoveableImageView.h"
#import "LWTutorialViewController.h"
#import "DragAnimationView.h"
#import "UIImage+Overlay.h"
#import "UIImage+StackBlur.h"
#import "MHGallery.h"


#define kDefaultAlpha 1

#define kFocusViewTag 1
#define kExposeViewTag 2


#define kSwipeVelocityUntilGuarenteedSwitch 800
#define kLargeFontSize 70
#define kMediumFontSize 60
#define kSmallFontSize 47

#define kSettingsViewHeight 100
#define kiPhonePhotoPreviewHeight 426.666

#define kVideoDimension (9.0/16)
#define kPhotoDimension (3.0/4)


#define IPAD (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
#define IPHONE_4 ([UIScreen mainScreen].bounds.size.height == 480)
#define IPHONE_5 ([UIScreen mainScreen].bounds.size.height == 568)


// Interface here for private properties
@interface CameraRemoteViewController () <UIPickerViewDataSource, UIPickerViewDelegate, AVAudioPlayerDelegate, DragAnimationViewDelegate>

@property (nonatomic, weak) IBOutlet UIImageView *previewView;

@property (nonatomic, weak) IBOutlet UIView *cameraUIView;

@property (nonatomic) UIImageView *cameraRollImage; //child of cameraRollButton (stacks on top just taken picture)
@property (nonatomic, weak) IBOutlet CSRMoveableImageView *focusPointView;
@property (nonatomic, weak) IBOutlet CSRMoveableImageView *exposePointView;
@property (nonatomic, weak) IBOutlet UIImageView *blurredImagePlaceholder;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *cameraUIDistanceToBottom;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *cameraUIDistanceToTop;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *cameraPreviewViewDistanceToBottom;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *cameraPreviewViewDistanceToTop;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *blackBackgroundDistanceToBottom;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *blackBackgroundDistanceToTop;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *blurredImageDistanceToBottom;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *blurredImageDistanceToTop;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *flashOnDistanceToTop;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *flashOffDistanceToTop;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *flashAutoDistanceToTop;
@property (weak, nonatomic) IBOutlet UILabel *flashOnLabel;
@property (weak, nonatomic) IBOutlet UILabel *flashOffLabel;
@property (weak, nonatomic) IBOutlet UILabel *flashAutoLabel;
@property (weak, nonatomic) IBOutlet UIView *UITransparentBG;
@property (nonatomic, weak) IBOutlet UIView *notConnectedToDeviceView;

@property (nonatomic) CGFloat distanceToCenterPhotoPreview;
@property (weak, nonatomic) IBOutlet UIView *blackBackground;

@property (nonatomic, weak)  UIView *pictureSwipeView;
@property (nonatomic, weak)  UIView *rapidShotSwipeView;
@property (nonatomic, weak)  UIView *videoSwipeView;

@property (nonatomic)  DragAnimationView *settingsButtonDragView;
@property (nonatomic)  DragAnimationView *previewOverlayDragView;
@property (nonatomic)  NSArray *menuAnimationSteps;
@property (nonatomic)  NSArray *iPhone5MenuAnimationSteps;

@property (nonatomic, strong) UIButton *currentFlashButton;
@property (nonatomic, strong) UIView *modeSelectorBar;
@property (nonatomic, strong) CAShapeLayer *modeSelector;



- (IBAction)pressedCameraRoll:(id)sender;
- (IBAction)pressedSettings:(id)sender;
- (IBAction)pressedFlashButton:(id)sender;
- (IBAction)switchCamera:(id)sender;
- (IBAction)focusAndExposeTap:(UIGestureRecognizer *)gestureRecognizer;

// Settings Menu
@property (nonatomic, weak) IBOutlet UIView *settingsView;

@property (nonatomic, weak) IBOutlet UIButton *tutorialButton;
@property (nonatomic, weak) IBOutlet UIView *bluetoothMenu;
@property (nonatomic, weak) BluetoothCommunicationViewController *bluetoothViewController;
@property (nonatomic, weak) IBOutlet LWTutorialContainerView *tutorialView;
@property (nonatomic, weak) LWTutorialViewController *tutorialViewController;

@property (nonatomic, weak) IBOutlet UIPickerView *soundPicker;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *soundPickerDistsanceFromLeft;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *soundPickerDistsanceFromRight;
- (IBAction)toggleFocusButton:(id)sender;
- (IBAction)toggleExposureButton:(id)sender;
- (IBAction)pressedSounds:(id)sender;

@property (nonatomic, weak) IBOutlet UIButton *clickShotModeButton;
- (IBAction)pressedClickShotMode:(id)sender;


// Utilities.
@property (nonatomic) BOOL lockInterfaceRotation;
@property (nonatomic) id runtimeErrorHandlingObserver;
@property (nonatomic) CSStateFlashMode flashMode;
@property (nonatomic) BOOL flashModeMenuIsOpen;
@property (nonatomic) AVAudioPlayer *soundPlayer;
@property (nonatomic) BOOL shouldPlaySound;

// Swipe Mode Control
@property (nonatomic) UITouch *primaryTouch;

@property (nonatomic) CGFloat startXTouch;
@property (nonatomic) CGFloat previousXTouch;
@property (nonatomic) CFTimeInterval lastMoveTime;
@property (nonatomic) BOOL hasMoved;
@property (nonatomic) CGFloat velocity;
@property (nonatomic) CGFloat selectorBarStartCenterX;


@property (nonatomic) NSDate *recordingStart;
@property (nonatomic) NSTimer *recordingTimer;

//@property (nonatomic) GPUImageiOSBlurFilter *blurFilter;
@property (nonatomic) NSMutableArray *galleryItems;

@property (nonatomic) BOOL micPermission;
@property (nonatomic) BOOL assetsPermission;




@end

#pragma mark - Implementation

@implementation CameraRemoteViewController

static NSInteger const settingsClosedAnimStep = 0;
static NSInteger const settingsOpenAnimStep = 1;
static NSInteger const soundsOpenAnimStep = 2;
static NSInteger const bluetoothOpenAnimStep = 3;
static UIColor *_highlightColor;

+(UIColor *)getHighlightColor {
    return _highlightColor;
}

-(void)customInit {
    _highlightColor = [UIColor colorWithRed:0.824 green:0.651 blue:1.000 alpha:1.000];
}

-(id)init {
    self = [super init];
    if (self) {
        [self customInit];
    }
    return self;
}

-(id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self customInit];
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [self customInit];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    __weak CameraRemoteViewController *weakSelf = self;

    self.cameraMode = CSStateCameraModeStill;
    [self updateModeButtonsForMode:self.cameraMode];
    self.flashMode = CSStateFlashModeAuto;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger soundNumber = [[defaults objectForKey:@"sound"] integerValue];
    [self updateSoundPlayerWithSoundNumber:soundNumber];
    [self.soundPicker selectRow:soundNumber inComponent:0 animated:NO];
    
    BOOL notFirstTime = [[defaults objectForKey:@"isNotFirstTime"] boolValue];
    if (!notFirstTime) {
        [self openTutorial];
        [defaults setObject:@YES forKey:@"isNotFirstTime"];
        [defaults setObject:@YES forKey:@"shouldSendPreviewImages"];
        [defaults setObject:@YES forKey:@"shouldSendTakenPictures"];
        [self.bluetoothViewController.receivePicturesSwitch setOn:YES];
        [self.bluetoothViewController.shouldSendPreviewImagesSwitch setOn:YES];

        [defaults synchronize];
    } else {
        [self.bluetoothViewController.receivePicturesSwitch setOn:[[defaults objectForKey:@"shouldSendTakenPictures"] boolValue]];
        [self.bluetoothViewController.shouldSendPreviewImagesSwitch setOn:[[defaults objectForKey:@"shouldSendPreviewImages"] boolValue]];
    }
    
    _shouldSendChangesToCamera = YES;
    [self changedShouldReceivePreviewImages:self.bluetoothViewController.shouldSendPreviewImagesSwitch.on];
    

    
    self.currentFlashButton = self.flashModeAutoButton;
    self.autoExposureMode = ![[defaults objectForKey:@"noAutoExposureMode"] boolValue];
    [self updateMoveableExposureView];
    self.exposePointView.center = self.view.center;
    self.autoFocusMode = [[defaults objectForKey:@"autoFocusMode"] boolValue];
    [self updateMoveableFocusView];
    self.focusPointView.center = self.view.center;
    self.swipeModesGestureIsBlocked = NO;
    
    self.focusPointView.parentViewController = weakSelf;
    self.exposePointView.parentViewController = weakSelf;
    self.cameraButton.cameraController = weakSelf;
    [self.cameraButton initialize];
	   
	// Check for device authorization
//	[self checkMicPermission];
    [self checkAssetsPremission];


    self.currentFlashButton.alpha = kDefaultAlpha;
    self.focusButton.alpha = kDefaultAlpha;
    self.exposureButton.alpha = kDefaultAlpha;
    self.swithCameraButton.alpha = kDefaultAlpha;
    
    self.modeSelectorBar = [[UIView alloc] initWithFrame:self.pictureModeButton.frame];
    self.modeSelectorBar.backgroundColor = [UIColor clearColor];
    _modeSelector = [CAShapeLayer layer];
    _modeSelector.lineWidth = 3;
    _modeSelector.fillColor   = [UIColor clearColor].CGColor;
    _modeSelector.bounds = CGRectMake(0, 0, 32, 28);
    _modeSelector.path = [UIBezierPath bezierPathWithRect:_modeSelector.bounds].CGPath;
    _modeSelector.anchorPoint = CGPointMake(0.5, 0.5);
    _modeSelector.strokeColor = [UIColor whiteColor].CGColor;
    _modeSelector.position = CGPointMake(self.pictureModeButton.frame.size.width/2, self.pictureModeButton.frame.size.height/2);
    [self.modeSelectorBar.layer addSublayer:_modeSelector];
    
    [self.cameraUIView addSubview:self.modeSelectorBar];

    self.cameraRollImage = [[UIImageView alloc] initWithFrame:CGRectMake(9, 9, self.cameraRollButton.frame.size.width-18, self.cameraRollButton.frame.size.height-18)];
    self.cameraRollImage.contentMode = UIViewContentModeScaleAspectFill;
    self.cameraRollImage.clipsToBounds = YES;
    [self.cameraRollButton addSubview:self.cameraRollImage];
    
//    self.blurFilter = [[GPUImageiOSBlurFilter alloc] init];
//    self.blurFilter.blurRadiusInPixels = 10.0f;
//    self.blurFilter.saturation = 0.6;
    
    self.distanceToCenterPhotoPreview = 0; // only iPhone 5 has non 0 here
    if (IPHONE_5) {
        self.distanceToCenterPhotoPreview = (self.view.center.y - ((self.view.frame.size.height-self.flashModeOnButton.frame.size.height-self.cameraButton.outerButtonImage.frame.size.height)/2+self.flashModeOnButton.frame.size.height))/2;
    }
    [self updateCameraPreviewPosition];
    [self updateTappablePreviewRectForCameraMode:self.cameraMode];


    self.pictureSwipeView = [self swipeViewForMode:CSStateCameraModeStill];
    self.rapidShotSwipeView = [self swipeViewForMode:CSStateCameraModeActionShot];
    self.videoSwipeView = [self swipeViewForMode:CSStateCameraModeVideo];
    
    if(!IPHONE_4) {
        [self createMenuAnimationArrays];
        _settingsButtonDragView = [[DragAnimationView alloc] initWithFrame:self.settingsButton.frame animations:_menuAnimationSteps];
        _settingsButtonDragView.delegate = self;
        _previewOverlayDragView = [[DragAnimationView alloc] initWithFrame:self.cameraUIView.frame animations:_menuAnimationSteps];
        _previewOverlayDragView.delegate = self;
        _previewOverlayDragView.hidden = YES;
        [self updateDragViewAnimations]; // adjust if iPhone 5
        [self.cameraUIView addSubview:_previewOverlayDragView];
        [self.cameraUIView addSubview:_settingsButtonDragView];
    }
    
    self.cameraPosition = CSStateCameraPositionBack;
    _cameraButton.isDraggable = NO;
    [self updateUIWithHighlightColor:_highlightColor];
}

-(void)updateUIWithHighlightColor:(UIColor *)highlightColor {
    UIColor *white = [UIColor whiteColor];
    UIColor *mediumGray = [UIColor colorWithWhite:0.530 alpha:1.000];
    UIColor *lightGray = [UIColor colorWithWhite:0.642 alpha:1.000];
    
    [self.swithCameraButton setImage:[self.swithCameraButton.imageView.image imageWithColor:highlightColor] forState:UIControlStateNormal];
    
    [self.flashModeOnButton setImage:[self.flashModeOnButton.imageView.image imageWithColor:white] forState:UIControlStateNormal];
    [self.flashModeOffButton setImage:[self.flashModeOffButton.imageView.image imageWithColor:mediumGray] forState:UIControlStateNormal];
    [self.flashModeAutoButton setImage:[self.flashModeAutoButton.imageView.image imageWithColor:highlightColor] forState:UIControlStateNormal];
    
    [self.flashModeOnButton setImage:[self.flashModeOnButton.imageView.image imageWithColor:mediumGray] forState:UIControlStateDisabled];
    [self.flashModeOffButton setImage:[self.flashModeOffButton.imageView.image imageWithColor:mediumGray] forState:UIControlStateDisabled];
    [self.flashModeAutoButton setImage:[self.flashModeAutoButton.imageView.image imageWithColor:mediumGray] forState:UIControlStateDisabled];
    
    [self.cameraRollButton setImage:[self.cameraRollButton.imageView.image imageWithColor:highlightColor] forState:UIControlStateNormal];
    [self.settingsButton setImage:[self.settingsButton.imageView.image imageWithColor:highlightColor] forState:UIControlStateNormal];
    
    [self.pictureModeButton setImage:[self.pictureModeButton.imageView.image imageWithColor:lightGray] forState:UIControlStateNormal];
    [self.pictureModeButton setImage:[self.pictureModeButton.imageView.image imageWithColor:white] forState:UIControlStateSelected];
    [self.rapidShotModeButton setImage:[self.rapidShotModeButton.imageView.image imageWithColor:lightGray] forState:UIControlStateNormal];
    [self.rapidShotModeButton setImage:[self.rapidShotModeButton.imageView.image imageWithColor:white] forState:UIControlStateSelected];
    [self.videoModeButton setImage:[self.videoModeButton.imageView.image imageWithColor:lightGray] forState:UIControlStateNormal];
    [self.videoModeButton setImage:[self.videoModeButton.imageView.image imageWithColor:white] forState:UIControlStateSelected];
    
    _modeSelector.strokeColor = highlightColor.CGColor;
    
    [_cameraButton.outerButtonImage setImage:[_cameraButton.outerButtonImage.image imageWithColor:highlightColor]];
    
    [self.bluetoothButton setImage:[self.bluetoothButton.imageView.image imageWithColor:white] forState:UIControlStateSelected];
    [self.bluetoothButton setImage:[self.bluetoothButton.imageView.image imageWithColor:lightGray] forState:UIControlStateNormal];
    self.bluetoothButton.layer.borderWidth = 3;
    if (self.bluetoothButton.selected) {
        self.bluetoothButton.layer.borderColor = highlightColor.CGColor;
    } else {
        self.bluetoothButton.layer.borderColor = lightGray.CGColor;
    }
    [self.focusButton setImage:[self.focusButton.imageView.image imageWithColor:white] forState:UIControlStateSelected];
    [self.focusButton setImage:[UIImage imageNamed:@"inwardAutoFocusLocked"] forState:UIControlStateNormal];
    self.focusButton.layer.borderWidth = 3;
    if (self.focusButton.selected) {
        self.focusButton.layer.borderColor = highlightColor.CGColor;
    } else {
        self.focusButton.layer.borderColor = lightGray.CGColor;
    }
    [self.exposureButton setImage:[self.exposureButton.imageView.image imageWithColor:white] forState:UIControlStateSelected];
    [self.exposureButton setImage:[UIImage imageNamed:@"inwardAutoExposureLocked"] forState:UIControlStateNormal];
    self.exposureButton.layer.borderWidth = 3;
    if (self.exposureButton.selected) {
        self.exposureButton.layer.borderColor = highlightColor.CGColor;
    } else {
        self.exposureButton.layer.borderColor = lightGray.CGColor;
    }
    [self.soundsButton setImage:[self.soundsButton.imageView.image imageWithColor:white] forState:UIControlStateSelected];
    [self.soundsButton setImage:[self.soundsButton.imageView.image imageWithColor:lightGray] forState:UIControlStateNormal];
    self.soundsButton.layer.borderWidth = 3;
    if (self.soundsButton.selected) {
        self.soundsButton.layer.borderColor = highlightColor.CGColor;
    } else {
        self.soundsButton.layer.borderColor = lightGray.CGColor;
    }
    
    [self.focusPointView setImage:[self.focusPointView.image imageWithColor:highlightColor]];
    [self.exposePointView setImage:[self.exposePointView.image imageWithColor:highlightColor]];
    
    CGFloat hue, saturation, brightness, alpha;
    [highlightColor getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];
    _soundPicker.backgroundColor = [UIColor colorWithHue:hue saturation:saturation-0.2 brightness:brightness alpha:alpha];
}


-(void)createMenuAnimationArrays {
    CABasicAnimation *moveUpForSettings=[CABasicAnimation animationWithKeyPath:@"position"];
    moveUpForSettings.duration = 1;
    moveUpForSettings.autoreverses = NO;
    moveUpForSettings.fromValue = [NSValue valueWithCGPoint:self.cameraUIView.layer.position];
    moveUpForSettings.toValue = [NSValue valueWithCGPoint:CGPointMake(self.cameraUIView.layer.position.x, self.cameraUIView.layer.position.y-kSettingsViewHeight)];
    moveUpForSettings.speed = 0;
    moveUpForSettings.timeOffset = 0;
    
    CABasicAnimation *moveUpForSounds = [CABasicAnimation animationWithKeyPath:@"position"];
    moveUpForSounds.duration = 1;
    moveUpForSounds.autoreverses = NO;
    moveUpForSounds.fromValue = [NSValue valueWithCGPoint:CGPointMake(self.cameraUIView.layer.position.x, self.cameraUIView.layer.position.y-kSettingsViewHeight)];
    moveUpForSounds.toValue = [NSValue valueWithCGPoint:CGPointMake(self.cameraUIView.layer.position.x, self.cameraUIView.layer.position.y-(kSettingsViewHeight+self.soundPicker.frame.size.height))];
    moveUpForSounds.speed = 0;
    moveUpForSounds.timeOffset = 0;
    
    CABasicAnimation *moveUpForBluetooth=[CABasicAnimation animationWithKeyPath:@"position"];
    moveUpForBluetooth.duration = 1;
    moveUpForBluetooth.autoreverses = NO;
    moveUpForBluetooth.fromValue = [NSValue valueWithCGPoint:CGPointMake(self.cameraUIView.layer.position.x, self.cameraUIView.layer.position.y-(kSettingsViewHeight+self.soundPicker.frame.size.height))];
    moveUpForBluetooth.toValue = [NSValue valueWithCGPoint:CGPointMake(self.cameraUIView.layer.position.x, self.cameraUIView.layer.position.y-(kSettingsViewHeight+self.bluetoothMenu.frame.size.height))];
    moveUpForBluetooth.speed = 0;
    moveUpForBluetooth.timeOffset = 0;
    
    CABasicAnimation *openSoundsMenuAnim =[CABasicAnimation animationWithKeyPath:@"position"];
    openSoundsMenuAnim.duration = 1;
    openSoundsMenuAnim.autoreverses = NO;
    openSoundsMenuAnim.toValue = [NSValue valueWithCGPoint:self.soundPicker.layer.position];
    openSoundsMenuAnim.fromValue = [NSValue valueWithCGPoint:self.soundPicker.layer.position];
    openSoundsMenuAnim.speed = 0;
    openSoundsMenuAnim.timeOffset = 0;
    
    CABasicAnimation *closeSoundsMenuAnim =[CABasicAnimation animationWithKeyPath:@"position"];
    closeSoundsMenuAnim.duration = 1;
    closeSoundsMenuAnim.autoreverses = NO;
    closeSoundsMenuAnim.toValue = [NSValue valueWithCGPoint:CGPointMake(self.cameraUIView.layer.position.x+CGRectGetWidth(self.view.frame), self.soundPicker.layer.position.y)];
    closeSoundsMenuAnim.fromValue = [NSValue valueWithCGPoint:self.soundPicker.layer.position];
    closeSoundsMenuAnim.speed = 0;
    closeSoundsMenuAnim.timeOffset = 0;
    
    _menuAnimationSteps = @[ @[@[self.cameraUIView, moveUpForSettings], @[self.previewView, moveUpForSettings], @[self.blackBackground, moveUpForSettings]], @[@[self.cameraUIView, moveUpForSounds], @[self.previewView, moveUpForSounds], @[self.blackBackground, moveUpForSounds], @[self.soundPicker, openSoundsMenuAnim]],  @[@[self.cameraUIView, moveUpForBluetooth], @[self.previewView, moveUpForBluetooth], @[self.blackBackground, moveUpForBluetooth], @[self.soundPicker, closeSoundsMenuAnim]] ];
    
//    if (IPHONE_5) {
//    NSLog(@"reg %@ non %@", NSStringFromCGPoint(self.cameraUIView.layer.position), NSStringFromCGPoint(self.previewView.layer.position));
        CABasicAnimation *previewMoveUpForSettings=[CABasicAnimation animationWithKeyPath:@"position"];
        previewMoveUpForSettings.duration = 1;
        previewMoveUpForSettings.autoreverses = NO;
        previewMoveUpForSettings.fromValue = [NSValue valueWithCGPoint:CGPointMake(self.previewView.layer.position.x, self.previewView.layer.position.y-self.distanceToCenterPhotoPreview)];
        previewMoveUpForSettings.toValue = [NSValue valueWithCGPoint:CGPointMake(self.previewView.layer.position.x, self.previewView.layer.position.y-kSettingsViewHeight-self.distanceToCenterPhotoPreview)];
        previewMoveUpForSettings.speed = 0;
        previewMoveUpForSettings.timeOffset = 0;
        
        CABasicAnimation *previewMoveUpForSounds = [CABasicAnimation animationWithKeyPath:@"position"];
        previewMoveUpForSounds.duration = 1;
        previewMoveUpForSounds.autoreverses = NO;
        previewMoveUpForSounds.fromValue = [NSValue valueWithCGPoint:CGPointMake(self.previewView.layer.position.x, self.previewView.layer.position.y-kSettingsViewHeight-self.distanceToCenterPhotoPreview)];
        previewMoveUpForSounds.toValue = [NSValue valueWithCGPoint:CGPointMake(self.previewView.layer.position.x, self.previewView.layer.position.y-(kSettingsViewHeight+self.soundPicker.frame.size.height)-self.distanceToCenterPhotoPreview)];
        previewMoveUpForSounds.speed = 0;
        previewMoveUpForSounds.timeOffset = 0;
        
        CABasicAnimation *previewMoveUpForBluetooth=[CABasicAnimation animationWithKeyPath:@"position"];
        previewMoveUpForBluetooth.duration = 1;
        previewMoveUpForBluetooth.autoreverses = NO;
        previewMoveUpForBluetooth.fromValue = [NSValue valueWithCGPoint:CGPointMake(self.previewView.layer.position.x, self.previewView.layer.position.y-(kSettingsViewHeight+self.soundPicker.frame.size.height)-self.distanceToCenterPhotoPreview)];
        previewMoveUpForBluetooth.toValue = [NSValue valueWithCGPoint:CGPointMake(self.previewView.layer.position.x, self.previewView.layer.position.y-(kSettingsViewHeight+self.bluetoothMenu.frame.size.height)-self.distanceToCenterPhotoPreview)];
        previewMoveUpForBluetooth.speed = 0;
        previewMoveUpForBluetooth.timeOffset = 0;
        
        _iPhone5MenuAnimationSteps = @[ @[@[self.cameraUIView, moveUpForSettings], @[self.previewView, previewMoveUpForSettings], @[self.blackBackground, moveUpForSettings]], @[@[self.cameraUIView, moveUpForSounds], @[self.previewView, previewMoveUpForSounds], @[self.blackBackground, moveUpForSounds], @[self.soundPicker, openSoundsMenuAnim]],  @[@[self.cameraUIView, moveUpForBluetooth], @[self.previewView, previewMoveUpForBluetooth], @[self.blackBackground, moveUpForBluetooth], @[self.soundPicker, closeSoundsMenuAnim]] ];
//    }
}

// used to fix preview view on iPhone 5
-(void)updateDragViewAnimations {
    if (IPHONE_5 && self.cameraMode != CSStateCameraModeVideo) {
        _settingsButtonDragView.animationSteps = _iPhone5MenuAnimationSteps;
        _previewOverlayDragView.animationSteps = _iPhone5MenuAnimationSteps;
    } else {
        _settingsButtonDragView.animationSteps = _menuAnimationSteps;
        _previewOverlayDragView.animationSteps = _menuAnimationSteps;
    }
}

-(void)updateTappablePreviewRectForCameraMode:(NSInteger)cameraMode {
    if (IPAD) {
        if (cameraMode == CSStateCameraModeVideo) {
            CGFloat previewWidth = self.view.frame.size.height * kVideoDimension;
            CGFloat leftOffset = (self.view.frame.size.width - previewWidth) / 2;
            self.tappablePreviewRect = CGRectMake(leftOffset, self.swithCameraButton.frame.size.height, previewWidth, self.view.frame.size.height-self.cameraButton.outerButtonImage.frame.size.height);
            self.previewImageRect = CGRectMake(leftOffset, 0, previewWidth, self.view.frame.size.height);
        } else {
            self.tappablePreviewRect = CGRectMake(0, self.swithCameraButton.frame.size.height, self.view.frame.size.width, self.view.frame.size.height-self.cameraButton.outerButtonImage.frame.size.height);
            self.previewImageRect = self.view.frame;
        }
    } else if (IPHONE_5) {
        if (cameraMode == CSStateCameraModeVideo) {
            CGFloat previewWidth = self.view.frame.size.height * kVideoDimension;
            CGFloat leftOffset = (self.view.frame.size.width - previewWidth) / 2;
            self.tappablePreviewRect = CGRectMake(leftOffset, self.swithCameraButton.frame.size.height, previewWidth, self.view.frame.size.height-self.cameraButton.outerButtonImage.frame.size.height);
            self.previewImageRect = self.view.frame;
        } else {
            self.distanceToCenterPhotoPreview = (self.view.center.y - ((self.view.frame.size.height-self.flashModeOnButton.frame.size.height-self.cameraButton.outerButtonImage.frame.size.height)/2+self.flashModeOnButton.frame.size.height))/2;
            CGFloat previewHeight = self.view.frame.size.height * kPhotoDimension;
            
            self.tappablePreviewRect = CGRectMake(0, (self.view.frame.size.height-previewHeight)/2-self.distanceToCenterPhotoPreview, self.view.frame.size.width, previewHeight);
            self.previewImageRect = CGRectMake(0, (self.view.frame.size.height-previewHeight)/2-self.distanceToCenterPhotoPreview, self.view.frame.size.width, previewHeight);

        }
    } else {
        if (cameraMode == CSStateCameraModeVideo) {
            CGFloat previewWidth = self.view.frame.size.height * kVideoDimension;
            CGFloat leftOffset = (self.view.frame.size.width - previewWidth) / 2;
            self.tappablePreviewRect = CGRectMake(leftOffset, self.swithCameraButton.frame.size.height, previewWidth, self.view.frame.size.height-self.cameraButton.outerButtonImage.frame.size.height);
            self.previewImageRect = CGRectMake(leftOffset, 0, previewWidth, self.view.frame.size.height);

        } else {
            CGFloat previewHeight = self.view.frame.size.height * kPhotoDimension;

            self.tappablePreviewRect = CGRectMake(0, self.swithCameraButton.frame.size.height, self.view.frame.size.width, self.view.frame.size.height-self.cameraButton.outerButtonImage.frame.size.height);
            self.previewImageRect = CGRectMake(0, (self.view.frame.size.height-previewHeight)/2, self.view.frame.size.width, previewHeight);

        }
    }
    [self.focusPointView fixIfOffscreen];
    [self.exposePointView fixIfOffscreen];
    
}

// used to fix iphone centering picture preview frame
// brings the cameraPreviewView to zero'd out position with its blurred image view
-(void)updateCameraPreviewPosition {
    if (self.cameraMode == CSStateCameraModeVideo) {
        self.cameraPreviewViewDistanceToTop.constant = 0;
        self.cameraPreviewViewDistanceToBottom.constant = 0;
        self.blurredImageDistanceToTop.constant = 0;
        self.blurredImageDistanceToBottom.constant = 0;
        self.blackBackgroundDistanceToBottom.constant = 0;
        self.blackBackgroundDistanceToTop.constant = 0;
    } else {
        self.cameraPreviewViewDistanceToTop.constant = -self.distanceToCenterPhotoPreview;
        self.cameraPreviewViewDistanceToBottom.constant = self.distanceToCenterPhotoPreview;
        self.blurredImageDistanceToTop.constant = -self.distanceToCenterPhotoPreview;
        self.blurredImageDistanceToBottom.constant = self.distanceToCenterPhotoPreview;
        self.blackBackgroundDistanceToBottom.constant = 0;
        self.blackBackgroundDistanceToTop.constant = 0;
    }
    [self.view layoutIfNeeded];
}

-(void)userReopenedApp {
    [self.bluetoothViewController reInitialize];
}

-(void)userClosedApp {
    [self.bluetoothViewController stopAdvertising];
    if ([_cameraButton isAnimatingButton]) {
        [_cameraButton cancelTimedAction];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    self.cameraRollIsOpen = NO;
    [self updateGalleryItems];
}

-(void)moveMainViewVerticallyTo:(CGFloat)yPosition {
    self.cameraUIDistanceToBottom.constant = yPosition;
    self.cameraUIDistanceToTop.constant = -yPosition;
    self.blackBackgroundDistanceToBottom.constant = yPosition;
    self.blackBackgroundDistanceToTop.constant = -yPosition;

    if (self.cameraMode != CSStateCameraModeVideo) {
        self.cameraPreviewViewDistanceToBottom.constant = yPosition+self.distanceToCenterPhotoPreview;
        self.cameraPreviewViewDistanceToTop.constant = -yPosition-self.distanceToCenterPhotoPreview;
        self.blurredImageDistanceToBottom.constant = yPosition+self.distanceToCenterPhotoPreview;
        self.blurredImageDistanceToTop.constant = -yPosition-self.distanceToCenterPhotoPreview;
    } else {
        self.cameraPreviewViewDistanceToBottom.constant = yPosition;
        self.cameraPreviewViewDistanceToTop.constant = -yPosition;
        self.blurredImageDistanceToBottom.constant = yPosition;
        self.blurredImageDistanceToTop.constant = -yPosition;
    }
    [self.view layoutIfNeeded];
}

#pragma mark -
#pragma mark IBActions

- (IBAction)pressedPictureMode:(id)sender {
    [self updateModeButtonsForMode:CSStateCameraModeStill];
    self.pictureSwipeView.frame = CGRectMake(-self.pictureSwipeView.frame.size.width, 0, self.pictureSwipeView.frame.size.width, self.pictureSwipeView.frame.size.height);
    [self swipeToSelectedButtonCameraMode];
}

- (IBAction)pressedRapidShotMode:(id)sender {
    [self updateModeButtonsForMode:CSStateCameraModeActionShot];
    if (self.cameraMode == CSStateCameraModeStill) {
        self.rapidShotSwipeView.frame = CGRectMake(self.view.frame.size.width, 0, self.rapidShotSwipeView.frame.size.width, self.rapidShotSwipeView.frame.size.height);
    } else {
        self.rapidShotSwipeView.frame = CGRectMake(-self.rapidShotSwipeView.frame.size.width, 0, self.rapidShotSwipeView.frame.size.width, self.rapidShotSwipeView.frame.size.height);
    }
    [self swipeToSelectedButtonCameraMode];
}

- (IBAction)pressedVideoMode:(id)sender {
    [self updateModeButtonsForMode:CSStateCameraModeVideo];
    self.videoSwipeView.frame = CGRectMake(self.videoSwipeView.frame.size.width, 0, self.videoSwipeView.frame.size.width, self.videoSwipeView.frame.size.height);
    [self swipeToSelectedButtonCameraMode];
}


- (IBAction)switchCamera:(id)sender {
    if (self.cameraPosition == CSStateCameraPositionBack) {
        self.cameraPosition = CSStateCameraPositionFront;
    } else {
        self.cameraPosition = CSStateCameraPositionBack;
    }
    
    [self willSwitchCamera];
    [self updateCameraPreviewPosition];
    [self updateTappablePreviewRectForCameraMode:self.cameraMode];
    
    
    [self updateCameraWithCurrentStateAndButtonAction:CSStateButtonActionNone];
}

- (IBAction)focusAndExposeTap:(UIGestureRecognizer *)gestureRecognizer
{
    CGPoint touchPoint = [gestureRecognizer locationInView:[gestureRecognizer view]];
    if (/*!self.swipeModesGestureIsBlocked && */!self.settingsMenuIsOpen && !CGRectContainsPoint(self.settingsButton.frame, touchPoint) && ![[self.cameraButton.buttonImage.layer presentationLayer] hitTest:touchPoint]) {
        self.exposePointView.center = touchPoint;
        self.focusPointView.center = touchPoint;
        self.focusPointView.alpha = 0;
        self.exposePointView.alpha = 0;
        [self.focusPointView fixIfOffscreen];
        [self.exposePointView fixIfOffscreen];
        _exposureDevicePoint = [self devicePointForScreenPoint:touchPoint];
        _focusDevicePoint = _exposureDevicePoint;
        [self updateCameraWithCurrentStateAndButtonAction:CSStateButtonActionNone];
        if (!self.autoFocusMode) {
            [UIView animateWithDuration:0.4 animations:^{
                self.focusPointView.alpha = kDefaultAlpha;
            }];
        } else {
            [UIView animateWithDuration:0.2 animations:^{
                self.focusPointView.alpha = kDefaultAlpha;
            } completion:^(BOOL finished) {
                [UIView animateWithDuration:0.7 animations:^{
                    self.focusPointView.alpha = 0;
                }];
            }];
        }
        if (!self.autoExposureMode) {
            [UIView animateWithDuration:0.4 animations:^{
                self.exposePointView.alpha = kDefaultAlpha;
            }];
        } else {
            [UIView animateWithDuration:0.2 animations:^{
                self.exposePointView.alpha = kDefaultAlpha;
            } completion:^(BOOL finished) {
                [UIView animateWithDuration:0.7 animations:^{
                    self.exposePointView.alpha = 0;
                }];
            }];
        }
    }
}

-(void)setExposureDevicePointWithTouchLocation:(CGPoint)touchLocation{
    self.exposureDevicePoint = [self devicePointForScreenPoint:touchLocation];
    [self updateCameraWithCurrentStateAndButtonAction:CSStateButtonActionNone];
}

-(void)setFocusDevicePointWithTouchLocation:(CGPoint)touchLocation{
    self.focusDevicePoint = [self devicePointForScreenPoint:touchLocation];
    [self updateCameraWithCurrentStateAndButtonAction:CSStateButtonActionNone];
}


-(CGPoint)devicePointForScreenPoint:(CGPoint)screenPoint {
    CGPoint imagePoint = CGPointMake((screenPoint.x-_previewImageRect.origin.x)/_previewImageRect.size.width, (screenPoint.y-_previewImageRect.origin.y)/_previewImageRect.size.height);

//    NSLog(@"device point: %@", NSStringFromCGPoint(imagePoint));
    return CGPointMake([self clamp:imagePoint.x between:0 and:1], [self clamp:imagePoint.y between:0 and:1]); // keep inside 0 and 1 bounds
}

// keep a number within bounds
-(CGFloat)clamp:(CGFloat)number between:(CGFloat)min and:(CGFloat)max {
    if (number > max) {
        return max;
    } else if (number < min) {
        return min;
    } else {
        return number;
    }
}

- (IBAction)pressedSettings:(id)sender {
    if (self.settingsMenuIsOpen) {
        [self closeSettingsMenu];
    } else {
        [self openSettingsMenu];
    }
}

- (IBAction)pressedCameraRoll:(id)sender {
    if (!self.cameraButton.isDragging) {
        MHGalleryController *gallery = [[MHGalleryController alloc]initWithPresentationStyle:MHGalleryViewModeOverView];
        __weak MHGalleryController *blockGallery = gallery;
        gallery.galleryItems = self.galleryItems;
        MHUICustomization *customize = [[MHUICustomization alloc] init];
        customize.barStyle = UIBarStyleBlackTranslucent;
        customize.barTintColor = [UIColor blackColor];
        
        customize.barButtonsTintColor = _highlightColor;
        [customize setMHGalleryBackgroundColor:[UIColor colorWithWhite:0.131 alpha:1.000] forViewMode:MHGalleryViewModeOverView];
        [customize setMHGalleryBackgroundColor:[UIColor colorWithWhite:0.131 alpha:1.000] forViewMode:MHGalleryViewModeImageViewerNavigationBarShown];
        [customize setMHGalleryBackgroundColor:[UIColor colorWithWhite:0.131 alpha:1.000] forViewMode:MHGalleryViewModeImageViewerNavigationBarHidden];
        
        gallery.UICustomization = customize;
        gallery.finishedCallback = ^(NSUInteger currentIndex,UIImage *image,MHTransitionDismissMHGallery *interactiveTransition,MHGalleryViewMode viewMode){
            [blockGallery dismissViewControllerAnimated:YES dismissImageView:nil completion:nil];
        };
        self.cameraRollIsOpen = YES;
        [self presentMHGalleryController:gallery animated:YES completion:nil];
    }
}

#pragma mark -
#pragma mark Settings Menu

-(void)closeSettingsMenu {
    self.settingsMenuIsOpen = NO;
    self.soundsMenuIsOpen = NO;
    self.bluetoothMenuIsOpen = NO;
    self.settingsButtonDragView.currentAnimationStep = settingsClosedAnimStep;
    self.previewOverlayDragView.currentAnimationStep = settingsClosedAnimStep;
    _previewOverlayDragView.hidden = YES;

    [self.view layoutIfNeeded];
    [UIView animateWithDuration:0.5 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.cameraUIDistanceToBottom.constant = 0;
        self.cameraUIDistanceToTop.constant = 0;
        [self updateCameraPreviewPosition];
    } completion:^(BOOL finished){
        [self ensureClosedSettingsMenu];
    }];
}

-(void)openSettingsMenu {
    self.settingsMenuIsOpen = YES;
    self.soundsMenuIsOpen = NO;
    self.bluetoothMenuIsOpen = NO;
    self.settingsButtonDragView.currentAnimationStep = settingsOpenAnimStep;
    self.previewOverlayDragView.currentAnimationStep = settingsOpenAnimStep;
    _previewOverlayDragView.hidden = NO;

    [self.view layoutIfNeeded];
    [UIView animateWithDuration:0.5 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        if (self.cameraMode != CSStateCameraModeVideo) {
            self.cameraPreviewViewDistanceToBottom.constant = kSettingsViewHeight+self.distanceToCenterPhotoPreview;
            self.cameraPreviewViewDistanceToTop.constant = -kSettingsViewHeight-self.distanceToCenterPhotoPreview;
        } else {
            self.cameraPreviewViewDistanceToBottom.constant = kSettingsViewHeight;
            self.cameraPreviewViewDistanceToTop.constant = -kSettingsViewHeight;
        }
        self.blackBackgroundDistanceToBottom.constant = kSettingsViewHeight;
        self.blackBackgroundDistanceToTop.constant = -kSettingsViewHeight;
        // not needed but the blurred image view could also move here
        self.cameraUIDistanceToBottom.constant = kSettingsViewHeight;
        self.cameraUIDistanceToTop.constant = -kSettingsViewHeight;
        [self.view layoutIfNeeded];
    }completion:^(BOOL finished){
        [self ensureOpenSettingsMenu];
    }];
}

-(void)ensureOpenSettingsMenu {
    self.settingsMenuIsOpen = YES;
    self.soundsMenuIsOpen = NO;
    self.bluetoothMenuIsOpen = NO;
    
    self.settingsButtonDragView.currentAnimationStep = settingsOpenAnimStep;
    self.previewOverlayDragView.currentAnimationStep = settingsOpenAnimStep;
    
    [self moveMainViewVerticallyTo:kSettingsViewHeight];

}

-(void)ensureClosedSettingsMenu {
    self.settingsMenuIsOpen = NO;
    self.soundsMenuIsOpen = NO;
    self.bluetoothMenuIsOpen = NO;
    
    self.settingsButtonDragView.currentAnimationStep = settingsClosedAnimStep;
    self.previewOverlayDragView.currentAnimationStep = settingsClosedAnimStep;

    [self moveMainViewVerticallyTo:0];
}

#pragma mark Settings Menu IBActions

- (IBAction)toggleFocusButton:(id)sender {
    self.autoFocusMode = !self.autoFocusMode;
    [self updateMoveableFocusView];
    [self updateCameraWithCurrentStateAndButtonAction:CSStateButtonActionNone];
}

- (IBAction)toggleExposureButton:(id)sender {
    self.autoExposureMode = !self.autoExposureMode;
    [self updateMoveableExposureView];
    [self updateCameraWithCurrentStateAndButtonAction:CSStateButtonActionNone];
}

-(IBAction)pressedSounds:(id)sender {
    if (self.soundsMenuIsOpen) {
        [self closeSoundsMenuToSettings];
    } else {
        [self openSoundsMenu];
    }
    self.bluetoothMenuIsOpen = NO;
}

-(void)openSoundsMenu {
    float yPosition = kSettingsViewHeight+self.soundPicker.frame.size.height;
    [self.settingsView bringSubviewToFront:self.soundPicker];
    if (self.bluetoothMenuIsOpen) {
        self.soundPickerDistsanceFromLeft.constant = self.view.frame.size.width;
        self.soundPickerDistsanceFromRight.constant = -self.view.frame.size.width;
        [self.view layoutIfNeeded];
        [UIView animateWithDuration:0.5 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            [self moveMainViewVerticallyTo:yPosition];
            self.soundPickerDistsanceFromLeft.constant = 0;
            self.soundPickerDistsanceFromRight.constant = 0;
            [self.view layoutIfNeeded];
        } completion:^(BOOL finished){
            [self ensureOpenSoundsMenu];
        }];
    } else {
        self.soundPickerDistsanceFromLeft.constant = 0;
        self.soundPickerDistsanceFromRight.constant = 0;
        [self.view layoutIfNeeded];
        [UIView animateWithDuration:0.5 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            [self moveMainViewVerticallyTo:yPosition];
            [self.view layoutIfNeeded];
        } completion:^(BOOL finished){
            [self ensureOpenSoundsMenu];
        }];
    }
    self.soundsMenuIsOpen = YES;
}

-(void)closeSoundsMenuToSettings {
    [self.settingsView bringSubviewToFront:self.soundPicker];
    [UIView animateWithDuration:0.5 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        [self moveMainViewVerticallyTo:kSettingsViewHeight];
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        [self ensureOpenSettingsMenu];
    }];
    self.soundsMenuIsOpen = NO;
}

-(void)ensureOpenSoundsMenu {
    self.settingsMenuIsOpen = YES;
    self.soundsMenuIsOpen = YES;
    self.bluetoothMenuIsOpen = NO;
    self.settingsButtonDragView.currentAnimationStep = soundsOpenAnimStep;
    self.previewOverlayDragView.currentAnimationStep = soundsOpenAnimStep;

    self.soundPickerDistsanceFromLeft.constant = 0;
    self.soundPickerDistsanceFromRight.constant = 0;
    
    float yPosition = kSettingsViewHeight+self.soundPicker.frame.size.height;
    [self moveMainViewVerticallyTo:yPosition];
    [self.view layoutIfNeeded];
}

- (IBAction)pressedBluetooth:(id)sender {
    if (self.bluetoothMenuIsOpen) {
        [self closeBluetoothMenuToSettings];
    } else {
        [self openBluetoothMenu];
    }
    self.soundsMenuIsOpen = NO;
}



-(void)openBluetoothMenu {
    float yPosition = kSettingsViewHeight+self.bluetoothMenu.frame.size.height;
    if (self.soundsMenuIsOpen) {
        [UIView animateWithDuration:0.5 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            [self moveMainViewVerticallyTo:yPosition];
            self.soundPickerDistsanceFromLeft.constant = self.view.frame.size.width;
            self.soundPickerDistsanceFromRight.constant = -self.view.frame.size.width;
            [self.view layoutIfNeeded];
        } completion:^(BOOL finished){
            [self.settingsView bringSubviewToFront:self.bluetoothMenu];
            [self ensureOpenBluetoothMenu];
        }];
    } else {
        [self.settingsView bringSubviewToFront:self.bluetoothMenu];
        [UIView animateWithDuration:0.5 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            [self moveMainViewVerticallyTo:yPosition];
            [self.view layoutIfNeeded];
        } completion:^(BOOL finished){
            [self ensureOpenBluetoothMenu];
        }];
    }
    self.bluetoothMenuIsOpen = YES;
}

-(void)closeBluetoothMenuToSettings {
    [UIView animateWithDuration:0.5 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        [self moveMainViewVerticallyTo:kSettingsViewHeight];
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished){
        [self.settingsView bringSubviewToFront:self.soundPicker];
        [self ensureOpenSettingsMenu];
    }];
    self.bluetoothMenuIsOpen = NO;
}

-(void)ensureOpenBluetoothMenu {
    self.settingsMenuIsOpen = YES;
    self.soundsMenuIsOpen = NO;
    self.bluetoothMenuIsOpen = YES;
    self.settingsButtonDragView.currentAnimationStep = bluetoothOpenAnimStep;
    self.previewOverlayDragView.currentAnimationStep = bluetoothOpenAnimStep;

    
    self.soundPickerDistsanceFromLeft.constant = self.view.frame.size.width;
    self.soundPickerDistsanceFromRight.constant = -self.view.frame.size.width;
    
    
    float yPosition = kSettingsViewHeight+self.bluetoothMenu.frame.size.height;
    [self moveMainViewVerticallyTo:yPosition];
    [self.view layoutIfNeeded];
}

- (IBAction)pressedTutorial:(id)sender {
    [self openTutorial];
}

-(void)openTutorial {
    [self closeSettingsMenu];
    [self.tutorialViewController restartTutorial];
    self.tutorialView.alpha = 0;
    self.tutorialView.hidden = NO;
    [UIView animateWithDuration:0.5 animations:^{
        self.tutorialView.alpha = 1;
        self.notConnectedToDeviceView.alpha = 0;
    }];
    self.tutorialIsOpen = YES;
}

-(void)closeTutorial {
    [UIView animateWithDuration:0.5 animations:^{
        self.tutorialView.alpha = 0;
        if (!self.bluetoothViewController.mainConnectedCameraPeerID) {
            self.notConnectedToDeviceView.alpha = 1;
        }
    } completion:^(BOOL finished){
        self.tutorialView.hidden = YES;
        self.tutorialIsOpen = NO;
    }];
}



- (IBAction)pressedClickShotMode:(id)sender {
    [self.bluetoothViewController stopAdvertising];
    [UIView animateWithDuration:0.3 animations:^{
        // slide over switching view
    } completion:^(BOOL finished) {
        // Close settings menu
        self.settingsMenuIsOpen = NO;
        self.soundsMenuIsOpen = NO;
        self.bluetoothMenuIsOpen = NO;
        self.settingsButtonDragView.currentAnimationStep = settingsClosedAnimStep;
        self.previewOverlayDragView.currentAnimationStep = settingsClosedAnimStep;
        _previewOverlayDragView.hidden = YES;
        
        [self.view layoutIfNeeded];
        [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.cameraUIDistanceToBottom.constant = 0;
            self.cameraUIDistanceToTop.constant = 0;
            [self updateCameraPreviewPosition];
        } completion:^(BOOL finished){
            [self ensureClosedSettingsMenu];
            [self.cameraViewController switchingToClickShotMode];
            // reset sliding view and stuff
        }];
    }];
}

-(void)switchingToRemoteMode {
    [self.bluetoothViewController startAdvertising];
}



#pragma mark -
#pragma mark Camera Functions


//-(void)setCameraButtonText:(NSString *)text withOffset:(CGPoint)offset fontSize:(float)fontSize{
//    self.cameraButtonString = text;
//    if ([text isEqualToString:@""]) {
//        self.cameraButton.buttonImage.image = [self currentCameraButtonImage];
//    } else if (self.cameraMode == CSStateCameraModeActionShot/* && (self.videoProcessor.actionShooting || cameraButton is dragging) */) {
//        self.cameraButton.buttonImage.image = [self maskImage:self.pictureCameraButtonImage withMaskText:text offsetFromCenter:offset fontSize:fontSize];
//    } else {
//        self.cameraButton.buttonImage.image = [self maskImage:[self currentCameraButtonImage] withMaskText:text offsetFromCenter:offset fontSize:fontSize];
//    }
//}

//- (UIImage*) maskImage:(UIImage *)image withMaskText:(NSString *)maskText offsetFromCenter:(CGPoint)offset fontSize:(float)fontSize {
//    
//    CGRect imageRect = CGRectMake(0, 0, image.size.width, image.size.height);
//    
//    // Create a context for our text mask
//    UIGraphicsBeginImageContextWithOptions(image.size, YES, 1);
//    CGContextRef textMaskContext = UIGraphicsGetCurrentContext();
//    
//	// Draw a white background
//	[[UIColor whiteColor] setFill];
//	CGContextFillRect(textMaskContext, imageRect);
//    // Draw black text
//    [[UIColor blackColor] setFill];
//    
//    NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
//    paragraphStyle.alignment = NSTextAlignmentCenter;
//    paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
//    NSDictionary *attr = @{NSParagraphStyleAttributeName: paragraphStyle,
//                           NSFontAttributeName: [UIFont boldSystemFontOfSize:fontSize],
//                           NSStrokeColorAttributeName: [UIColor blackColor],
//                           NSStrokeWidthAttributeName: [NSNumber numberWithFloat:5.0]};
//    
//    CGSize textSize = [maskText sizeWithAttributes:attr];
//	[maskText drawAtPoint:CGPointMake((imageRect.size.width-textSize.width)/2+offset.x, (imageRect.size.height-textSize.height)/2+offset.y) withAttributes:attr];
//    
//    //add small number for action shooting + animation
//    if (self.videoProcessor.actionShooting && self.cameraButton.isAnimatingButton && self.actionShotSequenceNumber > 0) {
//        attr = @{NSParagraphStyleAttributeName: paragraphStyle,
//                 NSFontAttributeName: [UIFont boldSystemFontOfSize:48],
//                 NSForegroundColorAttributeName: [UIColor blackColor]};
//        NSString *sequenceNumString = [NSString stringWithFormat:@"%i", self.actionShotSequenceNumber];
//        textSize = [sequenceNumString sizeWithAttributes:attr];
//        [sequenceNumString  drawAtPoint:CGPointMake((imageRect.size.width-textSize.width)/2+offset.x, (imageRect.size.height-textSize.height)/2+offset.y-70) withAttributes:attr];
//    }
//    
//	// Create an image from what we've drawn
//	CGImageRef textAlphaMask = CGBitmapContextCreateImage(textMaskContext);
//    CGContextRelease(textMaskContext);
//    
//    // create a bitmap graphics context the size of the image
//    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
//    CGContextRef mainImageContext = CGBitmapContextCreate (NULL, image.size.width, image.size.height, CGImageGetBitsPerComponent(image.CGImage), 0, colorSpace, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
//    
//    CGContextDrawImage(mainImageContext, imageRect, self.darkCameraButtonBG.CGImage); // for semi-transparent dark number
//    CGContextClipToMask(mainImageContext, imageRect, textAlphaMask);
//    CGContextDrawImage(mainImageContext, imageRect, image.CGImage);
//    
//    CGImageRef finishedImage =CGBitmapContextCreateImage(mainImageContext);
//    UIImage *finalMaskedImage = [UIImage imageWithCGImage: finishedImage];
//    
//    CGImageRelease(finishedImage);
//    CGContextRelease(mainImageContext);
//    CGImageRelease(textAlphaMask);
//    CGColorSpaceRelease(colorSpace);
//    
//    // return the image
//    return finalMaskedImage;
//    
//}


- (void)pressedCameraButton {
    if (self.shouldPlaySound && self.cameraMode == CSStateCameraModeStill && !self.cameraIsRecording) {
        [self.soundPlayer play];
        self.takePictureAfterSound = YES;
        [self.cameraButton animateSoundRingForDuration:self.soundDuration];
    }
    [self cameraAction];
}

-(void)cameraAction {
    if (self.bluetoothViewController.mainConnectedCameraPeerID) {
        switch (self.cameraMode) {
            case CSStateCameraModeStill:
                [self updateCameraWithCurrentStateAndButtonAction:CSStateButtonActionTakePicture];
                if (!self.takePictureAfterSound) [self runStillImageCaptureAnimation];
                break;
            case CSStateCameraModeActionShot:
                if (self.cameraIsActionShooting) {
                    [self updateCameraWithCurrentStateAndButtonAction:CSStateButtonActionStopActionShot];
                    self.cameraIsActionShooting = NO;
                    [self recordingWillStop];
                } else {
                    [self updateCameraWithCurrentStateAndButtonAction:CSStateButtonActionStartActionShot];
                    self.cameraIsActionShooting = YES;
                    [self recordingWillStart];
                }
                if (!self.cameraIsActionShooting && !self.cameraButton.isDragging)[self.cameraButton updateCameraButtonWithText:@""];
                
                break;
            case CSStateCameraModeVideo:
                if (self.cameraIsRecording) {
                    [self updateCameraWithCurrentStateAndButtonAction:CSStateButtonActionStopVideo];
                    self.cameraIsRecording = NO;
                    [self recordingWillStop];
                    if (!self.cameraButton.isAnimatingButton) {
                        [self stopRecordingTimer];
                    }
                } else {
                    [self updateCameraWithCurrentStateAndButtonAction:CSStateButtonActionStartVideo];
                    self.cameraIsRecording = YES;
                    [self recordingWillStart];
                    if (!self.cameraButton.isAnimatingButton) {
                        [self startRecordingTimer];
                    }
                    
                }
                
                break;
            default:
                break;
        }
    }
}

-(void)countRecordingTime:(NSTimer *)timer {
    NSTimeInterval secs = [[NSDate date] timeIntervalSinceDate:self.recordingStart];
    int minute = (int)secs/60;
    int second = (int)secs%60;
    if (!self.cameraButton.isAnimatingButton) {
        [self.cameraButton updateCameraButtonWithText:[NSString stringWithFormat:@"%i:%02i", minute, second]];
//TODO: locked orientation stuff for camera button
//        if (self.lockedOrientation == UIDeviceOrientationLandscapeLeft) {
//            if (self.cameraButton.buttonImage.isHighlighted) {
//                self.cameraButtonString = [NSString stringWithFormat:@"%i:%02i", minute, second];
//                self.cameraButton.buttonImage.highlightedImage = [self maskImage:self.videoCameraButtonImageHighlighted withMaskText:self.cameraButtonString offsetFromCenter:CGPointMake(-15, 0) fontSize:kSmallFontSize];
//            } else {
//                [self setCameraButtonText:[NSString stringWithFormat:@"%i:%02i", minute, second] withOffset:CGPointMake(-15, 0) fontSize:kSmallFontSize];
//            }
//        } else if (self.lockedOrientation == UIDeviceOrientationLandscapeRight) {
//            if (self.cameraButton.buttonImage.isHighlighted) {
//                self.cameraButtonString = [NSString stringWithFormat:@"%i:%02i", minute, second];
//                self.cameraButton.buttonImage.highlightedImage = [self maskImage:self.videoCameraButtonImageHighlighted withMaskText:self.cameraButtonString offsetFromCenter:CGPointMake(15, 0) fontSize:kSmallFontSize];
//            } else {
//                [self setCameraButtonText:[NSString stringWithFormat:@"%i:%02i", minute, second] withOffset:CGPointMake(15, 0) fontSize:kSmallFontSize];
//            }
//        } else {
//            if (self.cameraButton.buttonImage.isHighlighted) {
//                self.cameraButtonString = [NSString stringWithFormat:@"%i:%02i", minute, second];
//                self.cameraButton.buttonImage.highlightedImage = [self maskImage:self.videoCameraButtonImageHighlighted withMaskText:self.cameraButtonString offsetFromCenter:CGPointZero fontSize:kSmallFontSize];
//            } else {
//                [self setCameraButtonText:[NSString stringWithFormat:@"%i:%02i", minute, second] withOffset:CGPointZero fontSize:kSmallFontSize];
//            }
//        }
    }
}

-(void) updateCameraRollButtonWithImage:(UIImage *)image duration:(float)duration {
    [UIView transitionWithView:self.cameraRollButton
                      duration:duration
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        self.cameraRollImage.image = image;
                    } completion:nil];
}

#pragma mark -
#pragma mark Flash Button

- (IBAction)pressedFlashButton:(id)sender {
    if (self.flashModeMenuIsOpen) {
        [self closeFlashModeMenu:sender];
    } else {
        [self openFlashModeMenu];
    }
}

-(void)openFlashModeMenu {
    self.flashModeMenuIsOpen = YES;
    switch (self.flashMode) {
        case CSStateFlashModeAuto: {
            [UIView animateWithDuration:0.5 animations:^{
                self.flashOnDistanceToTop.constant = CGRectGetHeight(self.flashModeAutoButton.frame);
                self.flashModeOnButton.alpha = kDefaultAlpha;
                
                self.flashOffDistanceToTop.constant = CGRectGetHeight(self.flashModeAutoButton.frame)*2;
                self.flashModeOffButton.alpha = kDefaultAlpha;
                
                [self.view layoutIfNeeded];
            } completion:^(BOOL finished) {
            }];
            break;
        }
        case CSStateFlashModeOn: {
            [UIView animateWithDuration:0.5 animations:^{
                self.flashAutoDistanceToTop.constant = CGRectGetHeight(self.flashModeAutoButton.frame);
                self.flashModeAutoButton.alpha = kDefaultAlpha;
                
                self.flashOffDistanceToTop.constant = CGRectGetHeight(self.flashModeAutoButton.frame)*2;
                self.flashModeOffButton.alpha = kDefaultAlpha;
                [self.view layoutIfNeeded];

            } completion:^(BOOL finished) {
            }];
            break;
        }
        case CSStateFlashModeOff: {
            [UIView animateWithDuration:0.5 animations:^{
                self.flashAutoDistanceToTop.constant = CGRectGetHeight(self.flashModeAutoButton.frame);
                self.flashModeAutoButton.alpha = kDefaultAlpha;
                
                self.flashOnDistanceToTop.constant = CGRectGetHeight(self.flashModeAutoButton.frame)*2;
                self.flashModeOnButton.alpha = kDefaultAlpha;
                [self.view layoutIfNeeded];

            } completion:^(BOOL finished) {
            }];
            break;
        }
        default:
            break;
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL notFirstTime = [[defaults objectForKey:@"isNotFirstTimeFlashMenu"] boolValue];
    if (!notFirstTime) {
        [UIView animateWithDuration:0.5 animations:^{
            _flashOnLabel.alpha = 1;
            _flashOffLabel.alpha = 1;
            _flashAutoLabel.alpha = 1;
        }];
        [defaults setObject:@YES forKey:@"isNotFirstTimeFlashMenu"];
        [defaults synchronize];
    } else {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            if (_flashModeMenuIsOpen) {
                [UIView animateWithDuration:0.5 animations:^{
                    _flashOnLabel.alpha = 1;
                    _flashOffLabel.alpha = 1;
                    _flashAutoLabel.alpha = 1;
                }];
            }
        });
    }
}

-(void)closeFlashModeMenu:(id)sender {
    [UIView animateWithDuration:0.5 animations:^{
        self.flashOffDistanceToTop.constant = 0;
        self.flashOnDistanceToTop.constant = 0;
        self.flashAutoDistanceToTop.constant = 0;
        if ([sender isEqual:self.flashModeAutoButton]) {
            self.flashModeAutoButton.alpha = kDefaultAlpha;
            self.flashModeOffButton.alpha = 0;
            self.flashModeOnButton.alpha = 0;
            self.flashOffLabel.alpha = 0;
            self.flashOnLabel.alpha = 0;
        } else if ([sender isEqual:self.flashModeOnButton]) {
            self.flashModeOnButton.alpha = kDefaultAlpha;
            self.flashModeOffButton.alpha = 0;
            self.flashModeAutoButton.alpha = 0;
            self.flashAutoLabel.alpha = 0;
            self.flashOffLabel.alpha = 0;
        } else if ([sender isEqual:self.flashModeOffButton]) {
            self.flashModeOffButton.alpha = kDefaultAlpha;
            self.flashModeAutoButton.alpha = 0;
            self.flashModeOnButton.alpha = 0;
            self.flashAutoLabel.alpha = 0;
            self.flashOnLabel.alpha = 0;
        }
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {

        [UIView animateWithDuration:0.5 delay:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            _flashOnLabel.alpha = 0;
            _flashOffLabel.alpha = 0;
            _flashAutoLabel.alpha = 0;
        } completion:nil];
        
    }];
    
    if ([sender isEqual:self.flashModeAutoButton]) {
        self.currentFlashButton = self.flashModeAutoButton;
        self.flashMode = CSStateFlashModeAuto;
    } else if ([sender isEqual:self.flashModeOnButton]) {
        self.currentFlashButton = self.flashModeOnButton;
        self.flashMode = CSStateFlashModeOn;
    } else if ([sender isEqual:self.flashModeOffButton]) {
        self.currentFlashButton = self.flashModeOffButton;
        self.flashMode = CSStateFlashModeOff;
    }
    [self updateCameraWithCurrentStateAndButtonAction:CSStateButtonActionNone];
    
    
    self.flashModeMenuIsOpen = NO;
}

#pragma mark -
#pragma mark Camera Modes

-(void) updateModeButtonsForMode:(NSInteger)mode {
    switch (mode) {
        case CSStateCameraModeStill:
            [self.pictureModeButton setSelected:YES];
            [self.rapidShotModeButton setSelected:NO];
            [self.videoModeButton setSelected:NO];
            
            break;
        case CSStateCameraModeActionShot:
            [self.pictureModeButton setSelected:NO];
            [self.rapidShotModeButton setSelected:YES];
            [self.videoModeButton setSelected:NO];

            break;
        case CSStateCameraModeVideo:
            [self.pictureModeButton setSelected:NO];
            [self.rapidShotModeButton setSelected:NO];
            [self.videoModeButton setSelected:YES];

            break;
        default:
            break;
    }
}

-(void)switchToPictureMode {
    if (self.cameraMode != CSStateCameraModeStill) {
        self.cameraMode = CSStateCameraModeStill;
        [self updateModeButtonsForMode:self.cameraMode];
        [self.cameraButton updateCameraButtonImageForCurrentCameraMode];
        [self updateCameraWithCurrentStateAndButtonAction:CSStateButtonActionNone];
        
        [self updateCameraPreviewPosition];
        [self updateTappablePreviewRectForCameraMode:self.cameraMode];
        [self updateDragViewAnimations];
        
    }
}

- (void)switchToRapidShotMode {
    if (self.cameraMode != CSStateCameraModeActionShot) {
        
        self.cameraMode = CSStateCameraModeActionShot;
        [self updateModeButtonsForMode:self.cameraMode];
        [self.cameraButton updateCameraButtonImageForCurrentCameraMode];
        [self updateCameraWithCurrentStateAndButtonAction:CSStateButtonActionNone];
        
        [self updateCameraPreviewPosition];
        [self updateTappablePreviewRectForCameraMode:self.cameraMode];
        [self updateDragViewAnimations];
    }
}

- (void)switchToVideoMode {
    if (self.cameraMode != CSStateCameraModeVideo) {
        
        self.cameraMode = CSStateCameraModeVideo;
        [self updateModeButtonsForMode:self.cameraMode];
        [self.cameraButton updateCameraButtonImageForCurrentCameraMode];
        [self updateCameraWithCurrentStateAndButtonAction:CSStateButtonActionNone];
        
        [self updateCameraPreviewPosition];
        [self updateTappablePreviewRectForCameraMode:self.cameraMode];
        [self updateDragViewAnimations];
    }
}

-(AVCaptureFlashMode) currentAVFlashMode {
    switch (self.flashMode) {
        case CSStateFlashModeAuto:
            return AVCaptureFlashModeAuto;
            break;
        case CSStateFlashModeOn:
            return AVCaptureFlashModeOn;
            break;
        case CSStateFlashModeOff:
            return AVCaptureFlashModeOff;
            break;
        default:
            return AVCaptureFlashModeAuto;
            break;
    }
}

-(AVCaptureTorchMode) currentAVTorchMode {
    switch (self.flashMode) {
        case CSStateFlashModeAuto:
            return AVCaptureTorchModeAuto;
            break;
        case CSStateFlashModeOn:
            return AVCaptureTorchModeOn;
            break;
        case CSStateFlashModeOff:
            return AVCaptureTorchModeOff;
            break;
        default:
            return AVCaptureTorchModeAuto;
            break;
    }
}

-(AVCaptureFocusMode) currentAVFocusMode {
    if (self.autoFocusMode) {
        return AVCaptureFocusModeContinuousAutoFocus;
    } else {
        return AVCaptureFocusModeLocked;
    }
}

-(AVCaptureExposureMode) currentAVExposureMode {
    if (self.autoExposureMode) {
        return AVCaptureExposureModeContinuousAutoExposure;
    } else {
        return AVCaptureExposureModeLocked;
    }
}

-(void)enableProperCameraModeButtonsForCurrentCameraMode:(BOOL)setEnabled {
    switch (self.cameraMode) {
        case CSStateCameraModeStill:
            self.rapidShotModeButton.enabled = setEnabled;
            self.videoModeButton.enabled = setEnabled;
            break;
        case CSStateCameraModeActionShot:
            self.pictureModeButton.enabled = setEnabled;
            self.videoModeButton.enabled = setEnabled;
            break;
        case CSStateCameraModeVideo:
            self.rapidShotModeButton.enabled = setEnabled;
            self.pictureModeButton.enabled = setEnabled;
            break;
        default:
            self.pictureModeButton.enabled = setEnabled;
            self.rapidShotModeButton.enabled = setEnabled;
            self.videoModeButton.enabled = setEnabled;
            break;
    }
}


//-(UIImage *)currentCameraButtonImage {
//    switch (self.cameraMode) {
//        case CSStateCameraModeStill:
//            return self.pictureCameraButtonImage;
//            break;
//        case CSStateCameraModeActionShot:
//            return self.rapidCameraButtonImage;
//        case CSStateCameraModeVideo:
//            return self.videoCameraButtonImage;
//        default:
//            return self.pictureCameraButtonImage;
//            break;
//    }
//}

//-(UIImage *)currentHighlightedCameraButtonImage {
//    switch (self.cameraMode) {
//        case CSStateCameraModeStill:
//            return self.pictureCameraButtonImageHighlighted;
//            break;
//        case CSStateCameraModeActionShot:
//            if (self.videoProcessor.actionShooting) {
//                return [self maskImage:self.pictureCameraButtonImageHighlighted withMaskText:self.cameraButtonString offsetFromCenter:CGPointZero fontSize:kMediumFontSize];
//            } else {
//                return self.rapidCameraButtonImageHighlighted;
//            }
//        case CSStateCameraModeVideo:
//            return [self maskImage:self.videoCameraButtonImageHighlighted withMaskText:self.cameraButtonString offsetFromCenter:CGPointZero fontSize:kSmallFontSize];
//        default:
//            return self.pictureCameraButtonImageHighlighted;
//            break;
//    }
//    NSLog(@"%i", self.cameraMode);
//}


//-(void)switchCameraButtonImageTo:(UIImage *)newImage {
//    [UIView transitionWithView:self.cameraButton
//                      duration:0.35f
//                       options:UIViewAnimationOptionTransitionCrossDissolve
//                    animations:^{
//                        self.cameraButton.buttonImage.image = newImage;
//                    } completion:nil];
//}

#pragma mark -
#pragma mark UI

- (void)runStillImageCaptureAnimation
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.view.layer setOpacity:0.01];
        [UIView animateWithDuration:.2 animations:^{
            [self.view.layer setOpacity:1.0];
        }];
    });
}

//-(void)checkMicPermission {
//    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
//		if (granted) {
//            self.micPermission = YES;
//			//Granted access to mediaType
//		} else {
//			//Not granted access to mediaType
//			dispatch_async(dispatch_get_main_queue(), ^{
//				[[[UIAlertView alloc] initWithTitle:@"Where's the mic?"
//											message:@"Click-Shot doesn't have permission to use the microphone. You need to change this in your Privacy Settings to record a video."
//										   delegate:self
//								  cancelButtonTitle:@"OK, I'll fix that now"
//								  otherButtonTitles:nil] show];
//			});
//		}
//	}];
//}

-(void)checkAssetsPremission {
    self.assetsPermission = YES;
    ALAssetsLibraryGroupsEnumerationResultsBlock assetGroupEnumerator =
    ^(ALAssetsGroup *assetGroup, BOOL *stop) {
        if (assetGroup != nil) {
            // do nothing
        }
    };
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library enumerateGroupsWithTypes:ALAssetsGroupAll usingBlock:assetGroupEnumerator failureBlock:^(NSError *error) {
        NSLog(@"%@", error);
        self.assetsPermission = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            [[[UIAlertView alloc] initWithTitle:@"I can't save!"
                                        message:@"Click-Shot Remote doesn't have permission to access or save photos. Give the app permission in \nSettings -> Privacy -> Photos."
                                       delegate:self
                              cancelButtonTitle:@"OK, I'll do that now"
                              otherButtonTitles:nil] show];
        });
    }];

}

-(void) updateMoveableExposureView {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithBool:!self.autoExposureMode] forKey:@"noAutoExposureMode"];
    [self.exposureButton setSelected:self.autoExposureMode];
    if (self.exposureButton.selected) {
        self.exposureButton.layer.borderColor = _highlightColor.CGColor;
    } else {
        self.exposureButton.layer.borderColor = [UIColor colorWithWhite:0.642 alpha:1.000].CGColor;
    }
    CGPoint exposurePoint = CGPointMake(0.5, 0.5);
    _exposureDevicePoint = exposurePoint;
    self.exposePointView.userInteractionEnabled = !self.autoExposureMode;
    if (!self.autoExposureMode) {
        self.exposePointView.center = CGPointMake(exposurePoint.x*_tappablePreviewRect.size.width + _tappablePreviewRect.origin.x, exposurePoint.y*_tappablePreviewRect.size.height + _tappablePreviewRect.origin.y);
        [self.exposePointView fixIfOffscreen];
        [UIView animateWithDuration:0.4 animations:^{
            self.exposePointView.alpha = kDefaultAlpha;
        }];
    } else {
        [UIView animateWithDuration:0.4 animations:^{
            self.exposePointView.alpha = 0;
        }];
    }
}

-(void) updateMoveableExposureViewForCurrentExposurePoint {
    self.exposePointView.alpha = 0;
    
    self.exposePointView.center = CGPointMake(_exposureDevicePoint.x*_previewImageRect.size.width + _previewImageRect.origin.x, _exposureDevicePoint.y*_previewImageRect.size.height + _previewImageRect.origin.y);
    [self.exposePointView fixIfOffscreen];
    
    if (!self.autoExposureMode) {
        [UIView animateWithDuration:0.4 animations:^{
            self.exposePointView.alpha = kDefaultAlpha;
        }];
    } else {
        [UIView animateWithDuration:0.2 animations:^{
            self.exposePointView.alpha = kDefaultAlpha;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.7 animations:^{
                self.exposePointView.alpha = 0;
            }];
        }];
    }
}

-(void) updateMoveableFocusView {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithBool:self.autoFocusMode] forKey:@"autoFocusMode"];
    [self.focusButton setSelected:self.autoFocusMode];
    if (self.focusButton.selected) {
        self.focusButton.layer.borderColor = _highlightColor.CGColor;
    } else {
        self.focusButton.layer.borderColor = [UIColor colorWithWhite:0.642 alpha:1.000].CGColor;
    }
    CGPoint focusPoint = CGPointMake(0.5, 0.5);
    _focusDevicePoint = focusPoint;
    self.focusPointView.userInteractionEnabled = !self.autoFocusMode;
    if (!self.autoFocusMode) {
        self.focusPointView.center = CGPointMake(focusPoint.x*_tappablePreviewRect.size.width + _tappablePreviewRect.origin.x, focusPoint.y*_tappablePreviewRect.size.height + _tappablePreviewRect.origin.y);
        [self.focusPointView fixIfOffscreen];
        [UIView animateWithDuration:0.4 animations:^{
            self.focusPointView.alpha = kDefaultAlpha;
        }];
    } else {
        [UIView animateWithDuration:0.4 animations:^{
            self.focusPointView.alpha = 0;
        }];
    }
}


-(void) updateMoveableFocusViewForCurrentFocusPoint {
    self.focusPointView.alpha = 0;
    
    self.focusPointView.center = CGPointMake(_focusDevicePoint.x*_previewImageRect.size.width + _previewImageRect.origin.x, _focusDevicePoint.y*_previewImageRect.size.height + _previewImageRect.origin.y);
    [self.focusPointView fixIfOffscreen];
    if (!self.autoFocusMode) {
        [UIView animateWithDuration:0.4 animations:^{
            self.focusPointView.alpha = kDefaultAlpha;
        }];
    } else {
        [UIView animateWithDuration:0.2 animations:^{
            self.focusPointView.alpha = kDefaultAlpha;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.7 animations:^{
                self.focusPointView.alpha = 0;
            }];
        }];
    }
}

#pragma mark -
#pragma mark Manage Rotations

-(BOOL)shouldAutorotate {
    return NO;
}

- (void)deviceDidRotate:(NSNotification *)notification {
//    if (!self.tutorialIsOpen) {
//        [self updateRotations];
//    }
}

-(UIDeviceOrientation)deviceOrientationForCameraOrientation:(CSStateCameraOrientation)orientation {
    switch (orientation) {
        case CSStateCameraOrientationPortrait:
            return UIDeviceOrientationPortrait;
            break;
        case CSStateCameraOrientationLandscape:
            return UIDeviceOrientationLandscapeRight;
            break;
        case CSStateCameraOrientationUpsideDownPortrait:
            return UIDeviceOrientationPortraitUpsideDown;
            break;
        case CSStateCameraOrientationUpsideDownLandscape:
            return UIDeviceOrientationLandscapeLeft;
            break;
        default:
            break;
    }
}

-(void) updateRotationsForCameraOrientation:(CSStateCameraOrientation)orientation {
//    UIDeviceOrientation currentOrientation = [[UIDevice currentDevice] orientation];
	// Don't update the reference orientation when the device orientation is face up/down or unknown.
    UIDeviceOrientation currentOrientation = [self deviceOrientationForCameraOrientation:orientation];
    double rotation = 0;
    switch (currentOrientation) {
        case UIDeviceOrientationFaceDown:
        case UIDeviceOrientationFaceUp:
        case UIDeviceOrientationUnknown:
            return;
        case UIDeviceOrientationPortrait:
            rotation = 0;
            //TODO: set camera orientation
//            [self.videoProcessor setReferenceOrientation:AVCaptureVideoOrientationPortrait];
            
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            rotation = -M_PI;
//            [self.videoProcessor setReferenceOrientation:AVCaptureVideoOrientationPortraitUpsideDown];
            
            break;
        case UIDeviceOrientationLandscapeLeft:
            rotation = M_PI_2;
//            [self.videoProcessor setReferenceOrientation:AVCaptureVideoOrientationLandscapeRight];
            
            break;
        case UIDeviceOrientationLandscapeRight:
            rotation = -M_PI_2;
//            [self.videoProcessor setReferenceOrientation:AVCaptureVideoOrientationLandscapeLeft];
            
            break;
    }
    
    CGAffineTransform transform = CGAffineTransformMakeRotation(rotation);
    [UIView animateWithDuration:0.4 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        
        if (!self.cameraIsRecording)
            [self.cameraButton.buttonImage setTransform:transform];
        [self.cameraRollButton setTransform:transform];
        [self.flashModeAutoButton setTransform:transform];
        [self.flashModeOffButton setTransform:transform];
        [self.flashModeOnButton setTransform:transform];
        [self.focusButton setTransform:transform];
        [self.exposureButton setTransform:transform];
        [self.swithCameraButton setTransform:transform];
        [self.settingsButton setTransform:transform];
        [self.soundsButton setTransform:transform];
        [self.bluetoothButton setTransform:transform];
        [self.tutorialButton setTransform:transform];
    } completion:nil];
    if (self.flashModeMenuIsOpen) {
        [self pressedFlashButton:self.currentFlashButton];
    }
}


#pragma mark -
#pragma mark Handle Embed Segues

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"bluetoothMenuEmbed"]) {
        BluetoothCommunicationViewController *bluetoothController = segue.destinationViewController;
        bluetoothController.delegate = self;
        self.bluetoothViewController = bluetoothController;
    }
}

#pragma mark -
#pragma mark Bluetooth Delegates

-(void)updateCameraWithCurrentStateAndButtonAction:(CSStateButtonAction)buttonAction {
    if (_shouldSendChangesToCamera) {
        Byte focusX = [self byteForFEFloat:_focusDevicePoint.x];
        Byte focusY = [self byteForFEFloat:_focusDevicePoint.y];
        Byte exposureX = [self byteForFEFloat:_exposureDevicePoint.x];
        Byte exposureY = [self byteForFEFloat:_exposureDevicePoint.y];
        
        const Byte messageBytes[11] = { buttonAction , self.cameraMode, self.flashMode, self.cameraPosition, self.cameraSound, self.autoFocusMode, focusX, focusY, self.autoExposureMode, exposureX, exposureY};
        NSData *dataToSend = [NSData dataWithBytes:messageBytes length:sizeof(messageBytes)];
        //    NSLog(@"%@", dataToSend);
        [self.bluetoothViewController sendMessageToAllCameras:dataToSend];
    }
}

//-(NSData *)currentStateData {
//    Byte focusX = [self byteForFEFloat:_focusDevicePoint.x];
//    Byte focusY = [self byteForFEFloat:_focusDevicePoint.y];
//    Byte exposureX = [self byteForFEFloat:_exposureDevicePoint.x];
//    Byte exposureY = [self byteForFEFloat:_exposureDevicePoint.y];
//    
//    const Byte messageBytes[11] = { CSStateButtonActionNone , self.cameraMode, self.flashMode, self.cameraPosition, self.cameraSound, self.autoFocusMode, focusX, focusY, self.autoExposureMode, exposureX, exposureY};
//    NSData *dataToSend = [NSData dataWithBytes:messageBytes length:sizeof(messageBytes)];
//    return dataToSend;
//}


-(Byte)byteForFEFloat:(CGFloat)number{
    number *= 100;
    return (Byte)number;
}

-(void)receivedMessage:(NSData *)message fromPeer:(MCPeerID *)peer {
    if (message.length < 20) {
        NSLog(@"Received from Camera: %@", message);
    }
    
    if (message.length == 13) {
        _shouldSendChangesToCamera = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            
            CGFloat remoteFocusDevicePointX = 0;
            CGFloat remoteFocusDevicePointY = 0;
            CGFloat remoteExposureDevicePointX = 0;
            CGFloat remoteExposureDevicePointY = 0;
            for (int i = 0; i < message.length; i++) {
                Byte byteBuffer;
                [message getBytes:&byteBuffer range:NSMakeRange(i, 1)];
                switch (i) {
                    case 0: // Camera Action
                        // don't worry about it
                        break;
                    case 1: // Camera Mode
                        switch (byteBuffer) {
                            case CSStateCameraModeStill:
                                [self pressedPictureMode:nil];
                                break;
                            case CSStateCameraModeActionShot:
                                [self pressedRapidShotMode:nil];
                                break;
                            case CSStateCameraModeVideo:
                                [self pressedVideoMode:nil];
                                break;
                            default:
                                break;
                        }
                        break;
                    case 2: // Flash Mode
                        switch (byteBuffer) {
                            case CSStateFlashModeAuto:
                                [self closeFlashModeMenu:self.flashModeAutoButton];
                                break;
                            case CSStateFlashModeOn:
                                [self closeFlashModeMenu:self.flashModeOnButton];
                                break;
                            case CSStateFlashModeOff:
                                [self closeFlashModeMenu:self.flashModeOffButton];
                                break;
                            default:
                                break;
                        }
                        break;
                    case 3: // Camera Position
                        self.cameraPosition = byteBuffer;
                        break;
                    case 4: // Sound
                        if (self.cameraSound != byteBuffer) {
                            [self.soundPicker selectRow:byteBuffer inComponent:0 animated:YES];
                            [self updateSoundPlayerWithSoundNumber:byteBuffer];
                        }
                        break;
                    case 5: // auto focus
                        if (_autoFocusMode != byteBuffer) {
                            _autoFocusMode = byteBuffer;
                            [self updateMoveableFocusView];
                        }
                        break;
                    case 6: { // Focus X
                        remoteFocusDevicePointX = ((CGFloat)byteBuffer)/100.0;
                        break;
                    }
                    case 7: { // Focus Y
                        remoteFocusDevicePointY = ((CGFloat)byteBuffer)/100.0;
                        break;
                    }
                    case 8: // auto exposure
                        if (_autoExposureMode != byteBuffer) {
                            _autoExposureMode = byteBuffer;
                            [self updateMoveableExposureView];
                        }
                        break;
                    case 9: { // Exposure X
                        remoteExposureDevicePointX = ((CGFloat)byteBuffer)/100.0;
                    }
                    case 10: { // Exposure Y
                        remoteExposureDevicePointY = ((CGFloat)byteBuffer)/100.0;
                        break;
                    }
                    case 11: { // Has flash
                        [self switchedToCameraDeviceThatHasFlash:byteBuffer];
                        break;
                    }
                    case 12: { // orientation
                        [self updateRotationsForCameraOrientation:byteBuffer];
                    }
                    default:
                        break;
                }
            }
            if (remoteFocusDevicePointY != _focusDevicePoint.y || remoteFocusDevicePointX != _focusDevicePoint.x) {
                _focusDevicePoint = CGPointMake(remoteFocusDevicePointX, remoteFocusDevicePointY);
                [self updateMoveableFocusViewForCurrentFocusPoint];
            }
            if (remoteExposureDevicePointY != _exposureDevicePoint.y || remoteExposureDevicePointX != _exposureDevicePoint.x) {
                _exposureDevicePoint = CGPointMake(remoteExposureDevicePointX, remoteExposureDevicePointY);
                [self updateMoveableExposureViewForCurrentExposurePoint];
            }
            
            _shouldSendChangesToCamera = YES;
            
        });
    } else { // is preview image
        const Byte messageBytes[1] = { CSCommunicationReceivedPreviewPhoto};
        NSData *dataToSend = [NSData dataWithBytes:messageBytes length:sizeof(messageBytes)];
        [self.bluetoothViewController sendMessageToAllCameras:dataToSend];
        if (self.bluetoothViewController.shouldSendPreviewImagesSwitch.on) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIImage *image = [UIImage imageWithData:message];
                NSLog(@"Received preview image from camera %@", NSStringFromCGSize(image.size));
                if (self.cameraPosition == CSStateCameraPositionFront) {
                    _previewView.transform = CGAffineTransformMakeScale(-1, 1);
                } else {
                    _previewView.transform = CGAffineTransformMakeScale(1, 1);
                }
                self.previewView.image = image;
            });
        }
    }
}

-(void)didConnectToCamera {
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.5 animations:^{
            self.notConnectedToDeviceView.alpha = 0;
        }];
        _cameraButton.isDraggable = YES;
        _bluetoothButton.selected = YES;
        _bluetoothButton.layer.borderColor = _highlightColor.CGColor;

    });
}

-(void)didDisconnectFromCamera {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self switchedToCameraDeviceThatHasFlash:YES]; // reset flash menu
        [UIView animateWithDuration:0.5 animations:^{
            self.notConnectedToDeviceView.alpha = 1;
        } completion:^(BOOL finished){
            self.previewView.image = nil;
        }];
        _cameraButton.isDraggable = NO;
        _bluetoothButton.selected = NO;
        _bluetoothButton.layer.borderColor = [UIColor colorWithWhite:0.642 alpha:1.000].CGColor;
        
    });
}

-(void)finishedSavingReceivedImageToCameraRoll:(UIImage *)image {
    dispatch_async(dispatch_get_main_queue(), ^{
        _cameraRollImage.image = image;
        [self updateGalleryItems];
    });
}

-(NSArray *)newReceivingPictureLoadingRings {
    CAShapeLayer *ring = [CAShapeLayer layer];
    ring.strokeColor = [UIColor whiteColor].CGColor;
    ring.lineWidth = 3;
    ring.zPosition = 20;
    ring.fillColor   = [UIColor clearColor].CGColor;
    ring.strokeEnd = 0.0;
    ring.bounds = CGRectMake(0, 0, 20, 20);
    ring.path = [UIBezierPath bezierPathWithOvalInRect:ring.bounds].CGPath;
    ring.anchorPoint = CGPointMake(0.5, 0.5);
    ring.position = CGPointMake(self.cameraRollButton.frame.size.width/2, self.cameraRollButton.frame.size.height/2);
    ring.transform = CATransform3DMakeRotation(270*(M_PI/180), 0.0, 0.0, 1.0);
    
    CAShapeLayer *outerRing = [CAShapeLayer layer];
    outerRing.strokeColor = _highlightColor.CGColor;
    outerRing.lineWidth = 5;
    outerRing.zPosition = 20;
    outerRing.fillColor   = [UIColor clearColor].CGColor;
    outerRing.strokeEnd = 0.0;
    outerRing.bounds = CGRectMake(0, 0, 20, 20);
    outerRing.path = [UIBezierPath bezierPathWithOvalInRect:ring.bounds].CGPath;
    outerRing.anchorPoint = CGPointMake(0.5, 0.5);
    outerRing.position = CGPointMake(self.cameraRollButton.frame.size.width/2, self.cameraRollButton.frame.size.height/2);
    outerRing.transform = CATransform3DMakeRotation(270*(M_PI/180), 0.0, 0.0, 1.0);

    
    
    [self.cameraRollButton.layer addSublayer:outerRing];
    [self.cameraRollButton.layer addSublayer:ring];

    return @[ring, outerRing];
}

-(void)changedShouldReceivePreviewImages:(BOOL)shouldReceivePreviewImages {
    if (shouldReceivePreviewImages) {
        _turnOnPreviewImagesLabel.hidden = YES;
    } else {
        _turnOnPreviewImagesLabel.hidden = NO;
        [UIView animateWithDuration:0.4 animations:^{
            _previewView.alpha = 0;
        } completion:^(BOOL finished) {
            _previewView.image = nil;
            _previewView.alpha = 1;
        }];
    }
}

#pragma mark -
#pragma mark Manage Touches

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.pictureModeButton.enabled && !self.swipeModesGestureIsBlocked && !self.takePictureAfterSound && !self.settingsMenuIsOpen && !self.cameraRollIsOpen) { // make sure we can switch modes
        _primaryTouch = [touches anyObject];
        _startXTouch = [_primaryTouch locationInView:self.view].x;
        _hasMoved = NO;
        _lastMoveTime = CACurrentMediaTime();
        _selectorBarStartCenterX = self.modeSelectorBar.center.x;
    }
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.pictureModeButton.enabled && !self.swipeModesGestureIsBlocked && !self.takePictureAfterSound && !self.settingsMenuIsOpen && !self.cameraRollIsOpen) { // make sure we can switch modes
        // Switching camera mode with swipe
        CGFloat currentXPos = [[touches anyObject] locationInView:self.view].x;
        CGFloat diffFromBeginning = currentXPos - _startXTouch;
        if (diffFromBeginning < 0 ) { //swiping  to rapid shot or video shot
            if (self.modeSelectorBar.frame.origin.x < self.videoModeButton.frame.origin.x) {
                self.modeSelectorBar.center = CGPointMake(_selectorBarStartCenterX-(diffFromBeginning/(self.view.frame.size.width/55)), self.modeSelectorBar.center.y);
            }
            if (self.cameraMode == CSStateCameraModeStill) { // swiping to rapid from picture
                [self swipeView:self.rapidShotSwipeView distance:diffFromBeginning];
            } else if (self.cameraMode == CSStateCameraModeActionShot) { // swiping to video from rapid
                [self swipeView:self.videoSwipeView distance:diffFromBeginning];
            }
        } else  { // swiping  to rapid shot or picture shot
            if (self.modeSelectorBar.frame.origin.x > self.pictureModeButton.frame.origin.x) {
                self.modeSelectorBar.center = CGPointMake(_selectorBarStartCenterX-(diffFromBeginning/(self.view.frame.size.width/55)), self.modeSelectorBar.center.y);
            }
            if (self.cameraMode == CSStateCameraModeVideo) { // swiping to rapid from video
                [self swipeView:self.rapidShotSwipeView distance:diffFromBeginning];
            } else if (self.cameraMode == CSStateCameraModeActionShot) { // swiping to picture from rapid
                [self swipeView:self.pictureSwipeView distance:diffFromBeginning];
            }
        }
        [self highlightSelectorMode];
        CGFloat diffFromLastPos = currentXPos - _previousXTouch;
        CFTimeInterval now = CACurrentMediaTime();
        CFTimeInterval elapsedTime = now - _lastMoveTime;
        _velocity = diffFromLastPos/elapsedTime;
        
        _previousXTouch = currentXPos;
        _lastMoveTime = now;
        _hasMoved = YES;
    }
}

-(void)swipeView:(UIView *)view distance:(CGFloat)distance {
    view.alpha = fabsf(distance)/self.view.frame.size.width;
    if (distance < 0) {
        view.frame = CGRectMake(self.view.frame.size.width+distance, view.frame.origin.y, view.frame.size.width, view.frame.size.height);
    } else {
        view.frame = CGRectMake(distance-self.view.frame.size.width, view.frame.origin.y, view.frame.size.width, view.frame.size.height);
    }
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.pictureModeButton.enabled && !self.swipeModesGestureIsBlocked && !self.takePictureAfterSound && !self.settingsMenuIsOpen && !self.cameraRollIsOpen) { // make sure we can switch modes
        // Switching camera mode with swipe
        CGFloat currentXPos = [_primaryTouch locationInView:self.view].x;
        CGFloat diffFromBeginning = currentXPos - _startXTouch;
        if (_hasMoved) {
            if (_velocity >= kSwipeVelocityUntilGuarenteedSwitch) {
                if (self.cameraMode == CSStateCameraModeVideo) {
                    [self swipeToMode:CSStateCameraModeActionShot withVelocity:_velocity andDistanceMoved:diffFromBeginning];
                } else if (self.cameraMode == CSStateCameraModeActionShot) {
                    [self swipeToMode:CSStateCameraModeStill withVelocity:_velocity andDistanceMoved:diffFromBeginning];
                } else {
                    [self swipeToSelectedButtonCameraMode];
                }
            } else if (_velocity <= -kSwipeVelocityUntilGuarenteedSwitch) {
                if (self.cameraMode == CSStateCameraModeStill) {
                    [self swipeToMode:CSStateCameraModeActionShot withVelocity:_velocity andDistanceMoved:diffFromBeginning];
                } else if (self.cameraMode == CSStateCameraModeActionShot) {
                    [self swipeToMode:CSStateCameraModeVideo withVelocity:_velocity andDistanceMoved:diffFromBeginning];
                } else {
                    [self swipeToSelectedButtonCameraMode];
                }
            } else {
                [self swipeToSelectedButtonCameraMode];
            }
        }
        _primaryTouch = nil;
        _hasMoved = NO;
    }
    else if (self.settingsMenuIsOpen && IPHONE_4 && CGRectContainsPoint(self.previewView.frame, [[touches anyObject] locationInView:self.view])) {
        [self closeSettingsMenu];
    }
}


-(void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}

-(void)swipeToMode:(NSInteger)newMode withVelocity:(CGFloat)velocity andDistanceMoved:(CGFloat)distanceMoved {
    distanceMoved = fabsf(distanceMoved);
    velocity = fabsf(velocity);
    CGFloat distanceToMove = self.pictureModeButton.frame.size.width+1-distanceMoved;
    NSTimeInterval lengthOfAnimation = distanceToMove/velocity;
    lengthOfAnimation *= 2;
    
    if (newMode == CSStateCameraModeStill) {
        [self switchToPictureMode];
        [UIView animateWithDuration:lengthOfAnimation delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.modeSelectorBar.center = CGPointMake(self.pictureModeButton.center.x, self.modeSelectorBar.center.y);
            self.pictureSwipeView.center = self.view.center;
            self.pictureSwipeView.alpha = 1;
        } completion:^(BOOL finished) {
            [self fadeOutSwipeView:self.pictureSwipeView];
        }];
    } else if (newMode == CSStateCameraModeActionShot) {
        [self switchToRapidShotMode];
        [UIView animateWithDuration:lengthOfAnimation delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.modeSelectorBar.center = CGPointMake(self.rapidShotModeButton.center.x, self.modeSelectorBar.center.y);
            self.rapidShotSwipeView.center = self.view.center;
            self.rapidShotSwipeView.alpha = 1;
        } completion:^(BOOL finished) {
            [self fadeOutSwipeView:self.rapidShotSwipeView];
        }];
    } else if (newMode == CSStateCameraModeVideo) {
        [self switchToVideoMode];
        [UIView animateWithDuration:lengthOfAnimation delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.modeSelectorBar.center = CGPointMake(self.videoModeButton.center.x, self.modeSelectorBar.center.y);
            self.videoSwipeView.center = self.view.center;
            self.videoSwipeView.alpha = 1;
        } completion:^(BOOL finished) {
            [self fadeOutSwipeView:self.videoSwipeView];
        }];
    }
}

-(void)fadeOutSwipeView:(UIView *)view {
    [UIView animateWithDuration:0.3 delay:0.3 options:UIViewAnimationOptionCurveEaseOut animations:^{
        view.alpha = 0;
    } completion:nil];
}

-(void)swipeToSelectedButtonCameraMode {
    if (self.pictureModeButton.selected) {
        if (self.cameraMode == CSStateCameraModeStill) {
            [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                self.modeSelectorBar.center = CGPointMake(self.pictureModeButton.center.x, self.modeSelectorBar.center.y);
                self.rapidShotSwipeView.frame = CGRectMake(self.view.frame.size.width, self.rapidShotSwipeView.frame.origin.y, self.rapidShotSwipeView.frame.size.width, self.rapidShotSwipeView.frame.size.height);
            } completion:^(BOOL finished) {
            }];
        } else {
            [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                self.modeSelectorBar.center = CGPointMake(self.pictureModeButton.center.x, self.modeSelectorBar.center.y);
                self.pictureSwipeView.center = self.view.center;
                self.pictureSwipeView.alpha = 1;
            } completion:^(BOOL finished) {
                [self fadeOutSwipeView:self.pictureSwipeView];
            }];
        }
        [self switchToPictureMode];
    } else if (self.rapidShotModeButton.selected) {
        if (self.cameraMode == CSStateCameraModeActionShot) {
            [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                self.videoSwipeView.frame = CGRectMake(self.view.frame.size.width, self.rapidShotSwipeView.frame.origin.y, self.rapidShotSwipeView.frame.size.width, self.rapidShotSwipeView.frame.size.height);
                self.pictureSwipeView.frame = CGRectMake(-self.view.frame.size.width, self.rapidShotSwipeView.frame.origin.y, self.rapidShotSwipeView.frame.size.width, self.rapidShotSwipeView.frame.size.height);
                self.modeSelectorBar.center = CGPointMake(self.rapidShotModeButton.center.x, self.modeSelectorBar.center.y);
            } completion:^(BOOL finished) {

            }];
        } else {
            [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                self.modeSelectorBar.center = CGPointMake(self.rapidShotModeButton.center.x, self.modeSelectorBar.center.y);
                self.rapidShotSwipeView.center = self.view.center;
                self.rapidShotSwipeView.alpha = 1;
            } completion:^(BOOL finished) {
                [self fadeOutSwipeView:self.rapidShotSwipeView];
            }];
        }
        [self switchToRapidShotMode];
    } else if (self.videoModeButton.selected) {
        if (self.cameraMode == CSStateCameraModeVideo) {
            [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                self.modeSelectorBar.center = CGPointMake(self.videoModeButton.center.x, self.modeSelectorBar.center.y);
                self.rapidShotSwipeView.frame = CGRectMake(-self.view.frame.size.width, self.rapidShotSwipeView.frame.origin.y, self.rapidShotSwipeView.frame.size.width, self.rapidShotSwipeView.frame.size.height);
            } completion:^(BOOL finished) {

            }];
        } else {
            [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                self.modeSelectorBar.center = CGPointMake(self.videoModeButton.center.x, self.modeSelectorBar.center.y);
                self.videoSwipeView.center = self.view.center;
                self.videoSwipeView.alpha = 1;
            } completion:^(BOOL finished) {
                [self fadeOutSwipeView:self.videoSwipeView];

            }];
        }
        [self switchToVideoMode];
    }
}

-(void)highlightSelectorMode {
    if (fabsf(self.pictureModeButton.center.x-self.modeSelectorBar.center.x) < (self.pictureModeButton.frame.size.width/2)) {
        self.pictureModeButton.selected = YES;
        self.rapidShotModeButton.selected = NO;
        self.videoModeButton.selected = NO;
    } else if (fabsf(self.rapidShotModeButton.center.x-self.modeSelectorBar.center.x) < (self.pictureModeButton.frame.size.width/2)) {
        self.pictureModeButton.selected = NO;
        self.rapidShotModeButton.selected = YES;
        self.videoModeButton.selected = NO;
    } else if (fabsf(self.videoModeButton.center.x-self.modeSelectorBar.center.x) < (self.pictureModeButton.frame.size.width/2)) {
        self.pictureModeButton.selected = NO;
        self.rapidShotModeButton.selected = NO;
        self.videoModeButton.selected = YES;
    }
}

-(UIView *)swipeViewForMode:(NSInteger)mode {
    UIView *view = [[UIView alloc] initWithFrame:self.view.frame];
    view.backgroundColor = [UIColor colorWithWhite:0.754 alpha:0.750];
    switch (mode) {
        case CSStateCameraModeStill: {
            UIImageView *image = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"stillSwipeImage"]];
            image.center = view.center;
            [view addSubview:image];
            break;
        }
        case CSStateCameraModeActionShot: {
            UIImageView *image = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"actionSwipeImage"]];
            image.center = view.center;
            [view addSubview:image];
            break;
        }
        case CSStateCameraModeVideo: {
            UIImageView *image = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"videoSwipeImage"]];
            image.center = view.center;
            [view addSubview:image];
            break;
        }
        default:
            break;
    }
    view.alpha = 0;
    [self.cameraUIView insertSubview:view aboveSubview:self.notConnectedToDeviceView];
    return view;
}

#pragma mark - Drag Animation View Delegate

-(void)dragAnimationViewPressed:(DragAnimationView *)dragAnimationView {
    if (dragAnimationView == self.settingsButtonDragView) {
        self.settingsButton.highlighted = YES;
    }
}

-(void)dragAnimationViewReleased:(DragAnimationView *)dragAnimationView {
    if (dragAnimationView == self.settingsButtonDragView) {
        self.settingsButton.highlighted = NO;
    }
}

-(void)dragAnimationView:(DragAnimationView *)dragAnimationView beganAnimationStep:(NSInteger)animationStep {
    if (animationStep == soundsOpenAnimStep) {
        [self.settingsView bringSubviewToFront:self.soundPicker];
    }
}

-(void)dragAnimationViewTapped:(DragAnimationView *)dragAnimationView atAnimationStep:(NSInteger)animationStep {
    if (animationStep == settingsClosedAnimStep) {
        NSLog(@"tap: open settings menu");
        [self openSettingsMenu];
        _previewOverlayDragView.hidden = NO;
    } else {
        NSLog(@"tap: close settings menu");
        [self closeSettingsMenu];
        _previewOverlayDragView.hidden = YES;
    }
}

-(void)dragAnimationView:(DragAnimationView *)dragAnimationView finishedAtAnimationStep:(NSInteger)animationStep {
    switch (animationStep) {
        case settingsClosedAnimStep:
            NSLog(@"settings closed");
            [self ensureClosedSettingsMenu];
            break;
        case settingsOpenAnimStep:
            NSLog(@"settings open");
            [self ensureOpenSettingsMenu];
            break;
        case soundsOpenAnimStep:
            NSLog(@"sounds open");
            [self ensureOpenSoundsMenu];
            break;
        case bluetoothOpenAnimStep:
            NSLog(@"bluetooth open");
            [self ensureOpenBluetoothMenu];
            break;
        default:
            break;
    }
    if (animationStep == settingsClosedAnimStep) {
        _previewOverlayDragView.hidden = YES;
    } else {
        _previewOverlayDragView.hidden = NO;
    }
}

-(CGFloat)dragAnimationDistanceForView:(DragAnimationView *)dragAnimationView animationStep:(NSInteger)step {
    switch (step) {
        case 0:
            return kSettingsViewHeight;
            break;
        case 1:
            return CGRectGetHeight(self.soundPicker.frame);
        case 2:
            return CGRectGetHeight(self.bluetoothMenu.frame) - CGRectGetHeight(self.soundPicker.frame);
        default:
            return 100;
            break;
    }
}

#pragma mark - Video Processor Delegate



-(void)hideCameraUI {
    [UIView animateWithDuration:0.5 animations:^{
        self.flashModeOnButton.alpha = 0;
        self.flashModeOffButton.alpha = 0;
        self.flashModeAutoButton.alpha = 0;
        self.pictureModeButton.alpha = 0;
        self.rapidShotModeButton.alpha = 0;
        self.videoModeButton.alpha = 0;
        self.modeSelectorBar.alpha = 0;
        self.swithCameraButton.alpha = 0;
        self.cameraRollImage.alpha = 0;
        self.cameraRollButton.alpha = 0;
        self.settingsButton.alpha = 0;
        _UITransparentBG.alpha = 0;
    } completion:^(BOOL finished) {
        self.settingsButtonDragView.userInteractionEnabled = NO;
        self.settingsButton.enabled = NO;
        self.currentFlashButton.enabled = NO;
    }];
}

-(void)showCameraUI {
    self.settingsButtonDragView.userInteractionEnabled = YES;
    self.settingsButton.enabled = YES;
    self.currentFlashButton.enabled = YES;
    [UIView animateWithDuration:0.5 animations:^{
        self.flashModeOnButton.alpha = 1;
        self.flashModeOffButton.alpha = 1;
        self.flashModeAutoButton.alpha = 1;
        self.pictureModeButton.alpha = 1;
        self.rapidShotModeButton.alpha = 1;
        self.videoModeButton.alpha = 1;
        self.modeSelectorBar.alpha = 1;
        self.swithCameraButton.alpha = 1;
        self.cameraRollImage.alpha = 1;
        self.cameraRollButton.alpha = 1;
        self.settingsButton.alpha = 1;
        _UITransparentBG.alpha = 1;
    } completion:nil];
}

-(void)recordingWillStart {
    
    [self.pictureModeButton setEnabled:NO];
    [self.rapidShotModeButton setEnabled:NO];
    [self.swithCameraButton setEnabled:NO];
    [self.cameraRollButton setEnabled:NO];
    self.swipeModesGestureIsBlocked = YES;
    if (!self.cameraButton.isAnimatingButton) {
        self.cameraButton.isDraggable = NO;
    }
    self.lockedOrientation = [[UIDevice currentDevice] orientation];
    [self hideCameraUI];
}



-(void)recordingWillStop {
    [self.pictureModeButton setEnabled:YES];
    [self.rapidShotModeButton setEnabled:YES];
    [self.swithCameraButton setEnabled:YES];
    [self.cameraRollButton setEnabled:YES];
    if (!self.cameraButton.isDragging) {
        self.swipeModesGestureIsBlocked = NO;
        [self.cameraButton updateCameraButtonWithText:@""];
    }
    self.cameraButton.isDraggable = YES;
    [self showCameraUI];
}

-(void)startRecordingTimer {
    self.recordingStart = [NSDate date];
    [self countRecordingTime:nil];
    self.recordingTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(countRecordingTime:) userInfo:nil repeats:YES];
}

-(void)stopRecordingTimer {
    [self.recordingTimer invalidate];
}


//- (void)didTakeStillImage:(UIImage *)image {
//    [self updateCameraRollButtonWithImage:image duration:0.35];
//    // updated gallery items in didFinishSavingStillImage instead
//    //    MHGalleryItem *item = [[MHGalleryItem alloc] initWithImage:image];
//    //    [self.galleryItems insertObject:item atIndex:0];
//}

-(void)didFinishSavingStillImage {
    
}


- (void)didTakeActionShot:(UIImage *)image number:(int)seriesNumber {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.cameraIsActionShooting) {
            [self.cameraButton updateCameraButtonWithText:@""];
            self.actionShotSequenceNumber = 0;
        } else {
            [self updateCameraRollButtonWithImage:image duration:0.2];
            self.actionShotSequenceNumber = seriesNumber;

            if (!self.cameraButton.isAnimatingButton) {
                [self.cameraButton updateCameraButtonWithText:[NSString stringWithFormat:@"%i", seriesNumber]];
            } else {
                //TODO: might not need this line below
                [self.cameraButton updateCameraButtonWithText:self.cameraButton.cameraButtonString];
            }

//            [UIView animateWithDuration:0.05 delay:0 options:UIViewAnimationOptionAllowAnimatedContent animations:^{
//                self.cameraButton.buttonImage.alpha = 0;
//            } completion:^(BOOL finished) {
//                [UIView animateWithDuration:0.05 animations:^{
//                    self.cameraButton.buttonImage.alpha = 1;
//                }];
//            }];
            
            // taken out because caused large memory over load problems
            //TODO: updated gallery items here instead
//            [self updateGalleryItems];
//            MHGalleryItem *item = [[MHGalleryItem alloc] initWithImage:image];
//            [self.galleryItems insertObject:item atIndex:0];
        }
    });
}

-(void)actionShotDidStart {
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [self.pictureModeButton setEnabled:NO];
        [self.videoModeButton setEnabled:NO];
        [self.swithCameraButton setEnabled:NO];
        [self.cameraRollButton setEnabled:NO];
//        [self.settingsButton setEnabled:NO];
        self.swipeModesGestureIsBlocked = YES;
        self.cameraButton.isDraggable = NO;
        //TODO: set camera flash modes
        //        [self.videoProcessor setTorchMode:[self currentAVTorchMode]];
//        [self.videoProcessor setFlashMode:AVCaptureFlashModeOff];
        [self hideCameraUI];
    });
}

-(void)actionShotDidStop {
    dispatch_async(dispatch_get_main_queue(), ^{
        
        self.cameraButton.isDraggable = YES;
        [self.pictureModeButton setEnabled:YES];
        [self.videoModeButton setEnabled:YES];
        [self.swithCameraButton setEnabled:YES];
        [self.cameraRollButton setEnabled:YES];
//        [self.settingsButton setEnabled:YES];
        if (!self.cameraButton.isDragging) {
            self.swipeModesGestureIsBlocked = NO;
        }
        [self showCameraUI];
    });
}

-(void) willSwitchCamera {
    _settingsButton.enabled = NO;
    _settingsButtonDragView.userInteractionEnabled = NO;
    [UIView transitionWithView:self.blurredImagePlaceholder duration:0.5 options:UIViewAnimationOptionTransitionFlipFromLeft animations:nil completion:nil];
    [UIView transitionWithView:self.previewView duration:0.5 options:UIViewAnimationOptionTransitionFlipFromLeft animations:nil completion:^(BOOL finished){
        _previewView.alpha = 0;
        [UIView animateWithDuration:0.5 delay:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.blurredImagePlaceholder.alpha = 0;
            _previewView.alpha = 1;
            [self updateCameraPreviewPosition];
            [self updateTappablePreviewRectForCameraMode:self.cameraMode];
        } completion:^(BOOL finished) {
            _settingsButton.enabled = YES;
            _settingsButtonDragView.userInteractionEnabled = YES;
        }];
    }];
    
    UIImage *blurredImage = [_previewView.image blurredImageWithRadius:20 iterations:2 tint:[UIColor colorWithWhite:0.8 alpha:1]];

    if (self.cameraPosition == CSStateCameraPositionFront) { // means it was just CSStateCameraPositionBack
        _blurredImagePlaceholder.transform = CGAffineTransformMakeScale(1, 1);
    } else {
        _blurredImagePlaceholder.transform = CGAffineTransformMakeScale(-1, 1);
    }
    self.blurredImagePlaceholder.image = blurredImage;
    self.blurredImagePlaceholder.alpha = 1;
}



//-(void)readyToSwitchToCurrentOutputQuality:(UIImage *)image {
////    UIImage *blurredImage = [self.blurFilter imageByFilteringImage:image];
////    if (self.videoProcessor.captureDevice.position == AVCaptureDevicePositionFront) {
////        _blurredImagePlaceholder.transform = CGAffineTransformMakeScale(-1, 1);
////    } else {
//        _blurredImagePlaceholder.transform = CGAffineTransformMakeScale(1, 1);
////    }
//    self.blurredImagePlaceholder.image = image; //blurredImage
//    
//    _settingsButton.enabled = NO;
//    _settingsButtonDragView.userInteractionEnabled = NO;
//    [UIView animateWithDuration:0.5 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
//        self.blurredImagePlaceholder.alpha = 1;
//    } completion:^(BOOL finished) {
//        self.previewView.alpha = 0;
//        
//        //TODO: camera video processeor switchToCurrentOutputQuality
////        [self.videoProcessor switchToCurrentOutputQuality];
//        [UIView animateWithDuration:0.4 delay:1 options:UIViewAnimationOptionCurveEaseInOut animations:^{
//            self.blurredImagePlaceholder.alpha = 0;
//            self.previewView.alpha = 1;
//            [self updateCameraPreviewPosition];
//            [self updateTappablePreviewRectForCameraMode:self.cameraMode];
//            [self updateDragViewAnimations];
//        } completion:^(BOOL finished) {
//            _settingsButton.enabled = YES;
//            _settingsButtonDragView.userInteractionEnabled = YES;
//        }];
//    }];
//}


- (void)switchedToCameraDeviceThatHasFlash:(BOOL)hasFlash {
    _flashModeOnButton.enabled = hasFlash;
    _flashModeOffButton.enabled = hasFlash;
    _flashModeAutoButton.enabled = hasFlash;
}

-(void)updateGalleryItems {
    NSLog(@"updated gallery items");
    self.galleryItems = [NSMutableArray new];
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
        [group setAssetsFilter:[ALAssetsFilter allAssets]];
        [group enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:^(ALAsset *alAsset, NSUInteger index, BOOL *innerStop) {
            if (alAsset) {
                if ([[alAsset valueForProperty:@"ALAssetPropertyType"] isEqualToString:@"ALAssetTypePhoto"]) {
                    MHGalleryItem *item = [[MHGalleryItem alloc]initWithURL:[alAsset.defaultRepresentation.url absoluteString]
                                                                galleryType:MHGalleryTypeImage];
                    [self.galleryItems addObject:item];
                } else {
                    MHGalleryItem *item = [[MHGalleryItem alloc]initWithURL:[alAsset.defaultRepresentation.url absoluteString]
                                                                galleryType:MHGalleryTypeVideo];
                    [self.galleryItems addObject:item];
                }
            }
        }];
    } failureBlock: ^(NSError *error) {
        NSLog(@"ERROR in method updateGalleryItems in class CameraViewController =====> %@", error);
    }];
}

#pragma mark - Sound Picker Methods

-(NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

-(NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return 6;
}

-(NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    switch (row) {
        case 0:
            return @"No Sound";
            break;
        case 1:
            return @"Bomb Countdown";
            break;
        case 2:
            return @"Alien Ramp Up";
            break;
        case 3:
            return @"Cat Meow";
            break;
        case 4:
            return @"Bird Chirp";
            break;
        case 5:
            return @"Dog Bark";
            break;
        default:
            return @"No Sound";
            break;
    }
}

-(CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component {
    return 35;
}

-(void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    
    [self updateSoundPlayerWithSoundNumber:row];
    if (self.shouldPlaySound) {
        self.takePictureAfterSound = NO;
        [self.soundPlayer play];
    }
}

-(void)updateSoundPlayerWithSoundNumber:(NSInteger)number {
    self.shouldPlaySound = YES;
    self.cameraSound = number;
    [self updateCameraWithCurrentStateAndButtonAction:CSStateButtonActionNone];
    NSError *error;
    NSURL *soundURL = nil;
    switch (number) {
        case 0:
            self.shouldPlaySound = NO;
            [self.soundPlayer stop];
            break;
        case 1: {
            soundURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"bombCountdown" ofType:@"wav"]];
            break;
        }
        case 2: {
            soundURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"alienRampUp" ofType:@"wav"]];
            break;
        }
        case 3: {
            soundURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"catMeow" ofType:@"wav"]];
            break;
        }
        case 4: {
            soundURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"birdChirp" ofType:@"wav"]];
            break;
        }
        case 5: {
            soundURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"dogBark" ofType:@"wav"]];
            break;
        }
        default:
            self.shouldPlaySound = NO;
            [self.soundPlayer stop];
            break;
    }
    if (soundURL) {
        AVURLAsset* audioAsset = [AVURLAsset URLAssetWithURL:soundURL options:nil];
        CMTime audioDuration = audioAsset.duration;
        self.soundDuration = CMTimeGetSeconds(audioDuration);
        self.soundPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:soundURL error:&error];
    }
    if (number == 0) {
        [self.soundsButton setSelected:NO];
    } else {
        [self.soundsButton setSelected:YES];
    }
    if (self.soundsButton.selected) {
        self.soundsButton.layer.borderColor = _highlightColor.CGColor;
    } else {
        self.soundsButton.layer.borderColor = [UIColor colorWithWhite:0.642 alpha:1.000].CGColor;
    }
    self.soundPlayer.delegate = self;
    [self.soundPlayer prepareToPlay];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithInt:number] forKey:@"sound"];
}

#pragma  mark - Audio Player Delegate

-(void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    if (self.takePictureAfterSound) {
//        [self cameraAction];
        [self runStillImageCaptureAnimation];
        self.takePictureAfterSound = NO;
        [self.cameraButton updateCameraButtonWithText:@""]; // get rid of sound symbol in camera button
    }
}

#pragma  mark - Memory Warning
-(void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end
