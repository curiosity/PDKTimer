//
//  PDKTimer.swift
//  Produkt
//
//  Created by Daniel García García on 3/7/15.
//  Copyright © 2015 produkt. All rights reserved.
//

import Foundation

public typealias PDKTimerBlock = ()->()
public typealias PDKTProgressBlock = (_ current:TimeInterval, _ total:TimeInterval)->()

final public class PDKTimer {
    var tolerance:TimeInterval = 0
    private let timeInterval:TimeInterval
    private var repeats:Bool
    private var action:PDKTimerBlock
    private var completion:PDKTimerBlock?
    private var startDate:Date?
    private var completionDate:Date?
    private var timer:DispatchSource
    private var privateSerialQueue:DispatchQueue
    private var targetDispatchQueue:DispatchQueue
    private var invalidated = false
    private let privateQueueName:String
    private let privateQueueNameKey = DispatchSpecificKey<String>()
    
    init(timeInterval:TimeInterval, repeats:Bool, dispatchQueue:DispatchQueue, action:@escaping PDKTimerBlock){
        self.timeInterval = timeInterval
        self.repeats = repeats
        self.action = action
        
        let uid = String(describing: Date())
        privateQueueName = "com.produkt.pdktimer.\(uid)"
        privateSerialQueue = DispatchQueue(label: privateQueueName, attributes: [])
        privateSerialQueue.setSpecific(key: privateQueueNameKey, value: privateQueueName)
        targetDispatchQueue = dispatchQueue
        
        timer = DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags(rawValue: UInt(0)), queue: privateSerialQueue) as! DispatchSource
    }
    
    convenience init(timeInterval:TimeInterval, limitDate:Date, dispatchQueue:DispatchQueue, repetition:@escaping PDKTProgressBlock, completion:@escaping PDKTimerBlock){
        self.init(timeInterval:timeInterval, repeats:true, dispatchQueue:dispatchQueue, action:{})
        self.action = {
            if let completionDate = self.completionDate,
                let startDate = self.startDate{
                    let total = completionDate.timeIntervalSince1970 - startDate.timeIntervalSince1970
                    let current = completionDate.timeIntervalSince1970 - Date().timeIntervalSince1970
                    repetition(current >= 0 ? current : 0.0 , total)
            }
        }
        self.completion = completion
        self.startDate = Date()
        self.completionDate = limitDate        
    }
    
    convenience init(timeInterval:TimeInterval, repeats:Bool, action:@escaping PDKTimerBlock){
        self.init(timeInterval:timeInterval, repeats:repeats, dispatchQueue:DispatchQueue.main, action:action)
    }
    
    convenience init(timeInterval:TimeInterval, action:@escaping PDKTimerBlock){
        self.init(timeInterval:timeInterval, repeats:false, action:action)
    }
    
    deinit{
        invalidate()
    }
    
    class public func every(_ interval: TimeInterval, dispatchQueue:DispatchQueue, _ block: @escaping PDKTimerBlock) -> PDKTimer{
        let timer = PDKTimer(timeInterval: interval, repeats: true, dispatchQueue: dispatchQueue, action: block)
        timer.schedule()
        return timer
    }
    
    class public func every(_ interval: TimeInterval, _ block: @escaping PDKTimerBlock) -> PDKTimer{
        let timer = PDKTimer(timeInterval: interval, repeats: true, action: block)
        timer.schedule()
        return timer
    }
    
    class public func after(_ interval: TimeInterval, dispatchQueue:DispatchQueue, _ block: @escaping PDKTimerBlock) -> PDKTimer{
        let timer = PDKTimer(timeInterval: interval, repeats: false, dispatchQueue: dispatchQueue, action: block)
        timer.schedule()
        return timer
    }
    
    class public func after(_ interval: TimeInterval, _ block: @escaping PDKTimerBlock) -> PDKTimer{
        let timer = PDKTimer(timeInterval: interval, repeats: false, action: block)
        timer.schedule()
        return timer
    }
    
    class public func until(_ date:Date, interval:TimeInterval, dispatchQueue:DispatchQueue, repetition:@escaping PDKTProgressBlock, completion:@escaping PDKTimerBlock) -> PDKTimer{
        let timer = PDKTimer(timeInterval: interval, limitDate: date, dispatchQueue: dispatchQueue, repetition: repetition, completion: completion)
        timer.schedule()
        return timer
    }
    
    class public func until(_ date:Date, interval:TimeInterval, repetition:@escaping PDKTProgressBlock, completion:@escaping PDKTimerBlock) -> PDKTimer{
        let timer = PDKTimer(timeInterval: interval, limitDate: date, dispatchQueue: DispatchQueue.main, repetition: repetition, completion: completion)
        timer.schedule()
        return timer
    }
    
    public func fire(){
        timerFired()
        if repeats{
            schedule()
        }
    }
    
    public func schedule(){
        resetTimer()
        timer.setEventHandler{
            self.timerFired()
        }
        timer.resume();
    }
    
    public func invalidate(){
        dispatchInTimerQueue{
            self.invalidated = true
            self.timer.cancel()
        }
    }
    
    private func dispatchInTimerQueue(_ f:()->()){
        if privateQueueName == DispatchQueue.getSpecific(key: privateQueueNameKey){
            f()
        }else{
            privateSerialQueue.sync(execute: {
                f()
            });
        }
    }
    
    private func timerFired(){
        dispatchInTimerQueue{
            if self.invalidated { return }
            self.targetDispatchQueue.async {
                self.action()
            }
            
            if !self.repeats {
                self.invalidate()
            }
            
            if let limitDate = self.completionDate , Date().compare(limitDate) == ComparisonResult.orderedDescending,
                let completionBlock = self.completion{
                self.targetDispatchQueue.async {
                    completionBlock()
                }
                self.invalidate()
            }
        }
    }
    
    private func resetTimer(){
        let intervalInNanoseconds = DispatchTimeInterval.nanoseconds(Int(timeInterval * Double(NSEC_PER_SEC)))
        let toleranceInNanoseconds = DispatchTimeInterval.nanoseconds(Int(tolerance * Double(NSEC_PER_SEC)))
        
        timer.scheduleRepeating(
            deadline: (DispatchTime.now() + intervalInNanoseconds),
            interval: intervalInNanoseconds,
            leeway: toleranceInNanoseconds)
    }
}

extension Double {
    public var millisecond:  TimeInterval { return self / 100 }
    public var milliseconds:  TimeInterval { return self / 100 }
    public var second:  TimeInterval { return self }
    public var seconds: TimeInterval { return self }
    public var minute:  TimeInterval { return self * 60 }
    public var minutes: TimeInterval { return self * 60 }
    public var hour:    TimeInterval { return self * 3600 }
    public var hours:   TimeInterval { return self * 3600 }
}




//
////
////  PDKTimer.swift
////  Produkt
////
////  Created by Daniel García García on 3/7/15.
////  Copyright © 2015 produkt. All rights reserved.
////
//
//import Foundation
//
//public typealias PDKTimerBlock = ()->()
//public typealias PDKTProgressBlock = (current:NSTimeInterval, total:NSTimeInterval)->()
//
//final public class PDKTimer {
//    var tolerance:NSTimeInterval = 0
//    private let timeInterval:NSTimeInterval
//    private var repeats:Bool
//    private var action:PDKTimerBlock
//    private var completion:PDKTimerBlock?
//    private var startDate:NSDate?
//    private var completionDate:NSDate?
//    private var timer:dispatch_source_t
//    private var privateSerialQueue:dispatch_queue_t
//    private var targetDispatchQueue:dispatch_queue_t
//    private var invalidated = false
//    private let token:NSObject
//    private let privateQueueName:NSString
//    private var QVAL:UnsafePointer<Int8>
//    
//    init(timeInterval:NSTimeInterval, repeats:Bool, dispatchQueue:dispatch_queue_t, action:PDKTimerBlock){
//        self.timeInterval = timeInterval
//        self.repeats = repeats
//        self.action = action
//        token = NSObject()
//        
//        privateQueueName = NSString(format: "com.produkt.pdktimer.%p", unsafeAddressOf(token))
//        QVAL = privateQueueName.UTF8String
//        privateSerialQueue = dispatch_queue_create(privateQueueName.UTF8String, DISPATCH_QUEUE_SERIAL)
//        dispatch_queue_set_specific(privateSerialQueue, QVAL, &QVAL, nil)
//        targetDispatchQueue = dispatchQueue
//        
//        timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, privateSerialQueue)
//    }
//    
//    convenience init(timeInterval:NSTimeInterval, limitDate:NSDate, dispatchQueue:dispatch_queue_t, repetition:PDKTProgressBlock, completion:PDKTimerBlock){
//        self.init(timeInterval:timeInterval, repeats:true, dispatchQueue:dispatchQueue, action:{})
//        self.action = {
//            if let completionDate = self.completionDate,
//                let startDate = self.startDate{
//                    let total = completionDate.timeIntervalSince1970 - startDate.timeIntervalSince1970
//                    let current = completionDate.timeIntervalSince1970 - NSDate().timeIntervalSince1970
//                    repetition(current: current >= 0 ? current : 0.0 , total: total)
//            }
//        }
//        self.completion = completion
//        self.startDate = NSDate()
//        self.completionDate = limitDate        
//    }
//    
//    convenience init(timeInterval:NSTimeInterval, repeats:Bool, action:PDKTimerBlock){
//        self.init(timeInterval:timeInterval, repeats:repeats, dispatchQueue:dispatch_get_main_queue(), action:action)
//    }
//    
//    convenience init(timeInterval:NSTimeInterval, action:PDKTimerBlock){
//        self.init(timeInterval:timeInterval, repeats:false, action:action)
//    }
//    
//    deinit{
//        invalidate()
//    }
//    
//    class public func every(interval: NSTimeInterval, dispatchQueue:dispatch_queue_t, _ block: PDKTimerBlock) -> PDKTimer{
//        let timer = PDKTimer(timeInterval: interval, repeats: true, dispatchQueue: dispatchQueue, action: block)
//        timer.schedule()
//        return timer
//    }
//    
//    class public func every(interval: NSTimeInterval, _ block: PDKTimerBlock) -> PDKTimer{
//        let timer = PDKTimer(timeInterval: interval, repeats: true, action: block)
//        timer.schedule()
//        return timer
//    }
//    
//    class public func after(interval: NSTimeInterval, dispatchQueue:dispatch_queue_t, _ block: PDKTimerBlock) -> PDKTimer{
//        let timer = PDKTimer(timeInterval: interval, repeats: false, dispatchQueue: dispatchQueue, action: block)
//        timer.schedule()
//        return timer
//    }
//    
//    class public func after(interval: NSTimeInterval, _ block: PDKTimerBlock) -> PDKTimer{
//        let timer = PDKTimer(timeInterval: interval, repeats: false, action: block)
//        timer.schedule()
//        return timer
//    }
//    
//    class public func until(date:NSDate, interval:NSTimeInterval, dispatchQueue:dispatch_queue_t, repetition:PDKTProgressBlock, completion:PDKTimerBlock) -> PDKTimer{
//        let timer = PDKTimer(timeInterval: interval, limitDate: date, dispatchQueue: dispatchQueue, repetition: repetition, completion: completion)
//        timer.schedule()
//        return timer
//    }
//    
//    class public func until(date:NSDate, interval:NSTimeInterval, repetition:PDKTProgressBlock, completion:PDKTimerBlock) -> PDKTimer{
//        let timer = PDKTimer(timeInterval: interval, limitDate: date, dispatchQueue: dispatch_get_main_queue(), repetition: repetition, completion: completion)
//        timer.schedule()
//        return timer
//    }
//    
//    public func fire(){
//        timerFired()
//        if repeats{
//            schedule()
//        }
//    }
//    
//    public func schedule(){
//        resetTimer()
//        dispatch_source_set_event_handler(timer){
//            self.timerFired()
//        }
//        dispatch_resume(timer);
//    }
//    
//    public func invalidate(){
//        dispatchInTimerQueue{
//            self.invalidated = true
//            dispatch_source_cancel(self.timer)
//        }
//    }
//    
//    private func dispatchInTimerQueue(f:()->()){
//        if &QVAL == dispatch_get_specific(privateQueueName.UTF8String){
//            f()
//        }else{
//            dispatch_sync(privateSerialQueue, {
//                f()
//            });
//        }
//    }
//    
//    private func timerFired(){
//        dispatchInTimerQueue{
//            if self.invalidated { return }
//            dispatch_async(self.targetDispatchQueue) {
//                self.action()
//            }
//            
//            if !self.repeats {
//                self.invalidate()
//            }
//            
//            if let limitDate = self.completionDate where NSDate().compare(limitDate) == NSComparisonResult.OrderedDescending,
//                let completionBlock = self.completion{
//                dispatch_async(self.targetDispatchQueue) {
//                    completionBlock()
//                }
//                self.invalidate()
//            }
//        }
//    }
//    
//    private func resetTimer(){
//        let intervalInNanoseconds = Int64(timeInterval * Double(NSEC_PER_SEC))
//        let toleranceInNanoseconds = Int64(tolerance * Double(NSEC_PER_SEC))
//        
//        dispatch_source_set_timer(timer,
//            dispatch_time(DISPATCH_TIME_NOW, intervalInNanoseconds),
//            UInt64(intervalInNanoseconds),
//            UInt64(toleranceInNanoseconds)
//        );
//    }
//}
//
//extension Double {
//    public var millisecond:  NSTimeInterval { return self / 100 }
//    public var milliseconds:  NSTimeInterval { return self / 100 }
//    public var second:  NSTimeInterval { return self }
//    public var seconds: NSTimeInterval { return self }
//    public var minute:  NSTimeInterval { return self * 60 }
//    public var minutes: NSTimeInterval { return self * 60 }
//    public var hour:    NSTimeInterval { return self * 3600 }
//    public var hours:   NSTimeInterval { return self * 3600 }
//}
