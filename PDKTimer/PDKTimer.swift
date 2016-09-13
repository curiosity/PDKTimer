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
    private let token:NSObject
    private let privateQueueName:NSString
    private var QVAL:UnsafePointer<Int8>
    
    init(timeInterval:TimeInterval, repeats:Bool, dispatchQueue:DispatchQueue, action:@escaping PDKTimerBlock){
        self.timeInterval = timeInterval
        self.repeats = repeats
        self.action = action
        token = NSObject()
        
        privateQueueName = NSString(format: "com.produkt.pdktimer.%p", Unmanaged.passUnretained(token).toOpaque())
        QVAL = privateQueueName.utf8String!
        privateSerialQueue = DispatchQueue(label: privateQueueName.utf8String, attributes: [])
        privateSerialQueue.setSpecific(key: /*Migrator FIXME: Use a variable of type DispatchSpecificKey*/ QVAL, value: &QVAL)
        targetDispatchQueue = dispatchQueue
        
        timer = DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags(rawValue: UInt(0)), queue: privateSerialQueue) /*Migrator FIXME: Use DispatchSourceTimer to avoid the cast*/ as! DispatchSource
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
    
    fileprivate func dispatchInTimerQueue(_ f:()->()){
        if &QVAL == DispatchQueue.getSpecific(privateQueueName.utf8String){
            f()
        }else{
            privateSerialQueue.sync(execute: {
                f()
            });
        }
    }
    
    fileprivate func timerFired(){
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
    
    fileprivate func resetTimer(){
        let intervalInNanoseconds = Int64(timeInterval * Double(NSEC_PER_SEC))
        let toleranceInNanoseconds = Int64(tolerance * Double(NSEC_PER_SEC))
        
        timer.setTimer(start: DispatchTime.now() + Double(intervalInNanoseconds) / Double(NSEC_PER_SEC),
            interval: UInt64(intervalInNanoseconds),
            leeway: UInt64(toleranceInNanoseconds)
        );
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
