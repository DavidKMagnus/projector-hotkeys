# OBS Projector Hotkeys
Allows the setting of hotkeys to open fullscreen projectors in OBS, and for projectors to be opened to specific windows on startup.

## Limitations
- Due to the limitations of the OBS frontend API, projectors can only be opened and not closed
- Only fullscreen projectors are currently supported
- If the name of a scene changes, the hotkey for that scene will need to be reset

## Acknowledgements
This script is only possible thanks to the work done here:
https://github.com/obsproject/obs-studio/pull/1910/ by https://github.com/Rosuav

Thanks to *bfxdev* for [OBS Lua Tips and Tricks](https://obsproject.com/forum/threads/tips-and-tricks-for-lua-scripts.132256/)

## Configuration
After the script is loaded, the monitor for each output should be selected.
Hotkeys will be avaiable in OBS settings for the Program output, Multiview, and for each scene.