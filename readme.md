S4
==

S4 is a block based Cocoa / Objective-C client that helps you make requests to Amazon Web Services S3.

S4 supports these methods:
- GET Service
- GET Bucket
- GET Object
- PUT Object
- HEAD Object

Clearly, S4 is intended for use in application data storage and not as a library for administering an S3 account. It does not any further ambition and will stay focused on the core S3 methods.

S4 also provides convenience methods to ease listing keys by using directory semantics, breaking on /, and supports recursive listing.

S4 requires the XMLElement library available at https://github.com/aaron--/xmlelement

Status
======

S4 is largely untested and shouldn't be relied on for production quality projects. It requires XCode 4.2 for ARC support. It's been tested only lightly on iOS.

Todo
====

- DELETE Object support
- Better Documentation
- Code Style needs to be modernized
- Better Error handling with enumerated error codes
