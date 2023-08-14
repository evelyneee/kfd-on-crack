/*
 * Copyright (c) 2023 Félix Poulin-Bélanger. All rights reserved.
 */

import SwiftUI
import KernelPatchfinder
import SwiftMachO
import PatchfinderUtils

struct ContentView: View {
    @State private var kfd: UInt64 = 0

    private var puaf_pages_options = [16, 32, 64, 128, 256, 512, 1024, 2048]
    @State private var puaf_pages_index = 7
    @State private var puaf_pages = 0

    private var puaf_method_options = ["physpuppet", "smith"]
    @State private var puaf_method = 1

    private var kread_method_options = ["kqueue_workloop_ctl", "sem_open", "IOSurface"]
    @State private var kread_method = 2

    private var kwrite_method_options = ["dup", "sem_open", "IOSurface"]
    @State private var kwrite_method = 2

    @State var postExploited = false
    
//    @State var entireLog: [Log] = []
    //@State var entireLogString: [String] = []
    @State var str = ""
    
    var body: some View {
        NavigationView {
            Form {
                HStack {
                    Button("kopen") {
                        Task {
                            puaf_pages = puaf_pages_options[puaf_pages_index]
                            do {
                                try await Jailbreak.shared.start(puaf_pages: UInt64(puaf_pages), puaf_method: UInt64(puaf_method), kread_method: UInt64(kread_method), kwrite_method: UInt64(kwrite_method))
                            } catch {
                                print(#function)
                            }
                        }
                    }.disabled(kfd != 0).frame(minWidth: 0, maxWidth: .infinity)
                    
                    Button("kclose") {
                        kclose_intermediate(kfd)
                        puaf_pages = 0
                        kfd = 0
                    }.disabled(kfd == 0).frame(minWidth: 0, maxWidth: .infinity)
                }
                
                
                Section {
                    Text("to do: improve the log view below, this is just temporary!")
                    Text(str)
                }
            }
        }
        .onAppear {
            Logger.shared.callback = { newLog in
//                DispatchQueue.main.async {
//                    str.append(newLog.text)
//                }
//                DispatchQueue.main.async {
//                    self.entireLogString.append(newLog.text)
//                    str = entireLogString.joined(separator: "")
//                }
            }
        }
    }
}
