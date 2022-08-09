#ifndef FNBaseDefines_h
#define FNBaseDefines_h

#import <Foundation/Foundation.h>

#if defined(__IPHONE_14_0) || defined(__MAC_10_16) || defined(__TVOS_14_0) || defined(__WATCHOS_7_0)
  #define FN_OBJC_DIRECT_MEMBERS __attribute__((objc_direct_members))
  #define FN_OBJC_DIRECT __attribute__((objc_direct))
  #define FN_DIRECT ,direct
#else
  #define FN_OBJC_DIRECT_MEMBERS
  #define FN_OBJC_DIRECT
  #define FN_DIRECT
#endif

#ifndef FN_MIN
  #define FN_MIN(x, y) (((x) < (y)) ? (x) : (y))
#endif

#ifndef FN_SWAP
  #define FN_SWAP(a, b) do { typeof(a) temp = a; a = b; b = temp; } while (0)
#endif

typedef struct {
  id object;
  Class wasa;
} FNZombieRecord;

#endif /* FNBaseDefines_h */
