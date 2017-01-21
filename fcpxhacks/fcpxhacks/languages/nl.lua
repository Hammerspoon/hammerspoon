-- LANGUAGE: Dutch
-- AUTHOR: Jan Schoen
return {
	nl = {

		--------------------------------------------------------------------------------
		-- GENERIC:
		--------------------------------------------------------------------------------

			--------------------------------------------------------------------------------
			-- Numbers:
			--------------------------------------------------------------------------------
			one									=			"1",
			two									=			"2",
			three								=			"3",
			four								=			"4",
			five								=			"5",
			six									=			"6",
			seven								=			"7",
			eight								=			"8",
			nine								=			"9",
			ten									=			"10",

			--------------------------------------------------------------------------------
			-- Common Strings:
			--------------------------------------------------------------------------------
			button								=			"Knop",
			options								=			"Keuzes",
			open								=			"Open",
			secs								=
			{
				one								=			"sec",
				other							=			"secs",
			},
			mins								=
			{
				one								=			"min",
				other							=			"mins",
			},
			version								=			"Versie",
			unassigned							=			"Unassigned",
			enabled								=			"Enabled",
			disabled							=			"Disabled",

		--------------------------------------------------------------------------------
		-- DIALOG BOXES:
		--------------------------------------------------------------------------------

			--------------------------------------------------------------------------------
			-- Buttons:
			--------------------------------------------------------------------------------
			ok                                  =             "OK",
			yes                                 =             "Ja",
			no                                  =             "Nee",
			done                                =             "Klaar",
			cancel                              =             "Afbreken",
			buttonContinueBatchExport     	    =             "Ga door met Batch Export",

			--------------------------------------------------------------------------------
			-- Common Error Messages:
			--------------------------------------------------------------------------------
			commonErrorMessageStart             =           "Sorry, de volgende fout is opgetreden:",
			commonErrorMessageEnd               =           "Wilt u deze fout naar Chris e-mailen, zodat hij een oplossing kan vinden?",

			--------------------------------------------------------------------------------
			-- Common Strings:
			--------------------------------------------------------------------------------
			pleaseTryAgain                      =           "Probeert u het alstublieft opnieuw",
			doYouWantToContinue                 =           "Wilt u doorgaan?",

			--------------------------------------------------------------------------------
			-- Notifications:
			--------------------------------------------------------------------------------
			hasLoaded                           =           "Is geladen",
			keyboardShortcutsUpdated            =           "Toetsenbord-shortcuts vernieuwd",
			keywordPresetsSaved                 =           "Uw keywords zijn als preset opgeslagen",
			keywordPresetsRestored              =           "Uw keywords zijn teruggezet naar preset",
			scrollingTimelineDeactivated        =           "Scrollende tijdlijn niet meer actief",
			scrollingTimelineActivated          =           "Scrollende tijdlijn is actief",
			playheadLockActivated               =           "Playhead vergrendeling is actief",
			playheadLockDeactivated             =           "Playhead vergrendeling niet meer actief",
			pleaseSelectSingleClipInTimeline    =           "Selecteer één clip in de tijdlijn.",

			--------------------------------------------------------------------------------
			-- Update Effects List:
			--------------------------------------------------------------------------------
			updateEffectsListWarning            =           "Afhankelijk van het aantal effecten dat u heeft geïnstalleerd kan dit proces enige tijd duren.\n\nWilt u alstublieft uw muis of toetsenbord niet gebruiken totdat u zeker weet dat het hele proces is uitgevoerd.",
			updateEffectsListFailed             =           "Helaas is de Effectenlijst niet succesvol vernieuwd.",
			updateEffectsListDone               =           "Effectenlijst is succesvol vernieuwd.",

			--------------------------------------------------------------------------------
			-- Update Transitions List:
			--------------------------------------------------------------------------------
			updateTransitionsListWarning        =           "Afhankelijk van het aantal transitions dat u heeft geïnstalleerd kan dit proces enige tijd duren.\n\nWilt u alstublieft uw muis of toetsenbord niet gebruiken totdat u zeker weet dat het hele proces is uitgevoerd.",
			updateTransitionsListFailed         =           "Helaas is de transitionslijst niet succesvol vernieuwd.",
			updateTransitionsListDone           =           "transitionslijst is succesvol vernieuwd.",

			--------------------------------------------------------------------------------
			-- Update Titles List:
			--------------------------------------------------------------------------------
			updateTitlesListWarning             =           "Afhankelijk van het aantal titels dat u heeft geïnstalleerd kan dit proces enige tijd duren.\n\nWilt u alstublieft uw muis of toetsenbord niet gebruiken totdat u zeker weet dat het hele proces is uitgevoerd.",
			updateTitlesListFailed              =           "Helaas is de titelslijst niet succesvol vernieuwd.",
			updateTitlesListDone                =           "Titelslijst is succesvol vernieuwd.",

			--------------------------------------------------------------------------------
			-- Update Generators List:
			--------------------------------------------------------------------------------
			updateGeneratorsListWarning         =           "Afhankelijk van het aantal generators dat u heeft geïnstalleerd kan dit proces enige tijd duren.\n\nWilt u alstublieft uw muis of toetsenbord niet gebruiken totdat u zeker weet dat het hele proces is uitgevoerd.",
			updateGeneratorsListFailed          =           "Helaas is de generatorslijst niet succesvol vernieuwd.",
			updateGeneratorsListDone            =           "Generators lijst is succesvol vernieuwd.",

			--------------------------------------------------------------------------------
			-- Assign Shortcut Errors:
			--------------------------------------------------------------------------------
			assignEffectsShortcutError          =           "De Effectenlijst is niet de allernieuwste versie \n\nUpdate alstublieft uw Effectenlijst en probeer het opnieuw ",
			assignTransitionsShortcutError      =           "De Transitionslijst is niet de allernieuwste versie \n\nUpdate alstublieft uw Transitionslijst en probeer het opnieuw.",
			assignTitlesShortcutError           =           "De Titelslijst is niet de allernieuwste versie \n\nUpdate alstublieft uw Titelslijst en probeer het opnieuw.",
			assignGeneratorsShortcutError       =           "De Generatorslijst is niet de allernieuwste versie \n\nUpdate alstublieft uw Generatorslijst en probeer het opnieuw.",

			--------------------------------------------------------------------------------
			-- Error Messages:
			--------------------------------------------------------------------------------
			wrongHammerspoonVersionError		=			"FCPX Hacks requires Hammerspoon %{version} or later.\n\nPlease download the latest version of Hammerspoon and try again.",

			noValidFinalCutPro                  =           "FCPX Hacks kan op deze computer geen geschikte versie van Final Cut Pro vinden\n\nkijkt u alstublieft of Final Cut Pro 10.2.3, 10.3 of een hogere versie is geïnstalleerd in the hoofdmap van de Programmafolder en geen andere naam heeft gekregen dan ’Final Cut Pro'.\n\nHammerspoon wordt nu gestopt.",
			missingFiles                        =           "FCPX Hacks mist een aantal noodzakelijke files.\n\nWilt u alstublieft proberen om opnieuw de laatste versie van FCPX Hacks te downloaden van de website en volg de installatie-instructies zorgvuldig op.\n\nHammerspoon wordt nu gestopt.",

			customKeyboardShortcutsFailed       =           "Tijdens het uitlezen van uw eigen toetsenbord-shortcuts ging er iets mis\n\nAs werd niet opgeslagen, sorry, de standaard toetsenbord-shortcuts zullen nu worden gebruikt  ",

			newKeyboardShortcuts                =           "Deze laatste versie van FCPX Hacks heeft mogelijk nieuwe toetsenbord-shortcuts.\n\nOm deze shortcuts te tonen in De Final Cut Pro Commando Editor, moeten de shortcut files worden ge-updated.\n\n U moet uw beheerderswachtwoord invoeren.",
			newKeyboardShortcutsRestart         =           "Deze laatste versie van FCPX Hacks heeft mogelijk nieuwe toetsenbord-shortcuts.\n\nOm deze shortcuts te tonen in De Final Cut Pro Commando Editor, moeten de shortcut files worden ge-updated.\n\n U moet uw beheerderswachtwoord invoeren en Final Cut Pro opnieuw opstarten.",

			prowlError                          =           "De Prowl API Sleutel is niet geldig als gevolg van  de volgende fout:",

			sharedClipboardFileNotFound         =           "De Gedeelde Clipboard file kon niet worden gevonden.",
			sharedClipboardNotRead              =           "De Gedeelde Clipboard file kon niet worden gelezen.",

			restartFinalCutProFailed            =           "We waren niet in staat om Final Cut Pro te herstarten.\n\nWilt a.u.b zelf Final Cut Pro handmatig herstarten.",

			keywordEditorAlreadyOpen            =           "Deze shortcut kan alleen worden gebruikt waneer de toetsenbord Editor  open is.\n\nOpen a.u.b. de Toetsenbord Editor en probeer het opnieuw.",
			keywordShortcutsVisibleError        =           "Zorg er a.u.b. voor dat de Toetsenbord Shortcuts zichtbaar zijn voordat u deze voorziening gebruikt.",
			noKeywordPresetsError               =           "Het lijkt er op dat u tot dusver geen keyword instelling heeft opgeslagen?",
			noKeywordPresetError                =           "Het lijkt er op dat u niets heeft opgeslagen van deze keyword instelling?",

			noTransitionShortcut                =           "Er is geen Transition gekoppeld aan deze shortcut.\n\nU kunt Transitions koppelen aan shortcuts via de FCPX Hacks menu bar.",
			noEffectShortcut                    =           "Er is geen Effect gekoppeld aan deze shortcut.\n\nU kunt Effects koppelen aan shortcuts via de FCPX Hacks menu bar.",
			noTitleShortcut                     =           "Er is geen Title gekoppeld aan deze shortcut.\n\nU kunt Titles koppelen aan shortcuts via de FCPX Hacks menu bar.",
			noGeneratorShortcut                 =           "Er is geen Generator gekoppeld aan deze shortcut.\n\nU kunt Generators koppelen aan shortcuts via de FCPX Hacks menu bar.",

			touchBarError                       =           "Touch Bar ondersteuning  vereist macOS 10.12.1 (Build 16B2657) of hoger.\n\nUpdate a.u.b. macOS en probeer het opnieuw.",

			item								=
			{
				one								=			"item",
				other							=			"items"
			},

			batchExportDestinationsNotFound		=	"We kunnen de lijst met gedeelde lokaties niet vinden.",
			batchExportNoDestination		=	"Blijkbaar heeft u geen standaard lokatie ingesteld.\n\nU kunt een standaardlokatie instellen door naar ‘Preferences’ te gaan, klik op de 'Destinations' tab, klik dan met de rechtermuisknop ingedrukt op de te kiezen lokatie en klik op ‘Make Default’.\n\nU kunt een Batch Export Lokatie preset instellen via de FCP Hacks menubar.",
			batchExportEnableBrowser		=	"Zorg er a.u.b. voor dat de browser is ingeschakeld vóór het  exporteren.",
			batchExportCheckPath				=			"Final Cut Pro will export the%{count}selected %{item} to the following location:\n\n\t%{path}\n\nUsing the following preset:\n\n\t%{preset}\n\nIf the preset is adding the export to an iTunes Playlist, the Destination Folder will be ignored. %{replace}\n\nYou can change these settings via the FCPX Hacks Menubar Preferences.\n\nPlease do not interrupt Final Cut Pro once you press the Continue button as it may break the automation.",
			batchExportCheckPathSidebar			=			"Final Cut Pro will export all items in the selected containers to the following location:\n\n\t%{path}\n\nUsing the following preset:\n\n\t%{preset}\n\nIf the preset is adding the export to an iTunes Playlist, the Destination Folder will be ignored. %{replace}\n\nYou can change these settings via the FCPX Hacks Menubar Preferences.\n\nPlease do not interrupt Final Cut Pro once you press the Continue button as it may break the automation.",
			batchExportReplaceYes				=			"Exports met dezelfde filenamen with duplicate filenames will be replaced.",
			batchExportReplaceNo				=			"Exports with duplicate filenames will be incremented.",
			batchExportNoClipsSelected			="Zorg er a.u.b. voor dat tenminste 1 clip voor export is geselecteerd.",
			batchExportComplete				="Batch Export is nu compleet. De geselecteerde clips zijn toegevoegd aan uw render wachtrij.",

			activeCommandSetError               =           "Er ging iets mis tijdens het uitlezen van de Huidige Command Set.",
			failedToWriteToPreferences          =           "Het lukte niet om data weg te schrijven naar de Final Cut Pro Preferences file.",
			failedToReadFCPPreferences          =           "Het lukte niet om de Final Cut Pro Preferences uit te lezen",
			failedToChangeLanguage              =           "Het lukte niet om de taalversie van Final Cut Pro' te veranderen.",
			failedToRestart                     =           "Het lukte niet om Final Cut Pro te herstarten. U moet Final Cut Pro handmatig opnieuw herstarten.",

			backupIntervalFail                  =           "Het lukte niet om de Backup Interval weg te schrijven naar de Final Cut Pro Preferences file.",

			voiceCommandsError 					= 			"Voice Commands could not be activated.\n\nPlease try again.",

			--------------------------------------------------------------------------------
			-- Yes/No Dialog Boxes:
			--------------------------------------------------------------------------------
			changeFinalCutProLanguage           =           "Om de Taalversie van FCP X te veranderen moet FCP opnieuw opgestart worden.",
			changeBackupIntervalMessage         =           "Om de Backup Interval van FCP X te veranderen moet FCP opnieuw opgestart worden.",
			changeSmartCollectionsLabel         =           "Om het Smart Collections Label van FCP X te veranderen moet FCP opnieuw opgestart worden..",

			hacksShortcutsRestart               =           "Hacks Shortcuts in Final Cut Pro Heeft uw beheerderspaswoord nodig en om effectief te zijn moet FCP ook opnieuw worden opgestart.",
			hacksShortcutAdminPassword          =           "Hacks Shortcuts in Final Cut Pro Heeft uw beheerderspaswoord nodig.",

			togglingMovingMarkersRestart        =           "Om te bewegen Markers te activeren moet FCP opnieuw worden opgestart.",
			togglingBackgroundTasksRestart      =           "Om achtergrondtaken uit voeren tijdens weergave’ te activeren moet Final Cut Pro opnieuw worden opgestart.",
			togglingTimecodeOverlayRestart      =           "Om Timecode Overlays te activeren moet FCP opnieuw worden opgestart.",

			trashFCPXHacksPreferences           =           "Weet u zeker dat u de FCPX Hacks Preferences wilt verwijderen?",
			adminPasswordRequiredAndRestart     =           "Hiervoor heeft u uw beheerderswachtwoord nodig en moet Final Cut Pro opnieuw worden opgestart.",
			adminPasswordRequired               =           "Hiervoor heeft u uw beheerderswachtwoord nodig.",

			--------------------------------------------------------------------------------
			-- Textbox Dialog Boxes:
			--------------------------------------------------------------------------------
			smartCollectionsLabelTextbox        =           "Hoe wilt u uw  Smart Collections Label benoemen:",
			smartCollectionsLabelError          =           "De Smart Collections Label die u invoerde is niet geldig.\n\nGebruikt u alstublieft alleen standaard letters en cijfers.",

			changeBackupIntervalTextbox         =           "Op welke waarde (in minuten) wilt u Final Cut Pro Backup Interval zetten?",
			changeBackupIntervalError           =           "De backup interval die u heeft ingevoerd is niet geldig. Voer aub een waarde in minuten in.",

			selectDestinationPreset				=			"Please select a Destination Preset:",
			selectDestinationFolder				=			"Please select a Destination Folder:",

			--------------------------------------------------------------------------------
			-- Mobile Notifications
			--------------------------------------------------------------------------------
			iMessageTextBox						=			"Please enter the phone number or email address registered with iMessage to send the message to:",
			prowlTextbox						=			"Please enter your Prowl API key below.\n\nIf you don't have one you can register for free at prowlapp.com.",
			prowlTextboxError 					=			"The Prowl API Key you entered is not valid.",

			shareSuccessful 					=			"Share Successful\n%{info}",
			shareFailed							=			"Share Failed",
			shareUnknown						=			"Type: %{type}",
			shareDetails_export					=			"Type: Local Export\nLocation: %{result}",
			shareDetails_youtube				=			"Type: YouTube\nLogin: %{login}\nTitle: %{title}",
			shareDetails_Vimeo					=			"Type: Vimeo\nLogin: %{login}\nTitle: %{title}",
			shareDetails_Facebook				=			"Type: Facebook\nLogin: %{login}\nTitle: %{title}",
			shareDetails_Youku					=			"Type: Youku\nLogin: %{login}\nTitle: %{title}",
			shareDetails_Tudou					=			"Type: Tudou\nLogin: %{login}\nTitle: %{title}",


		--------------------------------------------------------------------------------
		-- MENUBAR:
		--------------------------------------------------------------------------------

			--------------------------------------------------------------------------------
			-- Update:
			--------------------------------------------------------------------------------
			updateAvailable                     =           "Update Beschikbaar",

			--------------------------------------------------------------------------------
			-- Keyboard Shortcuts:
			--------------------------------------------------------------------------------
			displayKeyboardShortcuts            =           "Toon Keyboard Shortcuts",
			openCommandEditor                   =           "Open Commandos Editer",

			--------------------------------------------------------------------------------
			-- Shortcuts:
			--------------------------------------------------------------------------------
			shortcuts                           =           "Shortcuts",
			createOptimizedMedia                =           "Creëer Optimized Media",
			createMulticamOptimizedMedia        =           "Creëer Multicam Optimized Media",
			createProxyMedia                    =           "Creëer Proxy Media",
			leaveFilesInPlaceOnImport           =           "Verplaats Files niet bij Import",
			enableBackgroundRender              =           "Sta Achtergrond Rendering Toe",

			--------------------------------------------------------------------------------
			-- Automation:
			--------------------------------------------------------------------------------
			automation                          =           "Automatisering",
			assignEffectsShortcuts              =           "Stel Effects Shortcuts In",
			assignTransitionsShortcuts          =           "Stel Transitions Shortcuts In",
			assignTitlesShortcuts               =           "Stel Titles Shortcuts In",
			assignGeneratorsShortcuts           =           "Stel Generators Shortcuts In",

				--------------------------------------------------------------------------------
				-- Effects Shortcuts:
				--------------------------------------------------------------------------------
				updateEffectsList               =           "Update Effects Lijst",
				effectShortcut                  =           "Effect Shortcut",

				--------------------------------------------------------------------------------
				-- Transitions Shortcuts:
				--------------------------------------------------------------------------------
				updateTransitionsList           =           "Update Transitions Lijst",
				transitionShortcut              =           "Transition Shortcut",

				--------------------------------------------------------------------------------
				-- Titles Shortcuts:
				--------------------------------------------------------------------------------
				updateTitlesList                =           "Update Titles Lijst",
				titleShortcut                   =           "Title Shortcut",

				--------------------------------------------------------------------------------
				-- Generators Shortcuts:
				--------------------------------------------------------------------------------
				updateGeneratorsList            =           "Update Generators Lijst",
				generatorShortcut               =           "Generator Shortcut",

				--------------------------------------------------------------------------------
				-- Automation Options:
				--------------------------------------------------------------------------------
				enableScrollingTimeline         =           "Zet Scrolling Timeline Aan",
				enableTimelinePlayheadLock      =           "Zet Timeline Playhead Blokkering Aan",
				enableShortcutsDuringFullscreen =           "Zet Shortcuts Tijdens Weergave van het volledige scherm Aan",
				closeMediaImport                =           "Sluit Media Import Als Een Kaart is aangesloten",

			--------------------------------------------------------------------------------
			-- Tools:
			--------------------------------------------------------------------------------
			tools                               =           "Gereedschap",
			importSharedXMLFile                 =           "Import Gedeelde XML File",
			pasteFromClipboardHistory           =           "Plak vanuit Clipboard Historie",
			pasteFromSharedClipboard            =           "Plak vanuit Gedeelde Clipbord",
			finalCutProLanguage                 =           "Final Cut Pro Taal",
			assignHUDButtons                    =           "Stel HUD Knoppen In",

				--------------------------------------------------------------------------------
				-- Languages:
				--------------------------------------------------------------------------------
				german                          =           "Duits",
				english                         =           "Engels",
				spanish                         =           "Spaans",
				french                          =           "Frans",
				japanese                        =           "Japans",
				chineseChina                    =           "Chinees (China)",

				--------------------------------------------------------------------------------
				-- Tools Options:
				--------------------------------------------------------------------------------
				enableTouchBar                  =           "Zet TouchBar Aan",
				enableHacksHUD                  =           "Zet Hacks Scherm Aan",
				enableMobileNotifications       =           "Zet Mobiele Meldingen Aan",
				enableClipboardHistory          =           "Zet Clipboard History Aan",
				enableSharedClipboard           =           "Zet Gedeeld Clipboard Aan",
				enableXMLSharing                =           "Zet XML Deling Aan",
				enableVoiceCommands				=			"Enable Voice Commands",

		--------------------------------------------------------------------------------
    	-- Hacks:
    	--------------------------------------------------------------------------------
		hacks                                   =           "Hacks",
		advancedFeatures                        =           "Uitgebreide Functies",

			--------------------------------------------------------------------------------
			-- Advanced:
			--------------------------------------------------------------------------------
			enableHacksShortcuts                =           "Zet Hacks Shortcuts in Final Cut Pro Aan",
			enableTimecodeOverlay               =           "Zet Tijdcode in Beeld Aan",
			enableMovingMarkers                 =           "Zet Verplaats Markers Aan",
			enableRenderingDuringPlayback       =           "Zet Rendering Gedurende Playback Aan",
			changeBackupInterval                =           "Verander Backup Interval",
			changeSmartCollectionLabel          =           "Verander Smart Collections Label",

		--------------------------------------------------------------------------------
    	-- Preferences:
    	--------------------------------------------------------------------------------
		preferences                             =           "Voorkeuren",
		quit                                    =           "Stop",

			--------------------------------------------------------------------------------
			-- Preferences:
			--------------------------------------------------------------------------------
			batchExportOptions					=			"Batch Export Options",
			menubarOptions                      =           "Menubar Opties",
			hudOptions                          =           "HUD Opties",
			voiceCommandOptions					=			"Voice Command Options",
			touchBarLocation                    =           "Touch Bar Lokatie",
			highlightPlayheadColour             =           "Accentueer Playhead Kleur",
			highlightPlayheadShape              =           "Accentueer Playhead Vorm",
			highlightPlayheadTime				=			"Highlight Playhead Time",
			language							=			"Language",
			enableDebugMode                     =           "Maak Debug Modus mogelijk",
			trachFCPXHacksPreferences           =           "Verwijder FCPX Hacks Voorkeuren",
			provideFeedback                     =           "Geef Respons",
			createdBy                           =           "Gemaakt door",
			scriptVersion                       =           "Script Versie",

			--------------------------------------------------------------------------------
			-- Notification Platform:
			--------------------------------------------------------------------------------
			iMessage							=			"iMessage",
			prowl								=			"Prowl",

			--------------------------------------------------------------------------------
			-- Batch Export Options:
			--------------------------------------------------------------------------------
			setDestinationPreset	 			=			"Set Destination Preset",
			setDestinationFolder				=			"Set Destination Folder",
			replaceExistingFiles				=			"Replace Existing Files",

			--------------------------------------------------------------------------------
			-- Menubar Options:
			--------------------------------------------------------------------------------
			showShortcuts                       =           "Toon Shortcuts",
			showAutomation                      =           "Toon Automatisering",
			showTools                           =           "Toon Gereedschap",
			showHacks                           =           "Toon Hacks",
			displayProxyOriginalIcon            =           "Geef Proxy/Origineel weer als Icon",
			displayThisMenuAsIcon               =           "Geef Dit Menu weer als Icon",

			--------------------------------------------------------------------------------
			-- HUD Options:
			--------------------------------------------------------------------------------
			showInspector                       =           "Toon Inspector",
			showDropTargets                     =           "Toon Plaats Targets",
			showButtons                         =           "Toon Knoppen",

			--------------------------------------------------------------------------------
			-- Voice Command Options:
			--------------------------------------------------------------------------------
			enableAnnouncements					=			"Enable Announcements",
			enableVisualAlerts					=			"Enable Visual Alerts",
			openDictationPreferences			=			"Open Dictation Preferences...",

			--------------------------------------------------------------------------------
			-- Touch Bar Location:
			--------------------------------------------------------------------------------
			mouseLocation                       =           "Muis Positie",
			topCentreOfTimeline                 =           "Boven het midden van de tijdlijn",
			touchBarTipOne                      =           "TIP: druk links OPTION",
			touchBarTipTwo                      =           "key &amp; sleep om het Venster (Touch Bar) te bewegen.",

			--------------------------------------------------------------------------------
			-- Highlight Colour:
			--------------------------------------------------------------------------------
			red                                 =           "Rood",
			blue                                =           "Blauw",
			green                               =           "Groen",
			yellow                              =           "Geel",
			custom								=			"Custom",

			--------------------------------------------------------------------------------
			-- Highlight Shape:
			--------------------------------------------------------------------------------
			rectangle                           =           "Rechthoek",
			circle                              =           "Cirkel",
			diamond                             =           "Diamant",

			--------------------------------------------------------------------------------
			-- Hammerspoon Settings:
			--------------------------------------------------------------------------------
			console                             =           "Console",
			showDockIcon                        =           "Toon Dock Icon",
			showMenuIcon                        =           "Toon Menu Icon",
			launchAtStartup                     =           "Start bij Opstarten",
			checkForUpdates                     =           "Controleer op Updates",

	--------------------------------------------------------------------------------
	-- VOICE COMMANDS:
	--------------------------------------------------------------------------------
	keyboardShortcuts					=			"Keyboard Shortcuts",
	scrollingTimeline					=			"Scrolling Timeline",
	highlight							=			"Highlight",
	reveal								=			"Reveal",
	play								=			"Play",
	lane								=			"Lane",

	--------------------------------------------------------------------------------
	-- HACKS HUD:
	--------------------------------------------------------------------------------
	hacksHUD							=			"Hacks HUD",
	originalOptimised					=			"Original/Optimised",
	betterQuality						=			"Better Quality",
	betterPerformance					=			"Better Performance",
	proxy								=			"Proxy",
	hudDropZoneText						=			"Drag from Browser to Here",
	hudDropZoneError					=			"Ah, I'm not sure what you dragged here, but it didn't look like FCPXML?",
	hudButtonError						=			"There is currently no action assigned to this button.\n\nYou can allocate a function to this button via the FCPX Hacks menubar.",
	hudXMLNameDialog					=			"How would you like to label this XML file?",
	hudXMLNameError						=			"The label you entered has special characters that cannot be used.\n\nPlease try again.",
	hudXMLSharingDisabled				=			"XML Sharing is currently disabled.\n\nPlease enable it via the FCPX Hacks menu and try again.",

	--------------------------------------------------------------------------------
	-- CONSOLE:
	--------------------------------------------------------------------------------
	highlightedItem						=			"Highlighted Item",
	removeFromList						=			"Remove from List",
	mode								=			"Mode",
	normal								=			"Normal",
	removeFromList						=			"Remove from List",
	restoreToList						=			"Restore to List",
	displayOptions						=			"Display Options",
	showNone							=			"Show None",
	showAll								=			"Show All",
	showAutomation						=			"Show Automation",
	showHacks							=			"Show Hacks",
	showShortcuts						=			"Show Shortcuts",
	showVideoEffects					=			"Show Video Effects",
	showAudioEffects					=			"Show Audio Effects",
	showTransitions						=			"Show Transitions",
	showTitles							=			"Show Titles",
	showGenerators						=			"Show Generators",
	showMenuItems						=			"Show Menu Items",
	rememberLastQuery					=			"Remember Last Query",
	update								=			"Update",
	effectsShortcuts					=			"Effects Shortcuts",
	transitionsShortcuts				=			"Transitions Shortcuts",
	titlesShortcuts						=			"Titles Shortcuts",
	generatorsShortcuts					=			"Generators Shortcuts",
	menuItems							=			"Menu Items",

	}
}
