//
//  IntentHandler.swift
//  AthanSiriIntents
//
//  Created by Omar Al-Ejel on 10/25/18.
//  Copyright © 2018 Omar Alejel. All rights reserved.
//

import Intents

class IntentHandler: INExtension {
    
    override func handler(for intent: INIntent) -> Any {
        // This is the default implementation.  If you want different objects to handle different intents,
        // you can override this and return the handler you want for that particular intent.
        
        if intent is NextPrayerIntent {
            return NextPrayerIntentHandler()
        } else if intent is GetFajrIntent {
            return GetFajrHandler()
        } else if intent is GetThuhrIntent {
            return GetThuhrHandler()
        } else if intent is GetAsrIntent {
            return GetAsrHandler()
        } else if intent is GetMaghribIntent {
            return GetMaghribHandler()
        } else if intent is GetIshaIntent {
            return GetIshaHandler()
        }
        
        return self
    }
}
