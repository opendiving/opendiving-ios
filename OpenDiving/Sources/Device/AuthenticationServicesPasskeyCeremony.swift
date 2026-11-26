import AuthenticationServices
import OpenDivingKit
import UIKit

/// The system's passkey sheet, over the foreground window. The relying party is always the one
/// it is handed, which the server's options named.
final class AuthenticationServicesPasskeyCeremony: NSObject, PasskeyCeremony {
  private enum Answer {
    case authorized(ASAuthorization)
    case error(any Error)
  }

  private var controller: ASAuthorizationController?
  private var continuation: CheckedContinuation<Answer, Never>?

  func signIn(_ request: PasskeySignInRequest) async -> PasskeyCeremonyResult<PasskeyAssertion> {
    let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
      relyingPartyIdentifier: request.relyingParty)
    let assertion = provider.createCredentialAssertionRequest(challenge: request.challenge)
    assertion.allowedCredentials = request.allowedCredentials.map {
      ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: $0)
    }
    if let preference = request.userVerification {
      assertion.userVerificationPreference = .init(rawValue: preference)
    }
    switch await perform(assertion, onlyOnThisPhone: request.onlyOnThisPhone) {
    case .authorized(let authorization):
      guard
        let credential = authorization.credential
          as? ASAuthorizationPlatformPublicKeyCredentialAssertion
      else { return .failed }
      return .done(
        PasskeyAssertion(
          credentialID: credential.credentialID, clientDataJSON: credential.rawClientDataJSON,
          authenticatorData: credential.rawAuthenticatorData, signature: credential.signature,
          userID: credential.userID, attachment: Self.attachment(credential.attachment)))
    case .error(let error):
      return Self.result(error)
    }
  }

  func register(_ request: PasskeyRegistrationRequest) async
    -> PasskeyCeremonyResult<PasskeyRegistration>
  {
    let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
      relyingPartyIdentifier: request.relyingParty)
    let registration = provider.createCredentialRegistrationRequest(
      challenge: request.challenge, name: request.name, userID: request.userID)
    registration.displayName = request.displayName
    if let preference = request.userVerification {
      registration.userVerificationPreference = .init(rawValue: preference)
    }
    registration.excludedCredentials = request.excludedCredentials.map {
      ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: $0)
    }
    switch await perform(registration, onlyOnThisPhone: false) {
    case .authorized(let authorization):
      guard
        let credential = authorization.credential
          as? ASAuthorizationPlatformPublicKeyCredentialRegistration,
        let attestation = credential.rawAttestationObject
      else { return .failed }
      return .done(
        PasskeyRegistration(
          credentialID: credential.credentialID, clientDataJSON: credential.rawClientDataJSON,
          attestationObject: attestation, attachment: Self.attachment(credential.attachment)))
    case .error(let error):
      return Self.result(error)
    }
  }

  func cancel() {
    controller?.cancel()
    finish(.error(ASAuthorizationError(.canceled)))
  }

  /// One ceremony at a time: a request made while another is out ends that one as a dismissal.
  private func perform(_ request: ASAuthorizationRequest, onlyOnThisPhone: Bool) async -> Answer {
    cancel()
    let controller = ASAuthorizationController(authorizationRequests: [request])
    controller.delegate = self
    controller.presentationContextProvider = self
    self.controller = controller
    return await withCheckedContinuation { continuation in
      self.continuation = continuation
      if onlyOnThisPhone {
        controller.performRequests(options: .preferImmediatelyAvailableCredentials)
      } else {
        controller.performRequests()
      }
    }
  }

  private func finish(_ answer: Answer) {
    controller = nil
    let continuation = continuation
    self.continuation = nil
    continuation?.resume(returning: answer)
  }

  private static func result<Value>(_ error: any Error) -> PasskeyCeremonyResult<Value> {
    switch (error as? ASAuthorizationError)?.code {
    case .canceled: .dismissed
    case .matchedExcludedCredential: .matchedExcludedCredential
    default: .failed
    }
  }

  private static func attachment(_ attachment: ASAuthorizationPublicKeyCredentialAttachment)
    -> PasskeyAttachment?
  {
    switch attachment {
    case .platform: .platform
    case .crossPlatform: .crossPlatform
    @unknown default: nil
    }
  }
}

extension AuthenticationServicesPasskeyCeremony: ASAuthorizationControllerDelegate {
  func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithAuthorization authorization: ASAuthorization
  ) {
    guard controller === self.controller else { return }
    finish(.authorized(authorization))
  }

  func authorizationController(
    controller: ASAuthorizationController, didCompleteWithError error: any Error
  ) {
    guard controller === self.controller else { return }
    finish(.error(error))
  }
}

extension AuthenticationServicesPasskeyCeremony:
  ASAuthorizationControllerPresentationContextProviding
{
  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let scene =
      scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    return scene?.keyWindow ?? scene?.windows.first ?? ASPresentationAnchor()
  }
}
