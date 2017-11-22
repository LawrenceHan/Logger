//
//  LHWLogger.swift
//  LHWLogger
//
//  Created by Sebastian Kreutzberger (Twitter @skreutzb) on 28.11.15.
//  Copyright © 2015 Sebastian Kreutzberger
//  Some rights reserved: http://publicsource.org/licenses/MIT
//

//
//  Logger.swift
//  Logger
//
//  Created by Hanguang on 22/11/2017.
//  Copyright © 2017 Hanguang. All rights reserved.
//

import Foundation

public final class LHWLogger {
    
    public static let `default` = LHWLogger()
    
    public enum Level: Int {
        case verbose = 0
        case debug = 1
        case info = 2
        case warning = 3
        case error = 4
    }
    
    // a set of active destinations
    public private(set) var destinations = Set<BaseDestination>()
    
    // MARK: Destination Handling
    
    /// returns boolean about success
    @discardableResult
    public func addDestination(_ destination: BaseDestination) -> Bool {
        if destinations.contains(destination) {
            return false
        }
        destinations.insert(destination)
        return true
    }
    
    /// returns boolean about success
    @discardableResult
    public func removeDestination(_ destination: BaseDestination) -> Bool {
        if destinations.contains(destination) == false {
            return false
        }
        destinations.remove(destination)
        return true
    }
    
    /// if you need to start fresh
    public func removeAllDestinations() {
        destinations.removeAll()
    }
    
    /// returns the amount of destinations
    public func countDestinations() -> Int {
        return destinations.count
    }
    
    /// returns the current thread name
    func threadName() -> String {
        
        #if os(Linux)
            // on 9/30/2016 not yet implemented in server-side Swift:
            // > import Foundation
            // > Thread.isMainThread
            return ""
        #else
            if Thread.isMainThread {
                return ""
            } else {
                let threadName = Thread.current.name
                if let threadName = threadName, !threadName.isEmpty {
                    return threadName
                } else {
                    return String(format: "%p", Thread.current)
                }
            }
        #endif
    }
    
    // MARK: Levels
    
    /// log something generally unimportant (lowest priority)
    public func verbose(_ message: @autoclosure () -> Any, _
        file: String = #file, _ function: String = #function, line: Int = #line, context: Any? = nil) {
        custom(level: .verbose, message: message, file: file, function: function, line: line, context: context)
    }
    
    /// log something which help during debugging (low priority)
    public func debug(_ message: @autoclosure () -> Any, _
        file: String = #file, _ function: String = #function, line: Int = #line, context: Any? = nil) {
        custom(level: .debug, message: message, file: file, function: function, line: line, context: context)
    }
    
    /// log something which you are really interested but which is not an issue or error (normal priority)
    public func info(_ message: @autoclosure () -> Any, _
        file: String = #file, _ function: String = #function, line: Int = #line, context: Any? = nil) {
        custom(level: .info, message: message, file: file, function: function, line: line, context: context)
    }
    
    /// log something which may cause big trouble soon (high priority)
    public func warning(_ message: @autoclosure () -> Any, _
        file: String = #file, _ function: String = #function, line: Int = #line, context: Any? = nil) {
        custom(level: .warning, message: message, file: file, function: function, line: line, context: context)
    }
    
    /// log something which will keep you awake at night (highest priority)
    public func error(_ message: @autoclosure () -> Any, _
        file: String = #file, _ function: String = #function, line: Int = #line, context: Any? = nil) {
        custom(level: .error, message: message, file: file, function: function, line: line, context: context)
    }
    
    /// custom logging to manually adjust values, should just be used by other frameworks
    public func custom(level: LHWLogger.Level, message: @autoclosure () -> Any,
                             file: String = #file, function: String = #function, line: Int = #line, context: Any? = nil) {
        dispatch_send(level: level, message: message, thread: threadName(),
                      file: file, function: function, line: line, context: context)
    }
    
    /// internal helper which dispatches send to dedicated queue if minLevel is ok
    func dispatch_send(level: LHWLogger.Level, message: @autoclosure () -> Any,
                             thread: String, file: String, function: String, line: Int, context: Any?) {
        var resolvedMessage: String?
        for dest in destinations {
            
            guard let queue = dest.queue else {
                continue
            }
            
            resolvedMessage = resolvedMessage == nil && dest.hasMessageFilters() ? "\(message())" : resolvedMessage
            if dest.shouldLevelBeLogged(level, path: file, function: function, message: resolvedMessage) {
                // try to convert msg object to String and put it on queue
                let msgStr = resolvedMessage == nil ? "\(message())" : resolvedMessage!
                let f = stripParams(function: function)
                
                if dest.asynchronously {
                    queue.async {
                        _ = dest.send(level, msg: msgStr, thread: thread, file: file, function: f, line: line, context: context)
                    }
                } else {
                    queue.sync {
                        _ = dest.send(level, msg: msgStr, thread: thread, file: file, function: f, line: line, context: context)
                    }
                }
            }
        }
    }
    
    /// removes the parameters from a function because it looks weird with a single param
    func stripParams(function: String) -> String {
        var f = function
        if let indexOfBrace = f.index(of: "(") {
            #if swift(>=4.0)
                f = String(f[..<indexOfBrace])
            #else
                f = f.substring(to: indexOfBrace)
            #endif
        }
        f += "()"
        return f
    }
}

// MARK: - Default Logger

public let Logger = LHWLogger.default
