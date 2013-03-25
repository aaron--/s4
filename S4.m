//
// Copyright 2013 Aaron Sittig. All rights reserved
// All code is governed by the BSD-style license at
// http://github.com/aaron--/s4
//

#import "S4.h"
#import "S4Op.h"

@interface S4 ()
@property (readwrite) NSArray*          buckets;
@property (readwrite) BOOL              authorized;
@property (readwrite) BOOL              authFailed;
@property (readwrite) NSString*         key;
@property (readwrite) NSString*         secret;
@end

@implementation S4

+ (S4*)s4WithKey:(NSString*)key secret:(NSString*)secret
{
  return [[S4 alloc] initWithKey:key secret:secret];
}

+ (NSString*)errorDomain
{
  return @"com.makesay.S4.error";
}

- (id)initWithKey:(NSString*)key secret:(NSString*)secret
{
  if(!(self = [super init])) return nil;
  
  self.key = key;
  self.secret = secret;
  
  return self;
}

- (void)authorize:(S4AuthorizeDone)block
{
  S4OpDone   opDone;
  S4Op*      authOp;
  
  opDone = ^(S4Op* op, NSError* error){ block(!error, error); };
  authOp = [S4Op opWithMethod:@"GET" s4:self bucket:nil uri:@"" data:nil whenDone:opDone];
}

- (void)getBuckets:(S4GetBucketsDone)block
{
  S4OpDone   opDone;
  S4Op*      bucketOp;
  
  opDone = ^(S4Op* op, NSError* error){ block(op.buckets, error); };
  bucketOp = [S4Op opWithMethod:@"GET" s4:self bucket:nil uri:@"" data:nil whenDone:opDone];
}

@end
