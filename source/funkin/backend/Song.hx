package funkin.backend;

class Song
{
	/**
	 * Loads a chart and converts Codename Engine, V-Slice, Psych, and legacy charts.
	 * @param songName String (The Name Of The Song)
	 * @param songDifficulty String (The Difficulty Of The Song)
	 * @return Chart
	 */
	public static inline function loadSong(songName:String, songDifficulty:String = "hard"):Chart
	{
		var finalChart:Chart = {
			bpm: 0,
			format: "HSlice Format",
			events: [],
			stage: "",
			strumLines: [
				{
					notes: [],
					cpu: true,
					position: [50, 50],
					characters: [],
					charPosition: "opponent",
					scrollSpeed: 1
				},
				{
					notes: [],
					cpu: false,
					position: [690, 50],
					characters: [],
					charPosition: "player",
					scrollSpeed: 1
				},
				{
					notes: [],
					cpu: true,
					position: [1380, 50],
					characters: [],
					charPosition: "spectator",
					scrollSpeed: 1
				}
			]
		};

		var chartPath:String = 'songs/$songName/charts';
		var songJson:Dynamic = Paths.exists('$chartPath/$songDifficulty.json') ? Paths.json('$chartPath/$songDifficulty') : Paths.json('$chartPath/chart');

		if (songJson.format != null && songJson.format == "HSlice Format")
		{ // HSlice / Better Than VSlice
			finalChart = songJson;
		}
		else if (songJson.generatedBy != null && cast(songJson.generatedBy, String).contains("Friday Night Funkin'"))
		{ // VSlice chart
			var metadata:Dynamic = Paths.json('$chartPath/metadata');
			var playData:Dynamic = metadata.playData;
			var timeChanges:Array<Dynamic> = cast metadata.timeChanges;

			if (timeChanges == null || timeChanges.length == 0)
				throw 'V-Slice chart for "$songName" is missing metadata time changes.';

			finalChart.bpm = timeChanges[0].bpm;
			var previousBpm:Float = finalChart.bpm;
			for (i in 1...timeChanges.length)
			{
				var timeChange:Dynamic = timeChanges[i];
				if (timeChange.bpm != previousBpm)
				{
					finalChart.events.push({
						time: timeChange.t,
						name: "Change BPM",
						values: [timeChange.bpm]
					});
					previousBpm = timeChange.bpm;
				}
			}

			var characters:Dynamic = playData != null ? playData.characters : null;
			if (characters != null)
			{
				if (characters.opponent != null)
					finalChart.strumLines[0].characters.push(characters.opponent);
				if (characters.player != null)
					finalChart.strumLines[1].characters.push(characters.player);
				if (characters.girlfriend != null)
					finalChart.strumLines[2].characters.push(characters.girlfriend);
			}
			finalChart.stage = playData.stage;

			var scrollSpeeds:Dynamic = songJson.scrollSpeed;
			var scrollSpeed:Float = scrollSpeeds != null
				&& Reflect.field(scrollSpeeds, songDifficulty) != null ? Reflect.field(scrollSpeeds, songDifficulty) : 1;
			for (strum in finalChart.strumLines)
				strum.scrollSpeed = scrollSpeed;

			var difficultyNotes:Dynamic = songJson.notes != null ? Reflect.field(songJson.notes, songDifficulty) : null;
			if (difficultyNotes == null)
				throw 'V-Slice chart for "$songName" has no notes for difficulty "$songDifficulty".';

			for (sourceNote in (cast difficultyNotes : Array<Dynamic>))
			{
				var lane:Int = Std.int(sourceNote.d);
				var isOpponent:Bool = lane >= 4;
				var note:NoteData = {
					time: sourceNote.t,
					direction: isOpponent ? lane - 4 : lane,
					sustainLength: sourceNote.l != null ? sourceNote.l : 0,
					type: sourceNote.k != null && sourceNote.k != "" ? sourceNote.k : "default"};

				finalChart.strumLines[isOpponent ? 0 : 1].notes.push(note);
			}

			if (songJson.events != null)
			{
				for (sourceEvent in (cast songJson.events : Array<Dynamic>))
				{
					switch sourceEvent.e
					{
						case "FocusCamera":
							var values:Dynamic = sourceEvent.v;
							finalChart.events.push({
								time: sourceEvent.t,
								name: "Camera Target",
								values: [
									values.char == 1 ? 0 : 1,
									values.ease,
									values.easeDir,
									values.duration,
									values.x,
									values.y
								]
							});
						case "ZoomCamera":
							var values:Dynamic = sourceEvent.v;
							finalChart.events.push({
								time: sourceEvent.t,
								name: "Camera Zoom",
								values: [values.zoom, values.duration, values.ease, values.easeDir, values.mode]
							});
						case "SetCameraBop":
							var values:Dynamic = sourceEvent.v;
							finalChart.events.push({
								time: sourceEvent.t,
								name: "Camera Beat Interval Change",
								values: [values.intensity, values.rate]
							});
						default:
							finalChart.events.push({
								time: sourceEvent.t,
								name: sourceEvent.e,
								values: [sourceEvent.v]
							});
					}
				}
			}
		} else if (songJson.codenameChart == true) { // Codename/CNE Charts
			var metadata:Dynamic = songJson.meta;
			if (metadata == null || metadata.bpm == null || metadata.bpm <= 0)
			{
				var metadataPaths:Array<String> = [
					'songs/$songName/data/meta'
				];
				for (metadataPath in metadataPaths)
				{
					if (Paths.exists('$metadataPath.json'))
					{
						metadata = Paths.json(metadataPath);
						if (metadata != null && metadata.bpm != null && metadata.bpm > 0)
							break;
					}
				}
			}
			if (metadata == null || metadata.bpm == null || metadata.bpm <= 0)
				throw 'Codename Engine chart for "$songName" is missing a valid metadata BPM. Expected bpm in chart meta or songs/$songName/meta.json.';
			if (!Std.isOfType(songJson.strumLines, Array) || songJson.strumLines.length == 0)
				throw 'Codename Engine chart for "$songName" is missing strum lines.';

			finalChart.format = "Codename Engine";
			finalChart.bpm = metadata.bpm;
			finalChart.stage = songJson.stage != null ? songJson.stage : "";

			var chartScrollSpeed:Float = songJson.scrollSpeed != null ? songJson.scrollSpeed : 1;
			if (songJson.noteTypes != null && !Std.isOfType(songJson.noteTypes, Array))
				throw 'Codename Engine chart for "$songName" has an invalid note types list.';
			var noteTypes:Array<Dynamic> = songJson.noteTypes != null ? cast songJson.noteTypes : [];
			var sourceStrumLines:Array<Dynamic> = cast songJson.strumLines;
			finalChart.strumLines = [];

			for (sourceLine in sourceStrumLines)
			{
				if (sourceLine == null || sourceLine.type == null || !Std.isOfType(sourceLine.notes, Array))
					throw 'Codename Engine chart for "$songName" contains an invalid strum line.';
				if (sourceLine.characters != null && !Std.isOfType(sourceLine.characters, Array))
					throw 'Codename Engine chart for "$songName" contains an invalid character list.';

				var cpu:Bool;
				var defaultCharacterPosition:String;
				switch Std.int(sourceLine.type)
				{
					case 0:
						cpu = true;
						defaultCharacterPosition = "opponent";
					case 1:
						cpu = false;
						defaultCharacterPosition = "player";
					case 2:
						cpu = true;
						defaultCharacterPosition = "opponent";
					default:
						throw 'Codename Engine chart for "$songName" contains unsupported strum line type ${sourceLine.type}.';
				}

				var sourceCharacterPosition:String = sourceLine.position;
				var characterPosition:String = sourceCharacterPosition == "player" || sourceCharacterPosition == "opponent"
					? sourceCharacterPosition : defaultCharacterPosition;
				var line:LineData = {
					notes: [],
					cpu: cpu,
					position: [cpu ? 50 : 690, 50],
					characters: sourceLine.characters != null ? cast sourceLine.characters : [],
					charPosition: characterPosition,
					scrollSpeed: sourceLine.scrollSpeed != null ? sourceLine.scrollSpeed : chartScrollSpeed
				};

				for (sourceNote in (cast sourceLine.notes : Array<Dynamic>))
				{
					if (sourceNote == null || sourceNote.time == null || sourceNote.id == null)
						throw 'Codename Engine chart for "$songName" contains an invalid note.';

					var direction:Int = Std.int(sourceNote.id);
					if (direction < 0 || direction > 3)
						throw 'Codename Engine chart for "$songName" uses unsupported lane $direction; this game supports four lanes.';

					var noteType:String = "default";
					var noteTypeIndex:Int = sourceNote.type != null ? Std.int(sourceNote.type) : 0;
					if (noteTypeIndex < 0)
						throw 'Codename Engine chart for "$songName" contains invalid note type $noteTypeIndex.';
					if (noteTypeIndex > 0)
					{
						if (noteTypeIndex > noteTypes.length)
							throw 'Codename Engine chart for "$songName" references missing note type $noteTypeIndex.';
						noteType = noteTypes[noteTypeIndex - 1];
					}

					line.notes.push({
						time: sourceNote.time,
						direction: direction,
						sustainLength: sourceNote.sLen != null ? sourceNote.sLen : 0,
						type: noteType
					});
				}

				finalChart.strumLines.push(line);
			}

			if (songJson.events != null)
			{
				if (!Std.isOfType(songJson.events, Array))
					throw 'Codename Engine chart for "$songName" has an invalid events list.';

				for (sourceEvent in (cast songJson.events : Array<Dynamic>))
				{
					if (sourceEvent == null || sourceEvent.time == null || sourceEvent.name == null)
						throw 'Codename Engine chart for "$songName" contains an invalid event.';

					if (sourceEvent.params != null && !Std.isOfType(sourceEvent.params, Array))
						throw 'Codename Engine chart for "$songName" contains an invalid event parameter list.';
					var params:Array<Dynamic> = sourceEvent.params != null ? cast sourceEvent.params : [];
					switch sourceEvent.name
					{
						case "Camera Movement":
							if (params.length > 0)
								finalChart.events.push({
									time: sourceEvent.time,
									name: "Camera Target",
									values: [
										params[0],
										params.length > 3 && params[3] != null ? params[3] : "CLASSIC",
										params.length > 4 && params[4] != null ? params[4] : "In",
										params.length > 2 && params[2] != null ? params[2] : 4,
										params.length > 5 && params[5] != null ? params[5] : 0,
										params.length > 6 && params[6] != null ? params[6] : 0,
										params.length > 1 ? params[1] != false : true
									]
								});
						case "FocusCamera":
							if (params.length > 0)
								finalChart.events.push({
									time: sourceEvent.time,
									name: "Camera Target",
									values: [
										params[0],
										params.length > 3 && params[3] != null ? params[3] : "CLASSIC",
										params.length > 4 && params[4] != null ? params[4] : "In",
										params.length > 2 && params[2] != null ? params[2] : 4,
										params.length > 5 && params[5] != null ? params[5] : 0,
										params.length > 6 && params[6] != null ? params[6] : 0,
										params.length > 1 ? params[1] != false : true
									]
								});
						case "Camera Zoom":
							if (params.length > 1)
								finalChart.events.push({
									time: sourceEvent.time,
									name: "Camera Zoom",
									values: [
										params[1],
										params.length > 3 && params[3] != null ? params[3] : 4,
										params.length > 4 && params[4] != null ? params[4] : "linear",
										params.length > 5 && params[5] != null ? params[5] : "In",
										params.length > 6 && params[6] != null ? params[6] : "direct",
										params.length > 0 ? params[0] != false : true,
										params.length > 2 && params[2] != null ? params[2] : "camGame",
										params.length > 7 ? params[7] == true : false
									]
								});
						case "SetCameraBop":
							if (params.length >= 2)
								finalChart.events.push({
									time: sourceEvent.time,
									name: "Camera Beat Interval Change",
									values: [params[0], params[1]]
								});
							else
								finalChart.events.push({
									time: sourceEvent.time,
									name: sourceEvent.name,
									values: params
								});
						default:
							finalChart.events.push({
								time: sourceEvent.time,
								name: sourceEvent.name,
								values: params
							});
					}
				}
			}
		} else if (songJson.song != null)
		{ // Psych / Legacy
			songJson = songJson.song;

			finalChart.bpm = songJson.bpm;
			var currentBpm:Float = finalChart.bpm;
			var sectionStartTime:Float = 0;
			var lastMustHitSection:Bool = false;

			for (strum in finalChart.strumLines)
				strum.scrollSpeed = songJson.speed != null ? songJson.speed : 1;

			finalChart.strumLines[0].characters.push(songJson.player2);
			finalChart.strumLines[1].characters.push(songJson.player1);
			finalChart.strumLines[2].characters.push(songJson.gfVersion);
			finalChart.stage = songJson.stage;

			for (i => events in cast(songJson.events, Array<Dynamic>))
			{
				finalChart.events.push({
					time: events[0],
					name: events[1][0],
					values: [events[1][1], events[1][2]]
				});
			}

			for (i => section in cast(songJson.notes, Array<Dynamic>))
			{
				var sectionBpm:Float = section.bpm != null ? section.bpm : currentBpm;

				if (section.changeBPM == true && sectionBpm != currentBpm)
				{
					finalChart.events.push({
						time: sectionStartTime,
						name: "Change BPM",
						values: [sectionBpm]
					});

					currentBpm = sectionBpm;
				}

				if (section.mustHitSection != lastMustHitSection || i == 0)
				{
					finalChart.events.push({
						time: sectionStartTime,
						name: "Camera Target",
						values: [section.mustHitSection ? 1 : 0, "Classic", 4, 0, 0]
					});

					lastMustHitSection = section.mustHitSection;
				}

				for (notes in cast(section.sectionNotes, Array<Dynamic>))
				{
					if (notes[1] < 0)
					{
						finalChart.events.push({
							time: notes[0],
							name: notes[2],
							values: [notes[3], notes[4]]
						});
						continue;
					}

					var daStrumTime:Float = notes[0];
					var daNoteData:Int = Std.int(notes[1] % 4);

					var gottaHitNote:Bool = section.mustHitSection;
					if (notes[1] > 3)
					{
						gottaHitNote = !section.mustHitSection;
					}

					var note:NoteData = {
						time: daStrumTime,
						direction: daNoteData,
						sustainLength: notes[2],
						type: notes[3] == null || notes[3] == "" ? "default" : notes[3]};

					finalChart.strumLines[gottaHitNote ? 1 : 0].notes.push(note);
				}

				sectionStartTime += section.lengthInSteps * (60000 / currentBpm / 4);
			}
		}
		return finalChart;
	}
}

typedef Chart =
{
	format:String,
	bpm:Float,
	stage:String,
	events:Array<EventData>,
	strumLines:Array<LineData>
}

typedef EventData =
{
	time:Float,
	name:String,
	values:Array<Dynamic>
}

typedef LineData =
{
	notes:Array<NoteData>,
	cpu:Bool,
	position:Array<Float>,
	scrollSpeed:Float,
	characters:Array<String>,
	charPosition:String
}

typedef NoteData =
{
	time:Float,
	direction:Int,
	sustainLength:Float,
	type:String
}

typedef SongMetaData = {
    name:String,
    displayName:String,
    difficulties:Array<String>,
    icon:String,
    color:String
}