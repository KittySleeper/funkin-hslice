package funkin.backend;

class Song
{
	/**
	 * Loads A Chart, Converts Psych And Legacy Charts Currently.
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
			strumLines: [
				{
					notes: [],
					type: "opponent",
					position: [50, 50],
					characters: [],
                    charPosition: "opponent",
					scrollSpeed: 1
				},
				{
					notes: [],
					type: "player",
					position: [690, 50],
					characters: [],
                    charPosition: "player",
					scrollSpeed: 1
				}
			]
		};

		var songJson:Dynamic = Paths.json('songs/$songName/charts/$songDifficulty');

		if (songJson.format != null && songJson.format == "HSlice Format")
		{ // HSlice / Better Than VSlice
			finalChart = songJson;
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
	type:String,
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
