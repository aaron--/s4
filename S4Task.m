//
// Copyright 2013 Aaron Sittig. All rights reserved
// All code is governed by the BSD-style license at
// http://github.com/aaron--/s4
//

#import "S4Task.h"
#import "XMLElement.h"
#import "S4.h"
#if TARGET_OS_IPHONE
#import <MobileCoreServices/MobileCoreServices.h>
#endif

static NSString*    kS3Endpoint = @"s3.amazonaws.com";

@interface NSObject (S4TaskDelegate)
- (void)taskStarted:(S4Task*)task;
- (void)taskEnded:(S4Task*)task;
@end

@interface S4 (Internal)
+ (NSError*)badParameter:(NSString*)message;
+ (NSError*)networkNotAvailable:(NSError*)underlying;
+ (NSError*)badServerResponse:(NSError*)underlying;
+ (NSError*)errorWithS3Code:(NSString*)code;
@end

@interface S4Task ()
@property NSString*             method;
@property NSString*             bucket;
@property NSString*             uri;
@property NSString*             key;
@property NSString*             secret;
@property NSHTTPURLResponse*    response;
@property NSMutableData*        responseData;
@property NSDictionary*         responseHeaders;
@property NSMutableArray*       responseList;
@property NSMutableArray*       responsePartial;
@property NSString*             responsePrefix;
@property NSMutableArray*       responseBuckets;
@property NSInteger             responseStatus;
@property double                responseProgress;
@property NSURLConnection*      connection;
@property NSData*               requestData;
@property NSMutableDictionary*  requestHeaders;
@property BOOL                  requestedList;
@property BOOL                  requestedBuckets;
@property (weak) id             delegate;
@property NSString*             outcome;
@end

@implementation S4Task

+ (instancetype)taskWithMethod:(NSString*)method
                        bucket:(NSString*)bucket
                           uri:(NSString*)uri
                          data:(NSData*)data
                           key:(NSString*)key
                        secret:(NSString*)secret
                      delegate:(id)delegate
{
  return [[self alloc] initWithMethod:method
                               bucket:bucket
                                  uri:uri
                                 data:data
                                  key:key
                               secret:secret
                             delegate:delegate];
}

- (instancetype)initWithMethod:(NSString*)method
                        bucket:(NSString*)bucket
                           uri:(NSString*)uri
                          data:(NSData*)data
                           key:(NSString*)key
                        secret:(NSString*)secret
                      delegate:(id)delegate
{
  if(!(self = [super init])) return nil;
  
  self.method       = method;
  self.bucket       = bucket;
  self.uri          = uri;
  self.requestData  = data;
  self.key          = key;
  self.secret       = secret;
  self.delegate     = delegate;
  self.outcome      = @"";
  
  [self addObserver:self forKeyPath:@"onDone"];
  [self addObserver:self forKeyPath:@"onError"];
  
  // Notify Delegate
  if([self.delegate respondsToSelector:@selector(taskStarted:)])
    [self.delegate taskStarted:self];
  return self;
}

- (void)dealloc
{
  [self removeObserver:self forKeyPath:@"onDone"];
  [self removeObserver:self forKeyPath:@"onError"];
}

#pragma mark - Request

- (void)go
{
  NSString*               pathBucket;
  NSString*               remotePath;
  NSMutableURLRequest*		request;
  NSString*               dateHeader;
  NSString*               typeHeader;
  NSDateFormatter*        formatter;
  
  // Don't Allow Re-entry of Go
  if(self.connection)
    return [self tellError:[S4 badParameter:@"Go Called Twice... Odd"]];
  
  // Report Progress
  self.outcome = @"In Progress";
  
  // Require PUT, GET or HEAD
  if(!([self.method isEqualToString:@"PUT"] ||
       [self.method isEqualToString:@"GET"] ||
       [self.method isEqualToString:@"HEAD"]))
    return [self tellError:[S4 badParameter:@"Task HTTP Method Invalid"]];
  
  // Create HTTP Request
  pathBucket = self.bucket ? [NSString stringWithFormat:@"%@.", self.bucket] : @"";
  remotePath = [NSString stringWithFormat:@"http://%@%@/%@", pathBucket, kS3Endpoint, self.uri];
  request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:remotePath]
                                    cachePolicy:NSURLRequestReloadIgnoringCacheData
                                timeoutInterval:60.0];
  
  // Request Date Format
  formatter = [NSDateFormatter new];
  formatter.timeZone = [NSTimeZone timeZoneWithName:@"GMT"];
  formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
  formatter.dateFormat = @"EEE, dd MMM yyyy HH:mm:ss z";
  dateHeader = [formatter stringFromDate:[NSDate date]];
  
  // Request Headers
  self.requestHeaders = [NSMutableDictionary dictionary];
  typeHeader = [self.method isEqualToString:@"PUT"] ?
               [self mimeTypeForFilename:self.uri] : nil;
  if(typeHeader) self.requestHeaders[@"Content-Type"] = typeHeader;
  self.requestHeaders[@"Date"] = dateHeader;
  self.requestHeaders[@"Authorization"] = [self authorization];
  
  // Request Method
	[request setHTTPMethod:self.method];
  [request setAllHTTPHeaderFields:self.requestHeaders];
	[request setValue:@"S4/1.0" forHTTPHeaderField:@"User-Agent"];
  
  // We Always want storage for incoming response body data
  self.responseData = [NSMutableData data];
  
  // If PUT and have requestData, set PUT content
  if([self.method isEqual:@"PUT"] && self.requestData)
    request.HTTPBody = self.requestData;
  
  // If GET and Requesting object list
  if([self.method isEqual:@"GET"])
    self.requestedList = [self.uri hasPrefix:@"?"] ||
    ([self.uri hasPrefix:@"/"] && self.uri.length == 1);
  
  // If GET and Requesting Buckets
  if([self.method isEqual:@"GET"])
    self.requestedBuckets = [self.uri isEqual:@""] && !self.bucket;
    
  // Run HTTP Request
  self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
}

- (void)retryList
{
  NSString*   marker;
  
  // Reset Connection
	self.connection     = nil;
	self.response       = nil;
	self.responseData   = nil;
  self.requestHeaders = nil;
  
  // Marker is Prefix + Last known Key
  marker = [self.responsePrefix stringByAppendingString:[self.responsePartial lastObject]];
  
  // Reset URI and Go
  self.uri = [NSString stringWithFormat:@"?prefix=%@&marker=%@", self.responsePrefix, marker];
  [self go];
}

- (NSString*)authorization
{
  NSArray*    splitURI;
  NSString*   shortURI;
  NSString*   pathBucket;
  NSString*   resource;
  NSString*   stringToSign;
  NSString*   amazonHeaders = @"";
  NSData*     digest;
  NSString*   auth;
  
  splitURI   = [self.uri componentsSeparatedByString:@"?"];
  shortURI   = splitURI[0];
  pathBucket = self.bucket ? [NSString stringWithFormat:@"/%@", self.bucket] : @"";
  resource   = [NSString stringWithFormat:@"%@/%@", pathBucket, shortURI];
  stringToSign = [NSString stringWithFormat:@"%@\n%@\n%@\n%@\n%@%@",
                  self.method,
                  self.requestHeaders[@"Content-MD5"] ? self.requestHeaders[@"Content-MD5"] : @"",
                  self.requestHeaders[@"Content-Type"] ? self.requestHeaders[@"Content-Type"] : @"",
                  self.requestHeaders[@"Date"] ? self.requestHeaders[@"Date"] : @"",
                  amazonHeaders,
                  resource];
  digest = [[stringToSign dataUsingEncoding:NSUTF8StringEncoding] sha1HMacWithKey:self.secret];
  auth = [NSString stringWithFormat:@"AWS %@:%@", self.key, [digest base64]];
  return auth;
}

- (NSString*)mimeTypeForFilename:(NSString*)filename
{
  CFStringRef   uti;
  CFStringRef   mimeType;
  NSString*     mimeString;
  
  uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)[filename pathExtension], NULL);
  mimeType = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType);
  mimeString = mimeType ? [NSString stringWithString:(__bridge NSString*)mimeType] : nil;
  if(uti) CFRelease(uti);
  if(mimeType) CFRelease(mimeType);
  return mimeString;
}

#pragma mark - NSURLConnection Delegate

- (void)connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)response
{
	// Response must be NSHTTPURLResponse
  if(![response isMemberOfClass:[NSHTTPURLResponse class]])
    NSLog(@"S4Task Error: Expected response of class NSHTTPURLResponse");
  
  // Delegate method is called after each redirect, so reset the data
  // to start our final response handler with fresh data storage
	self.response = (NSHTTPURLResponse*)response;
	self.responseData.length = 0;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
  // Accumulate Response Data
	[self.responseData appendData:data];

	// Response Percentage
  if(self.response.expectedContentLength != -1) {
    self.responseProgress = (double)self.responseData.length /
                            (double)self.response.expectedContentLength;
    [self tellUpdate:self.responseProgress];
    
    // Report Progress
    self.outcome = [NSString stringWithFormat:@"In Progress %d%%", (int)(100.0 * self.responseProgress)];
  }
}

- (void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)error
{
	// Release the connection data storage
	self.connection     = nil;
	self.response       = nil;
	self.responseData   = nil;
  
	// Tell Delegate
  [self tellError:[S4 networkNotAvailable:error]];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	NSError*  error = nil;
  
  // Save Headers
  self.responseHeaders = [self.response.allHeaderFields copy];
  
  // Save Status Code
  self.responseStatus = self.response.statusCode;
  
  // Check Status Error
  [self checkStatusError:&error];
  if(error) return [self tellError:error];
  
  // Parse Response for Error
  [self parseError:&error];
  if(error) return [self tellError:error];
  
  // Parse Buckets
  if(self.requestedBuckets)
    [self parseBucketResults:&error];
  if(error) return [self tellError:error];
  
  // Parse List
  if(self.requestedList)
    [self parseListResults:&error]; // modifies self.list and .partial
  if(error) return [self tellError:error];
  
  // On Partial List, Update URI and Retry
  if(!self.responseList && self.responsePartial)
    return [self retryList];
  
  // Record Outcome
  self.outcome = [NSString stringWithFormat:@"%ld", (long)self.responseStatus];
  
  // Tell Blocks
	[self tellDone];
  
  // Wrap Up Task
  [self tellOver];
}


#pragma mark - Response

- (void)checkStatusError:(NSError**)error
{
  // Start Fresh
  if(error)*error = nil;

  // Only Process HEAD status errors for now
  if(![self.method isEqualToString:@"HEAD"]) return;
  
  // Allow Whole 200 Range
  if(self.responseStatus >= 200 && self.responseStatus < 300) return;
  
  // Build Status Error
  // TODO: Build Message from HTTP Status http://en.wikipedia.org/wiki/List_of_HTTP_status_codes
  if(error)*error = [NSError errorWithDomain:S4.errorDomain code:2 userInfo:
                     @{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"HTTP Status %ld", (long)self.responseStatus]}];
}

- (void)parseError:(NSError**)error
{
  XMLElement*       root;
  NSString*         magic;
  NSError*          parseError;
  NSString*         codeString;
  NSString*         messageString;
  NSString*         errorString;
  
  // Start Fresh
  if(error)*error = nil;
  
  // Sanity Check that Response is XML
  if(self.responseData.length < 5) return;
  magic = [[NSString alloc] initWithBytes:self.responseData.bytes
            length:5 encoding:NSUTF8StringEncoding];
  if(![magic isEqualToString:@"<?xml"]) return;

  // Parse XML
  root = [XMLElement rootWithData:self.responseData error:&parseError];
  if(parseError){ if(error)*error = [S4 badServerResponse:parseError]; return; }
  
  // Only Process Error roots
  if(![root.name isEqualToString:@"Error"]) return;
  
  // Get Code and Message Strings
  codeString    = [root find:@"Code"].cdata;
  messageString = [root find:@"Message"].cdata;
  errorString   = [NSString stringWithFormat:@"%@: %@", codeString, messageString];
  
  // Generate Error
  if(error)*error = [S4 errorWithS3Code:errorString];
}

- (void)parseListResults:(NSError**)error
{
  XMLElement*       root;
  NSError*          parseError;
  NSString*         queryPrefix;
  BOOL              truncated;
  NSMutableArray*   list;
  
  // Start Fresh
  if(error)*error = nil;

  // Parse XML
  root = [XMLElement rootWithData:self.responseData error:&parseError];
  if(parseError){ if(error)*error = [S4 badServerResponse:parseError]; return; }
  
  // Get Query Prefix
  queryPrefix = [root find:@"Prefix"].cdata;
  
  // Generate List of Prefixes
  list = [NSMutableArray array];
  [root find:@"CommonPrefixes" forEach:^(XMLElement* element)
   {
     NSString* commonPrefix = [element find:@"Prefix"].cdata;
     commonPrefix = [commonPrefix substringFromIndex:queryPrefix.length];
     commonPrefix = [commonPrefix hasSuffix:@"/"] ?
     [commonPrefix substringToIndex:commonPrefix.length - 1] :
     commonPrefix;
     [list addObject:commonPrefix];
   }];
  
  // Add List of Contents (omit names with . prefix)
  [root find:@"Contents" forEach:^(XMLElement* element)
   {
     NSString* keyPath = [element find:@"Key"].cdata;
     keyPath = [keyPath substringFromIndex:queryPrefix.length];
     if([keyPath hasPrefix:@"."]) return;
     if(keyPath.length == 0) return;
     [list addObject:keyPath];
   }];
  
  // Check for Truncation
  truncated = [[root find:@"IsTruncated"].cdata isEqual:@"true"];
  
  // Assume we're building a partial list
  if(!self.responsePartial) self.responsePartial = [NSMutableArray array];
  
  // Save Prefix in case of partial list
  self.responsePrefix = queryPrefix;
  
  // Extend Partial List
  [self.responsePartial addObjectsFromArray:list];
  
  // If Not Trucated Set Final List and Clear Partial
  if(!truncated) {
    self.responseList = self.responsePartial;
    self.responsePartial = nil;
  }
}

- (void)parseBucketResults:(NSError**)error
{
  XMLElement*       root;
  NSError*          parseError;
  NSMutableArray*   buckets;
  
  // Start Fresh
  if(error)*error = nil;
  
  // Parse XML
  root = [XMLElement rootWithData:self.responseData error:&parseError];
  if(parseError){ if(error)*error = [S4 badServerResponse:parseError]; return; }
  
  // Only Process ListAllMyBucketsResult roots
  if(![root.name isEqual:@"ListAllMyBucketsResult"]) return;
  
  // Get Buckets
  buckets = [NSMutableArray array];
  [root find:@"Buckets.Bucket.Name" forEach:^(XMLElement* element) {
    [buckets addObject:element.cdata];
  }];
  
  // Add Buckets to Op Results
  self.responseBuckets = buckets;
}

#pragma mark - Callback

- (void)tellDone
{
  // Override in Subclasses
}

- (void)tellError:(NSError*)error
{
  // Clean Up
	self.connection = nil;
	self.response = nil;
  
  // Record Outcome
  self.outcome = [NSString stringWithFormat:@"%ld %@", (long)self.responseStatus, [error description]];
	
  // Call Back
  if(self.onError)
    self.onError(error);
  
  // Wrap Up Task
  [self tellOver];
}

- (void)tellCancel
{
  // Clean Up
	self.connection = nil;
	self.response = nil;
	
  // Call Back
  if(self.onCancel)
    self.onCancel();

  // Wrap Up Task
  [self tellOver];
}

- (void)tellUpdate:(double)progress
{
  // Periodic Update
  if(self.onUpdate)
    self.onUpdate(progress);
}

- (void)tellOver
{
  // Alert Delegate
  if([self.delegate respondsToSelector:@selector(taskEnded:)])
    [self.delegate taskEnded:self];
  
  // Release Callbacks
  [self setValue:nil forKey:@"onDone"];
  self.onCancel = nil;
  self.onError = nil;
  self.onUpdate = nil;
  
  // Release Big Memory Chunks
	self.connection = nil;
	self.response = nil;
  self.responseData = nil;
  self.responseList = nil;
  self.responseBuckets = nil;
}

#pragma mark - Observe

- (void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
  // self.onDone
  if(object == self && [keyPath isEqual:@"onDone"])
    if([self valueForKey:@"onDone"] && self.onError)
      [self go];

  // self.onError
  if(object == self && [keyPath isEqual:@"onError"])
    if([self valueForKey:@"onDone"] && self.onError)
      [self go];
}

@end

#pragma mark - Concrete Tasks

@implementation S4AuthorizeTask

- (void)tellDone
{
  if(self.onDone) self.onDone();
}

@end

@implementation S4GetBucketsTask

- (void)tellDone
{
  if(self.onDone) self.onDone(self.responseBuckets);
}

@end

@implementation S4GetTask

- (void)tellDone
{
  if(self.onDone) self.onDone(self.responseData);
}

@end

@implementation S4HeadTask

- (void)tellDone
{
  if(self.onDone) self.onDone(self.responseHeaders);
}

@end

@implementation S4ListTask

- (void)tellDone
{
  if(self.onDone) self.onDone(self.responseList);
}

@end

@implementation S4PutTask

- (void)tellDone
{
  if(self.onDone) self.onDone();
}

@end
