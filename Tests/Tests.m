#import <Foundation/Foundation.h>
#import "AI7Protocol.h"
#import "AI7Store.h"
static void check(BOOL pass,NSString *message){if(!pass){fprintf(stderr,"FAIL: %s\n",message.UTF8String);exit(1);}}
static NSData* bytes(NSArray*values){NSMutableData*d=[NSMutableData new];for(NSNumber*n in values){uint8_t b=n.unsignedCharValue;[d appendBytes:&b length:1];}return d;}
int main(){@autoreleasepool{
    check([AI7Protocol download:@"../../etc/xxxx"]==nil,@"reject path traversal");
    check([AI7Protocol deleteRecording:@"2026010112000x"]==nil,@"reject malformed delete identifier");
    NSData*download=[AI7Protocol download:@"20260101120000"];check(download.length==22,@"download frame length");
    check([download subdataWithRange:NSMakeRange(0,4)].description.length>0,@"frame exists");
    const uint8_t*b=download.bytes;check(b[0]==0xca&&b[1]==0xac&&b[2]==8&&b[3]==18,@"download frame header");
    for(int i=18;i<22;i++)check(b[i]==0,@"zero download offset");
    NSData*del=[AI7Protocol deleteRecording:@"20260101120000"];b=del.bytes;check(del.length==18&&b[2]==10&&b[3]==14,@"delete command targets exact identifier only");
    check([AI7Protocol response:bytes(@[@0xac,@0xca,@2,@1])]==nil,@"reject truncated frame");
    check([AI7Protocol response:bytes(@[@0xac,@0xca,@2,@1,@2,@3])]==nil,@"reject extra bytes");
    check([AI7Protocol response:bytes(@[@0xca,@0xac,@2,@1,@2])]==nil,@"reject wrong direction");
    check([AI7Protocol response:bytes(@[@0xac,@0xca,@2,@1,@2])]!=nil,@"accept list completion");
    NSMutableData*p=[bytes(@[@0]) mutableCopy];[p appendData:[@"20260101120000" dataUsingEncoding:NSASCIIStringEncoding]];[p appendData:bytes(@[@0,@0,@0,@6,@0,@0,@0,@60,@1])];
    AI7Recording*r=[AI7Protocol recordingFromPayload:p];check(r&&r.byteCount==6&&r.seconds==60&&[r.category isEqual:@"Notes"],@"big-endian list fields");
    check([AI7Protocol recordingFromPayload:[p subdataWithRange:NSMakeRange(0,23)]]==nil,@"reject short entry");
    NSMutableData*bad=[p mutableCopy];((uint8_t*)bad.mutableBytes)[23]=3;check([AI7Protocol recordingFromPayload:bad]==nil,@"unknown type is not silently misclassified");
    NSURL*root=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[@"ai7-tests-" stringByAppendingString:NSUUID.UUID.UUIDString]] isDirectory:YES];
    AI7Store*s=[[AI7Store alloc]initWithRoot:root device:@"../TEST/1"];
    check([s.deviceRoot.path hasPrefix:root.path],@"device path contained in root");check([s stateForRecording:r].description&&[[s stateForRecording:r] isEqual:@"new"],@"absent files are new");
    NSError*e=nil;NSURL*stage=[s createStaging:&e];check(stage!=nil,@"create staging");
    [@"abcdef" writeToURL:[stage URLByAppendingPathComponent:@"recording.aac"] atomically:YES encoding:NSUTF8StringEncoding error:&e];
    [@"synthetic-mp3-data" writeToURL:[stage URLByAppendingPathComponent:@"recording.mp3"] atomically:YES encoding:NSUTF8StringEncoding error:&e];
    check([s publish:r staging:stage error:&e],@"publish complete export");check([[s stateForRecording:r] isEqual:@"local"],@"hash-verified export is local");
    AI7Recording*call=[AI7Recording new];call.identifier=r.identifier;call.byteCount=6;call.kind=0;check(![[s mp3URL:r] isEqual:[s mp3URL:call]],@"notes and calls separated");
    AI7Store*other=[[AI7Store alloc]initWithRoot:root device:@"SECOND"];check([[other stateForRecording:r] isEqual:@"new"],@"devices isolated");
    NSString*hash=[AI7Store hashFile:[s mp3URL:r]];stage=[s createStaging:&e];[@"abcdef" writeToURL:[stage URLByAppendingPathComponent:@"recording.aac"] atomically:YES encoding:NSUTF8StringEncoding error:&e];[@"replacement" writeToURL:[stage URLByAppendingPathComponent:@"recording.mp3"] atomically:YES encoding:NSUTF8StringEncoding error:&e];
    check(![s publish:r staging:stage error:&e],@"never overwrite an existing recording");check([hash isEqual:[AI7Store hashFile:[s mp3URL:r]]],@"existing bytes preserved");
    [@"modified" writeToURL:[s mp3URL:r] atomically:YES encoding:NSUTF8StringEncoding error:&e];check([[s stateForRecording:r] isEqual:@"conflict"],@"detect local corruption");
    r.byteCount=7;check(![s publish:r staging:stage error:&e],@"reject incomplete download");r.byteCount=0;check([[s stateForRecording:r] isEqual:@"empty"],@"empty entry cannot transfer");
    [NSFileManager.defaultManager removeItemAtURL:root error:nil];puts("PASS: protocol validation, safe paths, identity, byte counts, hash verification and no-overwrite storage");
}return 0;}
