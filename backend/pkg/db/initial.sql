CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(50),
  password VARCHAR(50),
  picture BYTEA,
  AboutMe VARCHAR(255),
  dog_name VARCHAR(50),
  location VARCHAR(100),
  dog_gender VARCHAR(10),
  dog_netured BOOLEAN,
  dog_size FLOAT,
  dog_energy_level VARCHAR(10),
  dog_favorite_play_style VARCHAR(15),
  dog_age INTEGER,
  preferred_distance INTEGER,
  preferred_gender VARCHAR(10),
  preferred_netured BOOLEAN
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
  compatible BOOLEAN DEFAULT FALSE,
  rejected BOOLEAN DEFAULT FALSE,
  match_score FLOAT,
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
&& LANGUAGE plpgsql;

CREATE TRIGGER ensure_user_ids_order_trigger
BEFORE INSERT OR UPDATE ON matches
FOR EACH ROW
EXECUTE FUNCTION ensure_user_ids_order();