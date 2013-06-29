//
// Copyright 2013 Aaron Sittig. All rights reserved
// All code is governed by the BSD-style license at
// http://github.com/aaron--/s4
//

#import "S4.h"

typedef void (^S4BlockOver)();

@interface S4Task (Internal)
+ (instancetype)taskWithMethod:(NSString*)method
                        bucket:(NSString*)bucket
                           uri:(NSString*)uri
                          data:(NSData*)data
                           key:(NSString*)key
                        secret:(NSString*)secret
                      delegate:(id)delegate;
@property (copy) S4BlockOver  onOver;
@end

@interface S4 ()
@property (readwrite) NSArray*          buckets;
@property (readwrite) BOOL              authorized;
@property (readwrite) BOOL              authFailed;
@property (readwrite) NSString*         key;
@property (readwrite) NSString*         secret;
@property (readwrite) NSArray*          tasks;
@end

@implementation S4

+ (S4*)s4WithKey:(NSString*)key secret:(NSString*)secret
{
  return [[S4 alloc] initWithKey:key secret:secret];
}

- (id)initWithKey:(NSString*)key secret:(NSString*)secret
{
  if(!(self = [super init])) return nil;
  self.key    = key;
  self.secret = secret;
  self.tasks  = @[];
  return self;
}

#pragma mark - Tasks

- (S4AuthorizeTask*)authorize
{
  return [S4AuthorizeTask taskWithMethod:@"GET"
                                  bucket:nil
                                     uri:@""
                                    data:nil
                                     key:self.key
                                  secret:self.secret
                                delegate:self];
}

- (S4GetBucketsTask*)getBuckets
{
  return [S4GetBucketsTask taskWithMethod:@"GET"
                                   bucket:nil
                                      uri:@""
                                     data:nil
                                      key:self.key
                                   secret:self.secret
                                 delegate:self];
}

#pragma mark - Task Delegate

- (void)taskStarted:(S4Task*)task
{
  assert(![self.tasks containsObject:task]);
  self.tasks = [self.tasks arrayByAddingObject:task];
}

- (void)taskEnded:(S4Task*)task
{
  NSMutableArray*   newArray;
  return;
  assert([self.tasks containsObject:task]);
  newArray = [NSMutableArray arrayWithArray:self.tasks];
  [newArray removeObject:task];
  self.tasks = [NSArray arrayWithArray:newArray];
}

#pragma mark - Errors

+ (NSString*)errorDomain
{
  return @"com.makesay.S4.error";
}

+ (NSError*)buildError:(NSInteger)code string:(NSString*)message underlying:(NSError*)underlying
{
  NSMutableDictionary*  info;
  
  info = [NSMutableDictionary dictionary];
  if(message)[info setObject:message forKey:NSLocalizedDescriptionKey];
  if(underlying)[info setObject:underlying forKey:NSUnderlyingErrorKey];
  return [NSError errorWithDomain:S4.errorDomain code:code userInfo:info];
}

+ (NSError*)badParameter:(NSString*)message
{
  return [S4 buildError:S4ErrorCodeBadParameter string:message underlying:nil];
}

+ (NSError*)networkNotAvailable:(NSError*)underlying
{
  return [S4 buildError:S4ErrorCodeNetworkNotAvailable string:@"Could not connect to the internet" underlying:underlying];
}

+ (NSError*)badServerResponse:(NSError*)underlying
{
  return [S4 buildError:S4ErrorCodeNetworkNotAvailable string:@"The Server response could not be understood" underlying:underlying];
}

+ (NSError*)errorWithS3Code:(NSString*)s3code
{
  NSString*   message;
  NSNumber*   codeNumber;
  NSInteger   code;
  
  message = [S4.errorMessageMap objectForKey:s3code];
  codeNumber = [S4.errorCodeMap objectForKey:s3code];
  code = !message ? S4ErrorCodeUnknownError : [codeNumber integerValue];
  message = !message ? s3code : message;
  
  return [S4 buildError:code string:message underlying:nil];
}

+ (NSDictionary*)errorMessageMap
{
  static NSDictionary* sErrorMessageMap = nil;
  
  if(!sErrorMessageMap) sErrorMessageMap = @{
    @"AccessDenied": @"Access Denied",
    @"AccountProblem": @"There is a problem with your AWS account that prevents the operation from completing successfully. Please use  Contact Us.",
    @"AmbiguousGrantByEmailAddress": @"The e-mail address you provided is associated with more than one account.",
    @"BadDigest": @"The Content-MD5 you specified did not match what we received.",
    @"BucketAlreadyExists": @"The requested bucket name is not available. The bucket namespace is shared by all users of the system. Please select a different name and try again.",
    @"BucketAlreadyOwnedByYou": @"Your previous request to create the named bucket succeeded and you already own it.",
    @"BucketNotEmpty": @"The bucket you tried to delete is not empty.",
    @"CredentialsNotSupported": @"This request does not support credentials.",
    @"CrossLocationLoggingProhibited": @"Cross location logging not allowed. Buckets in one geographic location cannot log information to a bucket in another location.",
    @"EntityTooSmall": @"Your proposed upload is smaller than the minimum allowed object size.",
    @"EntityTooLarge": @"Your proposed upload exceeds the maximum allowed object size.",
    @"ExpiredToken": @"The provided token has expired.",
    @"IllegalVersioningConfigurationException": @"Indicates that the Versioning configuration specified in the request is invalid.",
    @"IncompleteBody": @"You did not provide the number of bytes specified by the Content-Length HTTP header",
    @"IncorrectNumberOfFilesInPostRequest": @"POST requires exactly one file upload per request.",
    @"InlineDataTooLarge": @"Inline data exceeds the maximum allowed size.",
    @"InternalError": @"We encountered an internal error. Please try again.",
    @"InvalidAccessKeyId": @"The AWS Access Key Id you provided does not exist in our records.",
    @"InvalidAddressingHeader": @"You must specify the Anonymous role.",
    @"InvalidArgument": @"Invalid Argument",
    @"InvalidBucketName": @"The specified bucket is not valid.",
    @"InvalidBucketState": @"The request is not valid with the current state of the bucket.",
    @"InvalidDigest": @"The Content-MD5 you specified was an invalid.",
    @"InvalidLocationConstraint": @"The specified location constraint is not valid. For more information about Regions, see How to Select a Region for Your Buckets.",
    @"InvalidObjectState": @"The operation is not valid for the current state of the object.",
    @"InvalidPart": @"One or more of the specified parts could not be found. The part might not have been uploaded, or the specified entity tag might not have matched the part's entity tag.",
    @"InvalidPartOrder": @"The list of parts was not in ascending order.Parts list must specified in order by part number.",
    @"InvalidPayer": @"All access to this object has been disabled.",
    @"InvalidPolicyDocument": @"The content of the form does not meet the conditions specified in the policy document.",
    @"InvalidRange": @"The requested range cannot be satisfied.",
    @"InvalidRequest": @"SOAP requests must be made over an HTTPS connection.",
    @"InvalidSecurity": @"The provided security credentials are not valid.",
    @"InvalidSOAPRequest": @"The SOAP request body is invalid.",
    @"InvalidStorageClass": @"The storage class you specified is not valid.",
    @"InvalidTargetBucketForLogging": @"The target bucket for logging does not exist, is not owned by you, or does not have the appropriate grants for the log-delivery group.",
    @"InvalidToken": @"The provided token is malformed or otherwise invalid.",
    @"InvalidURI": @"Couldn't parse the specified URI.",
    @"KeyTooLong": @"Your key is too long.",
    @"MalformedACLError": @"The XML you provided was not well-formed or did not validate against our published schema.",
    @"MalformedPOSTRequest": @"The body of your POST request is not well-formed multipart/form-data.",
    @"MalformedXML": @"This happens when the user sends a malformed xml (xml that doesn't conform to the published xsd) for the configuration. The error message is, \"The XML you provided was not well-formed or did not validate against our published schema.\"",
    @"MaxMessageLengthExceeded": @"Your request was too big.",
    @"MaxPostPreDataLengthExceededError": @"Your POST request fields preceding the upload file were too large.",
    @"MetadataTooLarge": @"Your metadata headers exceed the maximum allowed metadata size.",
    @"MethodNotAllowed": @"The specified method is not allowed against this resource.",
    @"MissingAttachment": @"A SOAP attachment was expected, but none were found.",
    @"MissingContentLength": @"You must provide the Content-Length HTTP header.",
    @"MissingRequestBodyError": @"This happens when the user sends an empty xml document as a request. The error message is, \"Request body is empty.\"",
    @"MissingSecurityElement": @"The SOAP 1.1 request is missing a security element.",
    @"MissingSecurityHeader": @"Your request was missing a required header.",
    @"NoLoggingStatusForKey": @"There is no such thing as a logging status sub-resource for a key.",
    @"NoSuchBucket": @"The specified bucket does not exist.",
    @"NoSuchKey": @"The specified key does not exist.",
    @"NoSuchLifecycleConfiguration": @"The lifecycle configuration does not exist.",
    @"NoSuchUpload": @"The specified multipart upload does not exist. The upload ID might be invalid, or the multipart upload might have been aborted or completed.",
    @"NoSuchVersion": @"Indicates that the version ID specified in the request does not match an existing version.",
    @"NotImplemented": @"A header you provided implies functionality that is not implemented.",
    @"NotSignedUp": @"Your account is not signed up for the Amazon S3 service. You must sign up before you can use Amazon S3. You can sign up at the following URL: http://aws.amazon.com/s3",
    @"NotSuchBucketPolicy": @"The specified bucket does not have a bucket policy.",
    @"OperationAborted": @"A conflicting conditional operation is currently in progress against this resource. Please try again.",
    @"PermanentRedirect": @"The bucket you are attempting to access must be addressed using the specified endpoint. Please send all future requests to this endpoint.",
    @"PreconditionFailed": @"At least one of the preconditions you specified did not hold.",
    @"Redirect": @"Temporary redirect.",
    @"RestoreAlreadyInProgress": @"Object restore is already in progress.",
    @"RequestIsNotMultiPartContent": @"Bucket POST must be of the enclosure-type multipart/form-data.",
    @"RequestTimeout": @"Your socket connection to the server was not read from or written to within the timeout period.",
    @"RequestTimeTooSkewed": @"The difference between the request time and the server's time is too large.",
    @"RequestTorrentOfBucketError": @"Requesting the torrent file of a bucket is not permitted.",
    @"SignatureDoesNotMatch": @"The request signature we calculated does not match the signature you provided. Check your AWS Secret Access Key and signing method. For more information, see REST Authentication and SOAP Authentication for details.",
    @"ServiceUnavailable": @"Please reduce your request rate.",
    @"SlowDown": @"Please reduce your request rate.",
    @"TemporaryRedirect": @"You are being redirected to the bucket while DNS updates.",
    @"TokenRefreshRequired": @"The provided token must be refreshed.",
    @"TooManyBuckets": @"You have attempted to create more buckets than allowed.",
    @"UnexpectedContent": @"This request does not support content.",
    @"UnresolvableGrantByEmailAddress": @"The e-mail address you provided does not match any account on record.",
    @"UserKeyMustBeSpecified": @"The bucket POST must contain the specified field name. If it is specified, please check the order of the fields." };
  return sErrorMessageMap;
}

+ (NSDictionary*)errorCodeMap
{
  static NSDictionary*  sErrorCodeMap = nil;
  
  if(!sErrorCodeMap)
    sErrorCodeMap = @{
      @"AccessDenied" : [NSNumber numberWithInt:S4ErrorCodeAccessDenied],
      @"AccountProblem" : [NSNumber numberWithInt:S4ErrorCodeAccountProblem],
      @"InternalError" : [NSNumber numberWithInt:S4ErrorCodeInternalError],
      @"InvalidAccessKeyId" : [NSNumber numberWithInt:S4ErrorCodeInvalidAccessKeyId],
      @"InvalidArgument" : [NSNumber numberWithInt:S4ErrorCodeInvalidArgument],
      @"InvalidBucketName" : [NSNumber numberWithInt:S4ErrorCodeInvalidBucketName],
      @"InvalidBucketState" : [NSNumber numberWithInt:S4ErrorCodeInvalidBucketState],
      @"InvalidDigest" : [NSNumber numberWithInt:S4ErrorCodeInvalidDigest],
      @"InvalidObjectState" : [NSNumber numberWithInt:S4ErrorCodeInvalidObjectState],
      @"InvalidPayer" : [NSNumber numberWithInt:S4ErrorCodeInvalidPayer],
      @"InvalidRange" : [NSNumber numberWithInt:S4ErrorCodeInvalidRange],
      @"InvalidSecurity" : [NSNumber numberWithInt:S4ErrorCodeInvalidSecurity],
      @"MaxMessageLengthExceeded" : [NSNumber numberWithInt:S4ErrorCodeMaxMessageLengthExceeded],
      @"MaxPostPreDataLengthExceededError" : [NSNumber numberWithInt:S4ErrorCodeMaxPostPreDataLengthExceededError],
      @"MissingContentLength" : [NSNumber numberWithInt:S4ErrorCodeMissingContentLength],
      @"NoSuchBucket" : [NSNumber numberWithInt:S4ErrorCodeNoSuchBucket],
      @"NoSuchKey" : [NSNumber numberWithInt:S4ErrorCodeNoSuchKey],
      @"NotSignedUp" : [NSNumber numberWithInt:S4ErrorCodeNotSignedUp],
      @"OperationAborted" : [NSNumber numberWithInt:S4ErrorCodeOperationAborted],
      @"PermanentRedirect" : [NSNumber numberWithInt:S4ErrorCodePermanentRedirect],
      @"PreconditionFailed" : [NSNumber numberWithInt:S4ErrorCodePreconditionFailed],
      @"RequestTimeout" : [NSNumber numberWithInt:S4ErrorCodeRequestTimeout],
      @"RequestTimeTooSkewed" : [NSNumber numberWithInt:S4ErrorCodeRequestTimeTooSkewed],
      @"ServiceUnavailable" : [NSNumber numberWithInt:S4ErrorCodeServiceUnavailable],
      @"SlowDown" : [NSNumber numberWithInt:S4ErrorCodeSlowDown],
      @"TooManyBuckets" : [NSNumber numberWithInt:S4ErrorCodeTooManyBuckets] };
  return sErrorCodeMap;
}

@end


