public struct WikidataAPI {
    public static let host = "www.wikidata.org"
    public static let path = "/w/api.php"
    public static let scheme = "https"
    
    public static let components: URLComponents = {
        var components = URLComponents()
        components.host = host
        components.scheme = scheme
        components.path = path
        return components
    }()
    
    public static var urlWithoutAPIPath: URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        return components.url
    }
}

struct WikidataAPIResult: Decodable {
    struct Error: Decodable {
        let code, info: String?
    }
    let error: Error?
    let success: Int?
}

extension WikidataAPIResult.Error: LocalizedError {
    var errorDescription: String? {
        return info
    }
}

extension WikidataAPIResult {
    var succeeded: Bool {
        return success == 1
    }
}

enum WikidataPublishingError: LocalizedError {
    case invalidArticleURL
    case apiResultNotParsedCorrectly
    case notEditable
    case unknown
}

@objc public final class WikidataDescriptionEditingController: NSObject {
    private let session: Session

    static let DidMakeAuthorizedWikidataDescriptionEditNotification = NSNotification.Name(rawValue: "WMFDidMakeAuthorizedWikidataDescriptionEdit")

    @objc public init(with session: Session) {
        self.session = session
    }



    /// Publish new wikidata description.
    ///
    /// - Parameters:
    ///   - newWikidataDescription: new wikidata description to be published, e.g., "Capital of England and the United Kingdom".
    ///   - source: description source; none, central or local.
    ///   - wikidataID: id for the Wikidata entity including the prefix
    ///   - language: language code of the page's wiki, e.g., "en".
    ///   - completion: completion block called when operation is completed.
    public func publish(newWikidataDescription: String, from source: ArticleDescriptionSource, forWikidataID wikidataID: String, language: String, completion: @escaping (Error?) -> Void) {
        guard source != .local else {
            completion(WikidataPublishingError.notEditable)
            return
        }
        let requestWithCSRFCompletion: (WikidataAPIResult?, URLResponse?, Bool?, Error?) -> Void = { result, response, authorized, error in
            if let error = error {
                completion(error)
            }
            guard let result = result else {
                completion(WikidataPublishingError.apiResultNotParsedCorrectly)
                return
            }

            completion(result.error)

            if let authorized = authorized, authorized, result.error == nil {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: WikidataDescriptionEditingController.DidMakeAuthorizedWikidataDescriptionEditNotification, object: nil)
                }
            }
        }
        let queryParameters = ["action": "wbsetdescription",
                               "format": "json",
                               "formatversion": "2"]
        let bodyParameters = ["language": language,
                              "uselang": language,
                              "id": wikidataID,
                              "value": newWikidataDescription]
        var components = WikidataAPI.components
        components.replacePercentEncodedQueryWithQueryParameters(queryParameters)
        let _ = session.requestWithCSRF(type: CSRFTokenJSONDecodableOperation.self, components: components, method: .post, bodyParameters: bodyParameters, bodyEncoding: .form, tokenContext: CSRFTokenOperation.TokenContext(tokenName: "token", tokenPlacement: .body), completion: requestWithCSRFCompletion)
    }
}

public extension MWKArticle {
    @objc var isWikidataDescriptionEditable: Bool {
        return wikidataId != nil && descriptionSource != .local
    }
}
