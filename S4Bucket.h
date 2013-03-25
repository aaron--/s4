//
//  S4Bucket
//
//  Use and S4 instance to create an S4Bucket which can be
//  used to get S3 resources. Buckets are read only for now.
//  Being deleted and modifying metadata are not implemented.
//

@class S4, S4Op;
typedef void(^S4BucketGetDone)(NSData* data, NSError* error);
typedef void(^S4BucketHeadDone)(NSDictionary* head, NSError* error);
typedef void(^S4BucketListDone)(NSArray* list, NSError* error);
typedef void(^S4BucketPutDone)(NSError* error);


@interface S4Bucket : NSObject

+ (S4Bucket*)bucketWithName:(NSString*)name s4:(S4*)s4;

- (void)get:(NSString*)uri whenDone:(S4BucketGetDone)block;
- (void)head:(NSString*)uri whenDone:(S4BucketHeadDone)block;
- (void)list:(NSString*)prefix whenDone:(S4BucketListDone)block;
- (void)listDeep:(NSString*)prefix whenDone:(S4BucketListDone)block;
- (void)put:(NSString*)uri data:(NSData*)data whenDone:(S4BucketPutDone)block;

@property (readonly) S4*        s4;
@property (readonly) NSString*  name;

@end
