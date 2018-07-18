//
//  ModelStore.swift
//  ImageDocker
//
//  Created by Kelvin Wong on 2018/7/14.
//  Copyright © 2018年 nonamecat. All rights reserved.
//

import Foundation
import GRDB


class ModelStore {
    
    fileprivate let dbfile = "/Users/kelvinwong/Documents/ImageDocker/ImageDocker.sqlite"
    
    static let `default` = ModelStore()
    
    init(){
        self.versionCheck()
    }
    
    static func save(){
        print("DUMMY SAVE: DO NOTHING")
    }
    
    private static var _sharedDBQueue:DatabaseWriter?
    private static var _sharedDBPool:DatabaseWriter?
    
    static func sharedDBQueue() -> DatabaseWriter{
        if _sharedDBQueue == nil {
            do {
                _sharedDBQueue = try DatabaseQueue(path: ModelStore.default.dbfile)
            }catch{
                print(error)
            }
        }
        return _sharedDBQueue!
    }
    
    static func sharedDBPool() -> DatabaseWriter{
        if _sharedDBPool == nil {
            do {
                _sharedDBPool = try DatabasePool(path: ModelStore.default.dbfile)
            }catch{
                print(error)
            }
        }
        return _sharedDBPool!
    }
    
    // MARK: COMMONS
    
    fileprivate func inArray(field:String, array:[Any]?, where whereStmt:inout String, args sqlArgs:inout [Any]){
        if let array = array {
            if array.count > 0 {
                let marks = repeatElement("?", count: array.count).joined(separator: ",")
                whereStmt = "AND \(field) in (\(marks))"
                sqlArgs.append(contentsOf: array)
            }
        }
    }
    
    fileprivate func likeArray(field:String, array:[Any]?, wildcardPrefix:Bool = true, wildcardSuffix:Bool = true) -> String{
        if let array = array {
            if array.count > 0 {
                var stmts:[String] = []
                let p = wildcardPrefix ? "'%" : "'"
                let s = wildcardSuffix ? "%'" : "'"
                for value in array {
                    if "\(value)" == "" {
                        stmts.append("\(field) is null")
                        stmts.append("\(field) = ''")
                    }
                    stmts.append("\(field) LIKE \(p)\(value)\(s)")
                }
                return stmts.joined(separator: " OR ")
            }
        }
        return ""
    }
    
    // MARK: Duplicates
    
    var _duplicates:Duplicates? = nil
    
    func reloadDuplicatePhotos() {
        print("\(Date()) Loading duplicate photos from db")
        
        let duplicates:Duplicates = Duplicates()
        var dupDates:[Date] = []
        do {
            let db = try DatabaseQueue(path: dbfile)
            try db.read { db in
                let rows = try Row.fetchAll(db, "SELECT photoTakenYear,photoTakenMonth,photoTakenDay,photoTakenDate,place,count(path) as photoCount FROM Image GROUP BY photoTakenDate, place, photoTakenDay, photoTakenMonth, photoTakenYear")
                
                for row in rows {
                    let count:Int = Int(exactly: row["photoCount"] as Int64)!
                    if count == 1 {
                        continue
                    }
                    if row["photoTakenDate"] == nil {
                        continue
                    }
                    let dup:Duplicate = Duplicate()
                    dup.year = row["photoTakenYear"] as Int
                    dup.month = row["photoTakenMonth"]  as Int
                    dup.day = row["photoTakenDay"]  as Int
                    dup.date = row["photoTakenDate"] as Date
                    dup.place = row["place"] as! String? ?? ""
                    //dup.event = row["event"] as! String? ?? ""
                    duplicates.duplicates.append(dup)
                    
                    let monthString = dup.month < 10 ? "0\(dup.month)" : "\(dup.month)"
                    let dayString = dup.day < 10 ? "0\(dup.day)" : "\(dup.day)"
                    let category:String = "\(dup.year)年\(monthString)月\(dayString)日"
                    
                    if duplicates.categories.index(where: {$0 == category}) == nil {
                        duplicates.categories.append(category)
                    }
                    
                    dupDates.append(dup.date)
                }
            }
        }catch{
            print(error)
        }
        
        var firstPhotoInPlaceAndDate:[String:String] = [:]
        var dupPhotos:Set<String> = []
        print("\(Date()) Marking duplicate tag to photo files")
        do {
            let db = try DatabaseQueue(path: dbfile)
            try db.read { db in
                let marks = repeatElement("?", count: dupDates.count).joined(separator: ",")
                let photosInSameDate = try Row.fetchAll(db, "SELECT photoTakenYear,photoTakenMonth,photoTakenDay,photoTakenDate,place FROM Image WHERE photoTakenDate in (\(marks))", arguments:StatementArguments(dupDates))
                
                for photo in photosInSameDate {
                    if photo["photoTakenYear"] == 0 {
                        continue
                    }
                    let key = "\(photo["place"] ?? "")_\(photo["photoTakenYear"] ?? "0")_\(photo["photoTakenMonth"] ?? "0")_\(photo["photoTakenDay"] ?? "0")"
                    if let first = firstPhotoInPlaceAndDate[key] {
                        // duplicates
                        dupPhotos.insert(first)
                        dupPhotos.insert(photo["path"] ?? "")
                    }else{
                        firstPhotoInPlaceAndDate[key] = photo["path"] ?? ""
                    }
                }
            }
        }catch{
            print(error)
        }
        duplicates.paths = dupPhotos.sorted()
        print("\(Date()) Marking duplicate tag to photo files: DONE")
        
        _duplicates = duplicates
        print("\(Date()) Loading duplicate photos from db: DONE")
    }
    
    func getDuplicatePhotos() -> Duplicates {
        if _duplicates == nil {
            reloadDuplicatePhotos()
        }
        return _duplicates!
    }
    
    
    
    func getAllContainerPaths() -> [Row] {
        var rows:[Row] = []
        do {
            let db = try DatabaseQueue(path: dbfile)
            try db.read { db in
                rows = try Row.fetchAll(db, "SELECT containerPath, count(path) as photoCount FROM Image GROUP BY containerPath")
            }
        }catch{
            print(error)
        }
        
        return rows
        
    }
    
    // MARK: Options
    
    func getImageSources() -> [String:Bool]{
        var results:[String:Bool] = [:]
        do {
            let db = try DatabaseQueue(path: dbfile)
            try db.read { db in
                let rows = try Row.fetchAll(db, "SELECT DISTINCT imageSource FROM Image")
                for row in rows {
                    let src = row["imageSource"] as String?
                    if let src = src, src != "" {
                        results[src] = false
                    }
                }
            }
        }catch{
            print(error)
        }
        
        return results
    }
    
    func getCameraModel() -> [String:Bool] {
        var results:[String:Bool] = [:]
        do {
            let db = try DatabaseQueue(path: dbfile)
            try db.read { db in
                let rows = try Row.fetchAll(db, "SELECT DISTINCT cameraMaker,cameraModel FROM Image")
                for row in rows {
                    let name1:String = row["cameraMaker"] ?? ""
                    let name2:String = row["cameraModel"] ?? ""
                    if name1 != "" && name2 != "" {
                        results["\(name1),\(name2)"] = false
                    }
                }
            }
        }catch{
            print(error)
        }
        
        return results
    }
    
    // MARK: CONTAINERS
    
    func getAllContainers() -> [ImageContainer] {
        var containers:[ImageContainer] = []
        
        do {
            let dbPool = try DatabasePool(path: dbfile)
            try dbPool.read { db in
                containers = try ImageContainer.order(Column("path").asc).fetchAll(db)
            }
        }catch{
            print(error)
        }
        return containers
    }
    
    func deleteContainer(path: String) {
        do {
            let db = try DatabasePool(path: dbfile)
            try db.write { db in
                try db.execute("DELETE FROM ImageContainer WHERE path LIKE '\(path)/%'")
                try db.execute("DELETE FROM Image WHERE path LIKE '\(path)/%'")
            }
        }catch{
            print(error)
        }
    }
    
    func getContainers(rootPath:String) -> [ImageContainer] {
        var result:[ImageContainer] = []
        do {
            let db = try DatabasePool(path: dbfile)
            try db.read { db in
                result = try ImageContainer.filter(Column("path").like("\(rootPath)%")).fetchAll(db)
            }
        }catch{
            print(error)
        }
        return result
    }
    
    func getOrCreateContainer(name:String, path:String, parentPath:String = "", sharedDB:DatabaseWriter? = nil) -> ImageContainer {
        var container:ImageContainer?
        do {
            let db = try sharedDB ?? DatabaseQueue(path: dbfile)
            try db.read { db in
                container = try ImageContainer.fetchOne(db, key: path)
            }
            if container == nil {
                let queue = try sharedDB ?? DatabaseQueue(path: dbfile)
                try queue.write { db in
                    container = ImageContainer(name: name, parentFolder: parentPath, path: path, imageCount: 0)
                    try container?.save(db)
                }
            }
        }catch{
            print(error)
        }
        return container!
    }
    
    func getRepositories() -> [ImageContainer] {
        var result:[ImageContainer] = []
        do {
            let db = try DatabasePool(path: dbfile)
            try db.read { db in
                result = try ImageContainer.filter(sql: "parentFolder=''").order(Column("path").asc).fetchAll(db)
                print(result.count)
            }
        }catch{
            print(error)
        }
        return result
        
    }
    
    func saveImageContainer(container:ImageContainer){
        var container = container
        do {
            let db = try DatabasePool(path: dbfile)
            try db.write { db in
                try container.save(db)
            }
        }catch{
            print(error)
        }
    }
    
    // MARK: IMAGES
    
    func getOrCreatePhoto(filename:String, path:String, parentPath:String, sharedDB:DatabaseWriter? = nil) -> Image{
        var image:Image?
        do {
            let db = try sharedDB ?? DatabasePool(path: dbfile)
            try db.read { db in
                image = try Image.fetchOne(db, key: path)
            }
            if image == nil {
                let queue = try sharedDB ?? DatabaseQueue(path: dbfile)
                try queue.write { db in
                    image = Image.new(filename: filename, path: path, parentFolder: parentPath)
                    try image?.save(db)
                }
                
            }
        }catch{
            print(error)
        }
        return image!
    }
    
    func saveImage(image: Image, sharedDB:DatabaseWriter? = nil){
        do {
            let db = try sharedDB ?? DatabasePool(path: dbfile)
            let _ = try db.write { db in
                var image = image
                try image.save(db)
                //print("saved image")
            }
        }catch{
            print(error)
        }
    }
    
    func deletePhoto(atPath path:String){
        do {
            let db = try DatabasePool(path: dbfile)
            let _ = try db.write { db in
                try Image.deleteOne(db, key: path)
            }
        }catch{
            print(error)
        }
    }
    
    func getAllPhotoFiles(includeHidden:Bool = true, sharedDB:DatabaseWriter? = nil) -> [Image] {
        var result:[Image] = []
        do {
            let db = try sharedDB ?? DatabasePool(path: dbfile)
            try db.read { db in
                if includeHidden {
                    result = try Image.order([Column("photoTakenDate").asc, Column("filename").asc]).fetchAll(db)
                }else{
                    result = try Image.filter(sql: "hidden = 0").order([Column("photoTakenDate").asc, Column("filename").asc]).fetchAll(db)
                }
            }
        }catch{
            print(error)
        }
        return result
    }
    
    func getPhotoFiles(parentPath:String, includeHidden:Bool = true) -> [Image] {
        var otherPredicate:String = ""
        if !includeHidden {
            otherPredicate = " AND (hidden is null || hidden = 0)"
        }
        
        var result:[Image] = []
        do {
            let db = try DatabasePool(path: dbfile)
            try db.read { db in
                result = try Image.filter(sql: "containerPath = ? \(otherPredicate)", arguments: StatementArguments([parentPath])).order([Column("photoTakenDate").asc, Column("filename").asc]).fetchAll(db)
            }
        }catch{
            print(error)
        }
        return result
    }
    
    func getPhotoFiles(rootPath:String) -> [Image] {
        var result:[Image] = []
        do {
            let db = try DatabasePool(path: dbfile)
            try db.read { db in
                result = try Image.filter(Column("path").like("\(rootPath)%")).fetchAll(db)
            }
        }catch{
            print(error)
        }
        return result
    }
    
    func countPhotoFiles(rootPath:String) -> Int {
        var result:Int = 0
        do {
            let db = try DatabasePool(path: dbfile)
            try db.read { db in
                result = try Image.filter(Column("path").like("\(rootPath)%")).fetchCount(db)
            }
        }catch{
            print(error)
        }
        return result
    }
    
    // MARK: IMAGES - UPDATES
    
    func getPhotoFilesWithoutExif(limit:Int? = nil) -> [Image] {
        var result:[Image] = []
        do {
            let db = try DatabasePool(path: dbfile)
            try db.read { db in
                result = try Image.filter(sql: "hidden != 1 AND (updateExifDate is null OR photoTakenYear = 0 OR (latitude <> '0.0' AND latitudeBD = '0.0') OR (latitudeBD <> '0.0' AND COUNTRY = ''))").order([Column("photoTakenDate").asc, Column("filename").asc]).fetchAll(db)
                // TODO: OR updateLocationDate is null
            }
        }catch{
            print(error)
        }
        return result
    }
    
    func getPhotoFilesWithoutLocation() -> [Image] {
        var result:[Image] = []
        do {
            let db = try DatabasePool(path: dbfile)
            try db.read { db in
                result = try Image.filter(sql: "hidden != 1 AND updateLocationDate is null").order([Column("photoTakenDate").asc, Column("filename").asc]).fetchAll(db)
            }
        }catch{
            print(error)
        }
        return result
    }
    
    func getPhotoFiles(after date:Date) -> [Image] {
        var result:[Image] = []
        do {
            let db = try DatabasePool(path: dbfile)
            try db.read { db in
                result = try Image.filter(sql: "updateLocationDate >= ?", arguments: StatementArguments([date])).fetchAll(db)
            }
        }catch{
            print(error)
        }
        return result
    }
    
    func getAllPhotoFilesForExporting(after date:Date) -> [Image] {
        var result:[Image] = []
        do {
            let db = try DatabasePool(path: dbfile)
            try db.read { db in
                result = try Image.filter(sql: "hidden != 1 AND (updateDateTimeDate > ? OR updateExifDate > ? OR updateLocationDate > ? OR updateEventDate > ? OR exporTime is null)", arguments:StatementArguments([date, date, date, date])).order([Column("photoTakenDate").asc, Column("filename").asc]).fetchAll(db)
            }
        }catch{
            print(error)
        }
        return result
    }
    
    func getAllPhotoFilesMarkedExported() -> [Image] {
        var result:[Image] = []
        do {
            let db = try DatabasePool(path: dbfile)
            try db.read { db in
                result = try Image.filter("hidden != 1 AND exporTime is not null)").order([Column("photoTakenDate").asc, Column("filename").asc]).fetchAll(db)
            }
        }catch{
            print(error)
        }
        return result
    }
    
    func cleanImageExportTime(path:String) {
        do {
            let db = try DatabasePool(path: dbfile)
            try db.write { db in
                try db.execute("UPDATE Image set exportTime = null WHERE path='\(path)'")
            }
        }catch{
            print(error)
        }
    }
    
    func storeImageExportedTime(path:String, date:Date, exportedFilename:String){
        do {
            let db = try DatabasePool(path: dbfile)
            try db.write { db in
                try db.execute("UPDATE Image set exportTime = ?, exportAsFilename = ? WHERE path=?", arguments: StatementArguments([date, exportedFilename, path]))
            }
        }catch{
            print(error)
        }
    }
    
    func storeImageExportedTime(path:String, date:Date, exportToPath:String){
        do {
            let db = try DatabasePool(path: dbfile)
            try db.write { db in
                try db.execute("UPDATE Image set exportTime = ?, exportToPath = ? WHERE path=?", arguments: StatementArguments([date, exportToPath, path]))
            }
        }catch{
            print(error)
        }
    }
    
    func storeImageExportedTime(path:String, date:Date){
        do {
            let db = try DatabasePool(path: dbfile)
            try db.write { db in
                try db.execute("UPDATE Image set exportTime = ?, WHERE path=?", arguments: StatementArguments([date, path]))
            }
        }catch{
            print(error)
        }
    }
    
    // MARK: IMAGES - TREE
    
    func getAllDates(groupByPlace:Bool = false, imageSource:[String]? = nil, cameraModel:[String]? = nil) -> [Row] {
        var selectPlace = ""
        var groupPlace = ""
        if groupByPlace {
            selectPlace = "place,"
            groupPlace = ",place"
        }
        var sqlArgs:[Any] = []
        var imageSourceWhere = ""
        var cameraModelWhere = ""
        inArray(field: "imageSource", array: imageSource, where: &imageSourceWhere, args: &sqlArgs)
        inArray(field: "cameraModel", array: cameraModel, where: &cameraModelWhere, args: &sqlArgs)
        
        let sql = "SELECT \(selectPlace) photoTakenYear, photoTakenMonth, photoTakenDay, count(path) as photoCount FROM Image WHERE 1=1 \(imageSourceWhere) \(cameraModelWhere) GROUP BY photoTakenYear,photoTakenMonth,photoTakenDay \(groupPlace) ORDER BY photoTakenYear DESC,photoTakenMonth DESC,photoTakenDay DESC \(groupPlace)"
        print(sql)
        var result:[Row] = []
        do {
            let db = try DatabasePool(path: dbfile)
            try db.read { db in
                result = try Row.fetchAll(db, sql, arguments:StatementArguments(sqlArgs))
            }
        }catch{
            print(error)
        }
        return result
        
    }
    
    // MARK: IMAGES - COLLECTION
    
    func getPhotoFiles(year:Int, month:Int, day:Int, place:String?, includeHidden:Bool = true, imageSource:[String]? = nil, cameraModel:[String]? = nil, hiddenCountHandler: ((_ hiddenCount:Int) -> Void)? = nil ) -> [Image] {
        
        var hiddenWhere = ""
        if !includeHidden {
            hiddenWhere = "AND hidden=0"
        }
        var placeWhere = ""
        if place != nil {
            placeWhere = "AND place = '\(place ?? "")'"
        }
        
        
        var stmtWithoutHiddenWhere = ""
        
        if year == 0 && month == 0 && day == 0 {
            stmtWithoutHiddenWhere = "photoTakenYear = 0 and photoTakenMonth = 0 and photoTakenDay = 0 \(placeWhere)"
        }else{
            if year == 0 {
                // no condition
            } else if month == 0 {
                stmtWithoutHiddenWhere = "photoTakenYear = \(year) \(placeWhere) \(hiddenWhere)"
            } else if day == 0 {
                stmtWithoutHiddenWhere = "photoTakenYear = \(year) and photoTakenMonth = \(month) \(placeWhere)"
            } else {
                stmtWithoutHiddenWhere = "photoTakenYear = \(year) and photoTakenMonth = \(month) and photoTakenDay = \(day) \(placeWhere)"
            }
        }
        
        var sqlArgs:[Any] = []
        
        self.inArray(field: "imageSource", array: imageSource, where: &stmtWithoutHiddenWhere, args: &sqlArgs)
        self.inArray(field: "cameraModel", array: cameraModel, where: &stmtWithoutHiddenWhere, args: &sqlArgs)
        
        let stmt = "\(stmtWithoutHiddenWhere) \(hiddenWhere)"
        let stmtHidden = "\(stmtWithoutHiddenWhere) AND hidden=1"
        
        var result:[Image] = []
        var hiddenCount:Int = 0
        do {
            let db = try DatabasePool(path: dbfile)
            try db.read { db in
                hiddenCount = try Image.filter(sql: stmtHidden, arguments:StatementArguments(sqlArgs)).fetchCount(db)
                result = try Image.filter(sql:stmt, arguments:StatementArguments(sqlArgs)).order([Column("photoTakenDate").asc, Column("filename").asc]).fetchAll(db)
            }
        }catch{
            print(error)
        }
        if hiddenCountHandler != nil {
            hiddenCountHandler!(hiddenCount)
        }
        return result
    }
    
    
    
    func getPhotoFiles(year:Int, month:Int, day:Int, event:String, place:String = "", includeHidden:Bool = true, imageSource:[String]? = nil, cameraModel:[String]? = nil, hiddenCountHandler: ((_ hiddenCount:Int) -> Void)? = nil ) -> [Image] {
        var hiddenWhere = ""
        if !includeHidden {
            hiddenWhere = "AND hidden=0"
        }
        var stmtWithoutHiddenWhere = ""
        
        if year == 0 {
            stmtWithoutHiddenWhere = "event = '\(event)' \(hiddenWhere)"
        } else if day == 0 {
            stmtWithoutHiddenWhere = "event = '\(event)' and photoTakenYear = \(year) and photoTakenMonth = \(month) \(hiddenWhere)"
        } else {
            stmtWithoutHiddenWhere = "event = '\(event)' and photoTakenYear = \(year) and photoTakenMonth = \(month) and photoTakenDay = \(day) \(hiddenWhere)"
        }
        
        var sqlArgs:[Any] = []
        
        self.inArray(field: "imageSource", array: imageSource, where: &stmtWithoutHiddenWhere, args: &sqlArgs)
        self.inArray(field: "cameraModel", array: cameraModel, where: &stmtWithoutHiddenWhere, args: &sqlArgs)
        
        let stmt = "\(stmtWithoutHiddenWhere) \(hiddenWhere)"
        let stmtHidden = "\(stmtWithoutHiddenWhere) AND hidden=1"
        
        var result:[Image] = []
        var hiddenCount:Int = 0
        do {
            let db = try DatabasePool(path: dbfile)
            try db.read { db in
                hiddenCount = try Image.filter(sql: stmtHidden, arguments:StatementArguments(sqlArgs)).fetchCount(db)
                result = try Image.filter(sql:stmt, arguments:StatementArguments(sqlArgs)).order([Column("photoTakenDate").asc, Column("filename").asc]).fetchAll(db)
            }
        }catch{
            print(error)
        }
        if hiddenCountHandler != nil {
            hiddenCountHandler!(hiddenCount)
        }
        return result
    }
    
    // MARK: PLACES
    
    
    func getAllPlaces() -> [ImagePlace] {
        var places:[ImagePlace] = []
        
        do {
            let dbPool = try DatabasePool(path: dbfile)
            try dbPool.read { db in
                places = try ImagePlace.fetchAll(db)
            }
        }catch{
            print(error)
        }
        return places
    }
    
    func getPlaces(byName names:String? = nil) -> [ImagePlace] {
        var result:[ImagePlace] = []
        var stmt = ""
        if let names = names {
            let keys:[String] = names.components(separatedBy: " ")
            stmt = self.likeArray(field: "name", array: keys)
        }
        do {
            let db = try DatabasePool(path: dbfile)
            try db.read { db in
                if stmt != "" {
                    result = try ImagePlace.filter(stmt).order(Column("name").asc).fetchAll(db)
                }else{
                    result = try ImagePlace.order(Column("name").asc).fetchAll(db)
                }
            }
        }catch{
            print(error)
        }
        return result
    }
    
    func getOrCreatePlace(name:String, location:Location) -> ImagePlace{
        var place:ImagePlace?
        do {
            let db = try DatabaseQueue(path: dbfile)
            try db.read { db in
                place = try ImagePlace.fetchOne(db, key: name)
            }
            if place == nil {
                try db.write { db in
                    place = ImagePlace(
                                       name: name,
                                       country:             location.country,
                                       province:            location.province,
                                       city:                location.city,
                                       district:            location.district,
                                       businessCircle:      location.businessCircle,
                                       street:              location.street,
                                       address:             location.address,
                                       addressDescription:  location.addressDescription,
                                       latitude:            location.coordinate?.latitude.description ?? "",
                                       latitudeBD:          location.coordinateBD?.latitude.description ?? "",
                                       longitude:           location.coordinate?.longitude.description ?? "",
                                       longitudeBD:         location.coordinateBD?.longitude.description ?? "" )
                    try place?.save(db)
                }
            }
        }catch{
            print(error)
        }
        return place!
    }
    
    
    
    func getPlace(name:String) -> ImagePlace? {
        var place:ImagePlace?
        do {
            let db = try DatabaseQueue(path: dbfile)
            try db.read { db in
                place = try ImagePlace.fetchOne(db, key: name)
            }
        }catch{
            print(error)
        }
        return place
    }
    
    func renamePlace(oldName:String, newName:String){
        do {
            let db = try DatabaseQueue(path: dbfile)
            try db.write { db in
                if let _ = try ImagePlace.fetchOne(db, key: newName){
                    try ImagePlace.deleteOne(db, key: oldName)
                }else {
                    if var place = try ImagePlace.fetchOne(db, key: oldName) {
                        place.name = newName
                        try place.save(db)
                    }
                }
                try db.execute("UPDATE Image SET AssignPlace=? WHERE AssignPlace=?", arguments: StatementArguments([oldName, newName]))
            }
        }catch{
            print(error)
        }
    }
    
    func updatePlace(name:String, location:Location){
        do {
            let db = try DatabaseQueue(path: dbfile)
            try db.write { db in
                if var place = try ImagePlace.fetchOne(db, key: name) {
                    place.country = location.country
                    place.province = location.province
                    place.city = location.city
                    place.businessCircle = location.businessCircle
                    place.district = location.district
                    place.street = location.street
                    place.address = location.address
                    place.addressDescription = location.addressDescription
                    place.latitude = location.coordinate?.latitude.description ?? ""
                    place.longitude = location.coordinate?.longitude.description ?? ""
                    place.latitudeBD = location.coordinateBD?.latitude.description ?? ""
                    place.longitudeBD = location.coordinateBD?.longitude.description ?? ""
                    try place.save(db)
                    try db.execute("UPDATE Image SET AssignCountry=?,AssignProvince=?,AssignCity=?,AssignBusinessCircle=?,AssignDistrict=?,AssignStreet=?,AssignAddress=?,AssignAddressDescription=?,Latitude=?,longitude=?,latitudeBD=?,longitudeBD=? WHERE AssignPlace=?",
                                   arguments: StatementArguments([
                                    location.country,
                                    location.province,
                                    location.city,
                                    location.businessCircle,
                                    location.district,
                                    location.street,
                                    location.address,
                                    location.addressDescription,
                                    location.coordinate?.latitude.description ?? "",
                                    location.coordinate?.longitude.description ?? "",
                                    location.coordinateBD?.latitude.description ?? "",
                                    location.coordinateBD?.longitude.description ?? "",
                                    name]))
                }
            }
        }catch{
            print(error)
        }
    }
    
    func deletePlace(name:String){
        do {
            let db = try DatabaseQueue(path: dbfile)
            try db.write { db in
                let _ = try ImagePlace.deleteOne(db, key: name)
            }
        }catch{
            print(error)
        }
    }
    
    // MARK: EVENTS
    
    func getAllEvents() -> [ImageEvent] {
        var events:[ImageEvent] = []
        
        do {
            let dbPool = try DatabasePool(path: dbfile)
            try dbPool.read { db in
                events = try ImageEvent.order([Column("country").asc, Column("province").asc, Column("city").asc, Column("name").asc]).fetchAll(db)
            }
        }catch{
            print(error)
        }
        return events
    }
    
    func getEvents(byName names:String? = nil) -> [ImageEvent] {
        var result:[ImageEvent] = []
        var stmt = ""
        if let names = names {
            let keys:[String] = names.components(separatedBy: " ")
            stmt = self.likeArray(field: "name", array: keys)
        }
        do {
            let db = try DatabasePool(path: dbfile)
            try db.read { db in
                if stmt != "" {
                    result = try ImageEvent.filter(stmt).order(Column("name").asc).fetchAll(db)
                }else{
                    result = try ImageEvent.order(Column("name").asc).fetchAll(db)
                }
            }
        }catch{
            print(error)
        }
        return result
    }
    
    func getOrCreateEvent(name:String) -> ImageEvent{
        var event:ImageEvent?
        do {
            let db = try DatabaseQueue(path: dbfile)
            try db.read { db in
                event = try ImageEvent.fetchOne(db, key: name)
            }
            if event == nil {
                try db.write { db in
                    event = ImageEvent(name: name)
                    try event?.save(db)
                }
            }
        }catch{
            print(error)
        }
        return event!
    }
    
    func deleteEvent(name:String){
        do {
            let db = try DatabaseQueue(path: dbfile)
            try db.write { db in
                try ImageEvent.deleteOne(db, key: name)
                try db.execute("UPDATE Image SET event='' WHERE event=?", arguments: StatementArguments([name]))
            }
        }catch{
            print(error)
        }
    }
    
    func renameEvent(oldName:String, newName:String){
        print("RENAME EVENT \(oldName) to \(newName)")
        do {
            let db = try DatabaseQueue(path: dbfile)
            try db.write { db in
                if let _ = try ImageEvent.fetchOne(db, key: newName){
                    try ImageEvent.deleteOne(db, key: oldName)
                }else {
                    if var event = try ImageEvent.fetchOne(db, key: oldName) {
                        event.name = newName
                        try event.save(db)
                    }
                }
                try db.execute("UPDATE Image SET AssignPlace=? WHERE AssignPlace=?", arguments: StatementArguments([oldName, newName]))
            }
        }catch{
            print(error)
        }
    }
    
    // MARK: EVENTS - TREE
    
    func getAllEvents(imageSource:[String]? = nil, cameraModel:[String]? = nil) -> [Row] {
        var sqlArgs:[Any] = []
        var imageSourceWhere = ""
        var cameraModelWhere = ""
        inArray(field: "imageSource", array: imageSource, where: &imageSourceWhere, args: &sqlArgs)
        inArray(field: "cameraModel", array: cameraModel, where: &cameraModelWhere, args: &sqlArgs)
        
        let sql = "SELECT event, photoTakenYear, photoTakenMonth, photoTakenDay, place, count(path) as photoCount FROM Image WHERE 1=1 \(imageSourceWhere) \(cameraModelWhere) ORDER BY event DESC,photoTakenYear DESC,photoTakenMonth DESC,photoTakenDay DESC,place"
        print(sql)
        var result:[Row] = []
        do {
            let db = try DatabasePool(path: dbfile)
            try db.read { db in
                result = try Row.fetchAll(db, sql, arguments:StatementArguments(sqlArgs))
            }
        }catch{
            print(error)
        }
        return result
        
    }
    
    // MARK: SCHEMA VERSION MIGRATION
    
    fileprivate func versionCheck(){
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("v1") { db in
            try db.create(table: "ImageEvent", body: { t in
                t.column("name", .text).primaryKey().unique().notNull()
                t.column("startDate", .datetime)
                t.column("startYear", .integer)
                t.column("startMonth", .integer)
                t.column("startDay", .integer)
                t.column("endDate", .datetime)
                t.column("endYear", .integer)
                t.column("endMonth", .integer)
                t.column("endDay", .integer)
            })
            
            try db.create(table: "ImagePlace", body: { t in
                t.column("name", .text).primaryKey().unique().notNull()
                t.column("latitude", .text)
                t.column("latitudeBD", .text)
                t.column("longitude", .text)
                t.column("longitudeBD", .text)
                t.column("country", .text).indexed()
                t.column("province", .text).indexed()
                t.column("city", .text).indexed()
                t.column("district", .text)
                t.column("businessCircle", .text)
                t.column("street", .text)
                t.column("address", .text)
                t.column("addressDescription", .text)
            })
            
            try db.create(table: "ImageContainer", body: { t in
                t.column("path", .text).primaryKey().unique().notNull()
                t.column("name", .text).indexed()
                t.column("parentFolder", .text).indexed()
                t.column("imageCount", .integer)
            })
            
            try db.create(table: "Image", body: { t in
                t.column("audioBits", .integer)
                t.column("audioChannels", .integer)
                t.column("audioRate", .integer)
                t.column("hidden", .boolean).defaults(to: false).indexed()
                t.column("imageHeight", .integer)
                t.column("imageWidth", .integer)
                t.column("photoTakenDay", .integer).defaults(to: 0).indexed()
                t.column("photoTakenMonth", .integer).defaults(to: 0).indexed()
                t.column("photoTakenYear", .integer).defaults(to: 0).indexed()
                t.column("photoTakenHour", .integer).defaults(to: 0).indexed()
                t.column("rotation", .integer)
                t.column("addDate", .datetime)
                t.column("assignDateTime", .datetime)
                t.column("exifCreateDate", .datetime)
                t.column("exifDateTimeOriginal", .datetime)
                t.column("exifModifyDate", .datetime)
                t.column("exportTime", .datetime)
                t.column("filenameDate", .datetime)
                t.column("filesysCreateDate", .datetime)
                t.column("photoTakenDate", .datetime).indexed()
                t.column("softwareModifiedTime", .datetime)
                t.column("trackCreateDate", .datetime)
                t.column("trackModifyDate", .datetime)
                t.column("updateDateTimeDate", .datetime).indexed()
                t.column("updateEventDate", .datetime).indexed()
                t.column("updateExifDate", .datetime).indexed()
                t.column("updateLocationDate", .datetime).indexed()
                t.column("updatePhotoTakenDate", .datetime).indexed()
                t.column("videoCreateDate", .datetime)
                t.column("videoFrameRate", .double)
                t.column("videoModifyDate", .datetime)
                t.column("address", .text)
                t.column("addressDescription", .text)
                t.column("aperture", .text)
                t.column("assignAddress", .text)
                t.column("assignAddressDescription", .text)
                t.column("assignBusinessCircle", .text)
                t.column("assignCity", .text)
                t.column("assignCountry", .text)
                t.column("assignDistrict", .text)
                t.column("assignLatitude", .text)
                t.column("assignLatitudeBD", .text)
                t.column("assignLongitude", .text)
                t.column("assignLongitudeBD", .text)
                t.column("assignPlace", .text).indexed()
                t.column("assignProvince", .text)
                t.column("assignStreet", .text)
                t.column("businessCircle", .text)
                t.column("cameraMaker", .text).indexed()
                t.column("cameraModel", .text).indexed()
                t.column("city", .text).indexed()
                t.column("containerPath", .text).indexed()
                t.column("country", .text).indexed()
                t.column("datetimeFromFilename", .text)
                t.column("district", .text)
                t.column("event", .text).indexed()
                t.column("exportAsFilename", .text)
                t.column("exportToPath", .text)
                t.column("exposureTime", .text)
                t.column("fileSize", .text)
                t.column("filename", .text).indexed()
                t.column("gpsDate", .text)
                t.column("hideForSourceFilename", .text).indexed()
                t.column("imageSource", .text).indexed()
                t.column("iso", .text)
                t.column("latitude", .text)
                t.column("latitudeBD", .text)
                t.column("longitude", .text)
                t.column("longitudeBD", .text)
                t.column("path", .text).primaryKey().unique().notNull()
                t.column("photoDescription", .text)
                t.column("place", .text).indexed()
                t.column("province", .text).indexed()
                t.column("softwareName", .text).indexed()
                t.column("street", .text)
                t.column("suggestPlace", .text)
                t.column("videoBitRate", .text)
                t.column("videoDuration", .text)
                t.column("videoFormat", .text)
            })
        }
        
        do {
            let dbQueue = try DatabaseQueue(path: dbfile)
            try migrator.migrate(dbQueue)
        }catch{
            print(error)
        }
    }
    
    // MARK: DATA MIGRATION FROM CORE DATA
    
    func checkData(){
        do {
            let dbQueue = try DatabaseQueue(path: dbfile)
            var containerCount:Int = 0
            var eventCount:Int = 0
            var placeCount:Int = 0
            var imageCount:Int = 0
            try dbQueue.read { db in
                containerCount = try ImageContainer.fetchCount(db)
                eventCount = try ImageEvent.fetchCount(db)
                placeCount = try ImagePlace.fetchCount(db)
                imageCount = try Image.fetchCount(db)
            }
            
            if containerCount == 0 {
                self.cloneImageContainersFromCoreDate()
            }
            
            if eventCount == 0 {
                self.cloneImageEventsFromCoreDate()
            }
            
            if placeCount == 0 {
                self.cloneImagePlacesFromCoreDate()
            }
            
            if imageCount == 0 {
                self.cloneImagesFromCoreDate()
            }
            
            
        }catch{
            print(error)
        }
    }
    
    fileprivate func cloneImageContainersFromCoreDate(){
        do {
            let dbQueue = try DatabaseQueue(path: dbfile)
            try dbQueue.write { db in
                try db.execute("INSERT INTO ImageContainer (PATH, NAME, PARENTFOLDER, IMAGECOUNT) SELECT ZPATH, ZNAME, ZPARENTFOLDER, ZIMAGECOUNT FROM ZCONTAINERFOLDER")
            }
        }catch{
            print(error)
        }
    }
    
    fileprivate func cloneImageEventsFromCoreDate(){
        do {
            let dbQueue = try DatabaseQueue(path: dbfile)
            try dbQueue.write { db in
                try db.execute("""
INSERT INTO ImageEvent (NAME, STARTDATE, STARTYEAR, STARTMONTH, STARTDAY, ENDDATE,ENDYEAR, ENDMONTH, ENDDAY)
SELECT ZNAME, DATETIME(ZSTARTDATE + 978307200, 'unixepoch'), ZSTARTYEAR, ZSTARTMONTH, ZSTARTDAY,
DATETIME(ZENDDATE + 978307200, 'unixepoch'),ZENDYEAR, ZENDMONTH, ZENDDAY FROM ZPHOTOEVENT
""")
            }
        }catch{
            print(error)
        }
    }
    
    fileprivate func cloneImagePlacesFromCoreDate(){
        do {
            let dbQueue = try DatabaseQueue(path: dbfile)
            try dbQueue.write { db in
                try db.execute("INSERT INTO ImagePlace (NAME, LATITUDE, LATITUDEBD, LONGITUDE, LONGITUDEBD, COUNTRY, PROVINCE, CITY, DISTRICT, BUSINESSCIRCLE, STREET, ADDRESS, ADDRESSDESCRIPTION) SELECT ZNAME, ZLATITUDE, ZLATITUDEBD, ZLONGITUDE, ZLONGITUDEBD, ZCOUNTRY, ZPROVINCE, ZCITY, ZDISTRICT, ZBUSINESSCIRCLE, ZSTREET, ZADDRESS, ZADDRESSDESCRIPTION FROM ZPHOTOPLACE ORDER BY ZCOUNTRY,ZPROVINCE,ZCITY,ZNAME")
            }
        }catch{
            print(error)
        }
    }
    
    fileprivate func cloneImagesFromCoreDate(){
        do {
            let dbQueue = try DatabaseQueue(path: dbfile)
            try dbQueue.write { db in
                try db.execute("""
INSERT INTO Image (addDate, address, addressDescription, aperture, assignAddress, assignAddressDescription, assignBusinessCircle, assignCity, assignCountry, assignDateTime, assignDistrict, assignLatitude, assignLatitudeBD, assignLongitude, assignLongitudeBD, assignPlace, assignProvince, assignStreet, audioBits, audioChannels, audioRate, businessCircle, cameraMaker, cameraModel, city, containerPath, country, dateTimeFromFilename, district, event, exifCreateDate, exifDateTimeOriginal, exifModifyDate, exportAsFilename, exportTime, exportToPath, exposureTime, filename, filenameDate, fileSize, filesysCreateDate, gpsDate, hidden, hideForSourceFilename, imageHeight, imageSource, imageWidth, iso, latitude, latitudeBD, longitude, longitudeBD, path, photoDescription, photoTakenDate, photoTakenDay, photoTakenHour, photoTakenMonth, photoTakenYear, place, province, rotation, softwareModifiedTime, softwareName, street, suggestPlace, trackCreateDate, trackModifyDate, updateDateTimeDate, updateEventDate, updateExifDate, updateLocationDate, updatePhotoTakenDate, videoBitRate, videoCreateDate, videoDuration, videoFormat, videoFrameRate, videoModifyDate)
SELECT
DATETIME(zaddDate + 978307200, 'unixepoch'),
zaddress, zaddressDescription, zaperture, zassignAddress, zassignAddressDescription, zassignBusinessCircle, zassignCity, zassignCountry, zassignDateTime, zassignDistrict, zassignLatitude, zassignLatitudeBD, zassignLongitude, zassignLongitudeBD, zassignPlace, zassignProvince, zassignStreet, zaudioBits, zaudioChannels, zaudioRate, zbusinessCircle, zcameraMaker, zcameraModel, zcity, zcontainerPath, zcountry,zdateTimeFromFilename,zdistrict, zevent,
DATETIME(zexifCreateDate + 978307200, 'unixepoch'),
DATETIME(zexifDateTimeOriginal + 978307200, 'unixepoch'),
DATETIME(zexifModifyDate + 978307200, 'unixepoch'),
zexportAsFilename,
DATETIME(zexportTime + 978307200, 'unixepoch'),
zexportToPath, zexposureTime, zfilename,
DATETIME(zfilenameDate + 978307200, 'unixepoch'),
zfileSize,
DATETIME(zfilesysCreateDate + 978307200, 'unixepoch'),
zgpsDate,
IFNULL(zhidden,0),
zhideForSourceFilename, zimageHeight, zimageSource, zimageWidth, ziso, zlatitude, zlatitudeBD, zlongitude, zlongitudeBD, zpath, zphotoDescription,
DATETIME(zphotoTakenDate + 978307200, 'unixepoch'),
zphotoTakenDay, zphotoTakenHour, zphotoTakenMonth, zphotoTakenYear, zplace, zprovince, zrotation,
DATETIME(zsoftwareModifiedTime + 978307200, 'unixepoch'),
zsoftwareName, zstreet, zsuggestPlace,
DATETIME(ztrackCreateDate + 978307200, 'unixepoch'),
DATETIME(ztrackModifyDate + 978307200, 'unixepoch'),
DATETIME(zupdateDateTimeDate + 978307200, 'unixepoch'),
DATETIME(zupdateEventDate + 978307200, 'unixepoch'),
DATETIME(zupdateExifDate + 978307200, 'unixepoch'),
DATETIME(zupdateLocationDate + 978307200, 'unixepoch'),
DATETIME(zupdatePhotoTakenDate + 978307200, 'unixepoch'),
zvideoBitRate,
DATETIME(zvideoCreateDate + 978307200, 'unixepoch'),
zvideoDuration, zvideoFormat, zvideoFrameRate,
DATETIME(zvideoModifyDate + 978307200, 'unixepoch')
FROM ZPHOTOFILE order by zpath
""")
            }
        }catch{
            print(error)
        }
    }
}
