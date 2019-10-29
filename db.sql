CREATE TABLE easteries (
	id INTEGER PRIMARY KEY,
	name TEXT,
	description TEXT,
	lan TEXT,
	lng TEXT,
	address TEXT,
	url TEXT,
	phone TEXT
);

CREATE TABLE default_easteries (
	id INTEGER PRIMARY KEY,
	eastery_id INTEGER,
	FOREIGN KEY (eastery_id)
		REFERENCES easteries (id)
			ON DELETE CASCADE
			ON UPDATE NO ACTION
);

CREATE TABLE vote_messages (
	id INTEGER PRIMARY KEY,
	message_id INTEGER
);

CREATE TABLE shuffled (
	id INTEGER PRIMARY KEY,
	eastery_id INTEGER
);

CREATE TABLE votes (
	id INTEGER PRIMARY KEY,
	username TEXT,
	eastery TEXT
);
