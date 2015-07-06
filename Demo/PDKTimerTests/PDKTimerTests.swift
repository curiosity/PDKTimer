//
//  PDKTimerTests.swift
//  Produkt
//
//  Created by Daniel García García on 3/7/15.
//  Copyright © 2015 Produkt. All rights reserved.
//

import XCTest

class PDKTimerTests: XCTestCase {
    var timer:PDKTimer!
    
    override func setUp() {
        super.setUp()
        
    }
    
    override func tearDown() {
        super.tearDown()
        timer = nil
    }
    
    func testSimpleDelayedTimer_shouldFireAutomatically(){
        let expectation = self.expectationWithDescription("fire automatically")
        timer = PDKTimer(timeInterval: 0.003, repeats: false){
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(0.5) { (let error:NSError?) -> Void in }
    }
    
    func testSimpleDelayedTimer_shouldBeFireableProgramatically(){
        var fired = false
        timer = PDKTimer(timeInterval: 0.003, repeats: false){
            fired = true
        }
        timer.fire()
        XCTAssert(fired)
    }
    
    func testDelayedTimerWithRepetition_shouldFireMultipleTimes(){
        var fireCounter = 0
        timer = PDKTimer(timeInterval: 0.003, repeats: true){
            fireCounter++
        }
        NSRunLoop.mainRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 0.01))
        XCTAssert(fireCounter >= 3, "should be fired at least 3 times")
    }
    
    func testTimer_shouldBeCancellable(){
        var fired = false
        timer = PDKTimer(timeInterval: 0.003, repeats: false){
            fired = true
        }
        timer.invalidate()
        NSRunLoop.mainRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(fired, false)
    }
    
    func testTimer_shouldFireOnCustomDispatchQueue(){
        let specificQueueKey = "timerQueue" as NSString
        let QKEY = specificQueueKey.UTF8String
        let dispatchQueueId = "com.produkt.pdktimer.test" as NSString
        var QVAL = dispatchQueueId.UTF8String
        let dispatchQueue = dispatch_queue_create(QVAL, DISPATCH_QUEUE_SERIAL)
        dispatch_queue_set_specific(dispatchQueue, QKEY, &QVAL, nil)
        let expectation = self.expectationWithDescription("custom dispatch queue")
        let _ = PDKTimer.after(5.milliseconds, dispatchQueue:dispatchQueue){
            let s = dispatch_get_specific(QKEY)
            XCTAssert(s == &QVAL)
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(0.5) { (let error:NSError?) -> Void in }
    }
    
    func testTimer_shouldFireOnMainQueue(){
        let expectation = self.expectationWithDescription("custom dispatch queue")
        let _ = PDKTimer.after(5.milliseconds, dispatchQueue:dispatch_get_main_queue()){
            XCTAssert(NSThread.isMainThread())
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(0.5) { (let error:NSError?) -> Void in }
    }
}