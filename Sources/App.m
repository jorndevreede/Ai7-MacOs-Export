#import <Cocoa/Cocoa.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "AI7Protocol.h"
#import "AI7Store.h"
#import "AI7USB.h"

@interface AI7App : NSObject <NSApplicationDelegate,CBCentralManagerDelegate,CBPeripheralDelegate,NSTableViewDataSource,NSTableViewDelegate>
@property NSWindow *window;
@property NSTextField *subtitle, *folderLabel, *summary, *status;
@property NSButton *folderButton, *scanButton, *connectButton, *disconnectButton, *refreshButton, *allButton, *noneButton, *transferButton, *transferNewButton, *deleteButton, *stopButton, *showButton;
@property NSPopUpButton *devicesMenu;
@property NSTableView *table;
@property NSProgressIndicator *progress;
@property CBCentralManager *central;
@property CBPeripheral *device;
@property CBCharacteristic *writer;
@property NSMutableArray<NSDictionary *> *devices;
@property NSMutableArray<AI7Recording *> *recordings, *incoming, *queue;
@property NSMutableSet<NSString *> *subscribed;
@property NSString *phase, *deviceID, *expectedDeletedID;
@property NSURL *folder, *staging, *usbSource;
@property AI7Store *store;
@property AI7Recording *current;
@property NSFileHandle *audioFile;
@property NSUInteger received, completed, total, generation;
@property NSTimeInterval activity;
@property BOOL connected, scanning, busy, converting, cancelRequested, demo;
@property NSTask *converter;
@property BOOL usbRequested;
@property NSButton *settingsButton;
@end
@implementation AI7App
- (NSButton *)button:(NSString *)title action:(SEL)action frame:(NSRect)frame {
    NSButton*b=[NSButton buttonWithTitle:title target:self action:action];b.frame=frame;b.bezelStyle=NSBezelStyleRounded;[self.window.contentView addSubview:b];return b;
}
- (NSTextField *)label:(NSString *)text frame:(NSRect)frame font:(NSFont *)font {
    NSTextField*l=[NSTextField labelWithString:text];l.frame=frame;l.font=font;l.lineBreakMode=NSLineBreakByTruncatingMiddle;[self.window.contentView addSubview:l];return l;
}
- (void)applicationDidFinishLaunching:(NSNotification *)n {
    self.demo=[NSProcessInfo.processInfo.arguments containsObject:@"--demo"];
    self.devices=[NSMutableArray new];self.recordings=[NSMutableArray new];self.phase=@"idle";
    self.window=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,1060,760) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];
    self.window.title=@"Ai7 interface";self.window.minSize=NSMakeSize(1060,760);[self.window center];
    NSImageView*icon=[[NSImageView alloc]initWithFrame:NSMakeRect(24,677,58,62)];icon.image=[NSImage imageNamed:@"Recorder"];icon.imageScaling=NSImageScaleProportionallyUpOrDown;icon.autoresizingMask=NSViewMinYMargin;[self.window.contentView addSubview:icon];
    NSTextField*title=[self label:@"Ai7 interface" frame:NSMakeRect(96,707,700,30) font:[NSFont boldSystemFontOfSize:25]];title.autoresizingMask=NSViewMinYMargin;
    self.subtitle=[self label:@"Your recordings. On your Mac." frame:NSMakeRect(97,679,830,24) font:[NSFont systemFontOfSize:14]];self.subtitle.textColor=NSColor.secondaryLabelColor;self.subtitle.autoresizingMask=NSViewMinYMargin;
    self.settingsButton=[self button:@"⚙" action:@selector(settings) frame:NSMakeRect(982,694,48,40)];self.settingsButton.autoresizingMask=NSViewMinXMargin|NSViewMinYMargin;[self.settingsButton setAccessibilityLabel:@"Settings"];
    [self step:@"1" text:@"Connect via USB" x:28 y:610];
    [self step:@"2" text:@"Identify recorder via Bluetooth" x:248 y:610];
    self.scanButton=[self button:@"Scan" action:@selector(scan) frame:NSMakeRect(248,561,85,34)];
    self.devicesMenu=[[NSPopUpButton alloc]initWithFrame:NSMakeRect(343,562,340,32) pullsDown:NO];self.devicesMenu.target=self;self.devicesMenu.action=@selector(deviceSelectionChanged);[self.devicesMenu addItemWithTitle:@"No recorder found — click Scan"];[self.window.contentView addSubview:self.devicesMenu];
    self.connectButton=[self button:@"Connect" action:@selector(connect) frame:NSMakeRect(693,561,100,34)];
    self.disconnectButton=[self button:@"Disconnect" action:@selector(disconnect) frame:NSMakeRect(803,561,115,34)];
    self.refreshButton=[self button:@"Refresh" action:@selector(refresh) frame:NSMakeRect(928,561,105,34)];
    [self step:@"3" text:@"Copy recordings to your Mac" x:28 y:495];
    self.summary=[self label:@"Connect your recorder to get started" frame:NSMakeRect(370,503,660,26) font:[NSFont boldSystemFontOfSize:13]];
    NSScrollView*scroll=[[NSScrollView alloc]initWithFrame:NSMakeRect(28,145,1004,340)];scroll.borderType=NSBezelBorder;scroll.hasVerticalScroller=YES;scroll.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;
    self.table=[[NSTableView alloc]initWithFrame:scroll.bounds];self.table.delegate=self;self.table.dataSource=self;self.table.rowHeight=38;self.table.usesAlternatingRowBackgroundColors=YES;self.table.selectionHighlightStyle=NSTableViewSelectionHighlightStyleNone;self.table.target=self;self.table.action=@selector(rowClicked);self.table.columnAutoresizingStyle=NSTableViewLastColumnOnlyAutoresizingStyle;
    NSArray*ids=@[@"selected",@"date",@"kind",@"duration",@"size",@"state"];NSArray*titles=@[@"",@"Recording",@"Type",@"Duration",@"Size",@"Status"];CGFloat widths[]={38,275,110,115,130,200};
    for(int i=0;i<6;i++){NSTableColumn*c=[[NSTableColumn alloc]initWithIdentifier:ids[i]];c.title=titles[i];c.width=widths[i];c.minWidth=widths[i];[self.table addTableColumn:c];}scroll.documentView=self.table;[self.window.contentView addSubview:scroll];
    self.allButton=[self button:@"Select all" action:@selector(selectAllRecordings) frame:NSMakeRect(24,95,110,32)];
    self.noneButton=[self button:@"Select none" action:@selector(selectNone) frame:NSMakeRect(140,95,120,32)];
    [self label:@"Select recordings to copy via USB." frame:NSMakeRect(280,99,310,24) font:[NSFont systemFontOfSize:12]].textColor=NSColor.secondaryLabelColor;
    self.transferButton=[self button:@"Transfer selected" action:@selector(transferSelected) frame:NSMakeRect(598,93,170,37)];
    self.transferNewButton=[self button:@"Transfer all new recordings" action:@selector(transferNew) frame:NSMakeRect(778,93,255,37)];self.transferNewButton.bezelColor=NSColor.controlAccentColor;
    self.transferButton.autoresizingMask=NSViewMinXMargin;self.transferNewButton.autoresizingMask=NSViewMinXMargin;
    self.stopButton=[self button:@"Stop" action:@selector(stop) frame:NSMakeRect(935,13,100,32)];self.stopButton.autoresizingMask=NSViewMinXMargin;
    self.progress=[[NSProgressIndicator alloc]initWithFrame:NSMakeRect(28,59,1004,8)];self.progress.indeterminate=NO;self.progress.maxValue=100;self.progress.autoresizingMask=NSViewWidthSizable;[self.window.contentView addSubview:self.progress];
    self.status=[self label:@"Connect the USB cable, turn on the recorder, then Scan and Connect." frame:NSMakeRect(28,18,890,28) font:[NSFont systemFontOfSize:12]];self.status.autoresizingMask=NSViewWidthSizable;
    for(NSView*v in @[self.scanButton,self.devicesMenu,self.connectButton,self.disconnectButton,self.refreshButton,self.summary])v.autoresizingMask=NSViewMinYMargin;
    NSMenu*menu=[NSMenu new];NSMenuItem*root=[NSMenuItem new];[menu addItem:root];NSMenu*appMenu=[NSMenu new];[appMenu addItemWithTitle:@"About Ai7 interface" action:@selector(about) keyEquivalent:@""];[appMenu addItemWithTitle:@"Settings…" action:@selector(settings) keyEquivalent:@","];[appMenu addItemWithTitle:@"Choose USB volume manually…" action:@selector(chooseUSBSource) keyEquivalent:@""];[appMenu addItem:NSMenuItem.separatorItem];[appMenu addItemWithTitle:@"Quit Ai7 interface" action:@selector(terminate:) keyEquivalent:@"q"];root.submenu=appMenu;NSApp.mainMenu=menu;
    NSData*bookmark=[NSUserDefaults.standardUserDefaults dataForKey:@"destinationBookmark"];
    if(bookmark){BOOL stale=NO;NSURL*u=[NSURL URLByResolvingBookmarkData:bookmark options:NSURLBookmarkResolutionWithoutUI relativeToURL:nil bookmarkDataIsStale:&stale error:nil];if(u.isFileURL){self.folder=u;[self updateFolderLabel];}}
    [self.window makeKeyAndOrderFront:nil];[NSApp activateIgnoringOtherApps:YES];[self updateControls];
    if(self.demo){self.subtitle.stringValue=@"Demo mode — no physical recorder commands are sent.";[self scan];}
    else self.central=[[CBCentralManager alloc]initWithDelegate:self queue:nil options:@{CBCentralManagerOptionShowPowerAlertKey:@YES}];
    [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer*t){
        if([self.phase isEqual:@"usb-wait"]){[self findUSBVolume];return;}
        if(self.usbSource&&!self.busy&&![NSFileManager.defaultManager fileExistsAtPath:self.usbSource.path]){self.usbSource=nil;[self statusText:@"USB volume disconnected. Reconnect the cable and choose the USB volume in Settings."];[self updateControls];}
        if(self.busy&&!self.converting&&NSDate.timeIntervalSinceReferenceDate-self.activity>40)[self fail:@"The recorder stopped responding. Completed files are safe. Reconnect to refresh the list."];
    }];
}
- (void)step:(NSString *)number text:(NSString *)text x:(CGFloat)x y:(CGFloat)y {
    NSTextField*badge=[self label:number frame:NSMakeRect(x,y,36,36) font:[NSFont boldSystemFontOfSize:26]];badge.alignment=NSTextAlignmentCenter;badge.textColor=NSColor.systemGreenColor;badge.autoresizingMask=NSViewMinYMargin;
    NSTextField*caption=[self label:text frame:NSMakeRect(x+44,y+4,300,28) font:[NSFont systemFontOfSize:14 weight:NSFontWeightMedium]];caption.autoresizingMask=NSViewMinYMargin;
}
- (void)settings {
    if(self.busy||self.scanning)return;NSMenu*m=[NSMenu new];
    NSMenuItem*path=[m addItemWithTitle:self.folder.path?:@"No destination selected" action:nil keyEquivalent:@""];path.enabled=NO;
    [m addItemWithTitle:@"Choose destination folder…" action:@selector(chooseFolder) keyEquivalent:@""].target=self;
    [m addItemWithTitle:@"Show destination folder" action:@selector(showFolder) keyEquivalent:@""].target=self;
    [m addItem:NSMenuItem.separatorItem];
    [m addItemWithTitle:@"Choose USB volume manually…" action:@selector(chooseUSBSource) keyEquivalent:@""].target=self;
    [m popUpMenuPositioningItem:nil atLocation:NSMakePoint(0,0) inView:self.settingsButton];
}
- (void)prepareUSB {
    if(!self.connected||self.usbRequested||self.demo)return;
    self.usbRequested=YES;self.busy=YES;self.phase=@"usb-wait";self.activity=NSDate.timeIntervalSinceReferenceDate;
    [self statusText:@"Enabling USB storage and waiting for the recorder disk…"];[self updateControls];
    uint8_t enabled=1;[self send:[AI7Protocol command:0x15 payload:[NSData dataWithBytes:&enabled length:1]]];
}
- (void)findUSBVolume {
    BOOL hasAudio=NO;for(AI7Recording*r in self.recordings)if(r.byteCount){hasAudio=YES;break;}
    if(!hasAudio){self.busy=NO;self.phase=@"idle";[self statusText:@"No recordings to transfer. USB mode requested."];[self updateControls];return;}
    NSArray*volumes=[NSFileManager.defaultManager mountedVolumeURLsIncludingResourceValuesForKeys:@[NSURLVolumeIsInternalKey] options:0];
    NSMutableArray*matches=[NSMutableArray new];
    for(NSURL*root in volumes){NSNumber*internal=nil;[root getResourceValue:&internal forKey:NSURLVolumeIsInternalKey error:nil];if(internal.boolValue)continue;
        BOOL found=NO,match=YES;for(AI7Recording*r in self.recordings){if(!r.byteCount)continue;found=YES;if(![AI7USB matchesRecording:r root:root]){match=NO;break;}}
        if(found&&match)[matches addObject:root];
    }
    if(matches.count==1){self.usbSource=matches[0];self.busy=NO;self.phase=@"idle";[self statusText:self.folder?@"Ready. All recordings will transfer via USB.":@"USB ready. Choose your destination folder in Settings (⚙)." ];[self updateControls];return;}
    if(matches.count>1||NSDate.timeIntervalSinceReferenceDate-self.activity>25){self.busy=NO;self.phase=@"idle";
        [self statusText:matches.count>1?@"Multiple matching disks found. Choose the recorder volume in Settings.":@"USB disk not found. Check the data cable, then choose the USB volume in Settings. No Bluetooth audio transfer will be used."];[self updateControls];}
}
- (void)chooseUSBSource {
    if(self.busy||self.scanning)return;
    if(!self.connected||!self.deviceID||!self.recordings.count){[self presentError:@"Connect first" detail:@"Connect over Bluetooth once to identify the recorder and load its file list. Then choose the mounted USB recorder."];return;}
    NSOpenPanel*p=[NSOpenPanel openPanel];p.canChooseFiles=NO;p.canChooseDirectories=YES;p.allowsMultipleSelection=NO;p.prompt=@"Use USB recordings";p.directoryURL=[NSURL fileURLWithPath:@"/Volumes" isDirectory:YES];p.message=@"Select the recorder volume (usually NO NAME). Files must match the connected recorder.";
    NSUInteger generation=self.generation;
    [p beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result){
        if(result!=NSModalResponseOK||generation!=self.generation||!self.connected)return;
        BOOL found=NO;for(AI7Recording*r in self.recordings){if(!r.byteCount)continue;
            if(![AI7USB matchesRecording:r root:p.URL]){[self presentError:@"USB files do not match" detail:@"Choose the root of this recorder's USB volume. Refresh the Bluetooth list if recordings have changed."];return;}found=YES;
        }
        if(!found)return;self.usbSource=p.URL;[self statusText:@"USB transfers selected. Transfer buttons now read USB files and save verified MP3s. Do not record or unplug during transfer."];[self updateControls];
    }];
}
- (void)about {
    NSAlert*a=[NSAlert new];a.messageText=@"Ai7 interface 0.4.0";a.informativeText=@"Local USB transfers with Bluetooth setup for compatible Ai7 / AI07 recorders. Audio stays on your Mac. Includes FFmpeg and LAME (LGPL); sources and notices are included in the disk image. Tested with firmware V1.0.0.";[a runModal];
}
- (void)statusText:(NSString *)s {self.status.stringValue=s;self.status.toolTip=s;}
- (void)updateFolderLabel {self.folderLabel.stringValue=self.folder.path?:@"Choose a local folder for Notes and Calls";self.folderLabel.toolTip=self.folder.path;}
- (NSUInteger)selectedCount {NSUInteger n=0;for(AI7Recording*r in self.recordings)if(r.selected)n++;return n;}
- (void)updateControls {
    BOOL idle=!self.busy&&!self.scanning;
    self.scanButton.enabled=idle&&!self.connected;
    self.devicesMenu.enabled=idle&&!self.connected&&self.devices.count>0;
    self.connectButton.enabled=idle&&!self.connected&&self.devices.count>0;
    self.disconnectButton.enabled=idle&&self.connected;self.disconnectButton.hidden=!self.connected;self.refreshButton.hidden=!self.connected;self.settingsButton.enabled=idle;
    self.folderButton.enabled=idle;self.showButton.enabled=self.folder!=nil;
    self.refreshButton.enabled=idle&&self.connected;
    self.allButton.enabled=idle&&self.recordings.count>0;self.noneButton.enabled=self.allButton.enabled;
    NSUInteger selected=0,new=0,transferable=0;
    for(AI7Recording*r in self.recordings){if(r.selected)selected++;if([r.localState isEqual:@"new"]){new++;if(r.selected)transferable++;}}
    self.transferButton.enabled=idle&&self.connected&&self.usbSource&&self.folder&&transferable>0;
    self.transferNewButton.enabled=idle&&self.connected&&self.usbSource&&self.folder&&new>0;
    self.deleteButton.enabled=idle&&self.connected&&selected>0&&!self.usbSource;
    self.stopButton.enabled=(self.busy||self.scanning)&&!self.converting;self.stopButton.hidden=!self.stopButton.enabled;
    if(self.connected)self.summary.stringValue=[NSString stringWithFormat:@"%lu recordings  ·  %lu new  ·  %lu selected%@",(unsigned long)self.recordings.count,(unsigned long)new,(unsigned long)selected,self.folder?(self.usbSource?@"  ·  USB":@"  ·  Waiting for USB"):@"  ·  Choose an export folder"];
    [self.table reloadData];
}
- (NSInteger)numberOfRowsInTableView:(NSTableView *)v {return self.recordings.count;}
- (BOOL)tableView:(NSTableView *)v shouldSelectRow:(NSInteger)row {return NO;}
- (NSView *)tableView:(NSTableView *)table viewForTableColumn:(NSTableColumn *)col row:(NSInteger)row {
    AI7Recording*r=self.recordings[row];NSString*key=col.identifier;
    if([key isEqual:@"selected"]){NSButton*b=[NSButton checkboxWithTitle:@"" target:self action:@selector(toggleRow:)];b.tag=row;b.state=r.selected?NSControlStateValueOn:NSControlStateValueOff;b.enabled=!self.busy&&!self.scanning;[b setAccessibilityLabel:[@"Select " stringByAppendingString:r.displayDate]];return b;}
    NSTextField*l=[NSTextField labelWithString:@""];l.font=[NSFont systemFontOfSize:13];l.lineBreakMode=NSLineBreakByTruncatingTail;
    if([key isEqual:@"date"])l.stringValue=r.displayDate;
    else if([key isEqual:@"kind"])l.stringValue=r.category;
    else if([key isEqual:@"duration"])l.stringValue=[NSString stringWithFormat:@"%u:%02u",r.seconds/60,r.seconds%60];
    else if([key isEqual:@"size"])l.stringValue=[NSByteCountFormatter stringFromByteCount:r.byteCount countStyle:NSByteCountFormatterCountStyleFile];
    else {l.stringValue=r.localState;if([r.localState isEqual:@"new"]){l.textColor=NSColor.systemBlueColor;l.font=[NSFont boldSystemFontOfSize:13];}else if([r.localState isEqual:@"local"])l.textColor=NSColor.systemGreenColor;else l.textColor=NSColor.secondaryLabelColor;}
    return l;
}
- (void)toggleRow:(NSButton *)sender {if(self.busy||sender.tag<0||(NSUInteger)sender.tag>=self.recordings.count)return;self.recordings[sender.tag].selected=sender.state==NSControlStateValueOn;[self updateControls];}
- (void)rowClicked {NSInteger row=self.table.clickedRow;if(self.busy||self.scanning||row<0||(NSUInteger)row>=self.recordings.count||self.table.clickedColumn==0)return;self.recordings[row].selected=!self.recordings[row].selected;[self updateControls];}
- (void)selectAllRecordings {for(AI7Recording*r in self.recordings)r.selected=YES;[self updateControls];}
- (void)selectNone {for(AI7Recording*r in self.recordings)r.selected=NO;[self updateControls];}
- (void)chooseFolder {
    NSOpenPanel*p=[NSOpenPanel openPanel];p.canChooseFiles=NO;p.canChooseDirectories=YES;p.canCreateDirectories=YES;p.allowsMultipleSelection=NO;p.prompt=@"Use this folder";p.message=@"Ai7 interface creates separate Notes and Calls folders for each recorder.";if(self.folder)p.directoryURL=self.folder;
    [p beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result){if(result!=NSModalResponseOK)return;
        self.folder=p.URL;NSData*b=[self.folder bookmarkDataWithOptions:0 includingResourceValuesForKeys:nil relativeToURL:nil error:nil];if(b)[NSUserDefaults.standardUserDefaults setObject:b forKey:@"destinationBookmark"];
        [self updateFolderLabel];[self checkLocalFiles];
    }];
}
- (void)showFolder {if(self.folder){NSURL*u=self.store.deviceRoot;if(!u||![NSFileManager.defaultManager fileExistsAtPath:u.path])u=self.folder;[NSWorkspace.sharedWorkspace openURL:u];}}
- (void)checkLocalFiles {
    if(!self.folder||!self.deviceID){self.busy=NO;self.converting=NO;self.phase=@"idle";for(AI7Recording*r in self.recordings)r.localState=r.byteCount?@"choose folder":@"empty";[self statusText:self.connected?@"Connected. Choose a local folder to check for new recordings.":@"Folder selected. Scan and connect to a recorder."];[self updateControls];[self prepareUSB];return;}
    self.store=[[AI7Store alloc]initWithRoot:self.folder device:self.deviceID];self.busy=YES;self.converting=YES;[self statusText:@"Checking local recordings…"];[self updateControls];
    NSArray*rows=[self.recordings copy];AI7Store*store=self.store;NSUInteger generation=self.generation;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{NSMutableArray*states=[NSMutableArray new];for(AI7Recording*r in rows)[states addObject:[store stateForRecording:r]];
        dispatch_async(dispatch_get_main_queue(),^{if(generation!=self.generation)return;for(NSUInteger i=0;i<rows.count;i++)((AI7Recording*)rows[i]).localState=states[i];self.converting=NO;self.busy=NO;self.phase=@"idle";[self statusText:self.usbSource?@"Ready. All recordings will transfer via USB.":@"Waiting for USB storage."];[self updateControls];[self prepareUSB];});
    });
}
- (void)deviceSelectionChanged {[self updateControls];}
- (void)scan {
    if(self.busy||self.connected||self.scanning)return;
    if(!self.demo&&self.central.state!=CBManagerStatePoweredOn){[self statusText:@"Enable Bluetooth and allow Ai7 interface in System Settings → Privacy & Security → Bluetooth."];return;}
    [self.devices removeAllObjects];[self.devicesMenu removeAllItems];[self.devicesMenu addItemWithTitle:@"Searching for Ai7 recorders…"];self.scanning=YES;self.progress.doubleValue=0;[self statusText:@"Scanning… turn on the Ai7 and close MindRec on your phone and Mac."];[self updateControls];
    if(self.demo){[self.devices addObject:@{@"name":@"Ai7 Demo",@"id":@"DEMO",@"rssi":@(-48)}];[self refreshDevicesMenu];self.scanning=NO;[self updateControls];return;}
    [self.central scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@YES}];NSUInteger g=++self.generation;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,15*NSEC_PER_SEC),dispatch_get_main_queue(),^{if(g!=self.generation||!self.scanning)return;[self.central stopScan];self.scanning=NO;[self statusText:self.devices.count?@"Select your recorder, then click Connect.":@"No Ai7 found. Turn it on, close MindRec, and scan again."];[self refreshDevicesMenu];[self updateControls];});
}
- (void)refreshDevicesMenu {
    NSInteger selected=self.devicesMenu.indexOfSelectedItem;[self.devicesMenu removeAllItems];
    for(NSDictionary*d in self.devices)[self.devicesMenu addItemWithTitle:[NSString stringWithFormat:@"%@  ·  %@  ·  %@ dBm",d[@"name"],d[@"id"],d[@"rssi"]]];
    if(!self.devices.count)[self.devicesMenu addItemWithTitle:self.scanning?@"Searching for Ai7 recorders…":@"No recorder found — click Scan"];
    else if(selected>=0&&(NSUInteger)selected<self.devices.count)[self.devicesMenu selectItemAtIndex:selected];
}
- (void)centralManagerDidUpdateState:(CBCentralManager *)c {
    if(c.state!=CBManagerStatePoweredOn){if(self.busy||self.connected||self.scanning)[self fail:@"Bluetooth is unavailable. Turn it on or allow this app in Privacy & Security."];else [self statusText:@"Enable Bluetooth and allow Ai7 interface in Privacy & Security → Bluetooth."];}
}
- (void)centralManager:(CBCentralManager *)c didDiscoverPeripheral:(CBPeripheral *)p advertisementData:(NSDictionary *)a RSSI:(NSNumber *)rssi {
    if(!self.scanning)return;NSString*name=a[CBAdvertisementDataLocalNameKey]?:p.name?:@"";
    BOOL service=[a[CBAdvertisementDataServiceUUIDsKey] containsObject:[CBUUID UUIDWithString:@"A0A0"]];
    if(![name.lowercaseString containsString:@"ai7"]&&![name.lowercaseString containsString:@"ai07"]&&!service)return;
    NSString*deviceID=p.identifier.UUIDString;NSData*m=a[CBAdvertisementDataManufacturerDataKey];
    if(m.length>=18){NSString*s=[[NSString alloc]initWithBytes:(const uint8_t*)m.bytes+8 length:10 encoding:NSASCIIStringEncoding];if(s.length==10&&[[AI7Protocol safeComponent:s] isEqual:s])deviceID=s;}
    NSDictionary*d=@{@"peripheral":p,@"name":name.length?name:@"Ai7 candidate",@"id":deviceID,@"rssi":rssi};
    NSUInteger existing=[self.devices indexOfObjectPassingTest:^BOOL(NSDictionary*x,NSUInteger i,BOOL*stop){return [((CBPeripheral*)x[@"peripheral"]).identifier isEqual:p.identifier];}];
    if(existing==NSNotFound)[self.devices addObject:d];else self.devices[existing]=d;[self refreshDevicesMenu];
}
- (void)connect {
    if(self.busy||self.scanning||!self.devices.count)return;NSInteger idx=self.devicesMenu.indexOfSelectedItem;if(idx<0||(NSUInteger)idx>=self.devices.count)return;
    NSDictionary*d=self.devices[idx];self.usbRequested=NO;self.usbSource=nil;self.deviceID=d[@"id"];self.device=d[@"peripheral"];self.writer=nil;self.subscribed=[NSMutableSet new];self.busy=YES;self.phase=@"connecting";self.activity=NSDate.timeIntervalSinceReferenceDate;self.generation++;[self.recordings removeAllObjects];[self updateControls];[self statusText:@"Connecting and checking recorder compatibility…"];
    if(self.demo){self.connected=YES;[self refresh];return;}
    self.device.delegate=self;[self.central connectPeripheral:self.device options:nil];
}
- (void)disconnect {if(self.busy)return;[self.central stopScan];if(self.device)[self.central cancelPeripheralConnection:self.device];self.connected=NO;self.device=nil;self.writer=nil;self.deviceID=nil;self.store=nil;self.usbSource=nil;[self.recordings removeAllObjects];self.subtitle.stringValue=@"Your recordings. On your Mac.";self.summary.stringValue=@"No recorder connected";[self statusText:@"Disconnected. You can now use MindRec again."];[self updateControls];}
- (void)centralManager:(CBCentralManager *)c didConnectPeripheral:(CBPeripheral *)p {if(p!=self.device)return;self.activity=NSDate.timeIntervalSinceReferenceDate;[p discoverServices:@[[CBUUID UUIDWithString:@"D0D0"]]];}
- (void)centralManager:(CBCentralManager *)c didFailToConnectPeripheral:(CBPeripheral *)p error:(NSError *)e {if(p==self.device)[self fail:@"Connection failed. Close MindRec and try again."];}
- (void)centralManager:(CBCentralManager *)c didDisconnectPeripheral:(CBPeripheral *)p error:(NSError *)e {
    if(p!=self.device)return;self.connected=NO;self.device=nil;self.writer=nil;
    if(self.converting){[self updateControls];return;}
    [self fail:self.expectedDeletedID?@"Connection lost. Deletion has not been confirmed; reconnect and refresh before trying again.":@"Recorder disconnected. Completed files are safe. Scan and reconnect to continue."];
}
- (void)peripheral:(CBPeripheral *)p didDiscoverServices:(NSError *)e {if(p!=self.device)return;if(e||!p.services.count){[self fail:@"This recorder does not expose the supported Ai7 service (D0D0)."];return;}for(CBService*s in p.services)[p discoverCharacteristics:nil forService:s];}
- (void)peripheral:(CBPeripheral *)p didDiscoverCharacteristicsForService:(CBService *)s error:(NSError *)e {
    if(p!=self.device)return;if(e){[self fail:e.localizedDescription];return;}NSMutableArray*notifications=[NSMutableArray new];
    for(CBCharacteristic*c in s.characteristics){NSString*u=c.UUID.UUIDString;if([u isEqual:@"D0D1"]&&(c.properties&CBCharacteristicPropertyWrite))self.writer=c;else if([@[@"D0D2",@"D0D3",@"D0D4"] containsObject:u]&&(c.properties&CBCharacteristicPropertyNotify))[notifications addObject:c];}
    if(!self.writer||notifications.count!=3){[self fail:@"This recorder uses an unsupported Bluetooth layout. No transfer commands were sent."];return;}
    for(CBCharacteristic*c in notifications)[p setNotifyValue:YES forCharacteristic:c];
}
- (void)peripheral:(CBPeripheral *)p didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)c error:(NSError *)e {
    if(p!=self.device)return;if(e||!c.isNotifying){[self fail:e.localizedDescription?:@"Could not subscribe to recorder notifications."];return;}[self.subscribed addObject:c.UUID.UUIDString];if(self.subscribed.count==3&&[self.phase isEqual:@"connecting"]){self.connected=YES;[self refresh];}
}
- (BOOL)send:(NSData *)data {
    if(!data||!self.writer||self.device.state!=CBPeripheralStateConnected){[self fail:@"The recorder is no longer connected."];return NO;}
    [self.device writeValue:data forCharacteristic:self.writer type:CBCharacteristicWriteWithResponse];return YES;
}
- (void)peripheral:(CBPeripheral *)p didWriteValueForCharacteristic:(CBCharacteristic *)c error:(NSError *)e {if(p==self.device&&e)[self fail:e.localizedDescription];}
- (void)refresh {
    if(!self.connected)return;
    if(self.demo){[self.recordings removeAllObjects];for(int i=0;i<4;i++){AI7Recording*r=[AI7Recording new];r.identifier=[NSString stringWithFormat:@"202601%02d120000",i+1];r.kind=i%2;r.byteCount=i==3?0:10000+i*5000;r.seconds=60+i*120;[self.recordings addObject:r];}self.busy=NO;[self checkLocalFiles];return;}
    self.busy=YES;self.phase=self.expectedDeletedID?@"verify-delete":@"listing";self.incoming=[NSMutableArray new];self.activity=NSDate.timeIntervalSinceReferenceDate;[self statusText:self.expectedDeletedID?@"Verifying deletion against a fresh recorder list…":@"Reading recordings from the Ai7…"];[self updateControls];[self send:[AI7Protocol command:2 payload:nil]];
}
- (void)peripheral:(CBPeripheral *)p didUpdateValueForCharacteristic:(CBCharacteristic *)c error:(NSError *)e {
    if(p!=self.device)return;if(e){[self fail:e.localizedDescription];return;}NSData*d=c.value;
    if([c.UUID.UUIDString isEqual:@"D0D4"]){
        if(![self.phase isEqual:@"download"]||!self.current||!self.audioFile)return;
        if(d.length>self.current.byteCount-self.received){[self fail:@"The recorder sent more data than expected. No MP3 was published."];return;}
        NSError*writeError=nil;if(![self.audioFile writeData:d error:&writeError]){[self fail:writeError.localizedDescription];return;}
        self.received+=d.length;self.activity=NSDate.timeIntervalSinceReferenceDate;self.progress.doubleValue=100.0*self.received/MAX(1,self.current.byteCount);
        [self statusText:[NSString stringWithFormat:@"Transferring %lu of %lu · %@ · %.0f%%",(unsigned long)self.completed+1,(unsigned long)self.total,self.current.displayDate,self.progress.doubleValue]];return;
    }
    if(![c.UUID.UUIDString isEqual:@"D0D3"])return;NSDictionary*response=[AI7Protocol response:d];if(!response)return;uint8_t command=[response[@"command"] unsignedCharValue];NSData*payload=response[@"payload"];const uint8_t*b=payload.bytes;
    if(command==0x15&&[self.phase isEqual:@"usb-wait"]){[self findUSBVolume];return;}
    if(command==2&&([self.phase isEqual:@"listing"]||[self.phase isEqual:@"verify-delete"])){self.activity=NSDate.timeIntervalSinceReferenceDate;
        if(payload.length==24){AI7Recording*r=[AI7Protocol recordingFromPayload:payload];if(!r){[self fail:@"Unsupported recording entry. No files were changed."];return;}for(AI7Recording*existing in self.incoming)if([existing.key isEqual:r.key]){[self fail:@"Duplicate recording identifiers received. Reconnect before continuing."];return;}[self.incoming addObject:r];}
        else if(payload.length==1&&b[0]==2)[self finishList];
    }else if(command==8&&[self.phase isEqual:@"download"]&&payload.length){self.activity=NSDate.timeIntervalSinceReferenceDate;
        if(b[0]==1){[self fail:@"The recorder cannot transfer this recording. Stop recording on the device and refresh."];return;}
        if(b[0]==0&&payload.length==5){uint32_t size=((uint32_t)b[1]<<24)|((uint32_t)b[2]<<16)|((uint32_t)b[3]<<8)|b[4];if(size!=self.current.byteCount)[self fail:@"Recording size changed. Refresh the list before transferring."];}
        else if(b[0]==2&&payload.length==1)[self finishDownload];
    }
    // Delete acknowledgements differ by firmware. Only a fresh, complete list proves removal.
}
- (void)finishList {
    NSMutableSet*selected=[NSMutableSet new];for(AI7Recording*r in self.recordings)if(r.selected)[selected addObject:r.key];
    self.recordings=self.incoming;self.incoming=nil;for(AI7Recording*r in self.recordings)r.selected=[selected containsObject:r.key];
    if(self.expectedDeletedID){BOOL remains=NO;for(AI7Recording*r in self.recordings)if([r.identifier isEqual:self.expectedDeletedID])remains=YES;
        if(remains){self.expectedDeletedID=nil;self.busy=NO;self.queue=nil;self.phase=@"idle";[self checkLocalFiles];[self presentError:@"Deletion was not confirmed" detail:@"The recording is still listed on the Ai7. No further delete commands were sent."];return;}
        self.expectedDeletedID=nil;self.completed++;[self nextDelete];return;
    }
    self.subtitle.stringValue=[NSString stringWithFormat:@"Connected to %@ · %@",self.device.name?:@"Ai7",self.deviceID];[self checkLocalFiles];
}
- (void)fail:(NSString *)message {
    self.generation++;[self.central stopScan];self.scanning=NO;self.busy=NO;self.converting=NO;self.cancelRequested=YES;self.phase=@"idle";self.expectedDeletedID=nil;self.current=nil;self.queue=nil;
    [self.audioFile closeFile];self.audioFile=nil;if(self.converter.isRunning)[self.converter terminate];self.converter=nil;
    if(self.device){CBPeripheral*p=self.device;self.device=nil;[self.central cancelPeripheralConnection:p];}self.connected=NO;self.writer=nil;
    [self statusText:message];self.summary.stringValue=@"Not connected — scan to reconnect";[self updateControls];
}
- (void)stop {if(self.scanning){[self.central stopScan];self.scanning=NO;self.generation++;[self refreshDevicesMenu];[self statusText:@"Scan stopped. Select a found recorder to connect."];[self updateControls];return;}[self fail:@"Stopped. Completed recordings are safe; incomplete transfers are not published as MP3."];}
- (void)presentError:(NSString *)title detail:(NSString *)detail {NSAlert*a=[NSAlert new];a.messageText=title;a.informativeText=detail;[a beginSheetModalForWindow:self.window completionHandler:nil];}
- (void)transferSelected {NSMutableArray*a=[NSMutableArray new];for(AI7Recording*r in self.recordings)if(r.selected&&[r.localState isEqual:@"new"])[a addObject:r];[self startTransfer:a];}
- (void)transferNew {NSMutableArray*a=[NSMutableArray new];for(AI7Recording*r in self.recordings)if([r.localState isEqual:@"new"])[a addObject:r];[self startTransfer:a];}
- (void)startTransfer:(NSArray *)recordings {
    if(self.busy||!self.connected||!self.folder||!self.usbSource||!recordings.count)return;
    if(self.demo){[self statusText:@"Demo mode: transfer disabled. Connect a physical recorder to export audio."];return;}
    self.queue=[recordings mutableCopy];self.total=recordings.count;self.completed=0;self.busy=YES;self.cancelRequested=NO;self.generation++;[self updateControls];[self nextDownload];
}
- (void)nextDownload {
    self.current=nil;self.audioFile=nil;
    if(!self.queue.count){self.busy=NO;self.phase=@"idle";self.progress.doubleValue=100;[self statusText:[NSString stringWithFormat:@"Finished. %lu recordings saved as MP3.",(unsigned long)self.completed]];[self updateControls];return;}
    if(!self.connected){[self fail:@"Recorder disconnected. Completed exports are safe; reconnect to transfer the rest."];return;}
    self.current=self.queue.firstObject;[self.queue removeObjectAtIndex:0];
    NSString*state=[self.store stateForRecording:self.current];if(![state isEqual:@"new"]){self.current.localState=state;[self fail:@"A destination already exists. Refresh the list; existing files will not be overwritten."];return;}
    NSError*e=nil;self.staging=[self.store createStaging:&e];if(!self.staging){[self fail:e.localizedDescription];return;}
    NSURL*raw=[self.staging URLByAppendingPathComponent:@"recording.aac"];if(![NSData.data writeToURL:raw options:NSDataWritingWithoutOverwriting error:&e]){[self fail:e.localizedDescription];return;}
    self.audioFile=[NSFileHandle fileHandleForWritingToURL:raw error:&e];if(!self.audioFile){[self fail:e.localizedDescription];return;}
    if(self.usbSource){
        [self.audioFile closeFile];self.audioFile=nil;
        self.phase=@"usb-copy";self.converting=YES;[self updateControls];[self statusText:@"Copying recording over USB…"];
        NSUInteger generation=self.generation;AI7Recording*recording=self.current;NSURL*sourceRoot=self.usbSource;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
            NSError*copyError=nil;BOOL ok=[AI7USB copyRecording:recording root:sourceRoot toEmptyFile:raw error:&copyError];
            dispatch_async(dispatch_get_main_queue(),^{if(generation!=self.generation)return;self.converting=NO;
                if(!ok){[self fail:copyError.localizedDescription?:@"Incomplete USB copy. No MP3 was published."];return;}
                self.received=recording.byteCount;[self finishDownload];
            });
        });return;
    }
    [self fail:@"USB storage is not available. Reconnect the disk before transferring."];
}
- (BOOL)runConverter:(NSArray *)arguments log:(NSURL *)log error:(NSError **)error {
    NSString*path=[NSBundle.mainBundle pathForResource:@"ffmpeg" ofType:nil inDirectory:@"Tools"];
    if(!path){if(error)*error=[NSError errorWithDomain:@"Ai7" code:1 userInfo:@{NSLocalizedDescriptionKey:@"The bundled MP3 converter is missing. Reinstall the application."}];return NO;}
    NSTask*t=[NSTask new];t.executableURL=[NSURL fileURLWithPath:path];t.arguments=arguments;t.standardOutput=NSFileHandle.fileHandleWithNullDevice;
    [NSFileManager.defaultManager createFileAtPath:log.path contents:nil attributes:nil];NSFileHandle*err=[NSFileHandle fileHandleForWritingToURL:log error:error];if(!err)return NO;t.standardError=err;
    self.converter=t;BOOL ok=[t launchAndReturnError:error];if(ok){NSDate*deadline=[NSDate dateWithTimeIntervalSinceNow:600];while(t.isRunning&&deadline.timeIntervalSinceNow>0&&!self.cancelRequested)[NSThread sleepForTimeInterval:0.05];if(t.isRunning){[t terminate];[t waitUntilExit];ok=NO;}else ok=t.terminationStatus==0;}
    [err closeFile];self.converter=nil;if(!ok&&error&&!*error)*error=[NSError errorWithDomain:@"Ai7" code:2 userInfo:@{NSLocalizedDescriptionKey:@"Audio conversion or validation failed. The original transfer is preserved in .incomplete."}];return ok;
}
- (void)finishDownload {
    if(self.received!=self.current.byteCount){[self fail:@"Incomplete transfer. The recorder's original was not changed."];return;}
    [self.audioFile synchronizeFile];[self.audioFile closeFile];self.audioFile=nil;self.phase=@"converting";self.converting=YES;[self statusText:@"Creating and checking MP3…"];[self updateControls];
    AI7Recording*r=self.current;NSURL*staging=self.staging;AI7Store*store=self.store;NSUInteger generation=self.generation;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{NSError*error=nil;NSString*input=[staging URLByAppendingPathComponent:@"recording.aac"].path,*output=[staging URLByAppendingPathComponent:@"recording.mp3"].path;NSURL*log=[staging URLByAppendingPathComponent:@"converter.log"];
        BOOL ok=[self runConverter:@[@"-v",@"error",@"-xerror",@"-nostdin",@"-n",@"-i",input,@"-c:a",@"libmp3lame",@"-b:a",@"64k",output] log:log error:&error];
        if(ok)ok=[self runConverter:@[@"-v",@"error",@"-xerror",@"-nostdin",@"-i",output,@"-f",@"null",@"-"] log:log error:&error];
        if(ok&&!self.cancelRequested)ok=[store publish:r staging:staging error:&error];
        dispatch_async(dispatch_get_main_queue(),^{if(generation!=self.generation)return;self.converting=NO;if(!ok){[self fail:error.localizedDescription?:@"Export failed; original audio is preserved."];return;}r.localState=@"local";r.selected=NO;self.completed++;[self updateControls];[self nextDownload];});
    });
}
- (void)confirmDelete {
    if(self.busy||!self.connected||self.usbSource)return;NSMutableArray*chosen=[NSMutableArray new];for(AI7Recording*r in self.recordings)if(r.selected)[chosen addObject:r];if(!chosen.count)return;
    for(AI7Recording*r in chosen){NSUInteger matches=0;for(AI7Recording*x in self.recordings)if([x.identifier isEqual:r.identifier])matches++;if(matches!=1){[self presentError:@"Ambiguous recording identifier" detail:@"This firmware lists more than one recording with the same ID. Deletion is disabled for these entries."];return;}}
    NSUInteger unbacked=0;NSMutableArray*names=[NSMutableArray new];for(AI7Recording*r in chosen){if(!self.store||![[self.store stateForRecording:r] isEqual:@"local"])unbacked++;[names addObject:[NSString stringWithFormat:@"%@ · %@",r.displayDate,r.category]];}
    NSAlert*a=[NSAlert new];a.alertStyle=NSAlertStyleCritical;a.messageText=[NSString stringWithFormat:@"Delete %lu recording%@ from the Ai7?",(unsigned long)chosen.count,chosen.count==1?@"":@"s"];
    NSString*list=[[names subarrayWithRange:NSMakeRange(0,MIN(names.count,8))] componentsJoinedByString:@"\n"];
    a.informativeText=[NSString stringWithFormat:@"This permanently removes the selected recordings from the connected Ai7. This cannot be undone. Local files are kept.\n\n%@%@%@",list,names.count>8?@"\n…":@"",unbacked?[NSString stringWithFormat:@"\n\n%lu selected recordings have no verified local backup in this folder.",(unsigned long)unbacked]:@""];
    [a addButtonWithTitle:@"Cancel"];NSButton*confirm=[a addButtonWithTitle:@"Delete permanently"];confirm.hasDestructiveAction=YES;confirm.keyEquivalent=@"";
    NSUInteger generation=self.generation;[a beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response){if(response!=NSAlertSecondButtonReturn||!self.connected||self.busy||generation!=self.generation)return;
        if(self.demo){[self statusText:@"Demo mode: no recordings were deleted."];return;}
        self.queue=[chosen mutableCopy];self.total=chosen.count;self.completed=0;self.busy=YES;[self updateControls];[self nextDelete];
    }];
}
- (void)nextDelete {
    if(!self.queue.count){NSUInteger n=self.completed;self.busy=NO;self.phase=@"idle";self.current=nil;[self checkLocalFiles];[self presentError:@"Deletion verified" detail:[NSString stringWithFormat:@"%lu recordings are no longer listed on the Ai7. Local files were kept.",(unsigned long)n]];return;}
    AI7Recording*r=self.queue.firstObject;[self.queue removeObjectAtIndex:0];self.expectedDeletedID=r.identifier;self.phase=@"deleting";self.activity=NSDate.timeIntervalSinceReferenceDate;
    [self statusText:[NSString stringWithFormat:@"Deleting %lu of %lu — %@",(unsigned long)self.completed+1,(unsigned long)self.total,r.displayDate]];
    if(![self send:[AI7Protocol deleteRecording:r.identifier]])return;
    NSUInteger generation=self.generation;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{if(generation==self.generation&&self.connected&&[self.phase isEqual:@"deleting"])[self refresh];});
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app {return YES;}
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)app {
    if(self.converting){[self statusText:@"Please wait: a recording is being checked and saved."];return NSTerminateCancel;}
    if(self.busy){NSAlert*a=[NSAlert new];a.messageText=@"Stop the current operation and quit?";a.informativeText=@"Completed files are kept. A pending recorder deletion may already have taken effect; refresh the list next time.";[a addButtonWithTitle:@"Keep open"];[a addButtonWithTitle:@"Stop and quit"];if([a runModal]!=NSAlertSecondButtonReturn)return NSTerminateCancel;}
    [self.central stopScan];if(self.device)[self.central cancelPeripheralConnection:self.device];[self.audioFile closeFile];return NSTerminateNow;
}
@end
int main(int argc,const char**argv){@autoreleasepool{NSApplication*app=NSApplication.sharedApplication;AI7App*delegate=[AI7App new];app.delegate=delegate;[app setActivationPolicy:NSApplicationActivationPolicyRegular];[app run];}return 0;}
