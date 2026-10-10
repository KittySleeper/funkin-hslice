package funkin.backend;

class Song {
    public static inline function loadSong(songName:String, songDifficulty:String = "hard"):Chart {
        var finalChart:Chart = {
            bpm: 0,
            scrollSpeed: 1,
            events: [],
            strumLines: [
                {
                    notes: [],
                    type: "opponent"
                },
                {
                    notes: [],
                    type: "player"
                }
            ]
        };

        var songJson:Dynamic = Paths.json('songs/$songName/charts/$songDifficulty');

        if (songJson.song != null) {
            songJson = songJson.song;
            
            finalChart.bpm = songJson.bpm;
            finalChart.scrollSpeed = songJson.speed;
            var currentBpm:Float = finalChart.bpm;
            var sectionStartTime:Float = 0;

            for (section in cast(songJson.notes, Array<Dynamic>)) {
                var sectionBpm:Float = section.bpm != null ? section.bpm : currentBpm;
                if (section.changeBPM == true && sectionBpm != currentBpm) {
                    finalChart.events.push({
                        time: sectionStartTime,
                        name: "Change BPM",
                        values: [sectionBpm]
                    });
                    currentBpm = sectionBpm;
                }

                for (notes in cast(section.sectionNotes, Array<Dynamic>)) {
                    if (notes[1] < 0) {
                        finalChart.events.push(
                            {
                                time: notes[0],
                                name: notes[2],
                                values: [notes[3], notes[4]]
                            }
                        );
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
                        type: notes[3]
                    };
                    
                    finalChart.strumLines[gottaHitNote ? 0 : 1].notes.push(note);
                }

                sectionStartTime += section.lengthInSteps * (60000 / currentBpm / 4);
            }
        }
        return finalChart;
    }
}

typedef Chart = {
    bpm:Float,
    scrollSpeed:Float,
    events:Array<EventData>,
    strumLines:Array<LineData>
}

typedef EventData = {
    time:Float,
    name:String,
    values:Array<Dynamic>
}

typedef LineData = {
    notes:Array<NoteData>,
    type:String
}

typedef NoteData = {
    time:Float,
    direction:Int,
    sustainLength:Float,
    type:String
}