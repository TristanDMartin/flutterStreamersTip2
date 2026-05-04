import Flutter
import UIKit

/// Registers `streamers_tip/gif_pasteboard` so Flutter can read/write animated GIF
/// bytes (UTType gif). The `pasteboard` package uses PNG on iOS and drops frames.
enum GifPasteboardBootstrap {
  private static var didRegister = false

  @discardableResult
  static func tryRegister(window: UIWindow?) -> Bool {
    if didRegister {
      return true
    }
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return false
    }
    didRegister = true
    let channel = FlutterMethodChannel(
      name: "streamers_tip/gif_pasteboard",
      binaryMessenger: controller.binaryMessenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "readGifBytes":
        if let data = GifPasteboardReader.readPreferredGifData() {
          result(FlutterStandardTypedData(bytes: data))
        } else {
          result(nil)
        }
      case "writeGifBytes":
        if let typed = call.arguments as? FlutterStandardTypedData {
          GifPasteboardWriter.write(data: typed.data)
          result(nil)
        } else {
          result(FlutterError(code: "arg", message: "Expected byte data", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    return true
  }
}

private enum GifPasteboardReader {
  static func readPreferredGifData() -> Data? {
    let pb = UIPasteboard.general
    let utis = [
      "com.compuserve.gif",
      "public.gif",
      "dyn.ah62d4rv4gk81g6pq",
    ]
    for uti in utis {
      if pb.contains(pasteboardTypes: [uti]),
         let data = pb.data(forPasteboardType: uti),
         data.count > 32 {
        return data
      }
    }
    for item in pb.items {
      guard let dict = item as? [String: Any] else {
        continue
      }
      for (key, value) in dict {
        let lower = key.lowercased()
        if lower.contains("gif"), let data = value as? Data, data.count > 32 {
          return data
        }
      }
    }
    return nil
  }
}

private enum GifPasteboardWriter {
  static func write(data: Data) {
    let pb = UIPasteboard.general
    let item: [String: Any] = [
      "public.gif": data,
      "com.compuserve.gif": data,
    ]
    pb.setItems([item], options: [:])
  }
}
