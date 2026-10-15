#import <Foundation/Foundation.h>
#import "AI7Protocol.h"
@interface AI7USB : NSObject
+ (NSURL *)sourceForRecording:(AI7Recording *)recording root:(NSURL *)root;
+ (BOOL)matchesRecording:(AI7Recording *)recording root:(NSURL *)root;
+ (BOOL)copyRecording:(AI7Recording *)recording root:(NSURL *)root toEmptyFile:(NSURL *)destination error:(NSError **)error;
@end
