//
//  Date.swift
//  DelivMyApp
//
//  Created by Moh abu on 3/26/16.
//  Copyright © 2016 DelivMy. All rights reserved.
//

import Foundation

extension NSDate {
    func yearsFrom(date:NSDate) -> Int{
        return NSCalendar.currentCalendar().components(.Year, fromDate: date, toDate: self, options: []).year
    }
    func monthsFrom(date:NSDate) -> Int{
        return NSCalendar.currentCalendar().components(.Month, fromDate: date, toDate: self, options: []).month
    }
    func weeksFrom(date:NSDate) -> Int{
        return NSCalendar.currentCalendar().components(.WeekOfYear, fromDate: date, toDate: self, options: []).weekOfYear
    }
    func daysFrom(date:NSDate) -> Int{
        return NSCalendar.currentCalendar().components(.Day, fromDate: date, toDate: self, options: []).day
    }
    func hoursFrom(date:NSDate) -> Int{
        return NSCalendar.currentCalendar().components(.Hour, fromDate: date, toDate: self, options: []).hour
    }
    func minutesFrom(date:NSDate) -> Int{
        return NSCalendar.currentCalendar().components(.Minute, fromDate: date, toDate: self, options: []).minute
    }
    func secondsFrom(date:NSDate) -> Int{
        return NSCalendar.currentCalendar().components(.Second, fromDate: date, toDate: self, options: []).second
    }
    func offsetFrom(date:NSDate) -> String {
        if yearsFrom(date)   > 0 { return "Within \(yearsFrom(date)) years"   }
        if monthsFrom(date)  > 0 { return "Within \(monthsFrom(date)) Months"  }
        if weeksFrom(date)   > 0 { return "Within \(weeksFrom(date)) weeks"   }
        if daysFrom(date)    > 0 { return "Within \(daysFrom(date)) days"    }
        if hoursFrom(date)   > 0 { return "Within \(hoursFrom(date)) hours"   }
        if minutesFrom(date) > 0 { return "Within \(minutesFrom(date)) minutes" }
        if secondsFrom(date) > 0 { return "Within \(secondsFrom(date)) seconds" }
        return "Expired!"
    }
    var formatted:String {
        let formatter = NSDateFormatter()
        formatter.dateFormat = "M/d/yy, H:mm"
        return formatter.stringFromDate(self)
    }
}


