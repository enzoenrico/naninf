//
//  SceneCaptionTests.swift
//  magoSanduicheTests
//

import Foundation
import Testing
@testable import magoSanduiche

struct SceneCaptionTests {
	@Test func emptyPoseIsNotIllustrated() {
		let scene = SceneDirection(poseOrAction: "  ").illustrated
		#expect(scene == nil)
	}

	@Test func captionLocksTheMageAndRemembersTheRoom() throws {
		var memory = SceneMemory()
		let first = SceneCaption.compose(
			SceneDirection(
				poseOrAction: "raises the staff",
				location: "a flooded crypt",
				lighting: "green witchfire from the water",
				ambience: "dread",
				threat: "a drowned priest climbing the stairs",
				angle: "low",
				scale: "wide",
				focus: "mage",
				lens: "deep",
				move: "push-in"
			),
			memory: &memory
		)

		let root = try jsonObject(first)
		let subject = try #require(root["subject"] as? [String: Any])
		let atmosphere = try #require(root["scene_atmosphere"] as? [String: Any])
		let direction = try #require(root["artistic_direction"] as? [String: Any])
		let shot = try #require(direction["shot"] as? [String: Any])
		let palette = try #require(direction["color_palette"] as? [String])

		#expect((subject["main_subject"] as? String)?.contains("long beard") == true)
		#expect((subject["attire_or_details"] as? String)?.contains("cracked crystal") == true)
		#expect(subject["pose_or_action"] as? String == "raises the staff, mid-motion")
		#expect(atmosphere["location"] as? String == "a flooded crypt")
		#expect(atmosphere["lighting"] as? String == "green witchfire from the water, \(SceneCaption.rimLight)")
		#expect(atmosphere["ambience"] as? String == "dread")
		#expect(atmosphere["threat"] as? String == "a drowned priest climbing the stairs")
		#expect(shot["angle"] as? String == "low angle, driving up with the motion")
		#expect((shot["move"] as? String)?.contains("pushes in") == true)
		#expect((direction["style"] as? String)?.contains("extreme contrast") == true)
		#expect((direction["style"] as? String)?.contains("mid-motion") == true)
		#expect((direction["epic"] as? String)?.contains("white-hot rim light") == true)
		#expect((direction["style"] as? String)?.contains("pitch black") == true)
		#expect(shot["focus"] as? String == "mage")
		#expect(palette.contains("pitch black"))
		#expect(palette.contains("bone white"))
		#expect(!first.lowercased().contains("watermark"))
		#expect(memory.location == "a flooded crypt")

		let second = SceneCaption.compose(
			SceneDirection(poseOrAction: "steps back", move: "pan"),
			memory: &memory
		)

		let remembered = try jsonObject(second)
		let rememberedAtmosphere = try #require(remembered["scene_atmosphere"] as? [String: Any])
		let rememberedShot = try #require(
			(remembered["artistic_direction"] as? [String: Any])?["shot"] as? [String: Any]
		)
		#expect(rememberedAtmosphere["location"] as? String == "a flooded crypt")
		#expect(rememberedAtmosphere["lighting"] as? String == "green witchfire from the water, \(SceneCaption.rimLight)")
		#expect(rememberedAtmosphere["threat"] == nil)
		#expect((rememberedShot["move"] as? String)?.contains("pans") == true)
		#expect(memory.location == "a flooded crypt")
	}

	@Test func aNewRoomReplacesTheRememberedOne() {
		var memory = SceneMemory(location: "a flooded crypt", lighting: "green witchfire")
		_ = SceneCaption.compose(
			SceneDirection(poseOrAction: "enters", location: "a collapsed bridge"),
			memory: &memory
		)
		#expect(memory.location == "a collapsed bridge")
		#expect(memory.lighting == "green witchfire")
	}

	@Test func firstImageUsesTheFallbackHall() throws {
		var memory = SceneMemory()
		let caption = SceneCaption.compose(
			SceneDirection(poseOrAction: "stands ready"),
			memory: &memory
		)
		let atmosphere = try #require(jsonObject(caption)["scene_atmosphere"] as? [String: Any])
		let direction = try #require(jsonObject(caption)["artistic_direction"] as? [String: Any])
		let shot = try #require(direction["shot"] as? [String: Any])
		let subject = try #require(jsonObject(caption)["subject"] as? [String: Any])
		#expect(atmosphere["location"] as? String == SceneCaption.fallbackLocation)
		#expect(atmosphere["lighting"] as? String == "\(SceneCaption.fallbackLighting), \(SceneCaption.rimLight)")
		#expect((subject["pose_or_action"] as? String)?.contains("mid-motion") == true)
		#expect((shot["move"] as? String)?.contains("pushes in") == true)
		#expect((shot["move"] as? String)?.localizedCaseInsensitiveContains("still") != true)
		#expect((direction["style"] as? String)?.contains("extreme contrast") == true)
		#expect(memory.location == SceneCaption.fallbackLocation)
		#expect(memory.lighting == SceneCaption.fallbackLighting)
	}

	@Test func aLockedCameraStillBecomesMotionAndHardLight() throws {
		var memory = SceneMemory()
		let caption = SceneCaption.compose(
			SceneDirection(
				poseOrAction: "stands ready",
				lighting: "soft candle glow",
				move: "locked-off"
			),
			memory: &memory
		)
		let root = try jsonObject(caption)
		let subject = try #require(root["subject"] as? [String: Any])
		let atmosphere = try #require(root["scene_atmosphere"] as? [String: Any])
		let direction = try #require(root["artistic_direction"] as? [String: Any])
		let shot = try #require(direction["shot"] as? [String: Any])
		let move = try #require(shot["move"] as? String)
		let lens = try #require(shot["lens"] as? String)

		#expect(subject["pose_or_action"] as? String == "stands ready, mid-motion")
		#expect(atmosphere["lighting"] as? String == "soft candle glow, \(SceneCaption.rimLight)")
		#expect(move.contains("pushes in"))
		#expect(!move.localizedCaseInsensitiveContains("still"))
		#expect(lens.contains("black"))
		#expect((direction["style"] as? String)?.contains("extreme contrast") == true)
		#expect((direction["epic"] as? String)?.contains("pitch-black") == true)
		#expect(lens.contains("white-hot"))
	}

	private func jsonObject(_ caption: String) throws -> [String: Any] {
		let data = try #require(caption.data(using: .utf8))
		return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
	}
}
