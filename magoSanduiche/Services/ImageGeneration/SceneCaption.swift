//
//  SceneCaption.swift
//  magoSanduiche
//

import Foundation
import FoundationModels

/// One turn's visible shot. The Mage's body, clothes, and palette stay in `scene_template.json`.
@Generable(description: "The shot to paint. A moving, high-contrast moment. Leave poseOrAction empty when nothing is visible.")
nonisolated struct SceneDirection: Equatable, Sendable {
	@Guide(description: "What the Mage is doing right now, one short clause of action in progress. Empty when nothing is visible. Do not describe age, beard, face, robe, or staff.")
	var poseOrAction: String

	@Guide(description: "One concrete room. Empty string keeps the current room.")
	var location: String

	@Guide(description: "One blinding light. Pitch-black background and a white-hot rim on the figure. Empty string keeps the current light.")
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

	@Guide(description: "push-in, pull-back, pan, tilt-up, tilt-down, or crane. A moving camera.")
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

/// Merges the locked sheet with one shot and renders the JSON prompt DreamLite paints.
enum SceneCaption {
	static let fallbackLocation = "a vast stone dungeon hall"
	static let fallbackLighting = "one hard torch amber light against deep shadow"
	/// Appended to every light so the figure separates from the room in a short glyph ramp.
	static let rimLight = "pitch-black void, white-hot rim light, silhouette bright against the black"

	static func compose(_ scene: SceneDirection, memory: inout SceneMemory) -> String {
		let sheet = SceneVisionTemplate.load()
		let location = remember(scene.location, into: &memory.location, fallback: fallbackLocation, words: 14)
		let lighting = remember(scene.lighting, into: &memory.lighting, fallback: fallbackLighting, words: 12)
		let shot = ShotLanguage.resolve(scene, defaults: sheet.artisticDirection.shot)
		let focusName = ShotLanguage.focusName(shot.focus)
		let phrases = ShotLanguage.phrases(shot, focusName: focusName)
		let art = artDirection(sheet.artisticDirection)

		let prompt = ScenePrompt(
			subject: .init(
				mainSubject: sheet.subject.mainSubject,
				poseOrAction: inMotion(scene.poseOrAction),
				attireOrDetails: sheet.subject.attireOrDetails
			),
			sceneAtmosphere: .init(
				location: location,
				lighting: hardLight(lighting),
				ambience: clip(scene.ambience, words: 4),
				threat: clip(scene.threat, words: 12)
			),
			artisticDirection: .init(
				style: art.style,
				epic: art.epic,
				colorPalette: sheet.artisticDirection.colorPalette,
				shot: .init(
					angle: phrases.angle,
					scale: phrases.scale,
					focus: shot.focus,
					lens: phrases.lens,
					move: phrases.move
				)
			)
		)
		return jsonString(prompt)
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

	/// ASCII keeps only a few luminance steps, so the pose is always mid-action.
	private static func inMotion(_ pose: String) -> String {
		let action = clip(pose, words: 12)
		guard !action.isEmpty else { return "moving through the frame" }
		if action.lowercased().contains("motion") {
			return action
		}
		return "\(action), mid-motion"
	}

	/// Every light gets a black void and a white-hot rim. A light that already says "hard" or "shadow" is still too close together for ASCII.
	private static func hardLight(_ lighting: String) -> String {
		if lighting.lowercased().contains("white-hot") {
			return lighting
		}
		return "\(lighting), \(rimLight)"
	}

	private static func artDirection(_ direction: SceneVisionSheet.ArtisticDirection) -> (style: String, epic: String) {
		var style = direction.style
		if !style.lowercased().contains("extreme contrast") {
			style += ", extreme contrast"
		}
		if !style.lowercased().contains("white-hot") {
			style += ", white-hot highlights against pitch black, no midtone gray"
		}
		if !style.lowercased().contains("mid-motion") {
			style += ", caught mid-motion"
		}
		var epic = direction.epic
		if !epic.lowercased().contains("rim light") {
			epic += ", white-hot rim light on a pitch-black void"
		}
		if !epic.lowercased().contains("sharp edges") {
			epic += ", sharp edges"
		}
		return (style, epic)
	}

	private static func jsonString(_ prompt: ScenePrompt) -> String {
		let encoder = JSONEncoder()
		encoder.keyEncodingStrategy = .convertToSnakeCase
		encoder.outputFormatting = [.withoutEscapingSlashes]
		guard let data = try? encoder.encode(prompt), let text = String(data: data, encoding: .utf8) else {
			return "{}"
		}
		return text
	}
}

/// The image prompt. Same shape as `scene_template.json`, filled for this shot.
private struct ScenePrompt: Encodable {
	var subject: Subject
	var sceneAtmosphere: Atmosphere
	var artisticDirection: ArtisticDirection

	struct Subject: Encodable {
		var mainSubject: String
		var poseOrAction: String
		var attireOrDetails: String
	}

	struct Atmosphere: Encodable {
		var location: String
		var lighting: String
		var ambience: String
		var threat: String

		func encode(to encoder: Encoder) throws {
			var container = encoder.container(keyedBy: CodingKeys.self)
			try container.encode(location, forKey: .location)
			try container.encode(lighting, forKey: .lighting)
			if !ambience.isEmpty {
				try container.encode(ambience, forKey: .ambience)
			}
			if !threat.isEmpty {
				try container.encode(threat, forKey: .threat)
			}
		}

		private enum CodingKeys: String, CodingKey {
			case location, lighting, ambience, threat
		}
	}

	struct ArtisticDirection: Encodable {
		var style: String
		var epic: String
		var colorPalette: [String]
		var shot: Shot
	}

	struct Shot: Encodable {
		var angle: String
		var scale: String
		var focus: String
		var lens: String
		var move: String
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
			style: "dark fantasy painting, extreme contrast, white-hot highlights against pitch black, no midtone gray, big clear shapes, caught mid-motion",
			epic: "white-hot rim light on a pitch-black void, sharp edges",
			colorPalette: ["pitch black", "bone white", "white-hot torch", "bright violet light"],
			shot: .init(angle: "low", scale: "wide", focus: "mage", lens: "deep", move: "push-in")
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
			move: moving(match(scene.move, aliases: moveAliases, fallback: defaults.move))
		)
	}

	static func focusName(_ focus: String) -> String {
		switch focus {
		case "threat": "the threat"
		case "prop": "one prop"
		default: "the mage"
		}
	}

	struct Phrases: Equatable {
		var angle: String
		var scale: String
		var lens: String
		var move: String
	}

	static func phrases(_ shot: Shot, focusName: String) -> Phrases {
		let angle =
			switch shot.angle {
			case "eye-level": "eye level, tracking with the motion"
			case "high": "high angle, dropping in with the motion"
			case "dutch": "tilted horizon, swinging with the motion"
			default: "low angle, driving up with the motion"
			}
		let scale =
			switch shot.scale {
			case "extreme wide": "extreme wide, the room sweeping past a moving figure"
			case "medium": "medium, \(focusName) large and in motion"
			case "close": "close on \(focusName) in motion"
			case "extreme close": "extreme close on \(focusName) in motion"
			default: "wide, \(focusName) large and moving through the room"
			}
		let lens =
			switch shot.lens {
			case "shallow": "white-hot edge on \(focusName), pitch-black background"
			default: "pitch-black background, white-hot edges, the room stays readable"
			}
		let move =
			switch shot.move {
			case "pull-back": "\(focusName) strides as the view pulls back"
			case "pan": "\(focusName) crosses the frame as the view pans"
			case "tilt-up": "\(focusName) rises as the view tilts up"
			case "tilt-down": "\(focusName) drops as the view tilts down"
			case "crane": "\(focusName) moves as the view cranes overhead"
			default: "\(focusName) moves toward the lens as the view pushes in"
			}
		return Phrases(angle: angle, scale: scale, lens: lens, move: move)
	}

	/// A locked or unknown camera still becomes a push-in. ASCII reads a frozen pose as a photograph.
	private static func moving(_ move: String) -> String {
		switch move {
		case "pull-back", "pan", "tilt-up", "tilt-down", "crane", "push-in":
			move
		default:
			"push-in"
		}
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
		"locked off": "push-in",
		"locked": "push-in",
		"static": "push-in",
		"still": "push-in",
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
