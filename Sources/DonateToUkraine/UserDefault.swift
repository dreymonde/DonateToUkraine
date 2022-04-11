//
//  UserDefaults.swift
//  NiceScanner
//
//  Created by Oleg Dreyman on 3/26/20.
//  Copyright © 2020 Nice Photon. All rights reserved.
//

import Foundation

struct UserDefaultsKey<Value>: Hashable {
    
    var rawValue: String
    
    init(_ key: String) {
        self.rawValue = key
    }
}

protocol UserDefaultsDefaultRetrievable {
    static func retrieveNonOptional(from userDefaults: UserDefaults) -> (_ key: String) -> Self
    static func inMemoryDefault() -> Self
}

extension Bool: UserDefaultsDefaultRetrievable {
    static func retrieveNonOptional(from userDefaults: UserDefaults) -> (String) -> Bool {
        return userDefaults.bool(forKey:)
    }
    
    static func inMemoryDefault() -> Bool {
        return false
    }
}

extension Int: UserDefaultsDefaultRetrievable {
    static func retrieveNonOptional(from userDefaults: UserDefaults) -> (String) -> Int {
        return userDefaults.integer(forKey:)
    }
    
    static func inMemoryDefault() -> Int {
        return 0
    }
}

extension Double: UserDefaultsDefaultRetrievable {
    static func retrieveNonOptional(from userDefaults: UserDefaults) -> (String) -> Double {
        return userDefaults.double(forKey:)
    }
    
    static func inMemoryDefault() -> Double {
        return 0
    }
}

extension Optional: UserDefaultsDefaultRetrievable where Wrapped == String {
    static func retrieveNonOptional(from userDefaults: UserDefaults) -> (String) -> Optional<Wrapped> {
        return { userDefaults.string(forKey: $0) }
    }
    
    static func inMemoryDefault() -> Optional<Wrapped> {
        return nil
    }
}

extension UserDefaults {

    func value<Value>(forKey key: UserDefaultsKey<Value>) -> Value? {
        return value(forKey: key.rawValue) as? Value
    }
    
    func value<Value : UserDefaultsDefaultRetrievable>(forKey key: UserDefaultsKey<Value>) -> Value {
        return Value.retrieveNonOptional(from: self)(key.rawValue)
    }
    
    func value<Value : RawRepresentable>(forKey key: UserDefaultsKey<Value>) -> Value? where Value.RawValue == String {
        return string(forKey: key.rawValue)
            .flatMap(Value.init(rawValue:))
    }
}

extension UserDefaults {
    
    func set<Value>(_ value: Value?, forKey key: UserDefaultsKey<Value>) {
        set(value, forKey: key.rawValue)
    }
    
    func set<Value : RawRepresentable>(_ value: Value?, forKey key: UserDefaultsKey<Value>) where Value.RawValue == String {
        set(value?.rawValue, forKey: key.rawValue)
    }
    
}

extension UserDefaults {
    
    func remove<Value>(atKey key: UserDefaultsKey<Value>) {
        removeObject(forKey: key.rawValue)
    }
    
}

extension UserDefaults {
    func register<Value: UserDefaultsDefaultRetrievable>(defaultValue value: Value, forKey key: UserDefaultsKey<Value>) {
        self.register(defaults: [key.rawValue: value])
    }
}

@propertyWrapper
struct UserDefault<Value: UserDefaultsDefaultRetrievable> {
    
    let userDefaults: UserDefaults
    let key: UserDefaultsKey<Value>
    
    //swiftlint:disable function_default_parameter_at_end
    init(userDefaults: UserDefaults = UserDefaults.standard,
         _ key: String) {
        self.userDefaults = userDefaults
        self.key = UserDefaultsKey<Value>(key)
    }
    
    var wrappedValue: Value {
        get {
            return userDefaults.value(forKey: key)
        }
        set {
            userDefaults.set(newValue, forKey: key)
        }
    }
}

@propertyWrapper
struct JSONUserDefault<T: Codable> {
    
    let userDefaults: UserDefaults
    let key: UserDefaultsKey<T>
    let defaultValue: T
    
    //swiftlint:disable function_default_parameter_at_end
    init(userDefaults: UserDefaults = UserDefaults.standard,
         _ key: String, default defaultValue: T) {
        self.userDefaults = userDefaults
        self.key = UserDefaultsKey<T>(key)
        self.defaultValue = defaultValue
    }
    
    var wrappedValue: T {
        get {
            guard let data = userDefaults.data(forKey: key.rawValue) else {
                return defaultValue
            }
            
            let object = try? JSONDecoder().decode(T.self, from: data)
            return object ?? defaultValue
        }
        
        set {
            let data = try? JSONEncoder().encode(newValue)
            userDefaults.set(data, forKey: key.rawValue)
        }
    }
}
