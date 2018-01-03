import UIKit
import SafariServices
import UptakeToolbox
import UptakeAuth
import UptakeUI


/// Required methods of a `LoginViewController` delegate class.
public protocol LoginViewControllerDelegate: class {
  
  /// Called on the delegate when the user cancels out of the login interface. The delegate should normally dismiss `loginViewController` in response.
  func cancelled(loginViewController: LoginViewController)
  
  /** 
   Called on the delegate when an error has occured in the login interface.
   
   Possible errors:
   
   - `WebView.failedToLoad` — when the Safari controller fails to load the auth URL successfully.
   
   - `AuthError.invalidAuth0TokenPayload` — when there's an issue decoding params from the auth URL returned from the authentication service.
   
   - `HTTPError.unexpectedStatusCode`, `ResponseError.unexpectedBody`, and various other networking errors.
   */
  func loginViewController(_ loginViewController: LoginViewController, failedWithError: Error)
  
  /// Called on the delegate to deliver the auth token to the client. Care should be taken in the secure handling of this token.
  func loginViewController(_ loginViewController: LoginViewController, authenticatedWithToken: UptakeSSOToken)
}



// A global ref to the presented login controller. We need this because, in the process of logging in, control will be passed to the app delegate to open the callback URL, and we need to be able to get back here. There are about 20 reasons why using a global ref for this is dodgy, but in practice it works.
private weak var loginControllerRef: LoginViewController?



/// The primary interface of this library. When an auth token is needed, an instance of this controller can be created and presented.
public class LoginViewController: UIViewController, Busy {

  
  public let busyStyle: BusyStyle
  

  fileprivate lazy var dummyController: UIViewController = { ()->UIViewController in
    let vc = UIViewController(nibName: nil, bundle: nil)
    vc.view.backgroundColor = .white
    return vc
  }()
  
  

  /// A delegate object that recieves calls defined in `LoginViewControllerDelegate`. It's not strictly required, but using `LoginViewController` without it is pretty pointless.
  public weak var delegate: LoginViewControllerDelegate?
  fileprivate var authService: AuthService!
  fileprivate weak var navController: UINavigationController!
  fileprivate let provider: ProviderType
  fileprivate let industry: IndustryType
  fileprivate let environment: AuthEnvironment
  fileprivate let clientID: String
  fileprivate let callback: URL
  fileprivate let showLanding: Bool
  
  
  /**
   Initializes an instance of the receiver.
   
   - Parameter provider: The auth service provider to be used for logging in.
   
   - Parameter industry: The type of industry the client app is involved in. This purly cosmetic setting controls what photo is shown behind the login landing page.
   
   - Parameter environment: The environment (production, staging, &c.) to use for authentication. This primarily effects what servers auth API calls are sent to.

   - Parameter apiKey: The API key, as used in the "X-Api-Key" header.
   
   - Parameter clientID: An ID registerd at the auth service to uniquely identify a given client. The ID passed here by the client and the ID registered at the auth service must match.

   - Parameter callback: The callback URL. It must match a URL registered with the auth service. It must also posess a scheme unique to the client app and the client app must be registered to handle this scheme.
   
   - Parameter showLanding: *Default: `true`* If `false`, the "Log In" button of the landing page will be hidden, and the view controller will immeditately attempt to fetch a URL and display the embedded web view as if "Log In" had been tapped. This can be useful when adding into a product with an existing, deeply integrated auth interface.
   */
  required public init(provider: ProviderType, industry: IndustryType, environment: AuthEnvironment, apiKey: String, clientID: String, callback: URL, showLanding: Bool = true) {
    self.provider = provider
    self.industry = industry
    self.environment = environment
    self.clientID = clientID
    self.callback = callback
    self.showLanding = showLanding
    busyStyle = showLanding ? .uptake : .cat
    
    super.init(nibName: nil, bundle: nil)
    
    authService = AuthService(environment: environment, apiKey: apiKey, delegate: self)
  }
  
  
  
  /// - Warning: This is unimplemented and will trap. Do not use `LoginViewController` in a NIB.
  required public init?(coder aDecoder: NSCoder) {
    fatalError("Should not be used from NIB.")
  }
}



public extension LoginViewController {
  /**
   This continues the authentication process after a presented `LoginViewController` redirects to the callback URL.
   
   In most situations, this should be called by the client when handling `UIApplicationDelegate.application(_:open:options:)`. If `url` is properly handled (that is, if it matches the callback URL sent with the original auth request), this returns `true`. Otherwise, `false`.
   
   - Parameters url: The URL passed in to `application(_:open:options:)`
   
   - Parameters options: The options passed in to `application(_:open:options:)`
   
   - Returns: `true` if the given `url` matches the callback URL sent with the auth request. Otherwise, `false`.
   */
  static func handleApplicationOpen(_ url: URL, options: [UIApplicationOpenURLOptionsKey : Any]) -> Bool {
    debug? {[
      "CALLBACK URI--------------",
      url.absoluteString,
      ]}
    
    guard
      loginControllerRef?.callback.scheme == url.scheme,
      loginControllerRef?.callback.host *== url.host,
      loginControllerRef?.callback.path == url.path else {
        return false
    }
    
    loginControllerRef?.isBusy = true
    loginControllerRef?.authService.processAuth0Callback(url: url)
    return true
  }

  
  /// :nodoc:
  override func viewDidLoad() {
    super.viewDidLoad()
    loginControllerRef = self
    view.backgroundColor = .darkBackground
    let landing = showLanding ? EmbeddedLoginViewController(industry: industry) : dummyController
    navController = given(UINavigationController(rootViewController: landing)) {
      $0.setNavigationBarHidden(true, animated: false)
      embedAndMaximize($0, useLayoutGuides: false)
    }
    if ❗️showLanding {
      isBusy = true
      //Has to be on the next run loop, or SFViewController freaks out.
      perform(#selector(logIn), with: nil, afterDelay: 1)
    }
  }
}


internal extension LoginViewController {
  @IBAction func logIn() {
    debug? {[
      "LOG IN-----------------------",
      "Fetching URL…",
      ]}
    
    isBusy = true
    authService.getAuthenticationURL(provider: provider, clientID: clientID, callback: callback, scope: "") { [weak self] urlResult -> Void in
      self?.isBusy = false
      switch urlResult {
      case let .failure(e):
        debug? {["Failed: \(e.localizedDescription)"]}
        self?.delegate?.loginViewController(self!, failedWithError: e)
      case let .success(url):
        debug? {["Success: \(url.absoluteString)"]}
        self?.presentURL(url)
      }
    }
  }
}



private extension LoginViewController {
  func presentURL(_ url: URL) {
    with(SFSafariViewController(url: url)) {
      $0.delegate = self
      navController.show($0, sender: self)
    }
  }
}



extension LoginViewController: AuthServiceDelegate {
  /// :nodoc:
  public func authServiceReceivedAuth0Callback(_ anAuthService: AuthService) {
    debug? {["RECEIVED AUTH0 CALLBACK-------------------"]}
  }
  
  
  /// :nodoc:
  public func authService(_ anAuthService: AuthService, resolvedAccessToken token: UptakeSSOToken) {
    debug? {[
      "DELEGATE-----------",
      "Token received."
      ]}
    
    isBusy = false
    delegate?.loginViewController(self, authenticatedWithToken: token)
  }
  
  
  /// :nodoc:
  public func authService(_ anAuthService: AuthService, failedWithError error: Error) {
    debug? {[
      "DELEGATE-----------",
      "Failed with error: \(error.localizedDescription)",
      ]}
    
    isBusy = false
    delegate?.loginViewController(self, failedWithError: error)
  }
}



extension LoginViewController: SFSafariViewControllerDelegate {
  /// Errors pertaining to the embedded web view `LoginViewController` manages.
  public enum WebView: Error {
    /// Raised when the embedded web encoutners an error loading the auth service's web page.
    case failedToLoad
  }

  
  /// :nodoc:
  public func safariViewController(_ controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool) {
    debug? {["HANDOFF TO SAFARI--------------------"]}
    guard didLoadSuccessfully else {
      debug? {["Safari failed to load."]}
      delegate?.loginViewController(self, failedWithError: WebView.failedToLoad)
      return
    }
  }
}
