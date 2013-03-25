//
//  S4
//  
//  The S4 Library establishes that AWS credentials are valid
//  and caches the list of available buckets. Some operations
//  may require multiple API calls so all operations are async
//  Authorization happens automatically on instantiation but
//  can be joined and watched with a call to -authorize
//
//  TODO: This whole description is wrong at this point
//  TODO: Do style pass on whole S4 library
//

typedef void(^S4AuthorizeDone)(BOOL authorized, NSError* error);
typedef void(^S4GetBucketsDone)(NSArray* buckets, NSError* error);


@interface S4 : NSObject

+ (S4*)s4WithKey:(NSString*)key secret:(NSString*)secret;
+ (NSString*)errorDomain;

- (void)authorize:(S4AuthorizeDone)block;
- (void)getBuckets:(S4GetBucketsDone)block;

@property (readonly) NSString*    key;
@property (readonly) NSString*    secret;

@end

#import "S4Bucket.h"
