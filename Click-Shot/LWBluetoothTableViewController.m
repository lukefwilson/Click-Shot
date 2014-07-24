//
//  LWBluetoothTableViewController.m
//  Click-Shot
//
//  Created by Luke Wilson on 6/4/14.
//  Copyright (c) 2014 Luke Wilson. All rights reserved.
//

#import "LWBluetoothTableViewController.h"

#define BTTN_SERVICE_UUID           @"fffffff0-00f7-4000-b000-000000000000"
#define BTTN_DETECTION_CHARACTERISTIC_UUID    @"fffffff2-00f7-4000-b000-000000000000"
#define BTTN_NOTIFICATION_CHARACTERISTIC_UUID    @"fffffff4-00f7-4000-b000-000000000000"
#define BTTN_VERIFICATION_CHARACTERISTIC_UUID    @"fffffff5-00f7-4000-b000-000000000000"
#define BTTN_VERIFICATION_KEY    @"BC:F5:AC:48:40" // old key (new key hard coded in below)

#define kTableHeaderHeight 100
#define kRowHeight 60

@interface LWBluetoothTableViewController ()

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
    self.discoveredPeripherals = [NSMutableArray array];
    if (_centralManager.state == CBCentralManagerStatePoweredOn) [self startScanningForButton];

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
    
//    self.refreshControl = [[UIRefreshControl alloc] init];
//    self.refreshControl.tintColor = [UIColor whiteColor];
//    [self.refreshControl addTarget:self action:@selector(refreshBluetoothDevices) forControlEvents:UIControlEventValueChanged];
//    UIView *refreshPositionView = [self.refreshControl.subviews objectAtIndex:0];
//    [refreshPositionView setFrame:CGRectMake(0, 10, refreshPositionView.frame.size.width, refreshPositionView.frame.size.height)];
    self.betterRefreshControl = [[ODRefreshControl alloc] initInScrollView:self.tableView];
    [self.betterRefreshControl addTarget:self action:@selector(refreshBluetoothDevices) forControlEvents:UIControlEventValueChanged];
    [self.betterRefreshControl setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhiteLarge];
//    [self.betterRefreshControl.activity setCenter:CGPointMake(0, 20)];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)refreshBluetoothDevices {
    self.discoveredPeripherals = [NSMutableArray array];
    if (_connectedPeripheral) {
        [self.discoveredPeripherals addObject:_connectedPeripheral];
        self.selectedIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    }
    [self startScanningForButton];
    if (self.scanTimer) [self.scanTimer invalidate];
    self.scanTimer = [NSTimer scheduledTimerWithTimeInterval:3 target:self selector:@selector(timedStopScanning:) userInfo:nil repeats:NO];
}

-(void)timedStopScanning:(NSTimer *)timer {
    NSLog(@"Scanning stopped");
    [self.centralManager stopScan];
//    [self.refreshControl endRefreshing];
    [self.betterRefreshControl endRefreshing];
    [timer invalidate];
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [self.discoveredPeripherals count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    CBPeripheral *peripheral = [self.discoveredPeripherals objectAtIndex:indexPath.row];

    cell.backgroundColor = [UIColor clearColor];

    cell.textLabel.text = peripheral.name;
    cell.textLabel.textColor = [UIColor colorWithRed:0.639 green:0.910 blue:0.980 alpha:1.000];
    cell.textLabel.backgroundColor = [UIColor clearColor];
    
    UIImageView *divider = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"tableViewDivider.png"]];
    divider.frame = CGRectMake(15, kRowHeight-divider.frame.size.height, self.view.frame.size.width-30, divider.frame.size.height);
    [cell addSubview:divider];
    
    UIView *selectedView = [[UIView alloc] initWithFrame:cell.frame];
    selectedView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
    cell.selectedBackgroundView = selectedView;
    
    cell.tintColor = [UIColor colorWithWhite:1 alpha:1]; // for the checkmark when selected
    
    if ([peripheral isEqual:_connectedPeripheral]) {
        _selectedIndexPath = indexPath;
        [self setSelectedCell:cell atIndexPath:indexPath isFullyConnected:YES];
        [self.tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
    }
    
    return cell;
}

#pragma mark - Table view delegate

-(CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return kRowHeight;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row != _selectedIndexPath.row || !_selectedIndexPath) {
        if (_connectedPeripheral) {
            [self.centralManager cancelPeripheralConnection:_connectedPeripheral];
            _connectedPeripheral = nil;
        }
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        [self setSelectedCell:cell atIndexPath:indexPath isFullyConnected:NO];
    }
}


-(void)setSelectedCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath isFullyConnected:(BOOL)connected {
    [cell setSelected:YES animated:YES];
    if (connected) {
        UIActivityIndicatorView *act = (UIActivityIndicatorView *)cell.accessoryView;
        [act stopAnimating];
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else { // in progress
        UIActivityIndicatorView *act = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        act.hidesWhenStopped = YES;
        [act startAnimating];
        cell.accessoryView = act;
        CBPeripheral *peripheral = [self.discoveredPeripherals objectAtIndex:indexPath.row];
        [_centralManager connectPeripheral:peripheral options:nil];
        _selectedIndexPath = indexPath;
    }
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
    
    if ([self.discoveredPeripherals indexOfObject:peripheral] == NSNotFound) [self.discoveredPeripherals addObject:peripheral];
    if (!_connectedPeripheral && ([peripheral.name rangeOfString:@"V.BTTN"].location != NSNotFound || [peripheral.name rangeOfString:@"V.ALRT"].location != NSNotFound)) {
        // Auto connect to first V.ALRT or V.BTTN
        NSIndexPath *selectedPath = [NSIndexPath indexPathForRow:[self.discoveredPeripherals indexOfObject:peripheral] inSection:0];
        NSLog(@"Auto Connecting to peripheral %@", peripheral);
        [self tableView:self.tableView didSelectRowAtIndexPath:selectedPath];
    }
    [self.tableView reloadData];

}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"Failed to connect");
    CBPeripheral *selectedPeripheral = [self.discoveredPeripherals objectAtIndex:self.selectedIndexPath.row];
    if ([selectedPeripheral isEqual:peripheral]) {
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:_selectedIndexPath];
        UIActivityIndicatorView *act = (UIActivityIndicatorView *)cell.accessoryView;
        [act stopAnimating];
        cell.accessoryView = nil;
        [cell setSelected:NO];
        // display HUD with error
    }
    [self cleanupBluetooth];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"Connected");
    [_centralManager stopScan];
    NSLog(@"Scanning stopped");
    
    CBPeripheral *selectedPeripheral = [self.discoveredPeripherals objectAtIndex:self.selectedIndexPath.row];
    if ([selectedPeripheral isEqual:peripheral]) {
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:_selectedIndexPath];
        [self setSelectedCell:cell atIndexPath:_selectedIndexPath isFullyConnected:YES];
        peripheral.delegate = self;
        [peripheral discoverServices:@[[CBUUID UUIDWithString:BTTN_SERVICE_UUID]]];
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
        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:BTTN_NOTIFICATION_CHARACTERISTIC_UUID], [CBUUID UUIDWithString:BTTN_VERIFICATION_CHARACTERISTIC_UUID], [CBUUID UUIDWithString:BTTN_DETECTION_CHARACTERISTIC_UUID]] forService:service];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        [self cleanupBluetooth];
        return;
    }
    
    // Set up characteristic connections with button
    for (CBCharacteristic *characteristic in service.characteristics) {
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:BTTN_NOTIFICATION_CHARACTERISTIC_UUID]]) { // Set up to receive notifications when button is pressed or released
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            NSLog(@"NOTIFY characteristic: %@", characteristic);
        } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:BTTN_VERIFICATION_CHARACTERISTIC_UUID]]) { // Create long lasting connection
//            const Byte identifierBytes[5] = { 0xBC, 0xF5, 0xAC, 0x48, 0x40 }; old code
            const Byte identifierBytes[5] = { 0x80, 0xBE, 0xF5, 0xAC, 0xFF };
            NSMutableData *data = [[NSMutableData alloc] initWithBytes:identifierBytes length:5];
            [peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
            NSLog(@"Created long lasting communication with button by sending verification key");
        } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:BTTN_DETECTION_CHARACTERISTIC_UUID]]) { // Set peripheral up to detect button pressed
            const Byte identifierByte[1] = { 0x01 };
            NSMutableData *data = [[NSMutableData alloc] initWithBytes:identifierByte length:1];
            [peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
        }
    }
}


- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Error didUpdateValueForCharacteristic:");
        return;
    }
    
    const Byte identifierByte[1] = { 0x01 };
    NSMutableData *buttonDownData = [[NSMutableData alloc] initWithBytes:identifierByte length:1];
    if ([characteristic.value isEqualToData:buttonDownData]) {
        [_delegate bluetoothButtonPressed];
    }
    
    NSLog(@"%@", characteristic.value);
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
    if ([peripheral isEqual:_connectedPeripheral]) {
        _connectedPeripheral = nil;
        _selectedIndexPath = nil;
        [_delegate disconnectedFromBluetoothDevice];
        [self.tableView reloadData];
    }
}

-(void)startScanningForButton {
    [_centralManager scanForPeripheralsWithServices:nil options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @NO }];
    NSLog(@"started scanning");
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
