//
//  StructuredOutput.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 23/12/24.
//

import Foundation

nonisolated protocol StructuredOutput: Codable {
	static var schemaName: String { get }
	nonisolated static var schemaDict: [String: Any] { get }
}
