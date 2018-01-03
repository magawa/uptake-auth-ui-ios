import UIKit
import UptakeToolbox
import UptakeUI
import UptakeAuth
import UptakeKeychain


private enum K {
  static let service = KeychainService("UptakeAuthTokenService")
}

private class SimpleLoginDelegate: NSObject, LoginViewControllerDelegate {
  func cancelled(loginViewController: LoginViewController){
    loginViewController.dismiss(animated: true, completion: nil)
  }
  
  
  func loginViewController(_ loginViewController: LoginViewController, failedWithError e: Error) {
    loginViewController.dismiss(animated: true) { 
      let alert = UIAlertController.makeInfo(title: "Log In Failed", message: "There was a problem logging in to your account.\n\n\(e.localizedDescription)")
      UIApplication.shared.presentOnTop(alert)
    }
  }
  
  
  func loginViewController(_ loginViewController: LoginViewController, authenticatedWithToken token: UptakeSSOToken) {
    loginViewController.dismiss(animated: true) {
      do {
        try KeychainHelper.writeString(token.accessToken, to: K.service)
        debug? {["Success!"]}
      } catch {
        debug? {["Failed: \(error.localizedDescription)"]}
        let alert = UIAlertController.makeInfo(title: "Log In Failed", message: "There was a problem saving your account information.\n\n\(error.localizedDescription)")
        UIApplication.shared.presentOnTop(alert)
      }
    }
  }
}



private var simpleDelegate: SimpleLoginDelegate = SimpleLoginDelegate()



/**
 `AuthHelper` is a thin, opinionated wrapper around `LoginViewController` that manages auth tokens and errors. If you can live with its assumptions, it's much simpler to use.
 
 `AuthHelper` automatically stores auth tokens securly in the client app's keychain (note that it does *not* use group access, so there's no way to share the tokens between apps). It abstracts all keychain interaction providing only a property to retreive a token and a method to remove one. The only way to set a token is by going through the log in process.
 
 `AuthHelper` doesn't allow for any fancy error handling. Whenever it encounters an error, it formats it and presents it in an alert.
 */
public enum AuthHelper {
}



public extension AuthHelper {
  /// Returns `true` if a token has been stored in the client app's keychain. Otherwise `false`.
  static var hasToken: Bool {
    return KeychainHelper.hasStringItem(K.service)
  }
  
  
  /// Returns an auth token if one has been previously stored to the client's keychain via the log in process. Otherwise `nil`.
  ///
  /// - Note: the keychain is a system-level entity. The auth token, like all values in the keychain, will persist across app installations. Deleting and re-installing the client will not purge it.
  static var token: String? {
    do {
      return try KeychainHelper.readString(from: K.service)
    } catch {
      return nil
    }
  }
  
  
  /// Removes any existing existing auth token from the client's keychain
  static func purgeToken() {
    do {
      try KeychainHelper.deleteItem(K.service)
    } catch {
      //fail silently
      debug? {["Error purging token: \(error.localizedDescription)"]}
    }
  }
  
  
  /**
   Presents a `LoginViewController` initialized with the given properties on top of all other view controllers.
   
   - Parameter provider: The auth service provider to be used for logging in.
   
   - Parameter industry: The type of industry the client app is involved in. This purly cosmetic setting controls what photo is shown behind the login landing page.
   
   - Parameter environment: The environment (production, staging, &c.) to use for authentication. This primarily effects what servers auth API calls are sent to.
   
   - Parameter apiKey: The API key, as used in the "X-Api-Key" header.
   
   - Parameter clientID: An ID registerd at the auth service to uniquely identify a given client. The ID passed here by the client and the ID registered at the auth service must match.
   
   - Parameter callback: The callback URL. It must match a URL registered with the auth service. It must also posess a scheme unique to the client app and the client app must be registered to handle this scheme.
   */
  static func presentLogin(provider: ProviderType, industry: IndustryType, environment: AuthEnvironment, apiKey: String, clientID: String, callback: URL) {
    let vc = LoginViewController(provider: provider, industry: industry, environment: environment, apiKey: apiKey, clientID: clientID, callback: callback)
    vc.delegate = simpleDelegate
    UIApplication.shared.presentOnTop(vc)
  }
}
