@import swift_shims;

#import <pthread.h>
#import <objc/runtime.h>
#import <Foundation/Foundation.h>

#import "FNZombie.h"
#import "FNBaseDefines.h"
#import "FNZombieService.h"

#pragma mark FNZombieService iVars

@interface FNZombieService() {
@public
  FNZombieRecord *_zombies;
@public
  Class _zombieClass;
@public
  size_t _zombiesIndex;
@public
  size_t _bufferSize;
@public
  BOOL _isEnabled;
@public
  IMP _deallocIMP;
}
@end

#pragma mark Utils functions

static void fatal_error(NSString *message) {
  [SwiftShims swiftFatalError:message];
};

static pthread_mutex_t* get_lock(void) {
  static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
  return &mutex;
};

static void zombie_dealloc(id object, SEL selector) {
  FNZombieService *service = [FNZombieService sharedInstance];

  Class objectClass = object_getClass(object);
  const size_t size = class_getInstanceSize(objectClass);

  objc_destructInstance(object);
  memset((__bridge void *)object, 0, size);

  object_setClass(object, service->_zombieClass);

  FNZombieRecord record = {};
  record.object = object;
  record.wasa = objectClass;

  if (service->_bufferSize > 0) {
    pthread_mutex_lock(get_lock());

    if (service->_bufferSize > 0) {
      FN_SWAP(record, service->_zombies[service->_zombiesIndex]);
      service->_zombiesIndex = (service->_zombiesIndex + 1) % service->_bufferSize;
    }
    
    pthread_mutex_unlock(get_lock());
  }

  if (record.object) {
    object_dispose(record.object);
  }
};

#pragma mark FNZombieService

@implementation FNZombieService

#pragma mark Shared

+ (instancetype)sharedInstance {
  static dispatch_once_t token;
  static FNZombieService *sharedInstance = nil;
  dispatch_once(&token, ^{
    sharedInstance = [FNZombieService new];
  });
  return sharedInstance;
};

#pragma mark Public methods

- (void)enableWithBufferSize:(size_t)bufferSize {
  if (![NSThread isMainThread]) {
    fatal_error(@"Enable FNZombieService on the main thread only");
    return;
  }

  if (_isEnabled) {
    return;
  }

  Class rootClass = [NSObject class];
  _deallocIMP = class_getMethodImplementation(rootClass, @selector(dealloc));

  Class zombieClass = objc_getClass("FNZombie");
  _zombieClass = zombieClass;

  if (!zombieClass) {
    fatal_error(@"Internal error");
    return;
  }

  Method rootClassMethod = class_getInstanceMethod(rootClass, @selector(dealloc));

  if (!rootClassMethod) {
    fatal_error(@"Internal error");
    return;
  }

  method_setImplementation(rootClassMethod, (IMP)zombie_dealloc);

  const size_t oldCount = _bufferSize;
  FNZombieRecord* oldZombies = _zombies;

  {
    pthread_mutex_lock(get_lock());

    size_t oldIndex = _zombiesIndex;

    _zombiesIndex = 0;
    _bufferSize = bufferSize;
    _zombies = nil;
    
    if (_bufferSize) {
      _zombies = (FNZombieRecord*)(calloc(_bufferSize, sizeof(*_zombies)));
      
      if (!_zombies) {
        _zombies = oldZombies;
        _bufferSize = oldCount;
        _zombiesIndex = oldIndex;
        
        [self disable];
        fatal_error(@"Internal error");
        return;
      }
    }
    
    const size_t sharedCount = FN_MIN(oldCount, _bufferSize);
    
    if (sharedCount) {
      oldIndex = (oldIndex + oldCount - sharedCount) % oldCount;
      
      for (; _zombiesIndex < sharedCount; ++_zombiesIndex) {
        FN_SWAP(_zombies[_zombiesIndex], oldZombies[oldIndex]);
        oldIndex = (oldIndex + 1) % oldCount;
      }
      
      _zombiesIndex %= _bufferSize;
    }
    
    pthread_mutex_unlock(get_lock());
  }

  if (oldZombies) {
    for (size_t i = 0; i < oldCount; ++i) {
      if (oldZombies[i].object)
        object_dispose(oldZombies[i].object);
    }
    free(oldZombies);
  }
};

- (void)disable {
  if (![NSThread isMainThread]) {
    fatal_error(@"Disable FNZombieService on the main thread only");
    return;
  }

  if (!_deallocIMP) {
    return;
  }

  Class rootClass = [NSObject class];
  Method rootClassMethod = class_getInstanceMethod(rootClass, @selector(dealloc));

  if (!rootClassMethod) {
    fatal_error(@"Internal error");
    return;
  }

  method_setImplementation(rootClassMethod, _deallocIMP);

  const size_t oldCount = _bufferSize;
  FNZombieRecord* oldZombies = _zombies;

  {
    pthread_mutex_lock(get_lock());
    _bufferSize = 0;
    _zombieClass = nil;
    _isEnabled = NO;
    _deallocIMP = nil;
    pthread_mutex_unlock(get_lock());
  }

  if (oldZombies) {
    for (size_t i = 0; i < oldCount; ++i) {
      if (oldZombies[i].object)
        object_dispose(oldZombies[i].object);
    }
    free(oldZombies);
  }
};

#pragma mark Private methods

- (void)crashWithObject:(id)object
           withSelector:(SEL)selector
           fromSelector:(SEL)fromSelector FN_OBJC_DIRECT {
  Class objectClass = object_getClass(object);
  Class objectPreviousClass = nil;

  FNZombieRecord record;
  BOOL found = [self isZombieByObject:object withRecord:&record];

  const char* objectPreviousClassName;

  if (found) {
    objectPreviousClass = record.wasa;
  }

  if (objectPreviousClass) {
    objectPreviousClassName = class_getName(objectPreviousClass);
  } else {
    objectPreviousClassName = "unknown";
  }

  NSString *className = @(objectPreviousClassName);
  NSString *selectorName = @(sel_getName(selector));

  NSString *message = [NSString stringWithFormat:@"Zombie <%@: %p> received -%@",
                       className,
                       object,
                       selectorName];
  
  pthread_mutex_unlock(get_lock());
  fatal_error(message);
}

- (BOOL)isZombieByObject:(id)object
              withRecord:(FNZombieRecord *)record FN_OBJC_DIRECT {
  pthread_mutex_lock(get_lock());
  for (size_t i = 0; i < _bufferSize; ++i) {
    if (_zombies[i].object == object) {
      *record = _zombies[i];
      return YES;
    }
  }
  pthread_mutex_unlock(get_lock());
  return NO;
};

@end

#pragma mark FNZombie

@implementation FNZombie

+ (void)initialize {};

- (id)forwardingTargetForSelector:(SEL)aSelector {
  [[FNZombieService sharedInstance]
   crashWithObject:self
   withSelector:aSelector
   fromSelector:nil
  ];
  return nil;
};

- (BOOL)respondsToSelector:(SEL)aSelector {
  [[FNZombieService sharedInstance]
   crashWithObject:self
   withSelector:aSelector
   fromSelector:_cmd
  ];
  return NO;
};

- (id)performSelector:(SEL)aSelector {
  [[FNZombieService sharedInstance]
   crashWithObject:self
   withSelector:aSelector
   fromSelector:_cmd
  ];
  return nil;
};

- (id)performSelector:(SEL)aSelector
           withObject:(id)anObject {
  [[FNZombieService sharedInstance]
   crashWithObject:self
   withSelector:aSelector
   fromSelector:_cmd
  ];
  return nil;
}

- (id)performSelector:(SEL)aSelector
           withObject:(id)anObject
           withObject:(id)anotherObject {
  [[FNZombieService sharedInstance]
   crashWithObject:self
   withSelector:aSelector
   fromSelector:_cmd
  ];
  return nil;
}

- (void)performSelector:(SEL)aSelector
             withObject:(id)anArgument
             afterDelay:(NSTimeInterval)delay {
  [[FNZombieService sharedInstance]
   crashWithObject:self
   withSelector:aSelector
   fromSelector:_cmd
  ];
};

@end
