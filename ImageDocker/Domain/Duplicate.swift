//
//  Duplicate.swift
//  ImageDocker
//
//  Created by Kelvin Wong on 2018/7/14.
//  Copyright © 2018年 nonamecat. All rights reserved.
//

import Foundation

class Duplicate {
    
    var year:Int = 0
    var month:Int = 0
    var day:Int = 0
    var date:Date = Date()
    var place:String = ""
    var event:String = ""
    
}

class Duplicates {
    
    //var duplicates:[Duplicate] = []
    var categories:Set<String> = []
    var paths:Set<String> = []
    var years:Set<Int> = []
    var yearMonths:Set<Int> = []
    var yearMonthDays:Set<Int> = []
}
