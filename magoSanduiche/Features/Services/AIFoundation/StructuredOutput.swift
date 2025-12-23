//
//  StructuredOutput.swift
//  magoSanduiche
//
//  Created by Migration on 23/12/24.
//

import Foundation
import OpenAI

/// Protocol for types that can be generated as structured outputs from OpenAI.
/// Conforming types provide both a schema definition and Codable decoding.
nonisolated protocol StructuredOutput: Codable {
    /// A stable identifier for the output used in API requests.
    static var schemaName: String { get }

    /// The JSON schema as a dictionary that describes the structure of this output type.
    /// This will be encoded and passed to the OpenAI API.
    nonisolated static var schemaDict: [String: Any] { get }
}
