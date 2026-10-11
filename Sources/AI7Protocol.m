#import "AI7Protocol.h"
static uint32_t BE32(const uint8_t *b) { return ((uint32_t)b[0]<<24)|((uint32_t)b[1]<<16)|((uint32_t)b[2]<<8)|b[3]; }
@implementation AI7Recording
- (instancetype)init { if((self=[super init])){_identifier=@"";_localState=@"new";}return self; }
- (NSString *)category {return self.kind==0?@"Calls":@"Notes";}
- (NSString *)key {return [NSString stringWithFormat:@"%@-%u",self.identifier,self.kind];}
- (NSString *)displayDate {
    if(self.identifier.length!=14)return self.identifier;
    NSString *s=self.identifier;
    return [NSString stringWithFormat:@"%@-%@-%@  %@:%@:%@",[s substringToIndex:4],[s substringWithRange:NSMakeRange(4,2)],[s substringWithRange:NSMakeRange(6,2)],[s substringWithRange:NSMakeRange(8,2)],[s substringWithRange:NSMakeRange(10,2)],[s substringFromIndex:12]];
}
@end
@implementation AI7Protocol
+ (BOOL)isValidIdentifier:(NSString *)s {
    return s.length==14 && [s rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789"].invertedSet].location==NSNotFound;
}
+ (NSData *)command:(uint8_t)command payload:(NSData *)payload {
    if(payload.length>255)return nil;
    uint8_t h[]={0xca,0xac,command,(uint8_t)payload.length};
    NSMutableData *d=[NSMutableData dataWithBytes:h length:4];if(payload)[d appendData:payload];return d;
}
+ (NSData *)download:(NSString *)s {
    if(![self isValidIdentifier:s])return nil;
    NSMutableData *d=[[s dataUsingEncoding:NSASCIIStringEncoding] mutableCopy];uint32_t zero=0;[d appendBytes:&zero length:4];return [self command:8 payload:d];
}
+ (NSData *)deleteRecording:(NSString *)s {
    if(![self isValidIdentifier:s])return nil;
    // BOT command enum 21 maps to wire 0x0a. Payload is only the 14-byte ID.
    return [self command:0x0a payload:[s dataUsingEncoding:NSASCIIStringEncoding]];
}
+ (NSDictionary *)response:(NSData *)d {
    if(d.length<4)return nil;const uint8_t *b=d.bytes;
    if(b[0]!=0xac||b[1]!=0xca||d.length!=4+(NSUInteger)b[3])return nil;
    return @{@"command":@(b[2]),@"payload":[d subdataWithRange:NSMakeRange(4,b[3])]};
}
+ (AI7Recording *)recordingFromPayload:(NSData *)d {
    if(d.length!=24)return nil;const uint8_t*b=d.bytes;if(b[0]!=0)return nil;
    NSString*s=[[NSString alloc]initWithBytes:b+1 length:14 encoding:NSASCIIStringEncoding];
    if(![self isValidIdentifier:s]||b[23]>1)return nil;
    AI7Recording*r=[AI7Recording new];r.identifier=s;r.byteCount=BE32(b+15);r.seconds=BE32(b+19);r.kind=b[23];return r;
}
+ (NSString *)safeComponent:(NSString *)value {
    NSMutableString*s=[NSMutableString new];NSCharacterSet *allowed=[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"];
    for(NSUInteger i=0;i<MIN(value.length,80);i++){unichar c=[value characterAtIndex:i];[s appendFormat:@"%C",(unichar)([allowed characterIsMember:c]?c:'_')];}
    return s.length?s:@"unknown";
}
@end
