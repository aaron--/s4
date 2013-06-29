//
//  S4
//
//  S4 is a block based Cocoa / Objective-C client that
//  helps you make requests to Amazon Web Services S3,
//  and supports these operations:
//
//  GET Service
//  GET Bucket
//  GET Object
//  PUT Object
//  HEAD Object
//
//  S4 also provides convenience methods to ease listing
//  keys by using directory semantics, breaking on /,
//  and supporting recursive listing.
//
//  Some operations, like bucket list operations, that
//  require multiple calls to get the full list are hidden
//  behind a simplified asynchronous interface to make
//  them appear like a single operation.
//
//  Not all operations can report progress accurately, but
//  most long running operations like GETs and PUTs of
//  large objects report accurately.
//
//  All operations in S4 are represented by a task. To run
//  an operation, create the task using an S4 or S4Bucket
//  instance, and set both the onDone and onError block
//  properties.
//
//  Some errors reported by S4 are thin wrappers around
//  corresponding S3 errors. Others occur because of misuse
//  of the S4 library itself. Some S3 errors are never
//  passed through to you, either because the operations
//  that cause them are not supported, or because S4 hides
//  the error for convenience.
//
//  Authorization is not managed for you beyond reporting
//  errors when authorization fails.
//
//  S4 requires the XMLElement library available at
//  https://github.com/aaron--/xmlelement and must be
//  compiled with XCode 4.2 for ARC support.
//

#import "S4Task.h"
#import "S4Bucket.h"

@interface S4 : NSObject

+ (S4*)s4WithKey:(NSString*)key secret:(NSString*)secret;

+ (NSString*)errorDomain;
- (S4AuthorizeTask*)authorize;
- (S4GetBucketsTask*)getBuckets;

@property (readonly) NSString*    key;
@property (readonly) NSString*    secret;
@property (readonly) NSArray*     tasks;

@end

enum : NSInteger {
  S4ErrorCodeBadParameter = 1,   // API Errors
  S4ErrorCodeNetworkNotAvailable,
  S4ErrorCodeBadServerReponse,
  S4ErrorCodeUnknownError,
  S4ErrorCodeAccessDenied = 100, // Service Errors
  S4ErrorCodeAccountProblem,
  S4ErrorCodeInternalError,
  S4ErrorCodeInvalidAccessKeyId,
  S4ErrorCodeInvalidArgument,
  S4ErrorCodeInvalidBucketName,
  S4ErrorCodeInvalidBucketState,
  S4ErrorCodeInvalidDigest,
  S4ErrorCodeInvalidObjectState,
  S4ErrorCodeInvalidPayer,
  S4ErrorCodeInvalidRange,
  S4ErrorCodeInvalidSecurity,
  S4ErrorCodeMaxMessageLengthExceeded,
  S4ErrorCodeMaxPostPreDataLengthExceededError,
  S4ErrorCodeMissingContentLength,
  S4ErrorCodeNoSuchBucket,
  S4ErrorCodeNoSuchKey,
  S4ErrorCodeNotSignedUp,
  S4ErrorCodeOperationAborted,
  S4ErrorCodePermanentRedirect,
  S4ErrorCodePreconditionFailed,
  S4ErrorCodeRequestTimeout,
  S4ErrorCodeRequestTimeTooSkewed,
  S4ErrorCodeServiceUnavailable,
  S4ErrorCodeSlowDown,  // Will move retry internal eventually
  S4ErrorCodeTooManyBuckets
};
