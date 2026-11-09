import Foundation

/// Fixed credential snapshot per URLSession. Ordinary server trust remains system-owned.
nonisolated final class MTLSSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    private let origin: ServerOrigin?
    private let credential: URLCredential?

    init(origin: ServerOrigin?, credential: URLCredential?) {
        self.origin = origin
        self.credential = credential
    }

    func permitsClientCertificate(space: URLProtectionSpace, previousFailures: Int) -> Bool {
        guard let origin, credential != nil, previousFailures == 0,
              space.authenticationMethod == NSURLAuthenticationMethodClientCertificate,
              space.protocol?.lowercased() == "https" else { return false }
        return space.host.lowercased() == origin.host && space.port == origin.port
    }

    func permitsRedirect(from source: URL, to destination: URL) -> Bool {
        guard let sourceOrigin = try? ServerOrigin(url: source), sourceOrigin.contains(destination) else { return false }
        return origin == nil || origin == sourceOrigin
    }

    private func answer(_ challenge: URLAuthenticationChallenge,
                        completion: (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate else {
            completion(.performDefaultHandling, nil)
            return
        }
        // Cancellation prevents automatic selection of arbitrary Keychain identities,
        // including on public icon and external attachment sessions.
        guard permitsClientCertificate(space: challenge.protectionSpace, previousFailures: challenge.previousFailureCount) else {
            completion(.cancelAuthenticationChallenge, nil)
            return
        }
        completion(.useCredential, credential)
    }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        answer(challenge, completion: completionHandler)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        answer(challenge, completion: completionHandler)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        guard let source = response.url, let destination = request.url, permitsRedirect(from: source, to: destination) else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}

nonisolated struct ServerSessionFactory: Sendable {
    let configuration: ClientCertificateConfiguration
    let store: ClientCertificateStore

    func makeServerSession(url: URL) throws -> (session: URLSession, certificateID: UUID?) {
        let origin = try ServerOrigin(url: url)
        let assignment = try configuration.certificate(for: origin)
        let credential = try assignment.map { try store.credential(id: $0.id) }
        return (Self.makeSession(origin: origin, credential: credential), assignment?.id)
    }

    static func makeExternalSession() -> URLSession { makeSession(origin: nil, credential: nil) }

    private static func makeSession(origin: ServerOrigin?, credential: URLCredential?) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.urlCredentialStorage = nil
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        return URLSession(configuration: config, delegate: MTLSSessionDelegate(origin: origin, credential: credential), delegateQueue: nil)
    }
}
