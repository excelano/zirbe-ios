// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

public enum ErrorText {
    public static func readable(_ error: Error) -> String {
        if let described = (error as? LocalizedError)?.errorDescription {
            return described
        }
        if error is CustomNSError || type(of: error) is NSError.Type {
            return error.localizedDescription
        }
        return "Couldn't reach the mail server."
    }
}
