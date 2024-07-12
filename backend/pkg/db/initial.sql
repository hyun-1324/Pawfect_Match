CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(50) NOT NULL,
  password VARCHAR(60) NOT NULL,
  about_me VARCHAR(255),
  dog_name VARCHAR(30) NOT NULL,
);

CREATE TABLE biographical_data (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL,
  dog_gender VARCHAR(10) NOT NULL CHECK (dog_gender IN ('male', 'female')),
  dog_neutered BOOLEAN NOT NULL,
  dog_size INTEGER NOT NULL,
  dog_energy_level VARCHAR(10) NOT NULL CHECK (dog_energy_level IN ('low', 'medium', 'high')),
  dog_favorite_play_style VARCHAR(15) NOT NULL,
  dog_age INTEGER NOT NULL,
  preferred_distance INTEGER NOT NULL,
  preferred_gender VARCHAR(10) NOT NULL CHECK (preferred_gender IN ('male', 'female', 'any')),
  preferred_neutered BOOLEAN NOT NULL,
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE
);

CREATE TABLE locations (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL,
  option VARCHAR(15) NOT NULL CHECK (option IN ('Live', 'Helsinki', 'Tampere', 'Turku', 'Jyväskylä', 'Kuopio')),
  latitude DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  longitude DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  geom GEOGRAPHY(POINT, 4326),
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE
);

CREATE INDEX idx_locations_geom ON locations USING GIST(geom);

CREATE OR REPLACE FUNCTION update_geom()
RETURNS TRIGGER AS $$
BEGIN
  NEW.geom := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_geom
BEFORE INSERT OR UPDATE ON locations
FOR EACH ROW
EXECUTE FUNCTION update_geom();

CREATE TABLE profile_pictures (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL UNIQUE,
  file_name TEXT NOT NULL,
  file_type TEXT NOT NULL CHECK (file_type IN ('image/jpeg', 'image/png', 'image/gif')),
  file_data BYTEA NOT NULL,
  file_url TEXT NOT NULL,
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE
);

CREATE TABLE jwt_blacklist (
  id SERIAL PRIMARY KEY,
  token VARCHAR(255) NOT NULL,
  expires_at TIMESTAMP NOT NULL
);

CREATE TABLE connections (
  id SERIAL PRIMARY KEY,
  user_id1 INTEGER,
  user_id2 INTEGER,
  FOREIGN KEY("user_id1") REFERENCES "users"("id") ON DELETE CASCADE,
  FOREIGN KEY("user_id2") REFERENCES "users"("id") ON DELETE CASCADE
);

CREATE TABLE requests (
  id SERIAL PRIMARY KEY,
  from_id INTEGER,
  to_id INTEGER,
  processed BOOLEAN DEFAULT FALSE,
  FOREIGN KEY("from_id") REFERENCES "users"("id") ON DELETE CASCADE,
  FOREIGN KEY("to_id") REFERENCES "users"("id") ON DELETE CASCADE
);

CREATE TABLE matches (
  id SERIAL PRIMARY KEY,
  user_id1 INTEGER NOT NULL,
  user_id2 INTEGER NOT NULL,
  compatible_neutered BOOLEAN DEFAULT FALSE,
  compatible_gender BOOLEAN DEFAULT FALSE,
  compatible_play_style BOLEAN DEFAULT FALSE,
  compatible_size BOOLEAN DEFAULT FALSE,
  rejected BOOLEAN DEFAULT FALSE,
  match_score FLOAT,
  compatible_distance BOOLEAN DEFAULT FALSE,
  FOREIGN KEY("user_id1") REFERENCES "users"("id") ON DELETE CASCADE,
  FOREIGN KEY("user_id2") REFERENCES "users"("id") ON DELETE CASCADE,
  CONSTRAINT unique_user_ids_pair UNIQUE (user_id1, user_id2)
);

CREATE OR REPLACE FUNCTION ensure_user_ids_order()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.user_id1 > NEW.user_id2 THEN
    DECLARE temp INTEGER;
    temp := NEW.user_id1;
    NEW.user_id1 := NEW.user_id2;
    NEW.user_id2 := temp;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ensure_user_ids_order_trigger
BEFORE INSERT OR UPDATE ON matches
FOR EACH ROW
EXECUTE FUNCTION ensure_user_ids_order();

CREATE OR REPLACE FUNCTION update_matches() 
RETURNS TRIGGER AS $$
BEGIN
	INSERT INTO matches (user_id1, user_id2)
	SELECT NEW.id, id
	FROM users
	WHERE id <> NEW.id;

	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_user_insert
AFTER INSERT ON users
FOR EACH rows
EXECUTE FUNCTION update_matches();

CREATE OR REPLACE FUNCTION update_compatible_distance()
RETURNS TRIGGER AS $$
BEGIN
  WITH user_distance AS (
    SELECT
      m.id AS match_id,
      m.user_id1,
      m.user_id2,
      ST_Distance(
        l1.geom::geography,
        l2.geom::geography
      ) / 1000 AS distance,
      bd1.preferred_distance AS preferred_distance1_km,
      bd2.preferred_distance AS preferred_distance2_km
    FROM matches m
      JOIN locations l1 ON m.user_id1 = l1.user_id
      JOIN locations l2 ON m.user_id2 = l2.user_id
      JOIN biographical_data bd1 ON m.user_id1 = bd1.user_id
      JOIN biographical_data bd2 ON m.user_id2 = bd2.user_id
    WHERE m.user_id1 = NEW.user_id OR m.user_id2 = NEW.user_id
  )
  UPDATE matches
  SET compatible_distance = TRUE
  FROM user_distance ud
  WHERE matches.id = ud.match_id
  AND ud.distance <= LEAST(ud.preferred_distance1_km, ud.preferred_distance2_km);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_compatible_distance_trigger
AFTER INSERT OR UPDATE ON locations
FOR EACH ROW
EXECUTE FUNCTION update_compatible_distance();


CREATE EXTENSION postgis;