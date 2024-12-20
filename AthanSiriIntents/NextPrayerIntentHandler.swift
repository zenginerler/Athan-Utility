//
//  NextPrayerIntent.swift
//  AthanSiriIntents
//
//  Created by Omar Al-Ejel on 5/7/19.
//  Copyright © 2019 Omar Alejel. All rights reserved.
//

import Foundation
import Intents

// for requests like "when is the next prayer?"
// should respond with the time, and remaining hours, minutes

class NextPrayerIntentHandler: NSObject, NextPrayerIntentHandling {
    
    var locationIsSynced: Bool = true
    let manager = AthanManager.shared
    
    func handle(intent: NextPrayerIntent, completion: @escaping (NextPrayerIntentResponse) -> Void) {
        // get prayer data if available
        
        guard let currentSalah = manager.currentPrayer else {
            completion(NextPrayerIntentResponse(code: .failure, userActivity: nil))
            return
        }
        
        let upcomingDate = manager.guaranteedNextPrayerTime()
        let df = DateFormatter()
        df.dateFormat = "h:mm a"
        let upcomingDateString = df.string(from: upcomingDate)
        
        let upcomingInterval = upcomingDate.timeIntervalSinceNow
        let hoursDiff = Int(upcomingInterval / 3600)
        let minutesDiff = (Int(upcomingInterval) % 3600) / 60
        let secondsDiff = Int(upcomingInterval) % 60
        
        var timeLeftString = ""
        if hoursDiff != 0 {
            timeLeftString += "\(hoursDiff) hour"
            if hoursDiff != 1 {
                timeLeftString += "s" // plural
            }
            
            // and x minutes (if we have nonzero minutes
            if minutesDiff != 0 {
                timeLeftString += " and "
            }
        }
        
        if minutesDiff != 0 {
            timeLeftString += "\(minutesDiff) minute"
            if minutesDiff != 1 {timeLeftString += "s"} // plural
        }
        
        // if we only have a few minutes, incorporate seconds in string
        if hoursDiff == 0 && minutesDiff < 5 {
            if minutesDiff != 0 {timeLeftString += " and "}
            timeLeftString += "\(secondsDiff) seconds"
        }
        
//        let upcomingPrayerName = upcomingPrayer.next().localizedOrCustomString()
        
        let response = NextPrayerIntentResponse(code: .success, userActivity: nil)
        response.upcomingDate = upcomingDateString
        response.upcomingTime = timeLeftString
//        response.upcomingPrayerName = upcomingPrayerName
        response.upcomingPrayerName = IntentPrayerOption(rawValue: currentSalah.next().rawValue() + 1) ?? IntentPrayerOption.unknown
        response.recentLocation = manager.locationSettings.locationName
        
        // we have put together a correct response
        completion(response)
    }
    
    // uncomment this to test out optionality of a custom request location
//    func confirm(intent: NextPrayerIntent, completion: @escaping (NextPrayerIntentResponse) -> Void) {
//
//    }
    
}
