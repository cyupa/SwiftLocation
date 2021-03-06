//
//  FindPlaceRequest.swift
//  SwiftLocation
//
//  Created by danielemargutti on 28/10/2017.
//  Copyright © 2017 Daniele Margutti. All rights reserved.
//

import Foundation
import SwiftyJSON
import MapKit

public typealias FindPlaceRequest_Success = (([PlaceMatch]) -> (Void))
public typealias FindPlaceRequest_Failure = ((LocationError) -> (Void))

public protocol PlaceMatch {
    /// Main text of the place
    var mainText: String { get set }
    
    /// Secondary text of the place
    var secondaryText: String { get set }
    
    func detail(timeout: TimeInterval?, onSuccess: @escaping ((Place) -> (Void)), onFail: ((LocationError) -> (Void))?) -> Void
}
/// Public protocol for place find request
public protocol FindPlaceRequest {
    
    /// Success handler
    var success: FindPlaceRequest_Success? { get set }
    
    /// Failure handler
    var failure: FindPlaceRequest_Failure? { get set }
    
    /// Timeout interval
    var timeout: TimeInterval { get set }
    
    /// Execute operation
    func execute()
    
    /// Cancel current execution (if any)
    func cancel()
}

/// Find Place with Google
public class FindPlaceRequest_Google: FindPlaceRequest {
    
    /// session task
    private var task: JSONOperation? = nil
    
    /// Success callback
    public var success: FindPlaceRequest_Success?
    
    /// Failure callback
    public var failure: FindPlaceRequest_Failure?
    
    /// Timeout interval
    public var timeout: TimeInterval
    
    /// Input to search
    public private(set) var input: String
    
    /// Language in which the results are displayed
    public private(set) var language: FindPlaceRequest_Google_Language?
    
    /// Init new find place operation
    ///
    /// - Parameters:
    ///   - operation: operation to execute
    ///   - timeout: timeout, `nil` uses default timeout of 10 seconds
    public init(input: String, timeout: TimeInterval? = nil, language: FindPlaceRequest_Google_Language? = nil) {
        self.input = input
        self.timeout = timeout ?? 10
        self.language = language ?? FindPlaceRequest_Google_Language.english
    }
    
    public func execute() {
        guard let APIKey = Locator.api.googleAPIKey else {
            self.failure?(LocationError.missingAPIKey(forService: "google"))
            return
        }
        let lang = language?.rawValue ?? "en"
        let url = URL(string: "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=\(input.urlEncoded)&language=\(lang)&key=\(APIKey)")!
        self.task = JSONOperation(url, timeout: self.timeout)
        self.task?.onFailure = { [weak self] err in
            guard let `self` = self else { return }
            self.failure?(err)
        }
        self.task?.onSuccess = { [weak self] json in
            guard let `self` = self else { return }
            if json["status"].stringValue != "OK" {
                self.failure?(LocationError.other("Wrong google response"))
                return
            }
            let places = Google_PlaceMatch.load(list: json["predictions"].arrayValue, language: lang)
            self.success?(places)
        }
        self.task?.execute()
    }
    
    public func cancel() {
        self.task?.cancel()
    }
    
}

/// Google Autocomplete supported languages
///
/// - arabic: Arabic
/// - bulgarian: Bulgarian
/// - bengali: Bengali
/// - catalan: Catalan
/// - czech: Czech
/// - danish: Danish
/// - dutch: Dutch
/// - german: German
/// - greek: Greek
/// - english: English
/// - english_AU: English (Australia)
/// - english_GB: English (Great Britain)
/// - spanish: Spanish
/// - basque: Basque
/// - chinese_simplified: Chinese (Simplified)
/// - chinese_traditional: Chinese (Traditional)
/// - farsi: Farsi
/// - finnish: Finnish
/// - filipino: Filipino
/// - french: French
/// - galician: Galician
/// - gujarati: Gujarati
/// - hindi: Hindi
/// - croatian: Croatian
/// - hungarian: Hungarian
/// - indonesian: Indonesian
/// - italian: Italian
/// - hebrew: Hebrew
/// - japanese: Japanese
/// - kannada: Kannada
/// - korean: Korean
/// - lithuanian: Lithuanian
/// - latvian: Latvian
/// - malayalam: Malayalam
/// - marathi: Marathi
/// - norwegian: Norwegian
/// - polish: Polish
/// - portuguese: Portuguese
/// - portuguese_BR: Portuguese (Brasil)
/// - portuguese_PT: portuguese (Portugal)
/// - romanian: Romanian
/// - russian: Russian
/// - slovak: Slovak
/// - slovenian: Slovenian
/// - serbian: Serbian
/// - swedish: Swedish
/// - tamil: Tamil
/// - telugu: Telugu
/// - thai: Hhai
/// - tagalog: Tagalog
/// - turkish: Turkish
/// - ukrainian: Ukrainian
/// - vietnamese: Vietnamese
public enum FindPlaceRequest_Google_Language: String {
    case arabic = "ar"
    case bulgarian = "bg"
    case bengali = "bn"
    case catalan    = "ca"
    case czech = "cs"
    case danish = "da"
    case dutch = "nl"
    case german = "de"
    case greek = "el"
    case english = "en"
    case english_AU = "en-AU"
    case english_GB = "en-GB"
    case spanish = "es"
    case basque = "eu"
    case chinese_simplified = "zh-CN"
    case chinese_traditional = "zh-TW"
    case farsi = "fa"
    case finnish = "fi"
    case filipino = "fil"
    case french = "fr"
    case galician    = "gl"
    case gujarati = "gu"
    case hindi = "hi"
    case croatian = "hr"
    case hungarian = "hu"
    case indonesian = "id"
    case italian = "it"
    case hebrew = "iw"
    case japanese = "ja"
    case kannada = "kn"
    case korean = "ko"
    case lithuanian = "lt"
    case latvian = "lv"
    case malayalam = "ml"
    case marathi = "mr"
    case norwegian = "no"
    case polish = "pl"
    case portuguese = "pt"
    case portuguese_BR = "pt-BR"
    case portuguese_PT = "pt-PT"
    case romanian = "ro"
    case russian = "ru"
    case slovak = "sk"
    case slovenian = "sl"
    case serbian = "sr"
    case swedish = "sv"
    case tamil = "ta"
    case telugu = "te"
    case thai = "th"
    case tagalog = "tl"
    case turkish = "tr"
    case ukrainian = "uk"
    case vietnamese = "vi"
}

/// Identify a single match entry for a place search
public class Google_PlaceMatch: PlaceMatch {
    
    /// session task
    private var task: JSONOperation? = nil
    
    /// Identifier of the place
    public internal(set) var placeID: String
    
    /// Name of the place
    public internal(set) var name: String
    
    /// Main text of the place
    public var mainText: String
    
    /// Secondary text of the place
    public var secondaryText: String
    
    /// Place types string (google)
    public internal(set) var types: [String]
    
    /// Place detail cache
    public private(set) var detail: Place?
    
    /// Place detail language
    private var language: String
    
    public init?(_ json: JSON, language: String) {
        guard let placeID = json["place_id"].string else { return nil }
        self.placeID = placeID
        self.name = json["description"].stringValue
        self.mainText = json["structured_formatting"]["main_text"].stringValue
        self.secondaryText = json["structured_formatting"]["secondary_text"].stringValue
        self.types = json["types"].arrayValue.map { $0.stringValue }
        self.language = language
    }
    
    public static func load(list: [JSON], language: String) -> [PlaceMatch] {
        return list.compactMap { Google_PlaceMatch($0, language: language) }
    }
    
    public func detail(timeout: TimeInterval? = nil,
                       onSuccess: @escaping ((Place) -> (Void)),
                       onFail: ((LocationError) -> (Void))? = nil) {
        if let p = self.detail {
            onSuccess(p)
            return
        }
        guard let APIKey = Locator.api.googleAPIKey else {
            onFail?(LocationError.missingAPIKey(forService: "google"))
            return
        }
        let url = URL(string: "https://maps.googleapis.com/maps/api/place/details/json?placeid=\(self.placeID)&key=\(APIKey)&language=\(language)")!
        self.task = JSONOperation(url, timeout: timeout ?? 10)
        self.task?.onSuccess = { [weak self] json in
            guard let `self` = self else { return }
            self.detail = Place(googleJSON: json["result"])
            onSuccess(self.detail!)
        }
        self.task?.onFailure = { err in
            onFail?(err)
        }
        self.task?.execute()
    }
    
}

#if os(iOS)
final public class FindPlaceRequest_Apple: NSObject, FindPlaceRequest, MKLocalSearchCompleterDelegate {
    
    private var task: MKLocalSearchCompleter
    
    private var input: String
    
    public var success: FindPlaceRequest_Success?
    
    public var failure: FindPlaceRequest_Failure?
    
    public var timeout: TimeInterval
    
    public func execute() {
        task.delegate = self
        task.queryFragment = self.input
    }
    
    public func cancel() {
        task.cancel()
    }
    
    public init(input: String, timeout: TimeInterval? = nil, language: FindPlaceRequest_Google_Language? = nil) {
        self.input = input
        self.timeout = timeout ?? 10
        task = MKLocalSearchCompleter()
        task.filterType = .locationsOnly
    }
    
    public func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        var results = [Apple_PlaceMatch]()
        for result in completer.results {
            let place = Apple_PlaceMatch(localSearchCompletion: result, for: input)
            results.append(place)
        }
        self.success?(results)
    }
    
    public func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        self.failure?(LocationError.other(error.localizedDescription))
    }
    
}


final public class Apple_PlaceMatch: PlaceMatch {
    
    public var mainText: String
    
    public var secondaryText: String
    
    private var localSearch: MKLocalSearch?
    
    private var localSearchCompletion: MKLocalSearchCompletion
    
    private var input: String
    
    init(localSearchCompletion: MKLocalSearchCompletion, for input: String) {
        self.mainText = localSearchCompletion.title
        if localSearchCompletion.subtitle.isEmpty, let lastComponent = mainText.split(separator: ",").last {
            let charSet = CharacterSet(charactersIn: " ")
            let string = lastComponent.trimmingCharacters(in: charSet)
            self.secondaryText = string
        } else {
            self.secondaryText = localSearchCompletion.subtitle
        }
        self.localSearchCompletion = localSearchCompletion
        self.input = input
    }
    
    public func detail(timeout: TimeInterval? = nil,
                       onSuccess: @escaping ((Place) -> (Void)),
                       onFail: ((LocationError) -> (Void))? = nil) {
        let request = MKLocalSearch.Request(completion: localSearchCompletion)
        localSearch = MKLocalSearch(request: request)
        localSearch?.start(completionHandler: { response, error in
            if let error = error {
                onFail?(LocationError.other(error.localizedDescription))
            } else if let response = response {
                if response.mapItems.count > 0, let item = response.mapItems.first {
                    if let place = Place(placemark: item.placemark) {
                        onSuccess(place)
                    } else {
                        onFail?(LocationError.failedToObtainData)
                    }
                } else {
                    onFail?(LocationError.failedToObtainData)
                }
            }
        })
    }
}
#endif
