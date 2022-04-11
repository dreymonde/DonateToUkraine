//
//  File.swift
//  
//
//  Created by Oleg Dreyman on 11.04.2022.
//

import Foundation

enum UkraineDonationTracking {
    @UserDefault("__DonateToUkraine.totalDonatedUAH")
    static var _totalDonatedUAH: Int

    @JSONUserDefault("__DonateToUkraine.donationReceipts", default: [])
    static var _donationReceipts: [UkraineDonation]
}

extension UkraineDonationTracking {
    static func didDonate(donation: UkraineDonation) {
        assert(Thread.isMainThread)
        _totalDonatedUAH += donation.amount.uah
        _donationReceipts.append(donation)
    }
}
