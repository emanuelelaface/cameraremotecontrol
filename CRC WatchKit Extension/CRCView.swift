//
//  CRCView.swift
//  CRC WatchKit Extension
//
//  Created by Emanuele Laface on 2021-11-30.
//

import SwiftUI

struct CRCView: View {
    @State var bleManager: BLEManager
    @State private var RemoteSwitch = SwitchImmediate
        
    var body: some View {
        VStack{
            Spacer()
            Picker("Camera Mode", selection: $RemoteSwitch) {
                Text("Immediate").tag(SwitchImmediate)
                Text("2s Delay").tag(SwitchDelay)
                Text("Video").tag(SwitchVideo)
            }
            .frame(width: .infinity, height: 64)
            Spacer()
            HStack {
                Button(action:{
                    bleManager.clickButton(mode: RemoteSwitch, button: ButtonTele)
                })
                { Text("T") }
                Spacer()
                Button(action:{
                    bleManager.clickButton(mode: RemoteSwitch, button: ButtonFocus)
                })
                { Text("AF") }
                Spacer()
                Button(action:{
                    bleManager.clickButton(mode: RemoteSwitch, button: ButtonWide)
                })
                { Text("W") }
            }
            Spacer()
            Button(action:{
                bleManager.clickButton(mode: RemoteSwitch, button: ButtonRelease)
            })
            { Text("Shutter") }
        }
        .navigationBarHidden(true)
        .ignoresSafeArea()
    }
}
