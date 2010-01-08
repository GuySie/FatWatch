BEGIN EXCLUSIVE;

CREATE TABLE metadata (
	name TEXT UNIQUE ON CONFLICT REPLACE,
	value
);

CREATE TABLE days (
	monthday INTEGER PRIMARY KEY,
	scaleWeight REAL,
	scaleFat REAL,
	flag0 INTEGER,
	flag1 INTEGER,
	flag2 INTEGER,
	flag3 INTEGER,
	note TEXT
);
CREATE INDEX scaleWeightIndex ON days (scaleWeight);
CREATE INDEX scaleFatIndex ON days (scaleFat);
CREATE INDEX flag0Index ON days (flag0);
CREATE INDEX flag1Index ON days (flag1);
CREATE INDEX flag2Index ON days (flag2);
CREATE INDEX flag3Index ON days (flag3);

CREATE TABLE months (
	month INTEGER PRIMARY KEY,
	outputTrendWeight REAL,
	outputTrendFat REAL
);
CREATE INDEX trendWeightIndex ON months (outputTrendWeight);
CREATE INDEX trendFatIndex ON months (outputTrendFat);

INSERT INTO metadata VALUES ("dataversion", 3);

END;