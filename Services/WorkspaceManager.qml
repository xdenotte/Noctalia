pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Services

Singleton {
    id: root

    property ListModel workspaces: ListModel {}
    property bool isHyprland: false
    property bool isNiri: false
    property var hlWorkspaces: Hyprland.workspaces.values
    // Detect which compositor we're using
    Component.onCompleted: {
        console.log("WorkspaceManager initializing...");
        detectCompositor();
    }

    function detectCompositor() {
        try {
            try {
                if (Hyprland.eventSocketPath) {
                    console.log("Detected Hyprland compositor");
                    isHyprland = true;
                    isNiri = false;
                    initHyprland();
                    return;
                }
            } catch (e) {
                console.log("Hyprland not available:", e);
            }
            
            if (typeof Niri !== "undefined") {
                console.log("Detected Niri service");
                isHyprland = false;
                isNiri = true;
                initNiri();
                return;
            }
            
            console.log("No supported compositor detected");
        } catch (e) {
            console.error("Error detecting compositor:", e);
        }
    }

    // Initialize Hyprland integration
    function initHyprland() {
        try {
            // Initial refresh to get workspaces
            Hyprland.refreshWorkspaces();
            
            // Update with current workspaces
            hlWorkspaces = Hyprland.workspaces.values || [];
            updateHyprlandWorkspaces();
            
            // Set up a timer to check again after a short delay
            const timer = Qt.createQmlObject('import QtQuick 2.15; Timer { interval: 500; running: true; repeat: false }', 
                                          root, "InitialWorkspaceTimer");
            timer.triggered.connect(function() {
                hlWorkspaces = Hyprland.workspaces.values || [];
                updateHyprlandWorkspaces();
                timer.destroy();
            });
            
            return true;
        } catch (e) {
            console.error("Error initializing Hyprland:", e);
            isHyprland = false;
            return false;
        }
    }

    onHlWorkspacesChanged: {
        updateHyprlandWorkspaces();
    }

    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() {
            updateHyprlandWorkspaces();
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            updateHyprlandWorkspaces();
        }
    }



    function updateHyprlandWorkspaces() {
        workspaces.clear();
        
        try {
            if (!hlWorkspaces || hlWorkspaces.length === 0) {
                return;
            }
            
            for (let i = 0; i < hlWorkspaces.length; i++) {
                const ws = hlWorkspaces[i];
                if (!ws) continue;
                
                workspaces.append({
                    id: i,
                    idx: ws.id || i,
                    name: ws.name || String(i + 1),
                    output: ws.monitor?.name || "",
                    isActive: ws.active === true,
                    isFocused: ws.focused === true,
                    isUrgent: ws.urgent === true,
                    isOccupied: true  // Always show as occupied if it exists
                });
            }
            
            workspacesChanged();
        } catch (e) {
            console.error("Error updating workspaces:", e);
        }
    }

    function initNiri() {
        updateNiriWorkspaces();
    }

    Connections {
        target: Niri
        function onWorkspacesChanged() { 
            updateNiriWorkspaces();
        }
    }

    function updateNiriWorkspaces() {
        const niriWorkspaces = Niri.workspaces || [];
        workspaces.clear();
        for (let i = 0; i < niriWorkspaces.length; i++) {
            const ws = niriWorkspaces[i];
            workspaces.append({
                id: ws.id,
                idx: ws.idx || 1,
                name: ws.name || "",
                output: ws.output || "",
                isFocused: ws.isFocused === true,
                isActive: ws.isActive === true,
                isUrgent: ws.isUrgent === true,
                isOccupied: ws.isOccupied === true,
            });
        }
        
        workspacesChanged();
    }

    function switchToWorkspace(workspaceId) {    
        if (isHyprland) {
            try {
                Hyprland.dispatch(`workspace ${workspaceId}`);
            } catch (e) {
                console.error("Error switching Hyprland workspace:", e);
            }
        } else if (isNiri) {
            try {
                Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", workspaceId.toString()]);
            } catch (e) {
                console.error("Error switching Niri workspace:", e);
            }
        } else {
            console.warn("No supported compositor detected for workspace switching");
        }
    }
}
