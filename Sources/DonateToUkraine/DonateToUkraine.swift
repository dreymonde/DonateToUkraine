//
//  File.swift
//  
//
//  Created by Oleg Dreyman on 11.04.2022.
//

import UIKit

public enum DonateToUkraine {

    public static func withDonation(contextViewController: UIViewController, then completion: @escaping (UkraineDonation) -> Void) {
        let donationVC = DonateToUkraineViewController(completion: completion)
        contextViewController.present(donationVC, animated: true, completion: nil)
    }
}

extension DonateToUkraine {
    static public var hasDonated: Bool {
        !donationReceipts.isEmpty
    }

    static public var totalDonatedUAH: UkraineDonation.AmountUAH {
        return .init(uah: UkraineDonationTracking._totalDonatedUAH)
    }

    static public var donationReceipts: [UkraineDonation] {
        UkraineDonationTracking._donationReceipts
    }
}

