//
// Copyright 2013 Aaron Sittig. All rights reserved
// All code is governed by the BSD-style license at
// http://github.com/aaron--/s4
//

#import "S4Bucket.h"
#import "S4Op.h"

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

- (void)get:(NSString*)uri whenDone:(S4BucketGetDone)block
{
  S4OpDone   opDone;
  S4Op*      newOp;
  
  opDone = ^(S4Op* op, NSError* error){ block(op.data, error); };
  newOp = [S4Op opWithMethod:@"GET" s4:self.s4 bucket:self uri:uri data:nil whenDone:opDone];
}

- (void)head:(NSString*)uri whenDone:(S4BucketHeadDone)block
{
  S4OpDone  opDone;
  S4Op*     newOp;
  
  // TODO: Make sure error is used for all non-20* HTTP statuses
  opDone = ^(S4Op* op, NSError* error){ block(op.head, error); };
  newOp = [S4Op opWithMethod:@"HEAD" s4:self.s4 bucket:self uri:uri data:nil whenDone:opDone];
}

- (void)list:(NSString*)prefix whenDone:(S4BucketListDone)block
{
  NSString*   uri;
  S4OpDone    opDone;
  S4Op*       newOp;
  
  uri = @"?delimiter=/";
  uri = prefix ? [NSString stringWithFormat:@"?prefix=%@&delimiter=/", prefix] : uri;
  opDone = ^(S4Op* op, NSError* error){ block(op.list, error); };
  newOp = [S4Op opWithMethod:@"GET" s4:self.s4 bucket:self uri:uri data:nil whenDone:opDone];
}

- (void)listDeep:(NSString*)prefix whenDone:(S4BucketListDone)block
{
  NSString*   uri;
  S4OpDone    opDone;
  S4Op*       newOp;
  
  // TODO: sanity check prefix
  uri = [NSString stringWithFormat:@"?prefix=%@", prefix];
  opDone = ^(S4Op* op, NSError* error){ block(op.list, error); };
  newOp = [S4Op opWithMethod:@"GET" s4:self.s4 bucket:self uri:uri data:nil whenDone:opDone];
}

- (void)put:(NSString*)uri data:(NSData*)data whenDone:(S4BucketPutDone)block
{
  S4OpDone    opDone;
  S4Op*       newOp;
  
  opDone = ^(S4Op* op, NSError* error){ block(error); };
  newOp = [S4Op opWithMethod:@"PUT" s4:self.s4 bucket:self uri:uri data:data whenDone:opDone];
}

@end
