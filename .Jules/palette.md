## 2024-05-20 - Adding ESC Key Closing to WoW Addon Frames
**Learning:** In World of Warcraft addon development, custom UI frames do not close when the user presses the Escape key by default. This creates a frustrating UX where users must manually click the "X" button to close windows, breaking immersion and slowing down interaction.
**Action:** Always add custom window frames to the global `UISpecialFrames` table. This built-in WoW API pattern automatically registers the frame to be hidden when the Escape key is pressed. The frame must have a global name assigned when it is created. Example: `tinsert(UISpecialFrames, myFrame:GetName())`

## 2024-05-20 - Adding Confirmation to Destructive Actions
**Learning:** In WoW addon development, traditional confirmation dialogs often require setting up `StaticPopupDialogs` which can be overly heavyweight for simple actions like resetting a session graph.
**Action:** Use an inline multi-click pattern with `C_Timer` (e.g. changing the button text to "Confirm Reset" and reverting after a few seconds) to gracefully handle destructive action confirmations without interrupting the user's flow with modal dialogs.
