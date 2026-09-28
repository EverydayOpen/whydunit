import AppKit
import SwiftUI

@main
struct WhydunitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Whydunit", id: "main") {
            MainView()
                .environment(appDelegate.store)
                .frame(minWidth: 1000, minHeight: 640)
        }
        .defaultSize(width: 1120, height: 760)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appInfo) { Button("About Whydunit", action: showAboutPanel) }
            CommandGroup(after: .appInfo) { CheckForUpdatesView() }
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Scan") { ScanCommands(store: appDelegate.store) }
            SidebarCommands()
            CommandGroup(after: .sidebar) { InspectorCommand(store: appDelegate.store) }
            // No help book (its default item only says "Help isn't available"): the website instead.
            // Only .help is replaced; the Edit menu (.pasteboard, .textEditing) stays, so ⌘C and ⌘V keep working.
            CommandGroup(replacing: .help) {
                Button("Whydunit Help") { NSWorkspace.shared.open(Links.support) }
                Button("What's New") { NSWorkspace.shared.open(Links.changelog) }
                Button("Privacy Policy") { NSWorkspace.shared.open(Links.privacy) }
                Divider()
                Button("Acknowledgements", action: showAboutPanel)
            }
        }

        Settings {
            SettingsView().environment(appDelegate.store)
        }
    }
}

/// A View (not Commands) so Observation tracks the store and the items enable/disable live.
private struct ScanCommands: View {
    let store: AppStore

    private var isScanning: Bool {
        if case .scanning = store.scanState { return true }
        return false
    }

    var body: some View {
        // Not behind an open sheet: a rescan mid-action would swap the items the user reviewed.
        Button("Scan Again") { store.scan() }
            .keyboardShortcut("r")
            .disabled(isScanning || store.sheet != nil)
        // ⌘. is Cancel in a sheet; it must never reach this item instead.
        Button("Stop Scan") { store.cancelScan() }
            .keyboardShortcut(".")
            .disabled(!isScanning || store.sheet != nil)
        Divider()
        Button("Copy Diagnosis") { store.copyDiagnosis() }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(store.diagnosis == nil)
    }
}

/// Replaces InspectorCommands, whose item stays enabled (and does nothing) off finding pages.
private struct InspectorCommand: View {
    let store: AppStore

    var body: some View {
        let shown = store.isFindingRoute && store.inspectorShown
        Button(shown ? "Hide Inspector" : "Show Inspector") { store.inspectorShown.toggle() }
            .keyboardShortcut("i", modifiers: [.command, .control])
            .disabled(!store.isFindingRoute)
    }
}

/// The standard About panel, with the website, the policies and the acknowledgements as its scrolling credits.
@MainActor private func showAboutPanel() {
    let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
    let plain: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.secondaryLabelColor]
    let credits = NSMutableAttributedString()
    for (title, url) in [("Website", Links.website), ("Terms", Links.terms), ("Privacy", Links.privacy)] {
        if credits.length > 0 { credits.append(NSAttributedString(string: " · ", attributes: plain)) }
        credits.append(NSAttributedString(string: title, attributes: [.font: font, .link: url]))
    }
    // Sparkle ships inside the app, so its licence notices (MIT, plus the BSD and zlib-style parts it bundles) must too.
    credits.append(NSAttributedString(string: "\n\nAcknowledgements\n\nSparkle (sparkle-project.org)\n\n" + sparkleLicense, attributes: plain))
    NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    NSApp.activate()
}

/// Sparkle 2.10.0's LICENSE (https://github.com/sparkle-project/Sparkle/blob/2.10.0/LICENSE), verbatim except
/// trailing spaces. Update it when project.yml's Sparkle version changes.
private let sparkleLicense = """
Copyright (c) 2006-2013 Andy Matuschak.
Copyright (c) 2009-2013 Elgato Systems GmbH.
Copyright (c) 2011-2014 Kornel Lesiński.
Copyright (c) 2015-2017 Mayur Pawashe.
Copyright (c) 2014 C.W. Betts.
Copyright (c) 2014 Petroules Corporation.
Copyright (c) 2014 Big Nerd Ranch.
All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=================
EXTERNAL LICENSES
=================

bspatch.c and bsdiff.c, from bsdiff 4.3 <http://www.daemonology.net/bsdiff/>:

Copyright 2003-2005 Colin Percival
All rights reserved

Redistribution and use in source and binary forms, with or without
modification, are permitted providing that the following conditions
are met:
1. Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

--

sais.c and sais.h, from sais-lite (2010/08/07) <https://sites.google.com/site/yuta256/sais>:

The sais-lite copyright is as follows:

Copyright (c) 2008-2010 Yuta Mori All Rights Reserved.

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

--

Portable C implementation of Ed25519, from https://github.com/orlp/ed25519

Copyright (c) 2015 Orson Peters <orsonpeters@gmail.com>

This software is provided 'as-is', without any express or implied warranty. In no event will the
authors be held liable for any damages arising from the use of this software.

Permission is granted to anyone to use this software for any purpose, including commercial
applications, and to alter it and redistribute it freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must not claim that you wrote the
   original software. If you use this software in a product, an acknowledgment in the product
   documentation would be appreciated but is not required.

2. Altered source versions must be plainly marked as such, and must not be misrepresented as
   being the original software.

3. This notice may not be removed or altered from any source distribution.

--

SUSignatureVerifier.m:

Copyright (c) 2011 Mark Hamlin.

All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted providing that the following conditions
are met:
1. Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.
"""
