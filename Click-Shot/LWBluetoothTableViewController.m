//
//  LWBluetoothTableViewController.m
//  Click-Shot
//
//  Created by Luke Wilson on 6/4/14.
//  Copyright (c) 2014 Luke Wilson. All rights reserved.
//

#import "LWBluetoothTableViewController.h"
#import "TransferService.h"

#define BTTN_SERVICE_UUID           @"fffffff0-00f7-4000-b000-000000000000"
#define BTTN_DETECTION_CHARACTERISTIC_UUID    @"fffffff2-00f7-4000-b000-000000000000"
#define BTTN_NOTIFICATION_CHARACTERISTIC_UUID    @"fffffff4-00f7-4000-b000-000000000000"
#define BTTN_VERIFICATION_CHARACTERISTIC_UUID    @"fffffff5-00f7-4000-b000-000000000000"
#define BTTN_VERIFICATION_KEY    @"BC:F5:AC:48:40" // old key (new key hard coded in below)

#define kTableHeaderHeight 100
#define kRowHeight 60

@interface LWBluetoothTableViewController ()

@property (nonatomic) NSInteger failCount;
@property (nonatomic) MCPeerID *myPeerID;
@property (nonatomic) MCSession *mySession;
@property (nonatomic) MCNearbyServiceBrowser *browser;
@end

@implementation LWBluetoothTableViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
     self.clearsSelectionOnViewWillAppear = NO;
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    _discoveredPeripherals = [NSMutableArray array];
    _discoveredPeers = [NSMutableArray array];

    _failCount = 0;
    _fullyConnectedToPeer = NO;
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, kTableHeaderHeight)];
    headerView.backgroundColor = [UIColor clearColor];
    
    
    UIImageView *divider = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"tableViewDivider.png"]];
    divider.frame = CGRectMake(0, kTableHeaderHeight-divider.frame.size.height, self.view.frame.size.width, divider.frame.size.height);
    [headerView addSubview:divider];
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 40, headerView.frame.size.width-40, 40)];
    label.text = @"Connect to a campatible Bluetooth Device to control the camera";
    label.textColor = [UIColor colorWithRed:0.639 green:0.910 blue:0.980 alpha:1.000];
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont systemFontOfSize:16];
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.numberOfLines = 0;
    [headerView addSubview:label];
    
    self.tableView.tableHeaderView = headerView;

    self.betterRefreshControl = [[ODRefreshControl alloc] initInScrollView:self.tableView];
    [self.betterRefreshControl addTarget:self action:@selector(refreshBluetoothDevices) forControlEvents:UIControlEventValueChanged];
    [self.betterRefreshControl setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [self.betterRefreshControl setTintColor:[UIColor colorWithRed:0.651 green:0.929 blue:1.000 alpha:1.000]];
    
    //MPC
    _myPeerID = [[MCPeerID alloc] initWithDisplayName:@"Click-Shot"];
    _mySession = [[MCSession alloc] initWithPeer:_myPeerID];
    [_mySession setDelegate:self];
    _browser = [[MCNearbyServiceBrowser alloc] initWithPeer:_myPeerID serviceType:MPC_SERVICE_TYPE];
    [_browser setDelegate:self];
    [_browser startBrowsingForPeers];
    NSLog(@"start MCP Scanning");
    // BTLE Central starts scanning once turned on (done in callback changeState)
    
    self.scanTimer = [NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(timedStopScanning:) userInfo:nil repeats:YES];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)refreshBluetoothDevices {

    [self startScanningForButton];
    [_browser startBrowsingForPeers];
    if (self.scanTimer) [self.scanTimer invalidate];
    self.scanTimer = [NSTimer scheduledTimerWithTimeInterval:40 target:self selector:@selector(timedStopScanning:) userInfo:nil repeats:YES];
    NSLog(@"started All scanning");

    self.hideRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:3 target:self selector:@selector(timedHideRefresh:) userInfo:nil repeats:NO];
}

-(void)timedHideRefresh:(NSTimer *)timer {
    [self.betterRefreshControl endRefreshing];
    [timer invalidate];
    [self.tableView reloadData];
}

-(void)timedStopScanning:(NSTimer *)timer {
    NSLog(@"All Scanning stopped");
    [self.centralManager stopScan];
    [_browser stopBrowsingForPeers];
    [timer invalidate];
    self.scanTimer = nil;
    [self.tableView reloadData];
}

#pragma mark - MPC Delegates

-(void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary *)info {
    NSLog(@"found peer %@", peerID);
    if (![_discoveredPeers containsObject:peerID]) {
        [_discoveredPeers addObject:peerID];
        [self.tableView reloadData];
    }
}

-(void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID {
    NSLog(@"lost peer %@", peerID);
    [_discoveredPeers removeObject:peerID];
    [self.tableView reloadData];
}

-(void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
    switch (state) {
        case MCSessionStateConnected:
            NSLog(@"Connected to peer: %@", peerID);
            if ([peerID isEqual:_connectedPeer]) {
                [self setSelectedCell:[self.tableView cellForRowAtIndexPath:_selectedIndexPath] atIndexPath:_selectedIndexPath isFullyConnected:YES];
                _fullyConnectedToPeer = YES;
                [_delegate connectedToBluetoothDevice];
                [self updateRemoteWithCurrentCameraState];
            }
            break;
        case MCSessionStateConnecting:
            NSLog(@"connecting to peer: %@", peerID);
            break;
        case MCSessionStateNotConnected:
            NSLog(@"NOT Connected to peer: %@", peerID);
            if ([peerID isEqual:_connectedPeer]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    UITableViewCell *prevCell = [self.tableView cellForRowAtIndexPath:_selectedIndexPath];
                    [prevCell setSelected:NO animated:YES];
                    prevCell.accessoryType = UITableViewCellAccessoryNone;
                    prevCell.accessoryView = nil;
                    _connectedPeer = nil;
                    _fullyConnectedToPeer = NO;
                    _selectedIndexPath = nil;
                    [_delegate disconnectedFromBluetoothDevice];
                });
            }
            break;
    }
}

-(void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress {
    
}

-(void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error {
    
}

-(void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    if ([peerID isEqual:_connectedPeer]) {
        [_delegate receivedMessageFromCameraRemoteApp:data];
    }
}

-(void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID {
    
}

#pragma mark - MPC Sending Data


-(void)updateRemoteWithCurrentCameraState {
    if (_connectedPeer && _fullyConnectedToPeer) {
        NSData *currentStateData = [_delegate currentStateData];
        if ( currentStateData.length != 1) {
            NSError *error = nil;
            if (![_mySession sendData:currentStateData toPeers:@[_connectedPeer] withMode:MCSessionSendDataReliable error:&error]) {
                NSLog(@"failed sending data: %@\n with error: %@", currentStateData, error);
            } else {
                NSLog(@"Sent to remote: %@", currentStateData);
            }
        }
    }
}

-(void)sendImageDataToRemote:(NSData *)imageData {
    if (_connectedPeer && _fullyConnectedToPeer) {
            NSError *error = nil;
            if (![_mySession sendData:imageData toPeers:@[_connectedPeer] withMode:MCSessionSendDataUnreliable error:&error]) {
                NSLog(@"failed sending image with error: %@", error);
            } else {
                NSLog(@"Sent preview image to remote with size: %lu", (unsigned long)imageData.length);
            }
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    if (section == 0) {
        return [_discoveredPeers count];
    } else {
        return [self.discoveredPeripherals count];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    
    cell.backgroundColor = [UIColor clearColor];
    
    cell.textLabel.backgroundColor = [UIColor clearColor];
    
    UIImageView *divider = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"tableViewDivider.png"]];
    divider.frame = CGRectMake(15, kRowHeight-divider.frame.size.height, self.view.frame.size.width-30, divider.frame.size.height);
    [cell addSubview:divider];
    
    UIView *selectedView = [[UIView alloc] initWithFrame:cell.frame];
    selectedView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
    cell.selectedBackgroundView = selectedView;
    
    cell.tintColor = [UIColor whiteColor]; // for the checkmark when selected
    
    if (indexPath.section == 0) {
        MCPeerID *peerID = [self.discoveredPeers objectAtIndex:indexPath.row];
        cell.textLabel.textColor = [UIColor colorWithRed:0.747 green:0.636 blue:0.999 alpha:1.000];
        cell.textLabel.text = peerID.displayName;
        
        if ([_mySession.connectedPeers containsObject:peerID]) {
            _selectedIndexPath = indexPath;
            [self setSelectedCell:cell atIndexPath:indexPath isFullyConnected:YES];
            [self.tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        
    } else {
        CBPeripheral *peripheral = [self.discoveredPeripherals objectAtIndex:indexPath.row];
        
        cell.textLabel.text = peripheral.name;
        cell.textLabel.textColor = [UIColor colorWithRed:0.639 green:0.910 blue:0.980 alpha:1.000];
        
        if ([peripheral isEqual:_connectedPeripheral]) {
            _selectedIndexPath = indexPath;
            [self setSelectedCell:cell atIndexPath:indexPath isFullyConnected:YES];
            [self.tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }
    
    return cell;
}

#pragma mark - Table view delegate

-(CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return kRowHeight;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        MCPeerID *selectedPeerID = [self.discoveredPeers objectAtIndex:indexPath.row];
        if ([selectedPeerID isEqual:_connectedPeer]) {
            UITableViewCell *prevCell = [self.tableView cellForRowAtIndexPath:_selectedIndexPath];
            dispatch_async(dispatch_get_main_queue(), ^{
                [prevCell setSelected:NO animated:YES];
                prevCell.accessoryType = UITableViewCellAccessoryNone;
                prevCell.accessoryView = nil;
                [_delegate disconnectedFromBluetoothDevice];
            });
            _connectedPeer = nil;
            _fullyConnectedToPeer = NO;
            _selectedIndexPath = nil;
        } else {
            if (![[_mySession connectedPeers] containsObject:selectedPeerID]) {
                NSLog(@"inviting peer: %@", selectedPeerID);
                [_browser invitePeer:selectedPeerID toSession:_mySession withContext:nil timeout:20.0];
                UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
                _fullyConnectedToPeer = NO;
                [self setSelectedCell:cell atIndexPath:indexPath isFullyConnected:NO];
            } else {
                UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
                [self setSelectedCell:cell atIndexPath:indexPath isFullyConnected:YES];
                _fullyConnectedToPeer = YES;
            }
            _connectedPeer = selectedPeerID;
            if (_connectedPeripheral) {
                [_centralManager cancelPeripheralConnection:_connectedPeripheral];
                _connectedPeripheral = nil;
            }
        }
    } else {
        CBPeripheral *selectedPeripheral = [self.discoveredPeripherals objectAtIndex:indexPath.row];
        
        UITableViewCell *prevCell = [self.tableView cellForRowAtIndexPath:_selectedIndexPath];
        dispatch_async(dispatch_get_main_queue(), ^{
            [prevCell setSelected:NO animated:YES];
            prevCell.accessoryType = UITableViewCellAccessoryNone;
            prevCell.accessoryView = nil;
        });
        
        
        if ([_connectedPeripheral isEqual:selectedPeripheral]) {
            [self.centralManager cancelPeripheralConnection:_connectedPeripheral];
            _connectedPeripheral = nil;
            _selectedIndexPath = nil;
            [_delegate disconnectedFromBluetoothDevice];

        } else {
            if (_connectedPeripheral) {
                [self.centralManager cancelPeripheralConnection:_connectedPeripheral];
            }
            [_centralManager connectPeripheral:selectedPeripheral options:nil];
            _connectedPeer = nil;
            _fullyConnectedToPeer = NO;
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
            [self setSelectedCell:cell atIndexPath:indexPath isFullyConnected:NO];
        }
    }
}


-(void)setSelectedCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath isFullyConnected:(BOOL)fullyConnected {
    dispatch_async(dispatch_get_main_queue(), ^{
        
        UITableViewCell *prevCell = [self.tableView cellForRowAtIndexPath:_selectedIndexPath];
        if (![prevCell isEqual:cell]) {
            [prevCell setSelected:NO animated:YES];
            prevCell.accessoryType = UITableViewCellAccessoryNone;
            prevCell.accessoryView = nil;
        }
        [cell setSelected:YES animated:YES];
        
        _selectedIndexPath = indexPath;
        
        if (fullyConnected) {
            UIActivityIndicatorView *act = (UIActivityIndicatorView *)cell.accessoryView;
            [act stopAnimating];
            cell.accessoryView = nil;
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else { // in progress
            UIActivityIndicatorView *act = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
            act.hidesWhenStopped = YES;
            [act startAnimating];
            cell.accessoryView = act;
        }
    });
}

#pragma mark -
#pragma mark Bluetooth Delegates

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    // Determine the state of the central manager
    if ([central state] == CBCentralManagerStatePoweredOff) {
        NSLog(@"CoreBluetooth BLE hardware is powered off");
    }
    else if ([central state] == CBCentralManagerStatePoweredOn) {
        NSLog(@"CoreBluetooth BLE hardware is powered on and ready");
        // Scan for devices
        [self startScanningForButton];
    }
    else if ([central state] == CBCentralManagerStateUnauthorized) {
        NSLog(@"CoreBluetooth BLE state is unauthorized");
    }
    else if ([central state] == CBCentralManagerStateUnknown) {
        NSLog(@"CoreBluetooth BLE state is unknown");
    }
    else if ([central state] == CBCentralManagerStateUnsupported) {
        NSLog(@"CoreBluetooth BLE hardware is unsupported on this platform");
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    
    NSLog(@"Discovered %@ at %@", peripheral.name, RSSI);
    
    if (![_discoveredPeripherals containsObject:peripheral]) {
        [self.discoveredPeripherals addObject:peripheral];
        [self.tableView reloadData];
    }

//    if (!_connectedPeripheral && ([peripheral.name rangeOfString:@"V.BTTN"].location != NSNotFound || [peripheral.name rangeOfString:@"V.ALRT"].location != NSNotFound)) {
//        // Auto connect to first V.ALRT or V.BTTN
//        NSIndexPath *selectedPath = [NSIndexPath indexPathForRow:[self.discoveredPeripherals indexOfObject:peripheral] inSection:0];
//        NSLog(@"Auto Connecting to peripheral %@", peripheral);
//        [self.tableView reloadData];
//        [self tableView:self.tableView didSelectRowAtIndexPath:selectedPath];
//    }

}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"Failed to connect to %@", peripheral.name);
    CBPeripheral *selectedPeripheral = [self.discoveredPeripherals objectAtIndex:self.selectedIndexPath.row];
    if ([selectedPeripheral isEqual:peripheral]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:_selectedIndexPath];
            UIActivityIndicatorView *act = (UIActivityIndicatorView *)cell.accessoryView;
            [act stopAnimating];
            cell.accessoryView = nil;
            [cell setSelected:NO animated:YES];
            cell.accessoryType = UITableViewCellAccessoryNone;
        });

        //TODO: display HUD with error
    }
    [self cleanupBluetooth];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"Connected to %@", peripheral.name);
    
    CBPeripheral *selectedPeripheral = [self.discoveredPeripherals objectAtIndex:self.selectedIndexPath.row];
    if ([selectedPeripheral isEqual:peripheral]) {
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:_selectedIndexPath];
        [self setSelectedCell:cell atIndexPath:_selectedIndexPath isFullyConnected:YES];
        peripheral.delegate = self;
        [peripheral discoverServices:@[[CBUUID UUIDWithString:BTTN_SERVICE_UUID],[CBUUID UUIDWithString:REMOTE_APP_TRANSFER_SERVICE_UUID]]];
        _connectedPeripheral = selectedPeripheral;
        [_delegate connectedToBluetoothDevice];
    } else {
        [_centralManager cancelPeripheralConnection:peripheral];
    }
    
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (error) {
        [self cleanupBluetooth];
        return;
    }
    
    for (CBService *service in peripheral.services) {
        NSLog(@"found service: %@", service);
        if ([service.UUID.UUIDString isEqualToString:REMOTE_APP_TRANSFER_SERVICE_UUID]) {
            [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:CAMERA_TO_REMOTE_CHARACTERISTIC_UUID], [CBUUID UUIDWithString:REMOTE_TO_CAMERA_CHARACTERISTIC_UUID]] forService:service];
        } else { // is V.BTTN?
            [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:BTTN_NOTIFICATION_CHARACTERISTIC_UUID], [CBUUID UUIDWithString:BTTN_VERIFICATION_CHARACTERISTIC_UUID], [CBUUID UUIDWithString:BTTN_DETECTION_CHARACTERISTIC_UUID]] forService:service];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        [self cleanupBluetooth];
        return;
    }
    NSLog(@"Found Characteristics %@ on peripheral %@", service.characteristics, peripheral.name);

    // Set up characteristic connections with button
    for (CBCharacteristic *characteristic in service.characteristics) {
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:BTTN_NOTIFICATION_CHARACTERISTIC_UUID]]) { // Set up to receive notifications when button is pressed or released
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            NSLog(@"NOTIFICATION characteristic: %@", characteristic);
        } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:BTTN_VERIFICATION_CHARACTERISTIC_UUID]]) { // Create long lasting connection
//            const Byte identifierBytes[5] = { 0xBC, 0xF5, 0xAC, 0x48, 0x40 }; old verification code
            const Byte identifierBytes[5] = { 0x80, 0xBE, 0xF5, 0xAC, 0xFF };
            NSMutableData *data = [[NSMutableData alloc] initWithBytes:identifierBytes length:5];
            [peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
            NSLog(@"Created long lasting communication with button by sending verification key");
        } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:BTTN_DETECTION_CHARACTERISTIC_UUID]]) { // Set peripheral up to detect button pressed
            const Byte identifierByte[1] = { 0x01 };
            NSMutableData *data = [[NSMutableData alloc] initWithBytes:identifierByte length:1];
            [peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
        } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:CAMERA_TO_REMOTE_CHARACTERISTIC_UUID]]) {
            [self updateRemoteWithCurrentCameraState];
        } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:REMOTE_TO_CAMERA_CHARACTERISTIC_UUID]]) {
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            NSLog(@"NOTIFICATION characteristic: %@", characteristic);
        }
        
        
    }
}

//-(void)updateRemoteWithCurrentCameraState {
//    for (CBService *service in _connectedPeripheral.services) {
//        if ([service.UUID.UUIDString isEqualToString:REMOTE_APP_TRANSFER_SERVICE_UUID]) {
//            for (CBCharacteristic *characteristic in service.characteristics) {
//                if ([characteristic.UUID.UUIDString isEqualToString:CAMERA_TO_REMOTE_CHARACTERISTIC_UUID]) {
//                    NSData *currentStateData = [_delegate currentStateData];
//                    if (currentStateData.length != 1) {
//                        NSLog(@"Sent to remote: %@", currentStateData);
//                        [_connectedPeripheral writeValue:currentStateData forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
//                    }
//                }
//            }
//        }
//    }
//}

//-(void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
//    //TODO: used to notify the camera when the remote successfully received the info
//    if (error) {
//        _failCount++;
//        NSLog(@"FAIL: peripheral didn't receive camera message: %@ with error: %@", characteristic.value, error);
//        if (_failCount <= 3) {
//            [self updateRemoteWithCurrentCameraState];
//        } else {
//            NSLog(@"FAILED 3 times in a row, giving up");
//        }
//    } else {
//        _failCount = 0;
////        NSLog(@"SUCCESS: peripheral did receive camera message: %@", characteristic.value);
//    }
//    
//}

//TODO: info from BTLE device to camera
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Error didUpdateValueForCharacteristic:");
        return;
    }
    if ([characteristic.value length] == 1) { // V.BTTN
        const Byte identifierByte[1] = { 0x01 };
        NSMutableData *buttonDownData = [[NSMutableData alloc] initWithBytes:identifierByte length:1];
        if ([characteristic.value isEqualToData:buttonDownData]) {
            [_delegate bluetoothButtonPressed];
        }
    }/* else { // Camera Remote App
        [_delegate receivedMessageFromCameraRemoteApp:characteristic.value];
    }*/
    
//    NSLog(@"peripheral did update characteristic value: %@", characteristic.value);
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    
    if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:BTTN_NOTIFICATION_CHARACTERISTIC_UUID]]) return; // only care about button stuff
    
    if (characteristic.isNotifying) {
        NSLog(@"Notification began on %@", characteristic);
    } else {
        // Button notification has stopped
        [_centralManager cancelPeripheralConnection:peripheral];
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"Did disconnect from %@", peripheral.name);

    if ([peripheral isEqual:_connectedPeripheral]) {

        _connectedPeripheral = nil;
        _selectedIndexPath = nil;
        [_delegate disconnectedFromBluetoothDevice];
        [self.tableView reloadData];
    }
}

-(void)startScanningForButton {
    [_centralManager scanForPeripheralsWithServices:nil options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @NO }];
    NSLog(@"started BTLE scanning");
}

- (void)cleanupBluetooth {
    if (_connectedPeripheral) {
        // See if we are subscribed to a characteristic on the peripheral
        if (_connectedPeripheral.services != nil) {
            for (CBService *service in _connectedPeripheral.services) {
                if (service.characteristics != nil) {
                    for (CBCharacteristic *characteristic in service.characteristics) {
                        if (characteristic.isNotifying) {
                            [_connectedPeripheral setNotifyValue:NO forCharacteristic:characteristic];
                            return;
                        }
                    }
                }
            }
        }
        
        [_centralManager cancelPeripheralConnection:_connectedPeripheral];
        _connectedPeripheral = nil;
        _selectedIndexPath = nil;
        [self.tableView reloadData];
    }
}


@end
