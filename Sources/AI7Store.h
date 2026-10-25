#import <Foundation/Foundation.h>
#import "AI7Protocol.h"
NS_ASSUME_NONNULL_BEGIN
@interface AI7Store : NSObject
@property(readonly) NSURL *root;
@property(readonly) NSURL *deviceRoot;
- (instancetype)initWithRoot:(NSURL *)root device:(NSString *)device;
// Always recomputes SHA-256 when local versus conflict depends on file bytes. Delete confirmation uses this.
- (NSString *)stateForRecording:(AI7Recording *)recording;
// Cache hit when size, modification time and file ID match. Never reads audio. Nil means a SHA-256 is still required.
- (nullable NSString *)quickStateForRecording:(AI7Recording *)recording;
- (NSURL *)mp3URL:(AI7Recording *)recording;
- (NSURL *)rawURL:(AI7Recording *)recording;
- (nullable NSURL *)createStaging:(NSError **)error;
- (BOOL)publish:(AI7Recording *)recording staging:(NSURL *)staging error:(NSError **)error;
+ (nullable NSString *)hashFile:(NSURL *)url;
@end
NS_ASSUME_NONNULL_END
