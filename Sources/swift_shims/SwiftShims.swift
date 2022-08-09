import Foundation

@objcMembers
public final class SwiftShims: NSObject {
  @inline(__always)
  public static func swiftFatalError(_ message: String) -> Never {
    fatalError(message)
  }
}
