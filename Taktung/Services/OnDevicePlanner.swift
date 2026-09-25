import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum OnDevicePlanner {
    /// True when Apple Intelligence / Foundation Models can run on this device.
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return true
            default:
                return false
            }
        }
        #endif
        return false
    }
}
