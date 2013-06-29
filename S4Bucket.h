//
//  S4Bucket
//
//  S4Bucket represents a bucket on S3 and can be
//  used to create tasks that require a bucket, like
//  object GETs and PUTs.
//

#import "S4Task.h"
@class S4;

@interface S4Bucket : NSObject

+ (S4Bucket*)bucketWithName:(NSString*)name s4:(S4*)s4;

- (S4GetTask*)get:(NSString*)uri;
- (S4HeadTask*)head:(NSString*)uri;
- (S4ListTask*)list:(NSString*)prefix;
- (S4ListTask*)listDeep:(NSString*)prefix;
- (S4PutTask*)put:(NSString*)uri data:(NSData*)data;

@property (readonly) S4*        s4;
@property (readonly) NSString*  name;

@end
