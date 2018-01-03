# UptakeAuthUI
![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat) ![API docs](http://mobile-toolkit-docs.services.common.int.uptake.com/docs/uptake-auth-ui-ios/badge.svg)

A fully-featured frontend to [UptakeAuth](https://github.com/UptakeMobile/uptake-auth-ios).

## Usage
> Be sure to read "Authenticating the Easy Way with `AuthHelper`" below if you're not interested in rolling your own solution.

The primary interface of `UptakeAuthUI` is the `LoginViewController` class. When you need to obtain an auth token, create an instance of this view controller, set a delegate, and present it wherever you want it to appear.

Assuming the user doesn't cancel and the API/network connection doesn't error out, your `LoginViewController` instance will, at some point, attempt to open the given callback URL via `openURL`. To continue with the authentication process:

1. Your app must be registered to handle the URL scheme matching the callback.
2. This scheme must be unique to this app.
3. Your app delegate must implement `application(_:open:options:)` and pass the parameters on to `LoginViewController.handleApplicationOpen(_:options:)`

Soon, (assuming no errors) your delegate will be passed an auth token through `loginViewController(_:authenticatedWithToken:)`. It is then your responsibility to deal with this token appropriately.

## Authenticating the Easy Way with `AuthHelper`
In the event you don't want to roll your own auth solution, `AuthHelper` abstracts many concerns such as handling delegate callbacks and managing the secure storage of the auth token.

To use it, simply call `AuthHelper.presentLogin(...)` with all your auth info. This will automatically present a `LoginViewController` modally on top of all other controllers, handle dismissing the controller when appropriate, and present any errors in an alert dialog.

***You are still responsible for implementing `application(_:open:options:)` and calling `LoginViewController.handleApplicationOpen(_:options:)`!***

But `AuthHelper` will take care of managing the auth token for you.

You can use `AuthHelper.token` to retrieve any token already stored in the keychain (or `nil` if none exist). So a common pattern might be:

```swift
guard let token = AuthHelper.token else {
  AuthHelper.presentLogin(/*...*/)
}
//Do stuff with «token»...
```

`AuthHelper.purgeToken()` will delete any existing tokens; for example when implementing "log out" functionality.

## Debugging
Uptake AuthUI will print debugging messages to console whenever the environment variable `UPTAKE_AUTH_UI_DEBUGGING` is set to a non-null value. Uptake Toolbox's messages will be prepended with "📲".

