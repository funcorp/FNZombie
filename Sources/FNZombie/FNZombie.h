#ifndef FNZombie_h
#define FNZombie_h

#import <Foundation/Foundation.h>

__attribute__((objc_root_class))
@interface FNZombie {
  Class isa;
}

+ (void)initialize;

- (id)forwardingTargetForSelector:(SEL)aSelector;

- (BOOL)respondsToSelector:(SEL)aSelector;

- (id)performSelector:(SEL)aSelector;

- (id)performSelector:(SEL)aSelector
           withObject:(id)anObject;

- (id)performSelector:(SEL)aSelector
           withObject:(id)anObject
           withObject:(id)anotherObject;

- (void)performSelector:(SEL)aSelector
             withObject:(id)anArgument
             afterDelay:(NSTimeInterval)delay;

@end

#endif /* FNZombie_h */
