//
//  File.swift
//  
//
//  Created by Oleg Dreyman on 11.04.2022.
//

import Foundation

public struct UkraineDonation: Codable {
    public var amount: AmountUAH
    public var receiptId: String
    public var donatedAt: Date

    public var verificationLink: URL? {
        return URL(string: "http://uahelp.monobank.ua/done/\(receiptId)")
    }
}

extension UkraineDonation {
    public struct AmountUAH: Codable {
        public var rawValue: String
        public var uah: Int

        public init?(rawValue: String) {
            self.rawValue = rawValue
            let nums = rawValue.filter({ $0.isNumber })
            guard !nums.isEmpty else {
                return nil
            }
            self.uah = Int(nums) ?? 0
        }

        public init(uah: Int) {
            self.rawValue = uah.description
            self.uah = uah
        }

        public var approxUSD: Int {
            return uah / 29
        }
    }
}
