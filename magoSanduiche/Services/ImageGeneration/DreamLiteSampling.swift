//
//  DreamLiteSampling.swift
//  magoSanduiche
//

import Foundation

/// `FlowMatchEulerDiscreteScheduler` as configured by `DreamLiteMobilePipeline`:
/// `sigmas = linspace(1, 1/n, n)`, exponential dynamic shift with `mu` from the latent size, Euler steps.
nonisolated struct DreamLiteFlowMatchSchedule: Equatable, Sendable {
	struct Configuration: Codable, Equatable, Sendable {
		var numTrainTimesteps: Int
		var baseImageSeqLen: Int
		var maxImageSeqLen: Int
		var baseShift: Double
		var maxShift: Double

		enum CodingKeys: String, CodingKey {
			case numTrainTimesteps = "num_train_timesteps"
			case baseImageSeqLen = "base_image_seq_len"
			case maxImageSeqLen = "max_image_seq_len"
			case baseShift = "base_shift"
			case maxShift = "max_shift"
		}

		static let dreamLiteMobile = Configuration(
			numTrainTimesteps: 1000,
			baseImageSeqLen: 256,
			maxImageSeqLen: 4096,
			baseShift: 0.5,
			maxShift: 1.15
		)
	}

	/// One sigma per step plus the trailing 0.
	let sigmas: [Double]
	let numTrainTimesteps: Int

	init(steps: Int, latentHeight: Int, latentWidth: Int, configuration: Configuration = .dreamLiteMobile) {
		let steps = max(1, steps)
		let imageSeqLen = Double(latentHeight * latentWidth / 4)
		let slope = (configuration.maxShift - configuration.baseShift)
			/ Double(configuration.maxImageSeqLen - configuration.baseImageSeqLen)
		let mu = imageSeqLen * slope + (configuration.baseShift - slope * Double(configuration.baseImageSeqLen))
		let shift = exp(mu)
		var sigmas: [Double] = []
		sigmas.reserveCapacity(steps + 1)
		for index in 0..<steps {
			let sigma = steps == 1 ? 1 : 1 - Double(index) * (1 - 1 / Double(steps)) / Double(steps - 1)
			sigmas.append(shift / (shift + (1 / sigma - 1)))
		}
		sigmas.append(0)
		self.sigmas = sigmas
		self.numTrainTimesteps = configuration.numTrainTimesteps
	}

	var stepCount: Int { sigmas.count - 1 }

	func timestep(at index: Int) -> Float {
		Float(sigmas[index] * Double(numTrainTimesteps))
	}

	/// `x_{i+1} = x_i + (sigma_{i+1} - sigma_i) * v`
	func step(_ latents: inout [Float], velocity: [Float], at index: Int) {
		precondition(latents.count == velocity.count)
		let delta = Float(sigmas[index + 1] - sigmas[index])
		for i in latents.indices {
			latents[i] += delta * velocity[i]
		}
	}
}

/// Seeded standard-normal noise (SplitMix64 + Box–Muller) so a scene can be regenerated from its seed.
nonisolated struct DreamLiteNoise {
	private var state: UInt64

	init(seed: UInt64) {
		state = seed
	}

	mutating func next() -> UInt64 {
		state &+= 0x9E37_79B9_7F4A_7C15
		var z = state
		z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
		z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
		return z ^ (z >> 31)
	}

	private mutating func unitInterval() -> Double {
		(Double(next() >> 11) + 0.5) / Double(1 << 53)
	}

	mutating func gaussian(count: Int) -> [Float] {
		var values = [Float](repeating: 0, count: count)
		var index = 0
		while index < count {
			let radius = (-2 * log(unitInterval())).squareRoot()
			let angle = 2 * Double.pi * unitInterval()
			values[index] = Float(radius * cos(angle))
			if index + 1 < count {
				values[index + 1] = Float(radius * sin(angle))
			}
			index += 2
		}
		return values
	}
}
