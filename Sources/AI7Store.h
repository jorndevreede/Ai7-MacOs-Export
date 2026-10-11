#import <Foundation/Foundation.h>
#import "AI7Protocol.h"
NS_ASSUME_NONNULL_BEGIN
@interface AI7Store : NSObject
@property(readonly) NSURL *root;
@property(readonly) NSURL *deviceRoot;
- (instancetype)initWithRoot:(NSURL *)root device:(NSString *)device;
- (NSString *)stateForRecording:(AI7Recording *)recording;
- (NSURL *)mp3URL:(AI7Recording *)recording;
- (NSURL *)rawURL:(AI7Recording *)recording;
- (nullable NSURL *)createStaging:(NSError **)error;
- (BOOL)publish:(AI7Recording *)recording staging:(NSURL *)staging error:(NSError **)error;
+ (nullable NSString *)hashFile:(NSURL *)url;
@end
NS_ASSUME_NONNULL_END
