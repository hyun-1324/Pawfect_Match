CREATE EXTENSION postgis;

CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(50) NOT NULL,
  password VARCHAR(60) NOT NULL,
  about_me VARCHAR(255),
  dog_name VARCHAR(30) NOT NULL
);

CREATE TABLE biographical_data (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL,
  dog_gender VARCHAR(10) NOT NULL CHECK (dog_gender IN ('male', 'female')),
  dog_neutered BOOLEAN NOT NULL,
  dog_size REAL NOT NULL,
  dog_energy_level VARCHAR(10) NOT NULL CHECK (dog_energy_level IN ('low', 'medium', 'high')),
  dog_favorite_play_style VARCHAR(15) NOT NULL,
  dog_age INTEGER NOT NULL,
  preferred_distance INTEGER NOT NULL,
  preferred_gender VARCHAR(10) NOT NULL CHECK (preferred_gender IN ('male', 'female', 'any')),
  preferred_neutered BOOLEAN NOT NULL,
  preferred_location VARCHAR(15) NOT NULL CHECK (preferred_location IN ('Live', 'Helsinki', 'Tampere', 'Turku', 'Jyväskylä', 'Kuopio')),
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE
);

CREATE TABLE locations (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL,
  option VARCHAR(15) NOT NULL CHECK (option IN ('Live', 'Helsinki', 'Tampere', 'Turku', 'Jyväskylä', 'Kuopio')),
  latitude DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  longitude DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  geom GEOMETRY(POINT, 4326),
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE,
  CONSTRAINT unique_user_id UNIQUE (user_id)
);

CREATE INDEX idx_locations_geom ON locations USING GIST(geom);

CREATE OR REPLACE FUNCTION update_geom()
RETURNS TRIGGER AS $$
BEGIN
  NEW.geom := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::GEOMETRY;
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
  id1_check BOOLEAN DEFAULT FALSE,
  id2_check BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  FOREIGN KEY("user_id1") REFERENCES "users"("id") ON DELETE CASCADE,
  FOREIGN KEY("user_id2") REFERENCES "users"("id") ON DELETE CASCADE,
  UNIQUE (user_id1, user_id2),
  CHECK (user_id1 < user_id2)
);

CREATE TABLE requests (
  id SERIAL PRIMARY KEY,
  from_id INTEGER NOT NULL,
  to_id INTEGER NOT NULL,
  accepted BOOLEAN DEFAULT FALSE,
  processed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  FOREIGN KEY("from_id") REFERENCES "users"("id") ON DELETE CASCADE,
  FOREIGN KEY("to_id") REFERENCES "users"("id") ON DELETE CASCADE
);

CREATE UNIQUE INDEX unique_request ON requests (
  LEAST(from_id, to_id), 
  GREATEST(from_id, to_id)
);

CREATE TABLE matches (
  id SERIAL PRIMARY KEY,
  user_id1 INTEGER NOT NULL,
  user_id2 INTEGER NOT NULL,
  compatible_neutered BOOLEAN DEFAULT FALSE,
  compatible_gender BOOLEAN DEFAULT FALSE,
  compatible_play_style BOOLEAN DEFAULT FALSE,
  compatible_size BOOLEAN DEFAULT FALSE,
  compatible_distance BOOLEAN DEFAULT FALSE,
  requested BOOLEAN DEFAULT FALSE,
  rejected BOOLEAN DEFAULT FALSE,
  match_score FLOAT,
  UNIQUE (user_id1, user_id2),
  CHECK (user_id1 < user_id2)
);

CREATE OR REPLACE FUNCTION update_matches() 
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO matches (user_id1, user_id2)
  SELECT
    LEAST(NEW.id, id),
    GREATEST(NEW.id, id)
  FROM users
  WHERE id <> NEW.id
  ON CONFLICT (user_id1, user_id2) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_user_insert
AFTER INSERT ON users
FOR EACH ROW
EXECUTE FUNCTION update_matches();

CREATE OR REPLACE FUNCTION update_compatible_distance()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE matches m
  SET compatible_distance = (
    SELECT
      CASE
        WHEN ST_Distance(l1.geom::GEOMETRY, l2.geom::GEOMETRY) / 1000 <= 
        LEAST(bd1.preferred_distance, bd2.preferred_distance)
        THEN TRUE
        ELSE FALSE
      END
    FROM locations l1
    JOIN locations l2 ON m.user_id2 = l2.user_id
    JOIN biographical_data bd1 ON m.user_id1 = bd1.user_id
    JOIN biographical_data bd2 ON m.user_id2 = bd2.user_id
    WHERE m.user_id1 = l1.user_id
  )
  WHERE m.user_id1 = NEW.user_id OR m.user_id2 = NEW.user_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_compatible_distance_trigger
AFTER INSERT OR UPDATE ON locations
FOR EACH ROW
EXECUTE FUNCTION update_compatible_distance();

CREATE TABLE rooms (
  id SERIAL PRIMARY KEY,
  user_id1 INTEGER NOT NULL,
  user_id2 INTEGER NOT NULL,
  FOREIGN KEY (user_id1) REFERENCES users (id) ON DELETE CASCADE,
  FOREIGN KEY (user_id2) REFERENCES users (id) ON DELETE CASCADE,
  UNIQUE (user_id1, user_id2),
  CHECK(user_id1 < user_id2)
);

CREATE TABLE messages (
  id SERIAL PRIMARY KEY,
  room_id INTEGER NOT NULL,
  from_id INTEGER NOT NULL,
  to_id INTEGER NOT NULL,
  message TEXT NOT NULL,
  sent_at TIMESTAMP NOT NULL DEFAULT NOW(),
  read BOOLEAN DEFAULT FALSE,
  FOREIGN KEY (room_id) REFERENCES rooms (id) ON DELETE SET NULL,
  FOREIGN KEY (from_id) REFERENCES users (id) ON DELETE SET NULL,
  FOREIGN KEY (to_id) REFERENCES users (id) ON DELETE SET NULL
);