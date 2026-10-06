//
//  DungeonMasterError.swift
//  magoSanduiche
//

import Foundation
import FoundationModels

nonisolated enum DungeonMasterError: Error, Equatable, Sendable {
	case unavailable(PCCUnavailability)
	case quotaReached(resetDate: Date?)
	case unreachable
	case refused
	case cancelled
	case failed(String)

	var terminalMessage: String {
		switch self {
		case .unavailable(.deviceNotEligible):
			String(localized: "nan_dm_unavailable_device")
		case .unavailable(.systemNotReady):
			String(localized: "nan_dm_unavailable_not_ready")
		case .quotaReached(let resetDate):
			if let resetDate {
				String(
					format: String(localized: "nan_dm_quota_reached"),
					resetDate.formatted(date: .abbreviated, time: .omitted)
				)
			} else {
				String(localized: "nan_dm_quota_reached_plain")
			}
		case .unreachable:
			String(localized: "nan_dm_offline")
		case .refused:
			String(localized: "nan_dm_refused")
		case .cancelled, .failed:
			String(localized: "nan_dm_error")
		}
	}

	var analyticsKind: String {
		switch self {
		case .unavailable(.deviceNotEligible):
			"unavailable_device"
		case .unavailable(.systemNotReady):
			"unavailable_system"
		case .quotaReached:
			"quota_reached"
		case .unreachable:
			"unreachable"
		case .refused:
			"refused"
		case .cancelled:
			"cancelled"
		case .failed:
			"failed"
		}
	}

	var analyticsDetail: String? {
		switch self {
		case .failed(let message):
			message.count > 160 ? String(message.prefix(160)) : message
		case .unavailable, .quotaReached, .unreachable, .refused, .cancelled:
			nil
		}
	}
}

nonisolated enum PCCUnavailability: Equatable, Sendable {
	case deviceNotEligible
	case systemNotReady
}

nonisolated enum PrivateCloudAccess: Equatable, Sendable {
	case granted
	case denied(PCCUnavailability)

	init(availability: PrivateCloudComputeLanguageModel.Availability) {
		switch availability {
		case .available:
			self = .granted
		case .unavailable(.deviceNotEligible):
			self = .denied(.deviceNotEligible)
		case .unavailable(.systemNotReady):
			self = .denied(.systemNotReady)
		@unknown default:
			self = .denied(.systemNotReady)
		}
	}
}
