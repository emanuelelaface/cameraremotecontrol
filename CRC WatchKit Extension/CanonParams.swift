//
//  CanonParams.swift
//  CRC WatchKit Extension
//
//  Created by Emanuele Laface on 2021-11-21.
//

import Foundation

let SwitchImmediate = 0b00001100
let SwitchDelay     = 0b00000100
let SwitchVideo     = 0b00001000

let ButtonRelease   = 0b10000000
let ButtonFocus     = 0b01000000
let ButtonTele      = 0b00100000
let ButtonWide      = 0b00010000

let AppName = Data([3])//,67,82,67,32,65,112,112,108,101,32,87,97,116,99,104]) // CRC Apple Watch

let UUIDService               = "00050000-0000-1000-0000-D8492FFFA821"
let UUIDCharacteristicPairing = "00050002-0000-1000-0000-D8492FFFA821"
let UUIDCharacteristicEvent   = "00050003-0000-1000-0000-D8492fffA821"
