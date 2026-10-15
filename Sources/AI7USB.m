#import "AI7USB.h"
@implementation AI7USB
+ (NSURL *)sourceForRecording:(AI7Recording *)r root:(NSURL *)root {
    if(![AI7Protocol isValidIdentifier:r.identifier]||r.kind>1)return nil;
    return [root URLByAppendingPathComponent:[NSString stringWithFormat:@"%@%@",r.kind?@"Note":@"Call",r.identifier]];
}
+ (BOOL)matchesRecording:(AI7Recording *)r root:(NSURL *)root {
    NSURL*u=[self sourceForRecording:r root:root];if(!u)return NO;
    NSDictionary*a=[NSFileManager.defaultManager attributesOfItemAtPath:u.path error:nil];
    return [a[NSFileType] isEqual:NSFileTypeRegular]&&[a[NSFileSize] unsignedLongLongValue]==r.byteCount;
}
+ (BOOL)copyRecording:(AI7Recording *)r root:(NSURL *)root toEmptyFile:(NSURL *)destination error:(NSError **)error {
    NSDictionary*a=[NSFileManager.defaultManager attributesOfItemAtPath:destination.path error:error];
    if(![self matchesRecording:r root:root]||![a[NSFileType] isEqual:NSFileTypeRegular]||[a[NSFileSize] unsignedLongLongValue]!=0){
        if(error)*error=[NSError errorWithDomain:@"Ai7USB" code:1 userInfo:@{NSLocalizedDescriptionKey:@"USB source changed, disappeared, or destination is not empty."}];return NO;
    }
    NSInputStream*input=[NSInputStream inputStreamWithURL:[self sourceForRecording:r root:root]];[input open];
    NSFileHandle*out=[NSFileHandle fileHandleForWritingToURL:destination error:error];
    uint8_t buffer[65536];NSUInteger count=0;BOOL ok=out!=nil;
    while(ok){NSInteger n=[input read:buffer maxLength:sizeof(buffer)];if(n<0){if(error)*error=input.streamError;ok=NO;break;}if(!n)break;
        if((NSUInteger)n>r.byteCount-count){ok=NO;break;}
        ok=[out writeData:[NSData dataWithBytes:buffer length:n] error:error];count+=n;
    }
    [input close];[out closeFile];ok=ok&&count==r.byteCount;
    if(!ok&&error&&!*error)*error=[NSError errorWithDomain:@"Ai7USB" code:2 userInfo:@{NSLocalizedDescriptionKey:@"Incomplete USB copy. No MP3 was published."}];return ok;
}
@end
