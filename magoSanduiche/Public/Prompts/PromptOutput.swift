//
//  PromptOutput.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 08/12/25.
//

import Foundation
import FoundationModels

@Generable
struct PromptOutput {
	@Guide(
		description:
			" Use this field to describe the story, progression and consequences of user's actions in this world. Use paragraphs starting with `>` to denote progression. Describe the environment and the immediate consequences of the previous turn."
	)
	var narrative: String

	//@Guide(description: "The tools called and their output. Insert the tool's name and it's result.")
	//var toolResults: [String: String]

	@Guide(
		description:
			"Three distinct options representing different approaches and paths the mage can follow, these approaches can be aggressive, stealthy, intellectual, whatever fits the situation"
	)
	var options: [String]
}
