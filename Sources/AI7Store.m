#import "AI7Store.h"
#import <CommonCrypto/CommonDigest.h>
#import <fcntl.h>
#import <unistd.h>
#import <copyfile.h>
@implementation AI7Store
- (instancetype)initWithRoot:(NSURL *)root device:(NSString *)device {
    if((self=[super init])){_root=root;_deviceRoot=[root URLByAppendingPathComponent:[@"Ai7-" stringByAppendingString:[AI7Protocol safeComponent:device]] isDirectory:YES];}return self;
}
- (NSURL *)mp3URL:(AI7Recording *)r {return [[self.deviceRoot URLByAppendingPathComponent:r.category isDirectory:YES] URLByAppendingPathComponent:[r.identifier stringByAppendingPathExtension:@"mp3"]];}
- (NSURL *)rawURL:(AI7Recording *)r {return [[[self.deviceRoot URLByAppendingPathComponent:@"Originals" isDirectory:YES] URLByAppendingPathComponent:r.category isDirectory:YES] URLByAppendingPathComponent:[r.identifier stringByAppendingPathExtension:@"aac"]];}
- (NSURL *)receiptURL:(AI7Recording *)r {return [[self.deviceRoot URLByAppendingPathComponent:@".receipts" isDirectory:YES] URLByAppendingPathComponent:[r.key stringByAppendingPathExtension:@"json"]];}
+ (NSString *)hashFile:(NSURL *)u {
    NSInputStream*s=[NSInputStream inputStreamWithURL:u];[s open];CC_SHA256_CTX ctx;CC_SHA256_Init(&ctx);uint8_t buf[65536];NSInteger n;
    while((n=[s read:buf maxLength:sizeof(buf)])>0)CC_SHA256_Update(&ctx,buf,(CC_LONG)n);
    [s close];if(n<0)return nil;uint8_t hash[CC_SHA256_DIGEST_LENGTH];CC_SHA256_Final(hash,&ctx);NSMutableString*out=[NSMutableString new];for(int i=0;i<32;i++)[out appendFormat:@"%02x",hash[i]];return out;
}
- (NSString *)stateForRecording:(AI7Recording *)r {
    if(!r.byteCount)return @"empty";
    NSFileManager*fm=NSFileManager.defaultManager;NSURL*mp3=[self mp3URL:r],*raw=[self rawURL:r];
    BOOL hasMP3=[fm fileExistsAtPath:mp3.path],hasRaw=[fm fileExistsAtPath:raw.path];
    NSData*d=[NSData dataWithContentsOfURL:[self receiptURL:r]];NSDictionary*j=d?[NSJSONSerialization JSONObjectWithData:d options:0 error:nil]:nil;
    if(!hasMP3&&!hasRaw&&!d)return @"new";
    if(!hasMP3)return @"incomplete";
    if(![j isKindOfClass:NSDictionary.class])return @"local (unverified)";
    if([j[@"size"] unsignedLongLongValue]!=r.byteCount)return @"conflict";
    NSNumber*rawSize=[fm attributesOfItemAtPath:raw.path error:nil][NSFileSize];
    if(hasRaw&&rawSize.unsignedLongLongValue==r.byteCount&&[j[@"aac_sha256"] isEqual:[AI7Store hashFile:raw]]&&[j[@"mp3_sha256"] isEqual:[AI7Store hashFile:mp3]])return @"local";
    return @"conflict";
}
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
    [fm removeItemAtURL:staging error:nil];return YES;
}
@end
