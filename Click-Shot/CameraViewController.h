//
//  CameraViewController.h
//  Remote Shot
//
//  Created by Luke Wilson on 3/18/14.
//  Copyright (c) 2014 Luke Wilson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "VideoProcessor.h"
#import "LWBluetoothTableViewController.h"
#import "CameraButton.h"


@interface CameraViewController : UIViewController <LWBluetoothButtonDelegate>

-(void)pressedCameraButton;
-(void)setCameraButtonText:(NSString *)text withOffset:(CGPoint)offset fontSize:(float)fontSize;
-(UIImage *) currentCameraButtonImage;
-(UIImage *) currentHighlightedCameraButtonImage;
-(AVCaptureTorchMode) currentAVTorchMode;
-(AVCaptureFlashMode) currentAVFlashMode;
-(CGPoint) devicePointForScreenPoint:(CGPoint)screenPoint;

-(void)resumeSessions;
-(void)pauseSessions;

-(void)openFlashModeMenu;
-(void)closeFlashModeMenu:(id)sender;
-(void)openSettingsMenu;
-(void)closeSettingsMenu;

-(void)openTutorial;
-(void)closeTutorial;

@property (nonatomic) BOOL autoFocusMode;
@property (nonatomic) BOOL autoExposureMode;
@property (nonatomic) BOOL gestureIsBlocked;
@property (nonatomic) NSInteger cameraMode;
@property (nonatomic, strong) NSString *cameraButtonString;
@property (nonatomic) CGRect tappablePreviewRect; // used in MoveableImageView

@property (nonatomic, weak) IBOutlet UIButton *pictureModeButton;
@property (nonatomic, weak) IBOutlet UIButton *rapidShotModeButton;
@property (nonatomic, weak) IBOutlet UIButton *videoModeButton;
@property (nonatomic, weak) IBOutlet UIButton *cameraRollButton;

@property (nonatomic, weak) IBOutlet UIButton *flashModeAutoButton;
@property (nonatomic, weak) IBOutlet UIButton *flashModeOnButton;
@property (nonatomic, weak) IBOutlet UIButton *flashModeOffButton;

@property (nonatomic, weak) IBOutlet UIButton *swithCameraButton;
@property (nonatomic, weak) IBOutlet UIButton *settingsButton;

@property (nonatomic, weak) IBOutlet UIButton *focusButton;
@property (nonatomic, weak) IBOutlet UIButton *exposureButton;
@property (nonatomic, weak) IBOutlet UIButton *soundsButton;
@property (nonatomic, weak) IBOutlet UIButton *bluetoothButton;

@property (nonatomic, weak) IBOutlet CameraButton *cameraButton;

@property (nonatomic) BOOL settingsMenuIsOpen;
@property (nonatomic) BOOL soundsMenuIsOpen;
@property (nonatomic) BOOL bluetoothMenuIsOpen;
@property (nonatomic) BOOL cameraRollIsOpen;
@property (nonatomic) BOOL tutorialIsOpen;

@property (nonatomic) VideoProcessor *videoProcessor;

@end
