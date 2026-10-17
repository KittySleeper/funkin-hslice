package funkin.backend;

class Song
{
	/**
	 * Loads a chart and converts V-Slice, Psych, and legacy charts.
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
								values: [values.char == 1 ? 0 : 1, values.ease, values.duration, values.x, values.y]
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
		}
		else if (songJson.song != null)
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
			finalChart.stage = songJson.stage;

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