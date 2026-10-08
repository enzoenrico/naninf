//
//  SceneCaption.swift
//  magoSanduiche
//

import Foundation
import FoundationModels

/// One turn's visible shot. The Mage's body, clothes, and palette stay in `scene_template.json`.
@Generable(description: "The shot to paint. Leave poseOrAction empty when nothing is visible.")
nonisolated struct SceneDirection: Equatable, Sendable {
	@Guide(description: "What the Mage is doing right now, one short clause. Empty when nothing is visible. Do not describe age, beard, face, robe, or staff.")
	var poseOrAction: String

	@Guide(description: "One concrete room. Empty string keeps the current room.")
	var location: String

	@Guide(description: "One dominant light source. Empty string keeps the current light.")
	var lighting: String

	@Guide(description: "One mood word: dread, awe, hush, fury, or wonder. Empty if unchanged.")
	var ambience: String

	@Guide(description: "One visible danger. Empty when nothing else shares the frame.")
	var threat: String

	@Guide(description: "eye-level, low, high, or dutch.")
	var angle: String

	@Guide(description: "extreme wide, wide, medium, close, or extreme close.")
	var scale: String

	@Guide(description: "mage, threat, or prop.")
	var focus: String

	@Guide(description: "deep or shallow.")
	var lens: String

	@Guide(description: "locked-off, push-in, pull-back, pan, tilt-up, tilt-down, or crane.")
	var move: String

	init(
		poseOrAction: String = "",
		location: String = "",
		lighting: String = "",
		ambience: String = "",
		threat: String = "",
		angle: String = "",
		scale: String = "",
		focus: String = "",
		lens: String = "",
		move: String = ""
	) {
		self.poseOrAction = poseOrAction
		self.location = location
		self.lighting = lighting
		self.ambience = ambience
		self.threat = threat
		self.angle = angle
		self.scale = scale
		self.focus = focus
		self.lens = lens
		self.move = move
	}

	/// A shot with something to paint. Dialogue and blackouts stay `nil`.
	var illustrated: SceneDirection? {
		let pose = poseOrAction.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !pose.isEmpty else { return nil }
		var copy = self
		copy.poseOrAction = pose
		return copy
	}
}

struct SceneMemory: Equatable, Sendable {
	var location = ""
	var lighting = ""
}

/// Merges the locked sheet with one shot and renders the caption DreamLite paints.
enum SceneCaption {
	static let fallbackLocation = "a vast stone dungeon hall"
	static let fallbackLighting = "one hard torch amber light against deep shadow"

	static func compose(_ scene: SceneDirection, memory: inout SceneMemory) -> String {
		let sheet = SceneVisionTemplate.load()
		let location = remember(scene.location, into: &memory.location, fallback: fallbackLocation, words: 14)
		let lighting = remember(scene.lighting, into: &memory.lighting, fallback: fallbackLighting, words: 12)
		let shot = ShotLanguage.resolve(scene, defaults: sheet.artisticDirection.shot)
		let focusName = ShotLanguage.focusName(shot.focus)

		var clauses = [
			sheet.subject.mainSubject,
			sheet.subject.attireOrDetails,
			sheet.artisticDirection.style,
			"palette of \(sheet.artisticDirection.colorPalette.joined(separator: ", "))",
			sheet.artisticDirection.epic,
			ShotLanguage.sentence(shot, focusName: focusName),
			clip(scene.poseOrAction, words: 14),
			location,
			lighting,
		]
		let ambience = clip(scene.ambience, words: 4)
		if !ambience.isEmpty {
			clauses.append("atmosphere of \(ambience)")
		}
		let threat = clip(scene.threat, words: 12)
		if !threat.isEmpty {
			clauses.append(threat)
		}
		return clauses.joined(separator: ". ")
	}

	private static func remember(_ incoming: String, into stored: inout String, fallback: String, words: Int) -> String {
		let trimmed = clip(incoming, words: words)
		if !trimmed.isEmpty {
			stored = trimmed
			return trimmed
		}
		if !stored.isEmpty {
			return stored
		}
		stored = fallback
		return fallback
	}

	private static func clip(_ text: String, words: Int) -> String {
		let parts = text.split { $0.isWhitespace }.prefix(words)
		return parts.joined(separator: " ")
	}
}

private struct SceneVisionSheet: Decodable, Sendable {
	var subject: Subject
	var artisticDirection: ArtisticDirection

	struct Subject: Decodable, Sendable {
		var mainSubject: String
		var attireOrDetails: String
	}

	struct ArtisticDirection: Decodable, Sendable {
		var style: String
		var epic: String
		var colorPalette: [String]
		var shot: ShotDefaults
	}

	struct ShotDefaults: Decodable, Sendable {
		var angle: String
		var scale: String
		var focus: String
		var lens: String
		var move: String
	}
}

enum SceneVisionTemplate {
	fileprivate static func load(bundle: Bundle = .main) -> SceneVisionSheet {
		guard
			let url = bundle.url(forResource: "scene_template", withExtension: "json"),
			let data = try? Data(contentsOf: url),
			let sheet = try? decoder.decode(SceneVisionSheet.self, from: data)
		else {
			return embedded
		}
		return sheet
	}

	private static let decoder: JSONDecoder = {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		return decoder
	}()

	/// Used when the bundled file cannot be read. Keep it identical to `scene_template.json`.
	private static let embedded = SceneVisionSheet(
		subject: .init(
			mainSubject: "one old mage, hood up, long beard, face lost in shadow",
			attireOrDetails: "charcoal hooded robe with a deep violet lining, worn leather belt, no armor, a tall black staff topped with a cracked crystal"
		),
		artisticDirection: .init(
			style: "dark fantasy cinematic painting, high contrast, big clear shapes, epic scale",
			epic: "one hard light against deep shadow",
			colorPalette: ["charcoal", "bone", "violet spell-light", "torch amber"],
			shot: .init(angle: "low", scale: "wide", focus: "mage", lens: "deep", move: "locked-off")
		)
	)
}

private enum ShotLanguage {
	struct Shot: Equatable {
		var angle: String
		var scale: String
		var focus: String
		var lens: String
		var move: String
	}

	static func resolve(_ scene: SceneDirection, defaults: SceneVisionSheet.ShotDefaults) -> Shot {
		Shot(
			angle: match(scene.angle, aliases: angleAliases, fallback: defaults.angle),
			scale: match(scene.scale, aliases: scaleAliases, fallback: defaults.scale),
			focus: match(scene.focus, aliases: focusAliases, fallback: defaults.focus),
			lens: match(scene.lens, aliases: lensAliases, fallback: defaults.lens),
			move: match(scene.move, aliases: moveAliases, fallback: defaults.move)
		)
	}

	static func focusName(_ focus: String) -> String {
		switch focus {
		case "threat": "the threat"
		case "prop": "one prop"
		default: "the mage"
		}
	}

	static func sentence(_ shot: Shot, focusName: String) -> String {
		let angle =
			switch shot.angle {
			case "eye-level": "camera at eye level"
			case "high": "camera high, looking down"
			case "dutch": "tilted horizon"
			default: "camera low, looking up"
			}
		let scale =
			switch shot.scale {
			case "extreme wide": "extreme wide view, the room immense"
			case "medium": "medium view, the mage large in frame"
			case "close": "close view on \(focusName)"
			case "extreme close": "extreme close view on \(focusName)"
			default: "wide view, the mage large in the room"
			}
		let lens =
			switch shot.lens {
			case "shallow": "shallow focus, only \(focusName) is sharp"
			default: "deep focus, the room stays readable"
			}
		let move =
			switch shot.move {
			case "push-in": "\(focusName) fills more of the frame and the background presses close"
			case "pull-back": "the room opens around \(focusName)"
			case "pan": "\(focusName) sits to one side with empty room ahead of the look"
			case "tilt-up": "the frame rises, ceiling and vertical scale visible"
			case "tilt-down": "the frame drops, the floor in the foreground"
			case "crane": "a high view, the floor pattern visible, the room spread out"
			default: "the frame is still"
			}
		return "\(angle), \(scale), \(lens), \(move)"
	}

	private static func match(_ raw: String, aliases: [String: String], fallback: String) -> String {
		let key = raw
			.lowercased()
			.replacingOccurrences(of: "_", with: " ")
			.replacingOccurrences(of: "-", with: " ")
			.split { $0.isWhitespace }
			.joined(separator: " ")
		if let canonical = aliases[key] {
			return canonical
		}
		return aliases[fallback] ?? fallback
	}

	private static let angleAliases = [
		"eye level": "eye-level",
		"eyelevel": "eye-level",
		"low": "low",
		"low angle": "low",
		"high": "high",
		"high angle": "high",
		"dutch": "dutch",
		"dutch angle": "dutch",
		"canted": "dutch",
	]

	private static let scaleAliases = [
		"extreme wide": "extreme wide",
		"establishing": "extreme wide",
		"wide": "wide",
		"medium": "medium",
		"close": "close",
		"close up": "close",
		"closeup": "close",
		"extreme close": "extreme close",
		"extreme close up": "extreme close",
	]

	private static let focusAliases = [
		"mage": "mage",
		"the mage": "mage",
		"subject": "mage",
		"threat": "threat",
		"danger": "threat",
		"enemy": "threat",
		"prop": "prop",
		"object": "prop",
		"staff": "prop",
	]

	private static let lensAliases = [
		"deep": "deep",
		"deep focus": "deep",
		"shallow": "shallow",
		"shallow focus": "shallow",
	]

	private static let moveAliases = [
		"locked off": "locked-off",
		"locked": "locked-off",
		"static": "locked-off",
		"push in": "push-in",
		"zoom in": "push-in",
		"pull back": "pull-back",
		"zoom out": "pull-back",
		"pan": "pan",
		"pan left": "pan",
		"pan right": "pan",
		"tilt up": "tilt-up",
		"tilt down": "tilt-down",
		"crane": "crane",
	]
}
