//
//  SceneCaptionTests.swift
//  magoSanduicheTests
//

import Testing
@testable import magoSanduiche

struct SceneCaptionTests {
	@Test func emptyPoseIsNotIllustrated() {
		let scene = SceneDirection(poseOrAction: "  ").illustrated
		#expect(scene == nil)
	}

	@Test func captionLocksTheMageAndRemembersTheRoom() {
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

		#expect(first.contains("long beard"))
		#expect(first.contains("cracked crystal"))
		#expect(first.contains("a flooded crypt"))
		#expect(first.contains("camera low, looking up"))
		#expect(first.contains("fills more of the frame"))
		#expect(!first.lowercased().contains("watermark"))
		#expect(memory.location == "a flooded crypt")

		let second = SceneCaption.compose(
			SceneDirection(poseOrAction: "steps back", move: "pan"),
			memory: &memory
		)

		#expect(second.contains("a flooded crypt"))
		#expect(second.contains("green witchfire from the water"))
		#expect(second.contains("sits to one side"))
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

	@Test func firstImageUsesTheFallbackHall() {
		var memory = SceneMemory()
		let caption = SceneCaption.compose(
			SceneDirection(poseOrAction: "stands ready"),
			memory: &memory
		)
		#expect(caption.contains(SceneCaption.fallbackLocation))
		#expect(memory.location == SceneCaption.fallbackLocation)
		#expect(memory.lighting == SceneCaption.fallbackLighting)
	}
}
