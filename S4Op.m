//
// Copyright 2013 Aaron Sittig. All rights reserved
// All code is governed by the BSD-style license at
// http://github.com/aaron--/s4
//

#import "S4Op.h"
#import "S4.h"
#import "S4Bucket.h"
#import "NSData+.h"
#import "XMLElement.h"
#if TARGET_OS_IPHONE
#import <MobileCoreServices/MobileCoreServices.h>
#endif

static NSString*        kS3Endpoint = @"s3.amazonaws.com";
static NSMutableArray*  sActiveOps = nil;

@interface S4Op ()
@property (readwrite) NSData*               data;
@property (readwrite) NSDictionary*         head;
@property (readwrite) NSArray*              list;
@property (readwrite) NSArray*              buckets;
@property (readwrite) NSInteger             status;
@property (readwrite) NSString*             uri;
@property (readwrite) NSError*              error;
@property (weak)      S4*                   s4;
@property (weak)      S4Bucket*             bucket;
@property (strong)    NSMutableDictionary*  headers;
@property (strong)    NSData*               putData;
@property (strong)    NSMutableData*        getData;
@property (strong)    NSURLConnection*      connection;
@property (strong)    NSHTTPURLResponse*    response;
@property (strong)    NSMutableArray*       partial;
@property (assign)    BOOL                  wantsList;
@property (assign)    BOOL                  wantsBuckets;
@property (copy)      NSString*             prefix;
@property (copy)      S4OpDone              whenDone;
@end

@implementation S4Op

+ (S4Op*)opWithMethod:(NSString*)method
                   s4:(S4*)s4
               bucket:(S4Bucket*)bucket
                  uri:(NSString*)uri
                 data:(NSData*)data
             whenDone:(S4OpDone)block
{
  return [[S4Op alloc] initWithMethod:method
                                   s4:s4
                               bucket:bucket
                                  uri:uri
                                 data:data
                             whenDone:block];
}

+ (NSArray*)activeOps
{
  return (NSArray*)sActiveOps;
}

- (id)initWithMethod:(NSString*)method
                  s4:(S4*)s4
              bucket:(S4Bucket*)bucket
                 uri:(NSString*)uri
                data:(NSData*)data
            whenDone:(S4OpDone)block
{
  if(!(self = [super init])) return nil;
  
  _method   = [method copy];
  _uri      = [uri copy];
  _putData  = data;
  _s4       = s4;
  _bucket   = bucket;
  _headers  = [NSMutableDictionary dictionary];
  _whenDone = [block copy];
  
  sActiveOps = sActiveOps ? sActiveOps : [NSMutableArray array];
  [sActiveOps addObject:self];
  
  [self go]; return self;
}

- (void)go
{
  NSString*               pathBucket;
  NSString*               remotePath;
  NSMutableURLRequest*		request;
  NSString*               dateHeader;
  NSString*               typeHeader;
  NSDateFormatter*        formatter;
  
  // Require PUT, GET or HEAD
  if(!([self.method isEqualToString:@"PUT"] ||
       [self.method isEqualToString:@"GET"] ||
       [self.method isEqualToString:@"HEAD"]))
    return;
  
  // Create HTTP Request
  pathBucket = self.bucket ? [NSString stringWithFormat:@"%@.", self.bucket.name] : @"";
  remotePath = [NSString stringWithFormat:@"http://%@%@/%@", pathBucket, kS3Endpoint, self.uri];
	request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:remotePath]
                                    cachePolicy:NSURLRequestReloadIgnoringCacheData
                                timeoutInterval:60.0];
  NSLog(@"S4Op: %@", remotePath);
  
  // Request Date
  formatter = [NSDateFormatter new];
  formatter.timeZone = [NSTimeZone timeZoneWithName:@"GMT"];
  formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
  formatter.dateFormat = @"EEE, dd MMM yyyy HH:mm:ss z";
  dateHeader = [formatter stringFromDate:[NSDate date]];
  
  // Set Request Headers
  typeHeader = [self.method isEqualToString:@"PUT"] ?
  [self mimeTypeForFilename:self.uri] : nil;
  if(typeHeader) self.headers[@"Content-Type"] = typeHeader;
  self.headers[@"Date"] = dateHeader;
  self.headers[@"Authorization"] = [self authorization];
  
  // Set Method
	[request setHTTPMethod:self.method];
  [request setAllHTTPHeaderFields:self.headers];
	[request setValue:@"S4/1.0" forHTTPHeaderField:@"User-Agent"];
  
  // We Always want storage for incoming response body data
  self.getData = [NSMutableData data];
  
  // If PUT and have putData, set PUT content
  if([self.method isEqualToString:@"PUT"] && self.putData)
    request.HTTPBody = self.putData;
  
  // If Get and Requesting object list
  if([self.method isEqualToString:@"GET"])
    self.wantsList = [self.uri hasPrefix:@"?"] ||
    ([self.uri hasPrefix:@"/"] && self.uri.length == 1);
  
  if([self.method isEqualToString:@"GET"])
    self.wantsBuckets = [self.uri isEqualToString:@""] && !self.bucket;
  
  // Run HTTP Request
  self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
}

- (void)retryList
{
  NSString*   marker;
  
  // Reset Connection
	self.connection = nil;
	self.response = nil;
	self.getData = nil;
  
  // Clear Headers
  [self.headers removeAllObjects];
  
  // Marker is Prefix + Last known Key
  marker = [self.prefix stringByAppendingString:[self.partial lastObject]];
  
  // Reset URI and Go
  self.uri = [NSString stringWithFormat:@"?prefix=%@&marker=%@", self.prefix, marker];
  [self go];
}

- (NSString*)authorization
{
  NSArray*    splitURI;
  NSString*   shortURI;
  NSString*   bucket;
  NSString*   resource;
  NSString*   stringToSign;
  NSString*   amazonHeaders = @"";
  NSData*     digest;
  NSString*   auth;
  NSString*   key;
  NSString*   secret;
  
  splitURI = [self.uri componentsSeparatedByString:@"?"];
  shortURI = splitURI[0];
  bucket   = self.bucket.name ? [NSString stringWithFormat:@"/%@", self.bucket.name] : @"";
  resource = [NSString stringWithFormat:@"%@/%@", bucket, shortURI];
  stringToSign = [NSString stringWithFormat:@"%@\n%@\n%@\n%@\n%@%@",
                  self.method,
                  self.headers[@"Content-MD5"] ? self.headers[@"Content-MD5"] : @"",
                  self.headers[@"Content-Type"] ? self.headers[@"Content-Type"] : @"",
                  self.headers[@"Date"] ? self.headers[@"Date"] : @"",
                  amazonHeaders,
                  resource];
  key = self.s4.key ? self.s4.key : self.bucket.s4.key;
  secret = self.s4.secret ? self.s4.secret : self.bucket.s4.secret;
  digest = [[stringToSign dataUsingEncoding:NSUTF8StringEncoding] sha1HMacWithKey:secret];
  auth = [NSString stringWithFormat:@"AWS %@:%@", key, [digest base64]];
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
	// check that the response object is an http response object
  if(![response isMemberOfClass:[NSHTTPURLResponse class]])
    NSLog(@"S4Op Error: Expected response of class NSHTTPURLResponse");
  
  // this method is called when the server has determined that it
	// has enough information to create the NSURLResponse
	// it can be called multiple times, for example in the case of a
	// redirect, so each time we reset the data.
	self.getData.length = 0;
	self.response = (NSHTTPURLResponse*)response;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	// append the new data to the receivedData
	[self.getData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError*)error
{
	// release the connection, and the data object
	self.connection = nil;
	self.response = nil;
	self.getData = nil;
  
	// Tell Delegate
  [self tellError:error];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	NSError*  error = nil;
  NSError*  bucketError = nil;
  NSError*  listError = nil;
  
  // Save Headers
  self.head = [self.response.allHeaderFields copy];
  
  // Save Status Code
  self.status = self.response.statusCode;
  
  // Status Error
  [self statusError:&error];
  if(error) {
    self.connection = nil;
    self.response = nil;
    return [self tellError:error];
  }
  
  // Parse Error
  [self parseError:&error];
  if(error) {
    self.connection = nil;
    self.response = nil;
    return [self tellError:error];
  }
  
  // Parse Bucket List
  if(self.wantsBuckets)
    [self parseBucketResults:&bucketError];
  if(bucketError) {
    self.connection = nil;
    self.response = nil;
    return [self tellError:bucketError];
  }
  
  // Parse List Results
  if(self.wantsList)
    [self parseListResults:&listError]; // modifies self.list and .partial
  if(listError) {
    self.connection = nil;
    self.response = nil;
    return [self tellError:listError];
  }
  
  // On Partial List, Update URI and Retry
  if(!self.list && self.partial)
  { [self retryList]; return; }
  
  // Save Data (make public)
  // TODO: make sure this doesn't copy data
  self.data = self.getData;
  
  //NSLog(@"Data: %@", [NSString stringWithData:self.data encoding:NSUTF8StringEncoding]);
  
  // Clean Up
	self.connection = nil;
	self.response = nil;
	
  // Tell Delegate
	[self tellDone];
}

#pragma mark -

- (void)tellDone
{
  if(self.whenDone)
    self.whenDone(self, nil);
  
  [sActiveOps removeObject:self];
}

- (void)tellError:(NSError*)error
{
  NSLog(@"S4Op ERROR: %@", error);
  
  // Save Error
  self.error = error;
  if(self.whenDone)
    self.whenDone(self, error);
  [sActiveOps removeObject:self];
}

#pragma mark -

- (void)statusError:(NSError**)error
{
  // Only Process HEAD status errors for now
  if(![self.method isEqualToString:@"HEAD"]) return;
  
  // Allow Whole 200 Range
  if(self.status >= 200 && self.status < 300) return;
  
  // Build Status Error
  // TODO: Build Message from HTTP Status http://en.wikipedia.org/wiki/List_of_HTTP_status_codes
  if(error)*error = [NSError errorWithDomain:S4.errorDomain code:2 userInfo:
                     @{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"HTTP Status %ld", (long)self.status]}];
  
}

- (void)parseError:(NSError**)error
{
  XMLElement*       root;
  NSError*          parseError;
  NSString*         codeString;
  NSString*         messageString;
  NSString*         errorString;
  
  // Parse XML
  if(error)*error = nil;
  root = [XMLElement rootWithData:self.getData error:&parseError];
  
  // Ignore Non-xml docs
  // TODO: Confirm that libxml doesn't choke or burn CPU and Mem on big image files
  if(parseError) return;
  
  // Only Process Error roots
  if(![root.name isEqualToString:@"Error"]) return;
  
  // Get Code and Message Strings
  codeString    = [root find:@"Code"].cdata;
  messageString = [root find:@"Message"].cdata;
  errorString   = [NSString stringWithFormat:@"%@: %@", codeString, messageString];
  
  // Generate Error
  if(error)*error = [NSError errorWithDomain:S4.errorDomain code:1 userInfo:
                     @{NSLocalizedDescriptionKey: errorString}];
}

- (void)parseListResults:(NSError**)error
{
  XMLElement*       root;
  NSError*          parseError;
  NSString*         queryPrefix;
  BOOL              truncated;
  NSMutableArray*   list;
  
  // Parse XML
  if(error)*error = nil;
  root = [XMLElement rootWithData:self.getData error:&parseError];
  if(parseError){ if(error)*error = parseError; return; };
  
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
  if(!self.partial) self.partial = [NSMutableArray array];
  
  // Save Prefix in case of partial list
  self.prefix = queryPrefix;
  
  // Extend Partial List
  [self.partial addObjectsFromArray:list];
  
  // If Not Trucated Set Final List and Clear Partial
  if(!truncated) {
    self.list = self.partial;
    self.partial = nil;
  }
}

- (void)parseBucketResults:(NSError**)error
{
  XMLElement*       root;
  NSError*          parseError;
  NSMutableArray*   buckets;
  
  // Parse XML
  if(error)*error = nil;
  root = [XMLElement rootWithData:self.getData error:&parseError];
  if(parseError){ if(error)*error = parseError; return; };
  
  // Only Process ListAllMyBucketsResult roots
  if(![root.name isEqual:@"ListAllMyBucketsResult"]) return;
  
  // Get Buckets
  buckets = [NSMutableArray array];
  [root find:@"Buckets.Bucket.Name" forEach:^(XMLElement* element) {
    [buckets addObject:element.cdata];
  }];
  
  // Add Buckets to Op Results
  self.buckets = buckets;
}

@end
