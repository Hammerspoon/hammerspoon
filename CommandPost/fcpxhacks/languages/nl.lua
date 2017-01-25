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
			wrongHammerspoonVersionError		=			"FCPX Hacks werkt met Hammerspoon %{version}of hoger.\n\nDownload U a.u.b. de laatste versie van Hammerspoon en probeer het opnieuw.",

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
				other							=			"items",
			},

			batchExport 						=			"We zijn niet in staat om de lijst met gedeelde bestemmingen te vinden.",
			batchExportNoDestination			=			"IHet schijnt dat u geen standaardbestemmingt heeft gekozen.\n\nU kunt een standaardbestemming kiezen door naar 'Preferences' te gaan, klik op de 'Destinations'  knop , dan rechts klikkend op de bestemming die u wilt kiezen en  klik dan op 'Make Default'Y'.\n\nU kunt een Batch Export bestemming instellen via De FCPX Hacks menubar.",
			batchExportEnableBrowser			=			"Let a.u.b. op voordat  u exporteert dat de browser is ingeschakeld.",
			batchExportCheckPath				=			"Final Cut Pro exporteert de %{count}geselecteerde %{item} naar de volgende lokatie:\n\n\t%{path}\n\ngebruik makend van de volgende preset:\n\n\t%{preset}\n\nAls de preset de export toevoegt aan een iTunes speellijst zal de bestemmingsfolder worden genegeerd. %{replace}\n\nU kunt deze instellingen veranderen via CPX Hacks Menubar preferences.\n\nOnderbreekt u a.u.b. FCP X niet nadat u de ‘Continue’ knop heeft ingedrukt omdat de automatisering dan kan worden onderbroken.",
			batchExportCheckPathSidebar			=			"Final Cut Pro zal alle items in de geselecteerde mappen exporteren naar de volgende lokatie:\n\n\t%{path}\n\ngebruik makend van de volgende preset:\n\n\t%{preset}\n\nAls de preset de export toevoegt aan een iTunes speellijst zal de bestemmingsfolder worden genegeerd. %{replace}\n\nU kunt deze instellingen veranderen via de FCPX Hacks menubar.\n\nOnderbreekt u a.u.b. FCP X niet nadat u de ‘Continue’ knop heeft ingedrukt omdat de automatisering dan kan worden onderbroken.",
			batchExportReplaceYes				=			"Exports met dezelfde filenamen zullen worden vervangen.",
			batchExportReplaceNo				=			"Exports met dezelfde filenamen zullen worden toegevoegd.",
			batchExportNoClipsSelected			=			"Zorg er a.u.b. voor dat tenminste een clip is geselecteerd voor export.",
			batchExportComplete					=			"Batch Export is nu  geheel uitgevoerd. De geselecteerd clips zijn toegevoegd aan uw render-wachtrij.",

			activeCommandSetError               =           "Er ging iets mis tijdens het uitlezen van de Huidige Command Set.",
			failedToWriteToPreferences          =           "Het lukte niet om data weg te schrijven naar de Final Cut Pro Preferences file.",
			failedToReadFCPPreferences          =           "Het lukte niet om de Final Cut Pro Preferences uit te lezen",
			failedToChangeLanguage              =           "Het lukte niet om de taalversie van Final Cut Pro' te veranderen.",
			failedToRestart                     =           "Het lukte niet om Final Cut Pro te herstarten. U moet Final Cut Pro handmatig opnieuw herstarten.",

			backupIntervalFail                  =           "Het lukte niet om de Backup Interval weg te schrijven naar de Final Cut Pro Preferences file.",

			voiceCommandsError 					= 			"Voice Commands could not be activated.\n\nProbeer het a.u.b. opnieuw.",

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

			selectDestinationPreset				=			"Selecteer een bestemmings-preset:",
			selectDestinationFolder				=			"Selecteer a.u.b. een bestemmingsfolder:",

			--------------------------------------------------------------------------------
			-- Mobile Notifications
			--------------------------------------------------------------------------------
			iMessageTextBox						=			"Voer, om een bericht te sturen,  a.u.b. een telefoonnummer of e-mailadres in,  dat bekend is bij iMessage:",
			prowlTextbox						=			"Voer hieronder a.u.b. uw Prowl API sleutel in .\n\nAls u geen sleutel heeft registreer dan gratis bij prowlapp.com.",
			prowlTextboxError 					=			"De Prowl API sleutel die u heeft ingevoerd is niet geldig.",

			shareSuccessful 					=			"Share geslaagd\n%{info}",
			shareFailed							=			"Share niet gelukt",
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
			setDestinationPreset	 			=			"Stel Destination Preset in",
			setDestinationFolder				=			"Stel Destination Folder in",
			replaceExistingFiles				=			"Vervang bestaande Files",

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
			enableAnnouncements					= 			"Schakel berichten in",
			enableVisualAlerts					=			"schakel Visuele Alerts in",
			openDictationPreferences			=			"Open spraak Idictations) Preferences...",

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
			custom								=			"Standaard",

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
	reveal								=			"Toon",
	play								=			"Play",
	lane								=			"Lane",

	--------------------------------------------------------------------------------
	-- HACKS HUD:
	--------------------------------------------------------------------------------
	hacksHUD							=			"Hacks HUD",
	originalOptimised					=			"Origineell/Optimaal gemaakt",
	betterQuality						=			"Betere kwaliteit",
	betterPerformance					=			"Betere weergave",
	proxy								=			"Proxy",
	hudDropZoneText						=			"Drag from Browser to Here",
	hudDropZoneError					=			"Ah, ik weet precies wat u hierheen gesleept heeft, maar het is geen FCPXML?",
	hudButtonError						=			"Er is momenteel geen functie  toegevoegd aan deze knop.\n\nU kunt een functie aan deze knop via  de FCPX Hacks menubar toewijzen.",
	hudXMLNameDialog					=			"Hoe wilt u deze XML file labelen?",
	hudXMLNameError						=			"The label you entered has special characters that cannot be used.\n\nProbeert u het a.u.b. opnieuw.",
	hudXMLSharingDisabled				=			"XML deling  is op dit moment niet actief .\n\nActiveert u dit a.u.b. via  het FCPX Hacks menu en probeer het opnieuw.",

	--------------------------------------------------------------------------------
	-- CONSOLE:
	--------------------------------------------------------------------------------
	highlightedItem						=			"Accentueer Item",
	removeFromList						=			"Verwijder van de lijst",
	mode								=			"Mode",
	normal								=			"Normaal",
	removeFromList						=			"Verwijder van de lijst",
	restoreToList						=			"Herstel naar lijstt",
	displayOptions						=			"Geef keuzes weer",
	showNone							=			"Toon niets",
	showAll								=			"Toon alles",
	showAutomation						=			"Toon Automation",
	showHacks							=			"Toon Hacks",
	showShortcuts						=			"Toon Shortcuts",
	showVideoEffects					=			"Toon Video Effects",
	showAudioEffects					=			"Toon Audio Effects",
	showTransitions						=			"Toon Transitions",
	showTitles							=			"Toon Titles",
	showGenerators						=			"Toon Generators",
	showMenuItems						=			"Toon Menu Items",
	rememberLastQuery					=			"Onthoud de laatste wachtrij",
	update								=			"Update",
	effectsShortcuts					=			"Effects Shortcuts",
	transitionsShortcuts				=			"Transitions Shortcuts",
	titlesShortcuts						=			"Titles Shortcuts",
	generatorsShortcuts					=			"Generators Shortcuts",
	menuItems							=			"Menu Items",

	}
}