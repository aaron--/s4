//
// Copyright 2013 Aaron Sittig. All rights reserved
// All code is governed by the BSD-style license at
// http://github.com/aaron--/s4
//

#import "S4Bucket.h"
#import "S4.h"

@interface S4Task (Internal)
+ (instancetype)taskWithMethod:(NSString*)method
                        bucket:(NSString*)bucket
                           uri:(NSString*)uri
                          data:(NSData*)data
                           key:(NSString*)key
                        secret:(NSString*)secret
                      delegate:(id)delegate;
@end

@interface S4Bucket ()
@property (readwrite) S4*         s4;
@property (readwrite) NSString*   name;
@end

@implementation S4Bucket

+ (S4Bucket*)bucketWithName:(NSString*)name s4:(S4*)s4
{
  return [[S4Bucket alloc] initWithName:name s4:s4];
}

- (id)initWithName:(NSString*)name s4:(S4*)s4
{
  if(!(self = [super init])) return nil;
  self.s4   = s4;
  self.name = name;
  return self;
}

#pragma mark -

- (S4GetTask*)get:(NSString*)uri
{
  return [S4GetTask taskWithMethod:@"GET"
                            bucket:self.name
                               uri:uri
                              data:nil
                               key:self.s4.key
                            secret:self.s4.secret
                          delegate:self.s4];
}

- (S4HeadTask*)head:(NSString*)uri
{
  return [S4HeadTask taskWithMethod:@"HEAD"
                             bucket:self.name
                                uri:uri
                               data:nil
                                key:self.s4.key
                             secret:self.s4.secret
                           delegate:self.s4];
}

- (S4ListTask*)list:(NSString*)prefix
{
  NSString*   uri;

  uri = @"?delimiter=/";
  uri = prefix ? [NSString stringWithFormat:@"?prefix=%@&delimiter=/", prefix] : uri;
  return [S4ListTask taskWithMethod:@"GET"
                             bucket:self.name
                                uri:uri
                               data:nil
                                key:self.s4.key
                             secret:self.s4.secret
                           delegate:self.s4];
}

- (S4ListTask*)listDeep:(NSString*)prefix
{
  NSString*   uri;
  
  // TODO: sanity check prefix
  uri = [NSString stringWithFormat:@"?prefix=%@", prefix];
  return [S4ListTask taskWithMethod:@"GET"
                             bucket:self.name
                                uri:uri
                               data:nil
                                key:self.s4.key
                             secret:self.s4.secret
                           delegate:self.s4];
}

- (S4PutTask*)put:(NSString*)uri data:(NSData*)data
{
  return [S4PutTask taskWithMethod:@"PUT"
                            bucket:self.name
                               uri:uri
                              data:data
                               key:self.s4.key
                            secret:self.s4.secret
                          delegate:self.s4];
}

@end
