//
//  ContentView.swift
//  CRC WatchKit Extension
//
//  Created by Emanuele Laface on 2021-11-21.
//

import SwiftUI

struct MainView: View {
    @ObservedObject var bleManager = BLEManager()
    @State private var selectedDate = Date()
    
    var body: some View {
        ZStack {
            if (bleManager.isSwitchedOn) {
                if (bleManager.isConnected) {
                    CRCView(bleManager: bleManager)
                }
                else {
                    VStack{
                        Spacer()
                        Text("Connecting...").foregroundColor(.green)
                        ProgressView()
                        Spacer()
                    }
                }
            }
            else {
                Text("Bluetooth is NOT swidtched on")
                    .foregroundColor(.red)
            }
        }
        .onAppear() { bleManager.startScanning() }
    }
}
