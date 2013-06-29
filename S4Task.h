//
//  S4Task
//
//  S4Task represents a concurrent call to S3 and can be
//  cancelled and observed for progress updates by using
//  block properties. For example:
//
//  task = [self.s4 getBuckets];
//  task.onDone = ^(NSArray* buckets) {
//    self.buckets = buckets;
//  };
//  task.onError = ^(NSError* error) {
//    [self handleError:error];
//  };
//
//  Most S3 methods subclass S4Task with their own
//  completion handler block format since data returned
//  by different tasks varies.
//
//  Callback blocks are deallocated after firing so
//  circular references to objects captures by the
//  block closure are release when the task is over.
//
//  TODO: Cancelling Tasks does not work
//  TODO: Queue and run tasks on dispatch queue
//

typedef void (^S4BlockError)    (NSError* error);
typedef void (^S4BlockCancel)   ();
typedef void (^S4BlockUpdate)   (double progress);

@interface S4Task : NSObject

@property (copy) S4BlockError      onError;
@property (copy) S4BlockCancel     onCancel;
@property (copy) S4BlockUpdate     onUpdate;

@end


// Concrete Tasks

typedef void (^S4AuthorizeDone)  ();
typedef void (^S4GetBucketsDone) (NSArray* buckets);
typedef void (^S4BucketGetDone)  (NSData* data);
typedef void (^S4BucketHeadDone) (NSDictionary* head);
typedef void (^S4BucketListDone) (NSArray* list);
typedef void (^S4BucketPutDone)  ();

@interface S4AuthorizeTask : S4Task
@property (copy) S4AuthorizeDone   onDone;
@end

@interface S4GetBucketsTask : S4Task
@property (copy) S4GetBucketsDone  onDone;
@end

@interface S4GetTask : S4Task
@property (copy) S4BucketGetDone   onDone;
@end

@interface S4HeadTask : S4Task
@property (copy) S4BucketHeadDone  onDone;
@end

@interface S4ListTask : S4Task
@property (copy) S4BucketListDone  onDone;
@end

@interface S4PutTask : S4Task
@property (copy) S4BucketPutDone   onDone;
@end

