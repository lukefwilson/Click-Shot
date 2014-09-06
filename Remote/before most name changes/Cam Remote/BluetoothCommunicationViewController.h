//
//  LWBluetoothTableViewController.h
//  Click-Shot
//
//  Created by Luke Wilson on 6/4/14.
//  Copyright (c) 2014 Luke Wilson. All rights reserved.
//

#import <UIKit/UIKit.h>
@import MultipeerConnectivity;


@protocol BluetoothCommunicationDelegate;

@interface BluetoothCommunicationViewController : UIViewController

@property (nonatomic, weak) id <BluetoothCommunicationDelegate> delegate;
@property (strong, nonatomic) MCPeerID *mainConnectedCameraPeerID;
@property (weak, nonatomic) IBOutlet UISwitch *shouldSendPreviewImagesSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *receivePicturesSwitch;

-(void)sendMessageToMainCamera:(NSData *)message;
-(void)sendMessageToAllCameras:(NSData *)message;
-(void)disconnectFromMainCamera;
-(void)connectToCamera:(MCPeerID *)peerID;
-(void)reInitialize; // called when app reopens
-(void)stopAdvertising; // called when app closes
- (IBAction)switchedPreviewImages:(UISwitch *)sender;
- (IBAction)switchedReceivePictures:(UISwitch *)sender;

@end


@protocol BluetoothCommunicationDelegate <NSObject>

//-(NSData *)currentStateData;
-(void)receivedMessage:(NSData *)message fromPeer:(MCPeerID *)peer;
-(void)didConnectToCamera;
-(void)didDisconnectFromCamera;
-(void)finishedSavingReceivedImageToCameraRoll:(UIImage *)image;
-(NSArray *)newReceivingPictureLoadingRings;
-(void)changedShouldReceivePreviewImages:(BOOL)shouldReceivePreviewImages;
@end

