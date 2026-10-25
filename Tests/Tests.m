#import <Foundation/Foundation.h>
#import <fcntl.h>
#import <unistd.h>
#import <sys/stat.h>
#import "AI7Protocol.h"
#import "AI7Store.h"
#import "AI7USB.h"
static void check(BOOL pass,NSString *message){if(!pass){fprintf(stderr,"FAIL: %s\n",message.UTF8String);exit(1);}}
static NSURL *fingerprintURL(AI7Store *s,AI7Recording *r){return [[s.deviceRoot URLByAppendingPathComponent:@".receipts"] URLByAppendingPathComponent:[r.key stringByAppendingPathExtension:@"fingerprint.json"]];}
static struct timespec fileMtime(const char *path){struct stat st;check(stat(path,&st)==0,@"stat mtime");return st.st_mtimespec;}
static void restoreMtime(const char *path,struct timespec mtime){struct stat st;check(stat(path,&st)==0,@"stat before mtime restore");struct timespec ts[2]={st.st_atimespec,mtime};check(utimensat(AT_FDCWD,path,ts,0)==0,@"restore mtime");}
static void publishText(AI7Store *s,AI7Recording *r,NSString *raw,NSString *mp3){NSError *e=nil;NSURL *stage=[s createStaging:&e];check(stage!=nil,@"cache-test staging");check([raw writeToURL:[stage URLByAppendingPathComponent:@"recording.aac"] atomically:YES encoding:NSUTF8StringEncoding error:&e],@"cache-test raw");check([mp3 writeToURL:[stage URLByAppendingPathComponent:@"recording.mp3"] atomically:YES encoding:NSUTF8StringEncoding error:&e],@"cache-test mp3");check([s publish:r staging:stage error:&e],e.localizedDescription?:@"cache-test publish");}
static BOOL writeCache(AI7Store *s,AI7Recording *r,NSString *text){NSError *e=nil;return [text writeToURL:fingerprintURL(s,r) atomically:NO encoding:NSUTF8StringEncoding error:&e];}
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
    r.byteCount=6;r.kind=1;
    NSURL*source=[AI7USB sourceForRecording:r root:root];
    [@"abcdef" writeToURL:source atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSURL*copied=[root URLByAppendingPathComponent:@"usb-copy.aac"];[NSData.data writeToURL:copied atomically:YES];
    check([AI7USB matchesRecording:r root:root],@"USB source matches BLE size and identifier");
    check([AI7USB copyRecording:r root:root toEmptyFile:copied error:&e],@"USB complete copy");
    check([[AI7Store hashFile:copied] isEqual:[AI7Store hashFile:source]],@"USB copy byte-for-byte identical");
    check(![AI7USB copyRecording:r root:root toEmptyFile:copied error:&e],@"USB destination never overwritten");
    r.byteCount=7;check(![AI7USB matchesRecording:r root:root],@"changed USB size rejected");r.byteCount=6;
    [NSFileManager.defaultManager removeItemAtURL:source error:nil];
    check(![AI7USB matchesRecording:r root:root],@"missing USB source rejected");
    [NSFileManager.defaultManager createSymbolicLinkAtURL:source withDestinationURL:copied error:nil];
    check(![AI7USB matchesRecording:r root:root],@"USB symlink rejected");
    AI7Recording*fresh=[AI7Recording new];fresh.identifier=@"20260303120000";fresh.kind=1;fresh.byteCount=4;
    check([[s quickStateForRecording:fresh] isEqual:@"new"],@"quick check sees absent files as new");fresh.byteCount=0;check([[s quickStateForRecording:fresh] isEqual:@"empty"],@"quick check sees empty entries");
    AI7Recording*c=[AI7Recording new];c.identifier=@"20260202120000";c.kind=1;c.byteCount=6;publishText(s,c,@"abcdef",@"synthetic-mp3-data");
    NSURL*cacheURL=fingerprintURL(s,c);NSError*ce=nil;NSDictionary*cache=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:cacheURL] options:0 error:&ce];
    check([cache[@"state"] isEqual:@"local"],@"publish writes a local fingerprint");
    check([cache[@"aac"][@"size"] isKindOfClass:NSString.class]&&[cache[@"mp3"][@"size"] length]>0,@"cache records file size");
    check([cache[@"aac"][@"mtime_sec"] length]>0&&[cache[@"mp3"][@"mtime_nsec"] isKindOfClass:NSString.class],@"cache records mtime");
    check([cache[@"aac"][@"file_id"] length]>0&&[cache[@"mp3"][@"file_id"] length]>0,@"cache records file id");
    NSURL*receiptURL=[[s.deviceRoot URLByAppendingPathComponent:@".receipts"] URLByAppendingPathComponent:[c.key stringByAppendingPathExtension:@"json"]];
    NSDictionary*receipt=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:receiptURL] options:0 error:&ce];
    check([receipt isKindOfClass:NSDictionary.class]&&[receipt[@"aac_sha256"] isKindOfClass:NSString.class]&&receipt[@"file_id"]==nil,@"receipt keeps hashes and gains no cache fields");
    for(NSString*key in receipt)check([@[@"size",@"aac_sha256",@"mp3_sha256",@"identifier",@"kind",@"exported_at"] containsObject:key],@"receipt format unchanged");
    check([[s quickStateForRecording:c] isEqual:@"local"],@"cache hit");
    uint32_t savedCount=c.byteCount;c.byteCount=5;check([[s quickStateForRecording:c] isEqual:@"conflict"],@"recorder size mismatch is conflict");c.byteCount=savedCount;check([[s quickStateForRecording:c] isEqual:@"local"],@"restored recorder size uses the cache");
    NSData*receiptBytes=[NSData dataWithContentsOfURL:receiptURL];check([@"not-json" writeToURL:receiptURL atomically:NO encoding:NSUTF8StringEncoding error:&ce],@"corrupt receipt");
    check([[s quickStateForRecording:c] isEqual:@"local (unverified)"],@"broken receipt is not a cache hit");
    check([receiptBytes writeToURL:receiptURL options:0 error:&ce],@"restore receipt");check([[s quickStateForRecording:c] isEqual:@"local"],@"restored receipt hits the cache again");
    NSURL*cMP3=[s mp3URL:c],*cRaw=[s rawURL:c];const char*mp3Path=cMP3.fileSystemRepresentation;const char*rawPath=cRaw.fileSystemRepresentation;
    struct timespec mp3Time=fileMtime(mp3Path);struct timespec rawTime=fileMtime(rawPath);
    struct timespec shifted=mp3Time;shifted.tv_sec+=10;restoreMtime(mp3Path,shifted);check([s quickStateForRecording:c]==nil,@"mp3 mtime change invalidates the cache");restoreMtime(mp3Path,mp3Time);check([[s quickStateForRecording:c] isEqual:@"local"],@"restored mp3 mtime is a cache hit");
    shifted=rawTime;shifted.tv_sec+=10;restoreMtime(rawPath,shifted);check([s quickStateForRecording:c]==nil,@"aac mtime change invalidates the cache");restoreMtime(rawPath,rawTime);check([[s quickStateForRecording:c] isEqual:@"local"],@"restored aac mtime is a cache hit");
    NSURL*junk=[[cacheURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:[NSString stringWithFormat:@".%@.%@.tmp",cacheURL.lastPathComponent,NSUUID.UUID.UUIDString]];
    check([@"{" writeToURL:junk atomically:NO encoding:NSUTF8StringEncoding error:&ce],@"plant cache temp");check([[s quickStateForRecording:c] isEqual:@"local"],@"temp file is not read as the cache");
    check([NSFileManager.defaultManager removeItemAtURL:junk error:&ce],@"remove planted temp");
    check([NSFileManager.defaultManager removeItemAtURL:cacheURL error:&ce],@"remove fingerprint");check([s quickStateForRecording:c]==nil,@"missing cache needs a thorough check");
    NSData*receiptBefore=[NSData dataWithContentsOfURL:receiptURL];check([[s stateForRecording:c] isEqual:@"local"],@"missing cache falls back to SHA-256");
    check([receiptBefore isEqualToData:[NSData dataWithContentsOfURL:receiptURL]],@"thorough check does not rewrite the receipt");check([[s quickStateForRecording:c] isEqual:@"local"],@"thorough check rebuilds the cache");
    check(writeCache(s,c,@"{"),@"write truncated cache");check([s quickStateForRecording:c]==nil,@"truncated cache ignored");
    check(writeCache(s,c,@"[]"),@"write array cache");check([s quickStateForRecording:c]==nil,@"non-object cache ignored");
    check(writeCache(s,c,@"{}" ),@"write incomplete cache");check([s quickStateForRecording:c]==nil,@"incomplete cache ignored");
    check([[s stateForRecording:c] isEqual:@"local"],@"broken cache falls back to SHA-256");check([[s quickStateForRecording:c] isEqual:@"local"],@"broken-cache fallback rebuilds the cache");
    NSArray*entries=[NSFileManager.defaultManager contentsOfDirectoryAtURL:cacheURL.URLByDeletingLastPathComponent includingPropertiesForKeys:nil options:0 error:&ce];
    check(entries!=nil,@"list receipt directory");
    for(NSURL*u in entries)check([u.lastPathComponent rangeOfString:@".tmp"].location==NSNotFound,@"atomic cache write leaves no temp file");
    NSData*mp3Bytes=[NSData dataWithContentsOfURL:[s mp3URL:c]];struct stat beforeID;check(stat(mp3Path,&beforeID)==0,@"stat before replace");
    NSURL*replacement=[[s mp3URL:c].URLByDeletingLastPathComponent URLByAppendingPathComponent:[[s mp3URL:c].lastPathComponent stringByAppendingString:@".replacement"]];
    check([mp3Bytes writeToURL:replacement options:0 error:&ce],@"write replacement mp3");check(rename(replacement.fileSystemRepresentation,mp3Path)==0,@"rename over mp3");
    struct stat afterID;check(stat(mp3Path,&afterID)==0,@"stat after replace");check(beforeID.st_ino!=afterID.st_ino,@"rename changes file id");
    restoreMtime(mp3Path,mp3Time);check([s quickStateForRecording:c]==nil,@"file id change invalidates the cache");
    check([[s stateForRecording:c] isEqual:@"local"],@"same bytes stay local after a thorough check");
    int grown=open(mp3Path,O_WRONLY|O_APPEND);check(grown>=0,@"open mp3 to grow");char extra='Z';check(write(grown,&extra,1)==1,@"grow mp3");close(grown);
    check([s quickStateForRecording:c]==nil,@"mp3 size change invalidates the cache");check([[s stateForRecording:c] isEqual:@"conflict"],@"changed mp3 size is conflict");
    AI7Recording*sized=[AI7Recording new];sized.identifier=@"20260203120000";sized.kind=1;sized.byteCount=6;publishText(s,sized,@"abcdef",@"synthetic-mp3-data");
    int rawfd=open([s rawURL:sized].fileSystemRepresentation,O_WRONLY|O_APPEND);check(rawfd>=0,@"open aac to grow");check(write(rawfd,&extra,1)==1,@"grow aac");close(rawfd);
    check([[s quickStateForRecording:sized] isEqual:@"conflict"],@"aac size change is not a stale local cache hit");check([[s stateForRecording:sized] isEqual:@"conflict"],@"changed aac size stays conflict");
    AI7Recording*wipe=[AI7Recording new];wipe.identifier=@"20260204120000";wipe.kind=1;wipe.byteCount=6;publishText(s,wipe,@"abcdef",@"synthetic-mp3-data");
    NSURL*wipeURL=[s mp3URL:wipe];const char*wipePath=wipeURL.fileSystemRepresentation;struct stat wipeBefore;check(stat(wipePath,&wipeBefore)==0,@"stat delete-path file");struct timespec wipeTime=wipeBefore.st_mtimespec;
    int tamper=open(wipePath,O_WRONLY);check(tamper>=0,@"open mp3 for in-place tamper");unsigned char flipped=0;check(pread(tamper,&flipped,1,0)==1,@"read byte");flipped^=0xff;check(pwrite(tamper,&flipped,1,0)==1,@"tamper one byte");close(tamper);
    struct stat wipeAfter;check(stat(wipePath,&wipeAfter)==0,@"stat tampered file");check(wipeBefore.st_ino==wipeAfter.st_ino&&wipeBefore.st_size==wipeAfter.st_size,@"tamper keeps file id and size");
    restoreMtime(wipePath,wipeTime);check([[s quickStateForRecording:wipe] isEqual:@"local"],@"unchanged size, mtime and file id still cache-hit");
    check([[s stateForRecording:wipe] isEqual:@"conflict"],@"delete verification always recomputes SHA-256");
    [NSFileManager.defaultManager removeItemAtURL:root error:nil];puts("PASS: protocol validation, safe paths, identity, byte counts, hash verification, fingerprint cache, no-overwrite storage and USB copy validation");
}return 0;}
