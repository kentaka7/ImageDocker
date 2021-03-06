# ImageDocker

A desktop application help organize pictures and videos between cameras/mobile devices and Plex Media Server.

![Platform](https://img.shields.io/badge/platforms-macOS%2010.13+-ff7711.svg)

## Major objectives

- Import images from local directories and mobile devices
- Change photo-taken-date and geolocation of images
- Export images to another directory in well-organized directory structure to feed Plex Media Server

## Features

- Organize images by directories, dates, events and places.
- EXIF information, such as dates, geolocation, camera models, etc. Could be modified in batch.
- Detect and recognize faces.

## Screenshot
v0.10.0
New feature: splash screen on startup
![Splash screen of v0.10.0](Screenshots/Screenshot_v0.10.0_1.png)
New feature: pagination for collection view
![Pagination of v0.10.0](Screenshots/Screenshot_v0.10.0_2.png)
New feature: scan and recognize faces (required dlib+python libraries)
![Pagination of v0.10.0](Screenshots/Screenshot_v0.10.0_3.png)
New feature: performance control
![Pagination of v0.10.0](Screenshots/Screenshot_v0.10.0_4.png)


v0.9.4
New feature: combine similar images into a group
![Image Docker of v0.9.4](Screenshots/Screenshot_v0.9.4_1.png)
New feature: Larger view of image
![Image Viewer of v0.9.4](Screenshots/Screenshot_v0.9.4_2.png)

v0.9.3
![Screenshot of v0.9.3](Screenshots/Screenshot_v0.9.3.png)

## Dependencies

- [GRDB](https://github.com/groue/GRDB.swift): to manage data in a SQLite database ([The MIT License](https://github.com/groue/GRDB.swift/blob/master/LICENSE))
- [ExifTool](https://www.sno.phy.queensu.ca/~phil/exiftool/): to load EXIF info from images ([Perl License](https://www.sno.phy.queensu.ca/~phil/exiftool/#license))
- [Baidu Map API](http://lbsyun.baidu.com): to recognize geolocation inside China, and to display maps ([License](http://lbsyun.baidu.com/index.php?title=open/law))
- [Google Map API](https://developers.google.com/maps/documentation/): to recognize geolocation outside China ([License](https://developers.google.com/terms/site-policies))
- [Android Debug Bridge](https://developer.android.com/studio/command-line/adb): to detect and access Android devices ([License](https://developer.android.com/license))
- [libimobiledevice](https://github.com/libimobiledevice/libimobiledevice): to detect and pair iOS devices ([LGPL License](https://github.com/libimobiledevice/libimobiledevice/blob/master/COPYING))
- [ifuse](https://github.com/libimobiledevice/ifuse): to access iOS devices ([LGPL License](https://github.com/libimobiledevice/ifuse/blob/master/COPYING))
- [PXSourceList](https://github.com/Perspx/PXSourceList): tree view ([The New BSD License](https://github.com/Perspx/PXSourceList/blob/master/LICENSE))
- [SwiftyJSON](https://github.com/SwiftyJSON/SwiftyJSON) ([The MIT License](https://github.com/SwiftyJSON/SwiftyJSON/blob/master/LICENSE))
- [CryptoSwift](https://github.com/krzyzanowskim/CryptoSwift) ([License](https://github.com/krzyzanowskim/CryptoSwift/blob/master/LICENSE))

## Prerequisite

- Personal AP key of Baidu Map API is required for displaying maps and recognizing geolocations inside China
- Personal AP key of Google Map API is required for recognizing geolocations outside China

## PLEASE NOTE

- This software supports screen resolution not less than 1920 x 1080 .
- Any pre-release versions of this software is applied to author/developer only.
- Please backup source pictures and videos before using any versions of this software.

## License

[The MIT License](LICENSE)
