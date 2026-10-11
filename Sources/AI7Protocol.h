#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface AI7Recording : NSObject
@property(copy) NSString *identifier;
@property uint32_t byteCount;
@property uint32_t seconds;
@property uint8_t kind;
@property BOOL selected;
@property(copy) NSString *localState;
@property(readonly) NSString *key;
@property(readonly) NSString *category;
@property(readonly) NSString *displayDate;
@end
@interface AI7Protocol : NSObject
+ (nullable NSData *)command:(uint8_t)command payload:(nullable NSData *)payload;
+ (BOOL)isValidIdentifier:(NSString *)identifier;
+ (nullable NSData *)download:(NSString *)identifier;
+ (nullable NSData *)deleteRecording:(NSString *)identifier;
+ (nullable NSDictionary *)response:(NSData *)data;
+ (nullable AI7Recording *)recordingFromPayload:(NSData *)payload;
+ (NSString *)safeComponent:(NSString *)value;
@end
NS_ASSUME_NONNULL_END
