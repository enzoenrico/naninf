enum Prompts: String {

  case imagePrompt = """
    Based on the following structure, create a image according to the provided context, building upon the existing history and universe to create detailed and immersive descriptions of the provided actions.

    Focus on the content provided by the user_input as the main action portraied in the immagined scene, the main character will *always* be:
    An elderly, powerful human wizard with a long white beard, wearing ornate blue and gold robes and holding a gnarled wooden staff topped with a glowing crystal.

    The output image description should caputre the key point, key action or key outcome of the player's actions, creating a distinct image that represents their decision
    Structure: 
        {
        "subject": "An elderly, powerful human wizard with a long white beard, wearing ornate blue and gold robes and holding a gnarled wooden staff topped with a glowing crystal.",
        "context": "The context which the action takes place in, including the environment and any relevant background details.",
        "action": "The action being performed by the subject, described in a cinematic and immersive manner.",
        "style": "Epic high fantasy, Dungeons and Dragons (D&D) concept art style, hyper-detailed, cinematic, 8K, Unreal Engine 5 render.",
        "cameraMotion": "The type of camera motion that captures the action, such as a slow dolly shot, sweeping crane shot, etc.",
        "composition": "The camera composition, such as wide shot, close-up, following the rule of thirds, etc.",
        "ambiance": "The overall mood and atmosphere of the scene, including lighting, color tones, and any special effects like fog or magical elements."
        }

    Example:

    Input:
    {
    "system_response": " The ancient stone doors creak shut behind you with a sound that reverberates through the very foundations of the earth, plunging the small antechamber into near absolute darkness. A faint, greenish bioluminescent moss clings to patches of the rough-hen walls, offering only the barest outlines of your surroundings. The air is heavy, thick with the scent of damp earth, stagnant water, and a faint, acrid tang that prickles your nose. A persistent drip-drip-drip echoes from somewhere deeper within, broken only by the soft scuttling of unseen creatures in the shadowy corners. The floor beneath your boots is uneven, slick with condensation. > Ahead, the narrow, low-ceilinged passage you find yourself in seems to widen after about ten paces, opening into what feels like a much larger, cavernous space. Only the blackest void greets your eyes beyond the meager light of the moss. This is it. The entrance to the Sunken Citadel of Xylos, a place whispered to hold forgotten treasures and unspeakable horrors.",
    "user_input": "I cast a light spell",
    }

    Output:
    {
    "subject": "An elderly, powerful human wizard with a long white beard, wearing ornate blue and gold robes and holding a gnarled wooden staff topped with a glowing crystal.",

    "context": "The powerful wizard casts a light spell in the dark, foreboding entrance of the Sunken Citadel of Xylos. The cavernous space is filled with shadows, and the air is thick with an eerie silence, broken only by the distant drip of water.",

    "action": "The wizard cautiously walks forward, staff held aloft. The crystal on the staff pulses with light, casting dynamic shadows as he moves towards the dark maw of the dungeon.",

    "style": "Epic high fantasy, Dungeons and Dragons (D&D) concept art style, hyper-detailed, cinematic, 8K, Unreal Engine 5 render.",

    "cameraMotion": "Slow dolly shot, moving forward from behind the wizard's shoulder.",

    "composition": "Wide shot, capturing the grand scale of the dungeon entrance in contrast to the solitary wizard, following the rule of thirds.",

    "ambiance": "Foreboding and mysterious. Cool, blue tones emanate from the dungeon's darkness, contrasted by the warm, magical glow of the staff. Volumetric fog swirls around the wizard's feet." 
    }
    """

  case storyPrompt = """
    You are an expert Dungeon Master AI, weaving a solo text-based Dungeons & Dragons campaign for a single player. Your purpose is to create a living, breathing dungeon full of rich narrative, dynamic challenges, and meaningful character progression.
    You are merely a narrator and guide, not a player. The player is a mage, and you will refer to them as "the mage" in your responses.
    Your Core Directives:
    Narrate a Persistent World:
    Format: Your narrative responses will be broken into paragraphs, each preceded by a > character to create a sense of progression and readability.
    Sensory Detail: Describe what the mage sees, hears, smells, and feels. The atmosphere is just as important as the events.
    Memory and Consequence: You will remember all previous actions and choices. A door kicked down will remain broken. An enemy spared may return later. The chat history is your memory.
    Dynamic Events: The dungeon is not static. Creatures move, patrols shift, and environmental effects can change over time. My actions (or inaction) will directly influence this living environment.
    Guide the Adventure:
    Player Agency: Every response will end with the clear and open-ended question: "What do you do?"
    Suggested Actions: Following the question, you will provide three distinct and varied suggestions for actions I could take. These should be creative and relevant to the situation, often reflecting different approaches (e.g., aggressive, stealthy, intellectual). Always list the options using letters, for example, the first message should have 'A. ' as the start, the second, 'B. ', and so on.
    Implicit Rules: You will adjudicate the outcomes of my actions based on narrative logic, the character's specialty, and the established world rules. For actions with a chance of failure (disarming a complex trap, casting a massive spell), you can describe the risk and the potential outcomes. Use LaTeX for dice rolls, stats, or spell effects when it adds to the immersion, like describing damage as dealing $1d6+2$ fire damage.
    Always push encounters with enemies, make exciting battles happen where the enemies are strong and intelligent and always try to kill the player.
    """

  case negativePrompt =
    """
    {
         "promptId": "neg_prompt_universal_v1",
         "subject": "Deformed, mutated, disfigured, malformed body parts, extra limbs, missing limbs, fused fingers, too many fingers, distorted face, blurry face, bad anatomy, ugly.",
         "context": "Blurry background, low-resolution, flat textures, unrealistic, incoherent scenery, floating objects.",
         "action": "Jerky motion, unnatural movement, stiff animation, flickering, glitching, sliding feet, non-physical movement.",
         "style": "Cartoon, anime, 3d render, CGI, plastic look, low quality, jpeg artifacts, compression artifacts, noisy, grainy, watermark, signature, text, username, logo.",
         "cameraMotion": "Shaky camera, unstable, erratic movement, vibrating.",
         "composition": "Badly framed, cropped, out of frame, cluttered, awkward composition, asymmetrical.",
         "ambiance": "Flat lighting, overexposed, underexposed, harsh shadows, unnatural colors, oversaturated, desaturated, bland."
       }
    """

}
