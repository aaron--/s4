//
//  S4Op
//
//  The S4Op class is internal to the S4 library. It
//  should not be instantiated directly.
//
//  Each S4Op instance encapsulates an http request
//  (or a series of requests for file lists) and relies
//  on blocks to notify calling code of completion. Use
//  factory methods to create instances and use blocks
//  to connect calling context to callback context.
//

@class S4Bucket, S4Op, S4;
typedef void(^S4OpDone)(S4Op* op, NSError* error);


@interface S4Op : NSObject

+ (S4Op*)opWithMethod:(NSString*)method
                   s4:(S4*)s4
               bucket:(S4Bucket*)bucket
                  uri:(NSString*)uri
                 data:(NSData*)data
             whenDone:(S4OpDone)block;
+ (NSArray*)activeOps;

@property (readonly) NSData*        data;
@property (readonly) NSDictionary*  head;
@property (readonly) NSArray*       list;
@property (readonly) NSArray*       buckets;
@property (readonly) NSInteger      status;
@property (readonly) NSString*      method;
@property (readonly) NSString*      uri;
@property (readonly) NSError*       error;

@end
