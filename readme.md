S4
==

S4 is a block based Cocoa / Objective-C client that helps you make requests to Amazon Web Services S3, and supports these operations:
- GET Service
- GET Bucket
- GET Object
- PUT Object
- HEAD Object

S4 also provides convenience methods to ease listing keys by using directory semantics, breaking on /, and supporting recursive listing.

Some operations, like bucket list operations, that require multiple calls to get the full list are hidden behind a simplified asynchronous interface to make them appear like a single operation.

Not all operations can report progress accurately, but most long running operations like GETs and PUTs of large objects report accurately.

All operations in S4 are represented by a task. To run an operation, create the task using an S4 or S4Bucket instance, and set both the onDone and onError block properties.

Some errors reported by S4 are thin wrappers around corresponding S3 errors. Others occur because of misuse of the S4 library itself. Some S3 errors are never passed through to you, either because the operations that cause them are not supported, or because S4 hides the error for convenience.

Authorization is not managed for you beyond reporting errors when authorization fails.

S4 requires the XMLElement library available at https://github.com/aaron--/xmlelement and must be compiled with XCode 4.2 for ARC support.

S4Task
------

S4Task represents a concurrent call to S3 and can be cancelled and observed for progress updates by using block properties. For example:

task = [self.s4 getBuckets];
task.onDone = ^(NSArray* buckets) {
  self.buckets = buckets;
};
task.onError = ^(NSError* error) {
  [self handleError:error];
};

Most S3 methods subclass S4Task with their own completion handler block format since data returned by different tasks varies.

Callback blocks are deallocated after firing so circular references to objects captures by the block closure are release when the task is over.

Status
------

S4 is largely untested and shouldn't be relied on for production quality projects. It's been tested only lightly on iOS.

Todo
----

- DELETE Object support
- Better Documentation
- Cancelling Tasks
- Use Grand Central Dispatch for queuing
