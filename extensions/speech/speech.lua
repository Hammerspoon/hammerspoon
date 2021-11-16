--- === hs.speech ===
---
--- This module provides access to the Speech Synthesizer component of OS X.
---
--- The speech synthesizer functions and methods provide access to OS X's Text-To-Speech capabilities and facilitates generating speech output both to the currently active audio device and to an AIFF file.
---
--- A discussion concerning the embedding of commands into the text to be spoken can be found at https://developer.apple.com/library/mac/documentation/UserExperience/Conceptual/SpeechSynthesisProgrammingGuide/FineTuning/FineTuning.html#//apple_ref/doc/uid/TP40004365-CH5-SW6.  It is somewhat dated and specific to the older MacinTalk style voices, but still contains some information relevant to the more modern higer quality voices as well in its discussion about embedded commands.

--- === hs.speech.listener ===
---
--- This module provides access to the Speech Recognizer component of OS X.
---
--- The speech recognizer functions and methods provide a way to add commands which may be issued to Hammerspoon through spoken words and phrases to trigger a callback.

local module = require("hs.libspeech")

module.listener = require("hs.libspeechlistener")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

-- Return speech Object --------------------------------------------------

return module
