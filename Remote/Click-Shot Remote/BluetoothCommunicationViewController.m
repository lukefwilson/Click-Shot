//
//  LWBluetoothTableViewController.m
//  Click-Shot
//
//  Created by Luke Wilson on 6/4/14.
//  Copyright (c) 2014 Luke Wilson. All rights reserved.
//

#import "BluetoothCommunicationViewController.h"
#import "TransferService.h"
#import "UIImage+ImageFromColor.h"
#import "CameraRemoteViewController.h"
@import AssetsLibrary;

#define CURRENTLY_RECEIVING_PHOTOS_MAX 4

@interface BluetoothCommunicationViewController ()  <MCSessionDelegate, MCNearbyServiceAdvertiserDelegate>

@property (strong, nonatomic) MCSession *mySession;
@property (strong, nonatomic) MCPeerID *myPeerID;
@property (strong, nonatomic) MCNearbyServiceAdvertiser *advertiser;
@property (strong, nonatomic) NSMutableArray *runningProgressArrays;
@property (weak, nonatomic) IBOutlet UILabel *connectedDeviceNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *connectedToLabel;
@property (weak, nonatomic) IBOutlet UILabel *notConnectedLabel;
@property (weak, nonatomic) IBOutlet UIButton *disconnectButton;
- (IBAction)tappedDisconnect:(UIButton *)sender;

@end

@implementation BluetoothCommunicationViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    _runningProgressArrays = [NSMutableArray array];
    
    _myPeerID = [[MCPeerID alloc] initWithDisplayName:[@"Click-Shot Remote: " stringByAppendingString:[UIDevice currentDevice].name]];
    _mySession = [[MCSession alloc] initWithPeer:_myPeerID];
    _mySession.delegate = self;
    _advertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:_myPeerID discoveryInfo:nil serviceType:MPC_SERVICE_TYPE];
    _advertiser.delegate = self;
    [_advertiser startAdvertisingPeer];
    NSLog(@"start advertising MPC");
    
    [_disconnectButton setBackgroundImage:[UIImage imageWithColor:[UIColor colorWithWhite:0.530 alpha:1.000]] forState:UIControlStateNormal];
}

// called when app reopens
-(void)reInitialize{
    _advertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:_myPeerID discoveryInfo:nil serviceType:MPC_SERVICE_TYPE];
    _advertiser.delegate = self;
    [_advertiser startAdvertisingPeer];
}

-(void)stopAdvertising {
    [_advertiser stopAdvertisingPeer];
}

-(void)startAdvertising{
    [_advertiser startAdvertisingPeer];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

#pragma mark -
#pragma mark MPC Delegates

-(void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didNotStartAdvertisingPeer:(NSError *)error {
    // Error occurred
    NSLog(@"Didn't start advertising peer with error: %@", error);
}

-(void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void (^)(BOOL, MCSession *))invitationHandler {
    if (_mainConnectedCameraPeerID && ![_mainConnectedCameraPeerID isEqual:peerID]) {
        NSLog(@"declined invitation because already connected");
        invitationHandler(NO, _mySession);
    } else {
        NSLog(@"received and accepted invitation");
        invitationHandler(YES, _mySession);
    }

}

-(void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
    switch (state) {
        case MCSessionStateNotConnected:
            NSLog(@"Session NOT Connected");
            if ([peerID isEqual:_mainConnectedCameraPeerID]) {
                [self disconnectFromMainCamera];
            }
            break;
        case MCSessionStateConnecting:
            NSLog(@"Session Connecting");
            break;
        case MCSessionStateConnected:
            NSLog(@"Session CONNECTED");
            if (!_mainConnectedCameraPeerID) {
                [self connectToCamera:peerID];
            }
            break;
            
        default:
            break;
    }
}

-(void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress {
    if ([_runningProgressArrays count] < CURRENTLY_RECEIVING_PHOTOS_MAX) {
        NSLog(@"started receiving: %@", resourceName);
        dispatch_async(dispatch_get_main_queue(), ^{
            NSArray *rings = [_delegate newReceivingPictureLoadingRings];
            
            NSArray *progressArray = @[progress, rings[0], rings[1], resourceName];
            [_runningProgressArrays addObject:progressArray];
            [progress addObserver:self forKeyPath:@"fractionCompleted" options:NSKeyValueObservingOptionNew context:NULL];
        });
    } else {
        NSLog(@"started receiving: %@ but CANCELLED it", resourceName);
        [progress cancel];
    }
}

-(void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error {
    for (int i =0; i < [_runningProgressArrays count]; i++) {
        NSArray *progressArray = _runningProgressArrays[i];
        NSString *string = progressArray[3];
        if ([string isEqualToString:resourceName]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self removeProgressArrayFromScreen:progressArray];
                [_runningProgressArrays removeObjectAtIndex:i];
            });
            break;
        }
    }
    if (error) {
        NSLog(@"error receiving: %@ \n error: %@", resourceName, error);
    } else {
        NSLog(@"finished receiving: %@", resourceName);
        NSData *imageData = [NSData dataWithContentsOfURL:localURL];
        UIImage *receivedImage = [UIImage imageWithData:imageData];
        
        UIImageWriteToSavedPhotosAlbum(receivedImage, self, @selector(finishedSavingImage:didFinishSavingWithError:contextInfo:), nil);
    }
    
}

-(void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    
    // deal with connection stuff here
    if (data.length == 1) {
        Byte byteBuffer;
        [data getBytes:&byteBuffer range:NSMakeRange(0, 1)];
        if (byteBuffer == CSCommunicationVirtuallyDisconnectedFromRemote) {
            if ([peerID isEqual:_mainConnectedCameraPeerID]) {
                [self disconnectFromMainCamera];
            }
        } else if (byteBuffer == CSCommunicationVirtuallyConnectedToRemote) {
            [self connectToCamera:peerID];
        }
    }
    
    // deal with everything else in CameraRemoteViewController
    if ([peerID isEqual:self.mainConnectedCameraPeerID]) {
        [_delegate receivedMessage:data fromPeer:peerID];
    }
}

-(void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID {
    
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    if ([keyPath isEqualToString:@"fractionCompleted"]) {
        for (int i = 0; i < [_runningProgressArrays count]; i++) {
            NSArray *progressArray = _runningProgressArrays[i];
            if ([progressArray[0] isEqual:object]) {
                NSNumber *value = [change objectForKey:NSKeyValueChangeNewKey];
//                NSLog(@"%@", value);
                CGFloat progressPercentage = [value floatValue];
                dispatch_async(dispatch_get_main_queue(), ^{
                    CAShapeLayer *ring = progressArray[1];
                    CAShapeLayer *outerRing = progressArray[2];
                    ring.strokeEnd = progressPercentage;
                    outerRing.strokeEnd = progressPercentage;
                });
            }
        }
    }
}

-(void)removeProgressArrayFromScreen:(NSArray *)progressArray {
    NSProgress *progress = progressArray[0];
    [progress cancel];
    @try {
        [progress removeObserver:self forKeyPath:@"fractionCompleted"];
    }
    @catch (NSException * __unused exception) {}
    
    CAShapeLayer *ring = progressArray[1];
    CAShapeLayer *outerRing = progressArray[2];
    [CATransaction begin];
    [CATransaction setCompletionBlock:^{
        [ring removeFromSuperlayer];
        [outerRing removeFromSuperlayer];
    }];
    ring.opacity = 0;
    outerRing.opacity = 0;
    CABasicAnimation *ringAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    ringAnimation.fromValue = [NSNumber numberWithFloat:1.0f];
    ringAnimation.toValue = [NSNumber numberWithFloat:0.0f];
    ringAnimation.duration = 0.35;
    ringAnimation.repeatCount = 1;
    [ring addAnimation:ringAnimation forKey:@"opacityAnimation"];
    [outerRing addAnimation:ringAnimation forKey:@"opacityAnimation"];
    [CATransaction commit];
}

-(void)removeAllRunningProgressArrays {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (int i = 0; i < [_runningProgressArrays count]; i++) {
            NSArray *progressArray = _runningProgressArrays[i];
            [self removeProgressArrayFromScreen:progressArray];
            [_runningProgressArrays removeObjectAtIndex:i];
            i--;
        }
    });
}

-(void)disconnectFromMainCamera {
    _mainConnectedCameraPeerID = nil;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        _connectedToLabel.hidden = YES;
        [_connectedDeviceNameLabel setText:@""];
        _disconnectButton.hidden = YES;
        _notConnectedLabel.hidden = NO;
    });
    
    [_delegate didDisconnectFromCamera];
    [self removeAllRunningProgressArrays];
    [_advertiser startAdvertisingPeer];
}

-(void)connectToCamera:(MCPeerID *)peerID {
    [self removeAllRunningProgressArrays]; // in case was connected and receiving files
    _mainConnectedCameraPeerID = peerID;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        _connectedToLabel.hidden = NO;
        [_connectedDeviceNameLabel setText:peerID.displayName];
        _disconnectButton.hidden = NO;
        _notConnectedLabel.hidden = YES;
    });
    
    [self switchedPreviewImages:self.shouldSendPreviewImagesSwitch]; // send preview image setting
    [self switchedReceivePictures:self.receivePicturesSwitch];

    [_delegate didConnectToCamera];
    [_advertiser stopAdvertisingPeer];
}

// called after didFinishReceivingResourceWithName finished saving image to camera roll
- (void) finishedSavingImage: (UIImage *) image didFinishSavingWithError: (NSError *) error contextInfo: (void *) contextInfo {
    if (error) {
        NSLog(@"error in saving image to camera roll: %@", error);
    } else {
        NSLog(@"successfully saved received image to camera roll");
        [_delegate finishedSavingReceivedImageToCameraRoll:image];
    }
}

#pragma mark -
#pragma mark MPC Sending Data

-(void)sendMessageToAllCameras:(NSData *)message {
    if (_mainConnectedCameraPeerID) {
        NSError *error = nil;
        BOOL didSend = [_mySession sendData:message toPeers:@[_mainConnectedCameraPeerID] withMode:MCSessionSendDataReliable error:&error];
        if (!didSend) {
            NSLog(@"failed sending message: %@\n with error: %@", message, error);
        } else {
            NSLog(@"Sent to all Cameras: %@", message);
        }
    }
}

// same function as above, use when you want to handle more than one attatched camera
-(void)sendMessageToMainCamera:(NSData *)message {
    if (_mainConnectedCameraPeerID) {
        NSError *error = nil;
        BOOL didSend = [_mySession sendData:message toPeers:@[_mainConnectedCameraPeerID] withMode:MCSessionSendDataReliable error:&error];
        if (!didSend) {
            NSLog(@"failed sending message: %@\n with error: %@", message, error);
        } else {
            NSLog(@"Sent to Camera: %@", message);
        }
    }
}

- (IBAction)switchedPreviewImages:(UISwitch *)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (sender.on) {
        const Byte messageBytes[1] = { CSCommunicationShouldSendPreviewImages};
        NSData *dataToSend = [NSData dataWithBytes:messageBytes length:sizeof(messageBytes)];
        [self sendMessageToAllCameras:dataToSend];
        [defaults setObject:@YES forKey:@"shouldSendPreviewImages"];
    } else {
        const Byte messageBytes[1] = { CSCommunicationShouldNotSendPreviewImages};
        NSData *dataToSend = [NSData dataWithBytes:messageBytes length:sizeof(messageBytes)];
        [self sendMessageToAllCameras:dataToSend];
        [defaults setObject:@NO forKey:@"shouldSendPreviewImages"];
    }
    [defaults synchronize];
    [_delegate changedShouldReceivePreviewImages:sender.on];

}

- (IBAction)switchedReceivePictures:(UISwitch *)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (sender.on) {
        const Byte messageBytes[1] = { CSCommunicationShouldSendTakenPictures};
        NSData *dataToSend = [NSData dataWithBytes:messageBytes length:sizeof(messageBytes)];
        [self sendMessageToAllCameras:dataToSend];
        [defaults setObject:@YES forKey:@"shouldSendTakenPictures"];
    } else {
        const Byte messageBytes[1] = { CSCommunicationShouldNotSendTakenPictures};
        NSData *dataToSend = [NSData dataWithBytes:messageBytes length:sizeof(messageBytes)];
        [self sendMessageToAllCameras:dataToSend];
        [defaults setObject:@NO forKey:@"shouldSendTakenPictures"];
    }
    [defaults synchronize];
}

- (IBAction)tappedDisconnect:(UIButton *)sender {
    const Byte messageBytes[1] = { CSCommunicationVirtuallyDisconnectedFromRemote};
    NSData *dataToSend = [NSData dataWithBytes:messageBytes length:sizeof(messageBytes)];
    [self sendMessageToAllCameras:dataToSend];
    [self disconnectFromMainCamera];
}


@end
