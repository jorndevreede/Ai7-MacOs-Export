#import "AI7Store.h"
#import <CommonCrypto/CommonDigest.h>
#import <errno.h>
#import <fcntl.h>
#import <unistd.h>
#import <sys/stat.h>
#import <copyfile.h>
typedef struct {BOOL ok;unsigned long long size;long long sec;long long nsec;unsigned long long fileID;unsigned long long device;} AI7Stamp;
static AI7Stamp AI7StampAt(NSURL *url) {
    struct stat st;AI7Stamp s={0};
    if(!url||stat(url.fileSystemRepresentation,&st)!=0)return s;
    s.ok=YES;s.size=(unsigned long long)st.st_size;s.sec=(long long)st.st_mtimespec.tv_sec;s.nsec=(long long)st.st_mtimespec.tv_nsec;s.fileID=(unsigned long long)st.st_ino;s.device=(unsigned long long)st.st_dev;return s;
}
static BOOL AI7StampSame(AI7Stamp a,AI7Stamp b) {
    return a.ok&&b.ok&&a.size==b.size&&a.sec==b.sec&&a.nsec==b.nsec&&a.fileID==b.fileID&&a.device==b.device;
}
static NSString *AI7Dec(unsigned long long v) {return [NSString stringWithFormat:@"%llu",v];}
static NSString *AI7SDec(long long v) {return [NSString stringWithFormat:@"%lld",v];}
static NSDictionary *AI7StampJSON(AI7Stamp s) {
    return @{@"size":AI7Dec(s.size),@"mtime_sec":AI7SDec(s.sec),@"mtime_nsec":AI7SDec(s.nsec),@"file_id":AI7Dec(s.fileID),@"device":AI7Dec(s.device)};
}
static BOOL AI7StampMatches(id json,AI7Stamp s) {
    if(![json isKindOfClass:NSDictionary.class]||!s.ok)return NO;
    NSDictionary *j=json;
    return [j[@"size"] isEqual:AI7Dec(s.size)]&&[j[@"mtime_sec"] isEqual:AI7SDec(s.sec)]&&[j[@"mtime_nsec"] isEqual:AI7SDec(s.nsec)]&&[j[@"file_id"] isEqual:AI7Dec(s.fileID)]&&[j[@"device"] isEqual:AI7Dec(s.device)];
}
static NSDictionary *AI7JSONDictionary(NSURL *url) {
    NSData *data=[NSData dataWithContentsOfURL:url];if(!data)return nil;
    id object=[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    return [object isKindOfClass:NSDictionary.class]?object:nil;
}
// Publish a complete JSON file under its final name. A crash leaves only a temp file, which readers ignore.
static BOOL AI7WriteJSONAtomic(NSURL *url,NSDictionary *object) {
    NSData *data=[NSJSONSerialization dataWithJSONObject:object options:0 error:NULL];
    if(!data||!url)return NO;
    NSURL *directory=url.URLByDeletingLastPathComponent;
    if(![NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:NULL])return NO;
    NSURL *temp=[directory URLByAppendingPathComponent:[NSString stringWithFormat:@".%@.%@.tmp",url.lastPathComponent,NSUUID.UUID.UUIDString]];
    int fd=open(temp.fileSystemRepresentation,O_CREAT|O_EXCL|O_WRONLY,0644);
    if(fd<0)return NO;
    const uint8_t *bytes=data.bytes;NSUInteger left=data.length;BOOL ok=YES;
    while(left){ssize_t n=write(fd,bytes,left);if(n<0){if(errno==EINTR)continue;ok=NO;break;}if(n==0){ok=NO;break;}bytes+=n;left-=(NSUInteger)n;}
    if(ok&&fsync(fd)!=0)ok=NO;
    if(close(fd)!=0)ok=NO;
    if(!ok||rename(temp.fileSystemRepresentation,url.fileSystemRepresentation)!=0){unlink(temp.fileSystemRepresentation);return NO;}
    return YES;
}
static NSString *AI7CachedState(NSDictionary *cache,AI7Stamp raw,AI7Stamp mp3,NSDictionary *receipt,unsigned long long byteCount) {
    if(![cache isKindOfClass:NSDictionary.class])return nil;
    id state=cache[@"state"];
    if(![state isEqual:@"local"]&&![state isEqual:@"conflict"])return nil;
    if(![cache[@"byte_count"] isKindOfClass:NSNumber.class]||[cache[@"byte_count"] unsignedLongLongValue]!=byteCount)return nil;
    id receiptRaw=receipt[@"aac_sha256"],receiptMP3=receipt[@"mp3_sha256"];
    if(![receiptRaw isKindOfClass:NSString.class]||![receiptMP3 isKindOfClass:NSString.class])return nil;
    if(![cache[@"receipt_aac_sha256"] isEqual:receiptRaw]||![cache[@"receipt_mp3_sha256"] isEqual:receiptMP3])return nil;
    if(![cache[@"aac_sha256"] isKindOfClass:NSString.class]||![cache[@"mp3_sha256"] isKindOfClass:NSString.class])return nil;
    if(!AI7StampMatches(cache[@"aac"],raw)||!AI7StampMatches(cache[@"mp3"],mp3))return nil;
    if([state isEqual:@"local"]&&(![cache[@"aac_sha256"] isEqual:receiptRaw]||![cache[@"mp3_sha256"] isEqual:receiptMP3]))return nil;
    return state;
}
@implementation AI7Store
- (instancetype)initWithRoot:(NSURL *)root device:(NSString *)device {
    if((self=[super init])){_root=root;_deviceRoot=[root URLByAppendingPathComponent:[@"Ai7-" stringByAppendingString:[AI7Protocol safeComponent:device]] isDirectory:YES];}return self;
}
- (NSURL *)mp3URL:(AI7Recording *)r {return [[self.deviceRoot URLByAppendingPathComponent:r.category isDirectory:YES] URLByAppendingPathComponent:[r.identifier stringByAppendingPathExtension:@"mp3"]];}
- (NSURL *)rawURL:(AI7Recording *)r {return [[[self.deviceRoot URLByAppendingPathComponent:@"Originals" isDirectory:YES] URLByAppendingPathComponent:r.category isDirectory:YES] URLByAppendingPathComponent:[r.identifier stringByAppendingPathExtension:@"aac"]];}
- (NSURL *)receiptURL:(AI7Recording *)r {return [[self.deviceRoot URLByAppendingPathComponent:@".receipts" isDirectory:YES] URLByAppendingPathComponent:[r.key stringByAppendingPathExtension:@"json"]];}
- (NSURL *)fingerprintURL:(AI7Recording *)r {return [[self.deviceRoot URLByAppendingPathComponent:@".receipts" isDirectory:YES] URLByAppendingPathComponent:[r.key stringByAppendingPathExtension:@"fingerprint.json"]];}
+ (NSString *)hashFile:(NSURL *)u {
    NSInputStream*s=[NSInputStream inputStreamWithURL:u];[s open];CC_SHA256_CTX ctx;CC_SHA256_Init(&ctx);uint8_t buf[65536];NSInteger n;
    while((n=[s read:buf maxLength:sizeof(buf)])>0)CC_SHA256_Update(&ctx,buf,(CC_LONG)n);
    [s close];if(n<0)return nil;uint8_t hash[CC_SHA256_DIGEST_LENGTH];CC_SHA256_Final(hash,&ctx);NSMutableString*out=[NSMutableString new];for(int i=0;i<32;i++)[out appendFormat:@"%02x",hash[i]];return out;
}
- (void)writeFingerprintForRecording:(AI7Recording *)r state:(NSString *)state aacHash:(NSString *)aacHash mp3Hash:(NSString *)mp3Hash receipt:(NSDictionary *)receipt matchRaw:(AI7Stamp)rawMatch matchMP3:(AI7Stamp)mp3Match {
    if(![state isEqual:@"local"]&&![state isEqual:@"conflict"])return;
    if(![aacHash isKindOfClass:NSString.class]||![mp3Hash isKindOfClass:NSString.class])return;
    id receiptRaw=receipt[@"aac_sha256"],receiptMP3=receipt[@"mp3_sha256"];
    if(![receiptRaw isKindOfClass:NSString.class]||![receiptMP3 isKindOfClass:NSString.class])return;
    AI7Stamp raw=AI7StampAt([self rawURL:r]),mp3=AI7StampAt([self mp3URL:r]);
    if(!AI7StampSame(raw,rawMatch)||!AI7StampSame(mp3,mp3Match)||raw.size!=r.byteCount)return;
    NSDictionary *cache=@{@"state":state,@"byte_count":@(r.byteCount),@"aac_sha256":aacHash,@"mp3_sha256":mp3Hash,@"receipt_aac_sha256":receiptRaw,@"receipt_mp3_sha256":receiptMP3,@"aac":AI7StampJSON(raw),@"mp3":AI7StampJSON(mp3)};
    AI7WriteJSONAtomic([self fingerprintURL:r],cache);
}
- (nullable NSString *)stateForRecording:(AI7Recording *)r quick:(BOOL)quick {
    if(!r.byteCount)return @"empty";
    NSFileManager *fm=NSFileManager.defaultManager;
    NSURL *mp3=[self mp3URL:r],*raw=[self rawURL:r];
    BOOL hasMP3=[fm fileExistsAtPath:mp3.path],hasRaw=[fm fileExistsAtPath:raw.path];
    NSData *receiptData=[NSData dataWithContentsOfURL:[self receiptURL:r]];
    id parsed=receiptData?[NSJSONSerialization JSONObjectWithData:receiptData options:0 error:NULL]:nil;
    NSDictionary *receipt=[parsed isKindOfClass:NSDictionary.class]?parsed:nil;
    if(!hasMP3&&!hasRaw&&!receiptData)return @"new";
    if(!hasMP3)return @"incomplete";
    if(!receipt)return @"local (unverified)";
    if([receipt[@"size"] unsignedLongLongValue]!=r.byteCount)return @"conflict";
    AI7Stamp rawStamp=AI7StampAt(raw),mp3Stamp=AI7StampAt(mp3);
    if(!hasRaw||!rawStamp.ok||rawStamp.size!=r.byteCount||!mp3Stamp.ok)return @"conflict";
    if(quick)return AI7CachedState(AI7JSONDictionary([self fingerprintURL:r]),rawStamp,mp3Stamp,receipt,r.byteCount);
    NSString *aacHash=[AI7Store hashFile:raw],*mp3Hash=[AI7Store hashFile:mp3];
    if(!aacHash||!mp3Hash)return @"conflict";
    AI7Stamp rawAfter=AI7StampAt(raw),mp3After=AI7StampAt(mp3);
    NSString *state=[receipt[@"aac_sha256"] isEqual:aacHash]&&[receipt[@"mp3_sha256"] isEqual:mp3Hash]?@"local":@"conflict";
    if(AI7StampSame(rawStamp,rawAfter)&&AI7StampSame(mp3Stamp,mp3After))[self writeFingerprintForRecording:r state:state aacHash:aacHash mp3Hash:mp3Hash receipt:receipt matchRaw:rawAfter matchMP3:mp3After];
    return state;
}
- (NSString *)stateForRecording:(AI7Recording *)r {return [self stateForRecording:r quick:NO]?:@"conflict";}
- (nullable NSString *)quickStateForRecording:(AI7Recording *)r {return [self stateForRecording:r quick:YES];}
- (NSURL *)createStaging:(NSError **)error {
    NSURL*u=[[self.deviceRoot URLByAppendingPathComponent:@".incomplete" isDirectory:YES] URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
    return [NSFileManager.defaultManager createDirectoryAtURL:u withIntermediateDirectories:YES attributes:nil error:error]?u:nil;
}
- (BOOL)publish:(AI7Recording *)r staging:(NSURL *)staging error:(NSError **)error {
    NSFileManager*fm=NSFileManager.defaultManager;NSURL*raw=[staging URLByAppendingPathComponent:@"recording.aac"],*mp3=[staging URLByAppendingPathComponent:@"recording.mp3"];
    NSNumber*size=[fm attributesOfItemAtPath:raw.path error:error][NSFileSize];
    if(size.unsignedLongLongValue!=r.byteCount){if(error)*error=[NSError errorWithDomain:@"AI7Store" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Incomplete source recording."}];return NO;}
    NSString*sourceHash=[AI7Store hashFile:raw],*mp3Hash=[AI7Store hashFile:mp3];
    if(!sourceHash||!mp3Hash){if(error)*error=[NSError errorWithDomain:@"AI7Store" code:2 userInfo:@{NSLocalizedDescriptionKey:@"Could not verify the exported files."}];return NO;}
    NSURL*destRaw=[self rawURL:r],*destMP3=[self mp3URL:r],*receipt=[self receiptURL:r];
    for(NSURL*u in @[destRaw,destMP3,receipt])if(![fm createDirectoryAtURL:u.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:error])return NO;
    // Exclusive copies support APFS and removable filesystems. A receipt is published last.
    if(copyfile(raw.fileSystemRepresentation,destRaw.fileSystemRepresentation,NULL,COPYFILE_DATA|COPYFILE_EXCL)!=0){if(error)*error=[NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];return NO;}
    if(copyfile(mp3.fileSystemRepresentation,destMP3.fileSystemRepresentation,NULL,COPYFILE_DATA|COPYFILE_EXCL)!=0){int e=errno;unlink(destRaw.fileSystemRepresentation);if(error)*error=[NSError errorWithDomain:NSPOSIXErrorDomain code:e userInfo:nil];return NO;}
    NSDictionary*j=@{@"size":@(r.byteCount),@"aac_sha256":sourceHash,@"mp3_sha256":mp3Hash,@"identifier":r.identifier,@"kind":@(r.kind),@"exported_at":[[NSISO8601DateFormatter new] stringFromDate:NSDate.date]};
    NSData*json=[NSJSONSerialization dataWithJSONObject:j options:NSJSONWritingPrettyPrinted error:error];
    if(!json||![json writeToURL:receipt options:NSDataWritingWithoutOverwriting error:error])return NO;
    AI7Stamp rawStamp=AI7StampAt(destRaw),mp3Stamp=AI7StampAt(destMP3);
    [self writeFingerprintForRecording:r state:@"local" aacHash:sourceHash mp3Hash:mp3Hash receipt:j matchRaw:rawStamp matchMP3:mp3Stamp];
    [fm removeItemAtURL:staging error:nil];return YES;
}
@end
