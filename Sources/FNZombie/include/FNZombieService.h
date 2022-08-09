#ifndef FNZombieService_h
#define FNZombieService_h

#import <Foundation/Foundation.h>

/// This implements a variant of Apple's
/// NSZombieEnabled which can help expose use-after-free errors where messages
/// are sent to freed Objective-C objects in production builds.
@interface FNZombieService : NSObject

+ (instancetype)sharedInstance;

/// Enable zombie object debugging.
/// @param bufferSize  Controls how many zombies to store before freeing the
///                   oldest. 
- (void)enableWithBufferSize:(size_t)bufferSize;

/// Disable zombies.
- (void)disable;

@end

#endif /* FNZombieService_h */
