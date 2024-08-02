--
-- PostgreSQL database dump
--

-- Dumped from database version 16.3 (Postgres.app)
-- Dumped by pg_dump version 16.3

-- Started on 2024-08-02 21:32:28 EEST

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 2 (class 3079 OID 90696)
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- TOC entry 4701 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- TOC entry 284 (class 1255 OID 91904)
-- Name: update_compatible_distance(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_compatible_distance() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  UPDATE matches m
  SET compatible_distance = (
    SELECT
      CASE
        WHEN ST_Distance(l1.geom, l2.geom) / 1000 <= 
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
$$;


ALTER FUNCTION public.update_compatible_distance() OWNER TO postgres;

--
-- TOC entry 329 (class 1255 OID 91815)
-- Name: update_geom(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_geom() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.geom := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude)::GEOGRAPHY, 4326);
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_geom() OWNER TO postgres;

--
-- TOC entry 623 (class 1255 OID 91902)
-- Name: update_matches(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_matches() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.update_matches() OWNER TO postgres;

--
-- TOC entry 938 (class 1255 OID 91955)
-- Name: update_messages_connected_status(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_messages_connected_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE messages
    SET from_id_connected = 
        CASE 
            WHEN (NEW.user_id1 = messages.from_id AND NEW.user1_connected = TRUE) OR
                 (NEW.user_id2 = messages.from_id AND NEW.user2_connected = TRUE)
            THEN TRUE
            ELSE FALSE
        END,
        to_id_connected = 
        CASE 
            WHEN (NEW.user_id1 = messages.to_id AND NEW.user1_connected = TRUE) OR
                 (NEW.user_id2 = messages.to_id AND NEW.user2_connected = TRUE)
            THEN TRUE
            ELSE FALSE
        END
    WHERE messages.room_id = NEW.id;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_messages_connected_status() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 224 (class 1259 OID 91780)
-- Name: biographical_data; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.biographical_data (
    id integer NOT NULL,
    user_id integer NOT NULL,
    dog_gender character varying(10) NOT NULL,
    dog_neutered boolean NOT NULL,
    dog_size real NOT NULL,
    dog_energy_level character varying(10) NOT NULL,
    dog_favorite_play_style character varying(15) NOT NULL,
    dog_age integer NOT NULL,
    preferred_distance integer NOT NULL,
    preferred_gender character varying(10) NOT NULL,
    preferred_neutered boolean NOT NULL,
    preferred_location character varying(15) NOT NULL,
    CONSTRAINT biographical_data_dog_energy_level_check CHECK (((dog_energy_level)::text = ANY ((ARRAY['low'::character varying, 'medium'::character varying, 'high'::character varying])::text[]))),
    CONSTRAINT biographical_data_dog_gender_check CHECK (((dog_gender)::text = ANY ((ARRAY['male'::character varying, 'female'::character varying])::text[]))),
    CONSTRAINT biographical_data_preferred_gender_check CHECK (((preferred_gender)::text = ANY ((ARRAY['male'::character varying, 'female'::character varying, 'any'::character varying])::text[]))),
    CONSTRAINT biographical_data_preferred_location_check CHECK (((preferred_location)::text = ANY ((ARRAY['Live'::character varying, 'Helsinki'::character varying, 'Tampere'::character varying, 'Turku'::character varying, 'Jyväskylä'::character varying, 'Kuopio'::character varying])::text[])))
);


ALTER TABLE public.biographical_data OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 91779)
-- Name: biographical_data_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.biographical_data_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.biographical_data_id_seq OWNER TO postgres;

--
-- TOC entry 4702 (class 0 OID 0)
-- Dependencies: 223
-- Name: biographical_data_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.biographical_data_id_seq OWNED BY public.biographical_data.id;


--
-- TOC entry 232 (class 1259 OID 91842)
-- Name: connections; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.connections (
    id integer NOT NULL,
    user_id1 integer,
    user_id2 integer,
    id1_check boolean DEFAULT false,
    id2_check boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT connections_check CHECK ((user_id1 < user_id2))
);


ALTER TABLE public.connections OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 91841)
-- Name: connections_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.connections_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.connections_id_seq OWNER TO postgres;

--
-- TOC entry 4703 (class 0 OID 0)
-- Dependencies: 231
-- Name: connections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.connections_id_seq OWNED BY public.connections.id;


--
-- TOC entry 230 (class 1259 OID 91835)
-- Name: jwt_blacklist; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.jwt_blacklist (
    id integer NOT NULL,
    token character varying(255) NOT NULL,
    expires_at timestamp without time zone NOT NULL
);


ALTER TABLE public.jwt_blacklist OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 91834)
-- Name: jwt_blacklist_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.jwt_blacklist_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.jwt_blacklist_id_seq OWNER TO postgres;

--
-- TOC entry 4704 (class 0 OID 0)
-- Dependencies: 229
-- Name: jwt_blacklist_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.jwt_blacklist_id_seq OWNED BY public.jwt_blacklist.id;


--
-- TOC entry 226 (class 1259 OID 91796)
-- Name: locations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.locations (
    id integer NOT NULL,
    user_id integer NOT NULL,
    option character varying(15) NOT NULL,
    latitude double precision DEFAULT 0.0 NOT NULL,
    longitude double precision DEFAULT 0.0 NOT NULL,
    geom public.geography(Point,4326),
    CONSTRAINT locations_option_check CHECK (((option)::text = ANY ((ARRAY['Live'::character varying, 'Helsinki'::character varying, 'Tampere'::character varying, 'Turku'::character varying, 'Jyväskylä'::character varying, 'Kuopio'::character varying])::text[])))
);


ALTER TABLE public.locations OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 91795)
-- Name: locations_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.locations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.locations_id_seq OWNER TO postgres;

--
-- TOC entry 4705 (class 0 OID 0)
-- Dependencies: 225
-- Name: locations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.locations_id_seq OWNED BY public.locations.id;


--
-- TOC entry 236 (class 1259 OID 91886)
-- Name: matches; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.matches (
    id integer NOT NULL,
    user_id1 integer NOT NULL,
    user_id2 integer NOT NULL,
    compatible_neutered boolean DEFAULT false,
    compatible_gender boolean DEFAULT false,
    compatible_play_style boolean DEFAULT false,
    compatible_size boolean DEFAULT false,
    compatible_distance boolean DEFAULT false,
    requested boolean DEFAULT false,
    rejected boolean DEFAULT false,
    match_score double precision,
    CONSTRAINT matches_check CHECK ((user_id1 < user_id2))
);


ALTER TABLE public.matches OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 91885)
-- Name: matches_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.matches_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.matches_id_seq OWNER TO postgres;

--
-- TOC entry 4706 (class 0 OID 0)
-- Dependencies: 235
-- Name: matches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.matches_id_seq OWNED BY public.matches.id;


--
-- TOC entry 240 (class 1259 OID 91930)
-- Name: messages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.messages (
    id integer NOT NULL,
    room_id integer,
    from_id integer,
    to_id integer,
    from_id_connected boolean,
    to_id_connected boolean NOT NULL,
    message text NOT NULL,
    sent_at timestamp without time zone DEFAULT now() NOT NULL,
    read boolean DEFAULT false
);


ALTER TABLE public.messages OWNER TO postgres;

--
-- TOC entry 239 (class 1259 OID 91929)
-- Name: messages_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.messages_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.messages_id_seq OWNER TO postgres;

--
-- TOC entry 4707 (class 0 OID 0)
-- Dependencies: 239
-- Name: messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.messages_id_seq OWNED BY public.messages.id;


--
-- TOC entry 228 (class 1259 OID 91818)
-- Name: profile_pictures; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.profile_pictures (
    id integer NOT NULL,
    user_id integer NOT NULL,
    file_name text NOT NULL,
    file_type text NOT NULL,
    file_data bytea NOT NULL,
    file_url text NOT NULL,
    CONSTRAINT profile_pictures_file_type_check CHECK ((file_type = ANY (ARRAY['image/jpeg'::text, 'image/png'::text, 'image/gif'::text])))
);


ALTER TABLE public.profile_pictures OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 91817)
-- Name: profile_pictures_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.profile_pictures_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.profile_pictures_id_seq OWNER TO postgres;

--
-- TOC entry 4708 (class 0 OID 0)
-- Dependencies: 227
-- Name: profile_pictures_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.profile_pictures_id_seq OWNED BY public.profile_pictures.id;


--
-- TOC entry 234 (class 1259 OID 91865)
-- Name: requests; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.requests (
    id integer NOT NULL,
    from_id integer NOT NULL,
    to_id integer NOT NULL,
    accepted boolean DEFAULT false,
    processed boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.requests OWNER TO postgres;

--
-- TOC entry 233 (class 1259 OID 91864)
-- Name: requests_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.requests_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.requests_id_seq OWNER TO postgres;

--
-- TOC entry 4709 (class 0 OID 0)
-- Dependencies: 233
-- Name: requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.requests_id_seq OWNED BY public.requests.id;


--
-- TOC entry 238 (class 1259 OID 91907)
-- Name: rooms; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rooms (
    id integer NOT NULL,
    user_id1 integer NOT NULL,
    user_id2 integer NOT NULL,
    user1_connected boolean DEFAULT true,
    user2_connected boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT rooms_check CHECK ((user_id1 < user_id2))
);


ALTER TABLE public.rooms OWNER TO postgres;

--
-- TOC entry 237 (class 1259 OID 91906)
-- Name: rooms_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.rooms_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.rooms_id_seq OWNER TO postgres;

--
-- TOC entry 4710 (class 0 OID 0)
-- Dependencies: 237
-- Name: rooms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.rooms_id_seq OWNED BY public.rooms.id;


--
-- TOC entry 222 (class 1259 OID 91773)
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id integer NOT NULL,
    email character varying(50) NOT NULL,
    password character varying(60) NOT NULL,
    about_me character varying(255),
    dog_name character varying(30) NOT NULL
);


ALTER TABLE public.users OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 91772)
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_id_seq OWNER TO postgres;

--
-- TOC entry 4711 (class 0 OID 0)
-- Dependencies: 221
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- TOC entry 4439 (class 2604 OID 91783)
-- Name: biographical_data id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.biographical_data ALTER COLUMN id SET DEFAULT nextval('public.biographical_data_id_seq'::regclass);


--
-- TOC entry 4445 (class 2604 OID 91845)
-- Name: connections id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.connections ALTER COLUMN id SET DEFAULT nextval('public.connections_id_seq'::regclass);


--
-- TOC entry 4444 (class 2604 OID 91838)
-- Name: jwt_blacklist id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.jwt_blacklist ALTER COLUMN id SET DEFAULT nextval('public.jwt_blacklist_id_seq'::regclass);


--
-- TOC entry 4440 (class 2604 OID 91799)
-- Name: locations id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.locations ALTER COLUMN id SET DEFAULT nextval('public.locations_id_seq'::regclass);


--
-- TOC entry 4453 (class 2604 OID 91889)
-- Name: matches id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matches ALTER COLUMN id SET DEFAULT nextval('public.matches_id_seq'::regclass);


--
-- TOC entry 4465 (class 2604 OID 91933)
-- Name: messages id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages ALTER COLUMN id SET DEFAULT nextval('public.messages_id_seq'::regclass);


--
-- TOC entry 4443 (class 2604 OID 91821)
-- Name: profile_pictures id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profile_pictures ALTER COLUMN id SET DEFAULT nextval('public.profile_pictures_id_seq'::regclass);


--
-- TOC entry 4449 (class 2604 OID 91868)
-- Name: requests id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requests ALTER COLUMN id SET DEFAULT nextval('public.requests_id_seq'::regclass);


--
-- TOC entry 4461 (class 2604 OID 91910)
-- Name: rooms id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rooms ALTER COLUMN id SET DEFAULT nextval('public.rooms_id_seq'::regclass);


--
-- TOC entry 4438 (class 2604 OID 91776)
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- TOC entry 4679 (class 0 OID 91780)
-- Dependencies: 224
-- Data for Name: biographical_data; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.biographical_data (id, user_id, dog_gender, dog_neutered, dog_size, dog_energy_level, dog_favorite_play_style, dog_age, preferred_distance, preferred_gender, preferred_neutered, preferred_location) FROM stdin;
1	1	female	t	3	low	tugging	26	21	female	f	Tampere
2	2	female	t	24	low	wrestling	3	22	female	f	Turku
3	3	male	t	16	low	cheerleading	19	30	any	t	Turku
4	4	female	f	17	low	body slamming	17	12	any	f	Tampere
5	5	female	t	8	low	wrestling	8	22	female	f	Tampere
6	6	female	t	12	medium	chasing	27	9	any	t	Tampere
7	7	female	t	6	medium	wrestling	9	22	any	t	Kuopio
8	8	male	f	10	low	chasing	15	27	any	f	Turku
9	9	male	t	6	low	tugging	11	3	any	f	Jyväskylä
10	10	female	f	11	medium	chasing	8	2	any	f	Tampere
11	11	male	f	4	medium	wrestling	8	13	female	t	Jyväskylä
12	12	female	f	5	low	ripping	28	26	female	f	Jyväskylä
13	13	female	f	28	high	cheerleading	30	17	male	f	Live
14	14	male	t	7	medium	body slamming	17	10	male	f	Kuopio
15	15	male	t	24	medium	ripping	9	18	male	t	Live
16	16	male	f	13	low	soft touch	2	1	any	f	Live
17	17	male	t	14	high	tugging	10	7	female	f	Kuopio
18	18	female	f	14	high	lonely wolf	18	24	male	f	Kuopio
19	19	male	t	21	medium	body slamming	16	24	any	f	Live
20	20	male	f	14	high	lonely wolf	18	10	male	f	Turku
21	21	female	f	8	high	body slamming	10	28	any	t	Live
22	22	female	t	1	medium	chasing	24	30	any	t	Jyväskylä
23	23	female	f	6	medium	soft touch	1	12	female	f	Jyväskylä
24	24	male	t	21	medium	tugging	12	6	any	t	Live
25	25	female	f	20	high	cheerleading	3	19	female	f	Helsinki
26	26	female	t	18	low	lonely wolf	17	9	any	t	Helsinki
27	27	male	f	18	high	ripping	20	23	male	t	Kuopio
28	28	male	f	30	medium	lonely wolf	10	13	female	f	Helsinki
29	29	male	f	26	medium	lonely wolf	6	30	female	t	Live
30	30	female	t	4	medium	cheerleading	3	23	female	f	Turku
31	31	male	t	2	low	cheerleading	19	11	male	t	Helsinki
32	32	male	f	13	medium	ripping	18	5	male	f	Jyväskylä
33	33	female	t	14	high	lonely wolf	15	8	male	t	Live
34	34	female	t	9	medium	tugging	26	21	any	t	Tampere
35	35	male	t	11	high	chasing	7	16	female	t	Helsinki
36	36	male	t	9	high	cheerleading	16	29	male	f	Kuopio
37	37	female	t	14	low	chasing	15	7	male	t	Jyväskylä
38	38	female	f	15	low	cheerleading	30	30	female	t	Helsinki
39	39	male	t	4	low	soft touch	10	20	female	f	Helsinki
40	40	male	t	4	low	body slamming	12	10	male	f	Turku
41	41	male	t	10	medium	ripping	9	8	male	f	Jyväskylä
42	42	female	t	4	high	soft touch	19	29	male	f	Jyväskylä
43	43	female	t	10	medium	lonely wolf	15	30	female	f	Live
44	44	female	f	12	high	lonely wolf	5	4	male	t	Tampere
45	45	female	f	22	high	body slamming	9	12	male	t	Live
46	46	female	f	3	low	tugging	27	21	male	f	Tampere
47	47	female	t	15	low	tugging	14	29	female	f	Kuopio
48	48	female	f	17	high	ripping	18	20	female	f	Turku
49	49	female	f	20	medium	tugging	9	24	male	t	Tampere
50	50	male	f	16	low	wrestling	20	26	any	t	Tampere
51	51	female	f	20	low	ripping	28	1	male	f	Tampere
52	52	male	t	12	medium	wrestling	2	1	female	t	Tampere
53	53	male	f	27	medium	tugging	5	23	any	t	Tampere
54	54	female	t	26	medium	cheerleading	23	30	female	f	Kuopio
55	55	male	t	13	medium	chasing	21	25	female	t	Helsinki
56	56	male	f	26	medium	cheerleading	10	26	male	t	Helsinki
57	57	male	f	18	high	wrestling	10	2	female	f	Helsinki
58	58	male	t	10	medium	tugging	2	29	female	f	Kuopio
59	59	male	f	23	medium	tugging	28	14	male	t	Helsinki
60	60	male	t	11	high	lonely wolf	17	30	male	f	Tampere
61	61	female	f	29	high	body slamming	26	15	male	f	Tampere
62	62	male	f	30	low	tugging	20	29	male	t	Live
63	63	female	f	9	medium	tugging	23	18	any	t	Jyväskylä
64	64	female	t	23	low	tugging	25	15	male	f	Jyväskylä
65	65	female	t	3	low	lonely wolf	28	11	any	t	Helsinki
66	66	female	f	4	high	cheerleading	15	1	any	t	Turku
67	67	male	f	13	low	ripping	27	9	male	t	Kuopio
68	68	female	t	28	low	ripping	2	2	male	f	Tampere
69	69	female	t	25	medium	lonely wolf	5	23	any	f	Tampere
70	70	female	f	20	low	soft touch	16	12	male	t	Helsinki
71	71	female	t	19	low	lonely wolf	28	16	male	t	Tampere
72	72	male	f	11	medium	soft touch	16	30	female	t	Jyväskylä
73	73	male	t	15	medium	lonely wolf	26	30	male	f	Live
74	74	female	t	3	high	wrestling	6	23	female	t	Turku
75	75	female	t	17	medium	ripping	26	6	female	f	Turku
76	76	female	t	5	low	cheerleading	2	2	male	t	Live
77	77	male	f	8	high	tugging	12	2	any	t	Helsinki
78	78	male	t	6	medium	ripping	29	10	female	t	Live
79	79	male	t	19	high	body slamming	4	3	female	f	Tampere
80	80	male	f	27	low	wrestling	10	6	female	f	Turku
81	81	male	t	25	low	body slamming	14	26	male	t	Tampere
82	82	male	t	27	medium	chasing	5	4	any	f	Kuopio
83	83	male	t	11	medium	body slamming	24	29	female	t	Jyväskylä
84	84	male	t	10	low	soft touch	26	4	any	f	Jyväskylä
85	85	male	t	14	medium	ripping	11	11	female	t	Helsinki
86	86	female	t	18	high	body slamming	25	8	male	f	Tampere
87	87	male	t	18	low	soft touch	17	7	female	t	Live
88	88	male	f	2	low	chasing	18	19	male	t	Live
89	89	male	f	2	high	chasing	5	13	male	t	Tampere
90	90	male	t	1	high	ripping	24	12	any	t	Jyväskylä
91	91	female	f	11	medium	tugging	1	11	female	f	Turku
92	92	male	f	10	low	body slamming	5	7	female	f	Helsinki
93	93	male	t	10	medium	lonely wolf	23	27	male	t	Kuopio
94	94	male	f	29	medium	soft touch	20	2	any	f	Tampere
95	95	female	f	1	low	wrestling	25	21	any	f	Jyväskylä
96	96	female	f	1	high	body slamming	12	18	female	t	Jyväskylä
97	97	female	f	19	low	tugging	24	25	any	f	Kuopio
98	98	female	f	8	low	ripping	13	7	male	f	Turku
99	99	male	t	14	low	ripping	5	27	female	f	Kuopio
100	100	female	f	11	low	ripping	15	22	male	t	Jyväskylä
101	101	male	t	8	medium	ripping	29	1	male	t	Helsinki
102	102	male	f	3	low	lonely wolf	19	27	male	f	Live
103	103	female	f	24	high	ripping	17	20	female	t	Jyväskylä
\.


--
-- TOC entry 4687 (class 0 OID 91842)
-- Dependencies: 232
-- Data for Name: connections; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.connections (id, user_id1, user_id2, id1_check, id2_check, created_at) FROM stdin;
\.


--
-- TOC entry 4685 (class 0 OID 91835)
-- Dependencies: 230
-- Data for Name: jwt_blacklist; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.jwt_blacklist (id, token, expires_at) FROM stdin;
\.


--
-- TOC entry 4681 (class 0 OID 91796)
-- Dependencies: 226
-- Data for Name: locations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.locations (id, user_id, option, latitude, longitude, geom) FROM stdin;
1	1	Tampere	61.4978	23.761	0101000020E6100000894160E5D0C2374072F90FE9B7BF4E40
2	2	Turku	60.4518	22.2666	0101000020E6100000151DC9E53F443640992A1895D4394E40
3	3	Turku	60.4518	22.2666	0101000020E6100000151DC9E53F443640992A1895D4394E40
4	4	Tampere	61.4978	23.761	0101000020E6100000894160E5D0C2374072F90FE9B7BF4E40
5	5	Tampere	61.4978	23.761	0101000020E6100000894160E5D0C2374072F90FE9B7BF4E40
6	6	Tampere	61.4978	23.761	0101000020E6100000894160E5D0C2374072F90FE9B7BF4E40
7	7	Kuopio	62.8988	27.6784	0101000020E61000003D9B559FABAD3B4089D2DEE00B734F40
8	8	Turku	60.4518	22.2666	0101000020E6100000151DC9E53F443640992A1895D4394E40
9	9	Jyväskylä	62.2416	25.7594	0101000020E61000001895D40968C23940575BB1BFEC1E4F40
10	10	Tampere	61.4978	23.761	0101000020E6100000894160E5D0C2374072F90FE9B7BF4E40
11	11	Jyväskylä	62.2416	25.7594	0101000020E61000001895D40968C23940575BB1BFEC1E4F40
12	12	Jyväskylä	62.2416	25.7594	0101000020E61000001895D40968C23940575BB1BFEC1E4F40
13	14	Kuopio	62.8988	27.6784	0101000020E61000003D9B559FABAD3B4089D2DEE00B734F40
14	17	Kuopio	62.8988	27.6784	0101000020E61000003D9B559FABAD3B4089D2DEE00B734F40
15	18	Kuopio	62.8988	27.6784	0101000020E61000003D9B559FABAD3B4089D2DEE00B734F40
16	20	Turku	60.4518	22.2666	0101000020E6100000151DC9E53F443640992A1895D4394E40
17	22	Jyväskylä	62.2416	25.7594	0101000020E61000001895D40968C23940575BB1BFEC1E4F40
18	23	Jyväskylä	62.2416	25.7594	0101000020E61000001895D40968C23940575BB1BFEC1E4F40
19	25	Helsinki	60.1695	24.9354	0101000020E6100000ACADD85F76EF384004560E2DB2154E40
20	26	Helsinki	60.1695	24.9354	0101000020E6100000ACADD85F76EF384004560E2DB2154E40
21	27	Kuopio	62.8988	27.6784	0101000020E61000003D9B559FABAD3B4089D2DEE00B734F40
22	28	Helsinki	60.1695	24.9354	0101000020E6100000ACADD85F76EF384004560E2DB2154E40
23	30	Turku	60.4518	22.2666	0101000020E6100000151DC9E53F443640992A1895D4394E40
24	31	Helsinki	60.1695	24.9354	0101000020E6100000ACADD85F76EF384004560E2DB2154E40
25	32	Jyväskylä	62.2416	25.7594	0101000020E61000001895D40968C23940575BB1BFEC1E4F40
26	34	Tampere	61.4978	23.761	0101000020E6100000894160E5D0C2374072F90FE9B7BF4E40
27	35	Helsinki	60.1695	24.9354	0101000020E6100000ACADD85F76EF384004560E2DB2154E40
28	36	Kuopio	62.8988	27.6784	0101000020E61000003D9B559FABAD3B4089D2DEE00B734F40
29	37	Jyväskylä	62.2416	25.7594	0101000020E61000001895D40968C23940575BB1BFEC1E4F40
30	38	Helsinki	60.1695	24.9354	0101000020E6100000ACADD85F76EF384004560E2DB2154E40
31	39	Helsinki	60.1695	24.9354	0101000020E6100000ACADD85F76EF384004560E2DB2154E40
32	40	Turku	60.4518	22.2666	0101000020E6100000151DC9E53F443640992A1895D4394E40
33	41	Jyväskylä	62.2416	25.7594	0101000020E61000001895D40968C23940575BB1BFEC1E4F40
34	42	Jyväskylä	62.2416	25.7594	0101000020E61000001895D40968C23940575BB1BFEC1E4F40
35	44	Tampere	61.4978	23.761	0101000020E6100000894160E5D0C2374072F90FE9B7BF4E40
36	46	Tampere	61.4978	23.761	0101000020E6100000894160E5D0C2374072F90FE9B7BF4E40
37	47	Kuopio	62.8988	27.6784	0101000020E61000003D9B559FABAD3B4089D2DEE00B734F40
38	48	Turku	60.4518	22.2666	0101000020E6100000151DC9E53F443640992A1895D4394E40
39	49	Tampere	61.4978	23.761	0101000020E6100000894160E5D0C2374072F90FE9B7BF4E40
40	50	Tampere	61.4978	23.761	0101000020E6100000894160E5D0C2374072F90FE9B7BF4E40
41	51	Tampere	61.4978	23.761	0101000020E6100000894160E5D0C2374072F90FE9B7BF4E40
42	52	Tampere	61.4978	23.761	0101000020E6100000894160E5D0C2374072F90FE9B7BF4E40
43	53	Tampere	61.4978	23.761	0101000020E6100000894160E5D0C2374072F90FE9B7BF4E40
44	54	Kuopio	62.8988	27.6784	0101000020E61000003D9B559FABAD3B4089D2DEE00B734F40
45	55	Helsinki	60.1695	24.9354	0101000020E6100000ACADD85F76EF384004560E2DB2154E40
46	56	Helsinki	60.1695	24.9354	0101000020E6100000ACADD85F76EF384004560E2DB2154E40
47	57	Helsinki	60.1695	24.9354	0101000020E6100000ACADD85F76EF384004560E2DB2154E40
48	58	Kuopio	62.8988	27.6784	0101000020E61000003D9B559FABAD3B4089D2DEE00B734F40
49	59	Helsinki	60.1695	24.9354	0101000020E6100000ACADD85F76EF384004560E2DB2154E40
50	60	Tampere	61.4978	23.761	0101000020E6100000894160E5D0C2374072F90FE9B7BF4E40
51	61	Tampere	61.4978	23.761	0101000020E6100000894160E5D0C2374072F90FE9B7BF4E40
52	63	Jyväskylä	62.2416	25.7594	0101000020E61000001895D40968C23940575BB1BFEC1E4F40
53	64	Jyväskylä	62.2416	25.7594	0101000020E61000001895D40968C23940575BB1BFEC1E4F40
54	65	Helsinki	60.1695	24.9354	0101000020E6100000ACADD85F76EF384004560E2DB2154E40
55	66	Turku	60.4518	22.2666	0101000020E6100000151DC9E53F443640992A1895D4394E40
56	67	Kuopio	62.8988	27.6784	0101000020E61000003D9B559FABAD3B4089D2DEE00B734F40
57	68	Tampere	61.4978	23.761	0101000020E6100000894160E5D0C2374072F90FE9B7BF4E40
58	69	Tampere	61.4978	23.761	0101000020E6100000894160E5D0C2374072F90FE9B7BF4E40
59	70	Helsinki	60.1695	24.9354	0101000020E6100000ACADD85F76EF384004560E2DB2154E40
60	71	Tampere	61.4978	23.761	0101000020E6100000894160E5D0C2374072F90FE9B7BF4E40
61	72	Jyväskylä	62.2416	25.7594	0101000020E61000001895D40968C23940575BB1BFEC1E4F40
62	74	Turku	60.4518	22.2666	0101000020E6100000151DC9E53F443640992A1895D4394E40
63	75	Turku	60.4518	22.2666	0101000020E6100000151DC9E53F443640992A1895D4394E40
64	77	Helsinki	60.1695	24.9354	0101000020E6100000ACADD85F76EF384004560E2DB2154E40
65	79	Tampere	61.4978	23.761	0101000020E6100000894160E5D0C2374072F90FE9B7BF4E40
66	80	Turku	60.4518	22.2666	0101000020E6100000151DC9E53F443640992A1895D4394E40
67	81	Tampere	61.4978	23.761	0101000020E6100000894160E5D0C2374072F90FE9B7BF4E40
68	82	Kuopio	62.8988	27.6784	0101000020E61000003D9B559FABAD3B4089D2DEE00B734F40
69	83	Jyväskylä	62.2416	25.7594	0101000020E61000001895D40968C23940575BB1BFEC1E4F40
70	84	Jyväskylä	62.2416	25.7594	0101000020E61000001895D40968C23940575BB1BFEC1E4F40
71	85	Helsinki	60.1695	24.9354	0101000020E6100000ACADD85F76EF384004560E2DB2154E40
72	86	Tampere	61.4978	23.761	0101000020E6100000894160E5D0C2374072F90FE9B7BF4E40
73	89	Tampere	61.4978	23.761	0101000020E6100000894160E5D0C2374072F90FE9B7BF4E40
74	90	Jyväskylä	62.2416	25.7594	0101000020E61000001895D40968C23940575BB1BFEC1E4F40
75	91	Turku	60.4518	22.2666	0101000020E6100000151DC9E53F443640992A1895D4394E40
76	92	Helsinki	60.1695	24.9354	0101000020E6100000ACADD85F76EF384004560E2DB2154E40
77	93	Kuopio	62.8988	27.6784	0101000020E61000003D9B559FABAD3B4089D2DEE00B734F40
78	94	Tampere	61.4978	23.761	0101000020E6100000894160E5D0C2374072F90FE9B7BF4E40
79	95	Jyväskylä	62.2416	25.7594	0101000020E61000001895D40968C23940575BB1BFEC1E4F40
80	96	Jyväskylä	62.2416	25.7594	0101000020E61000001895D40968C23940575BB1BFEC1E4F40
81	97	Kuopio	62.8988	27.6784	0101000020E61000003D9B559FABAD3B4089D2DEE00B734F40
82	98	Turku	60.4518	22.2666	0101000020E6100000151DC9E53F443640992A1895D4394E40
83	99	Kuopio	62.8988	27.6784	0101000020E61000003D9B559FABAD3B4089D2DEE00B734F40
84	100	Jyväskylä	62.2416	25.7594	0101000020E61000001895D40968C23940575BB1BFEC1E4F40
85	101	Helsinki	60.1695	24.9354	0101000020E6100000ACADD85F76EF384004560E2DB2154E40
86	103	Jyväskylä	62.2416	25.7594	0101000020E61000001895D40968C23940575BB1BFEC1E4F40
\.


--
-- TOC entry 4691 (class 0 OID 91886)
-- Dependencies: 236
-- Data for Name: matches; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.matches (id, user_id1, user_id2, compatible_neutered, compatible_gender, compatible_play_style, compatible_size, compatible_distance, requested, rejected, match_score) FROM stdin;
62	7	12	f	f	f	f	f	f	f	\N
45	9	10	t	t	t	t	f	f	f	2
87	9	14	t	t	t	t	f	f	f	10.6
63	8	12	t	f	f	f	f	f	f	\N
1	1	2	t	t	t	f	f	f	f	\N
76	10	13	t	f	f	f	f	f	f	\N
37	1	10	t	t	t	f	t	f	f	\N
64	9	12	t	f	f	f	t	f	f	\N
2	1	3	t	f	f	f	f	f	f	\N
77	11	13	f	f	f	f	f	f	f	\N
3	2	3	t	f	f	f	t	f	f	\N
26	5	8	t	f	f	f	f	f	f	\N
27	6	8	f	f	f	f	f	f	f	\N
28	7	8	f	f	f	f	f	f	f	\N
79	1	14	t	f	f	f	f	f	f	\N
22	1	8	t	f	f	f	f	f	f	\N
68	2	13	t	f	f	f	f	f	f	\N
23	2	8	t	f	f	f	t	f	f	\N
5	2	4	t	t	t	t	f	f	f	6.1
6	3	4	f	f	f	f	f	f	f	\N
24	3	8	f	f	f	f	t	f	f	\N
38	2	10	t	t	t	t	f	f	f	1.6
39	3	10	f	f	f	f	f	f	f	\N
4	1	4	t	t	t	f	t	f	f	\N
103	12	15	f	f	f	f	f	f	f	\N
65	10	12	t	t	t	t	f	f	f	1.1
25	4	8	t	t	t	t	f	f	f	3
7	1	5	t	t	t	t	t	f	f	0.1
8	2	5	t	t	t	f	f	f	f	\N
78	12	13	t	f	f	f	f	f	f	\N
9	3	5	t	f	f	f	f	f	f	\N
72	6	13	f	f	f	f	f	f	f	\N
41	5	10	t	t	t	t	t	f	f	7
43	7	10	f	f	f	f	f	f	f	\N
10	4	5	t	t	t	f	t	f	f	\N
84	6	14	t	f	f	f	f	f	f	\N
82	4	14	t	f	f	f	f	f	f	\N
56	1	12	t	t	t	t	f	f	f	3
58	3	12	f	f	f	f	f	f	f	\N
44	8	10	t	t	t	t	f	f	f	10.4
32	4	9	t	t	t	f	f	f	f	\N
12	2	6	t	t	t	t	f	f	f	2.1
33	5	9	t	f	f	f	f	f	f	\N
13	3	6	t	t	t	t	f	f	f	6.4
14	4	6	f	f	f	f	t	f	f	\N
34	6	9	t	t	t	t	f	f	f	2.1
15	5	6	t	t	t	t	t	f	f	4.1
112	7	16	f	f	f	f	f	f	f	\N
35	7	9	t	t	t	t	f	f	f	11
11	1	6	t	t	t	f	t	f	f	\N
75	9	13	t	t	t	f	f	f	f	\N
83	5	14	t	f	f	f	f	f	f	\N
59	4	12	t	t	t	f	f	f	f	\N
66	11	12	f	f	f	f	t	f	f	\N
36	8	9	t	t	t	t	f	f	f	4.8
67	1	13	t	f	f	f	f	f	f	\N
30	2	9	t	f	f	f	f	f	f	\N
57	2	12	t	t	t	f	f	f	f	\N
21	6	7	t	t	t	t	f	f	f	2.1
31	3	9	t	t	t	t	f	f	f	0.4
29	1	9	t	f	f	f	f	f	f	\N
16	1	7	t	t	t	t	f	f	f	1.1
17	2	7	t	t	t	f	f	f	f	\N
18	3	7	t	t	t	t	f	f	f	0.2
19	4	7	f	f	f	f	f	f	f	\N
20	5	7	t	t	t	t	f	f	f	7
60	5	12	t	t	t	t	f	f	f	4.1
46	1	11	t	f	f	f	f	f	f	\N
61	6	12	f	f	f	f	f	f	f	\N
48	3	11	f	f	f	f	f	f	f	\N
49	4	11	f	f	f	f	f	f	f	\N
52	7	11	f	f	f	f	f	f	f	\N
53	8	11	f	f	f	f	f	f	f	\N
55	10	11	f	f	f	f	f	f	f	\N
40	4	10	t	t	t	t	t	f	f	4.2
42	6	10	f	f	f	f	t	f	f	\N
47	2	11	t	f	f	f	f	f	f	\N
50	5	11	t	f	f	f	f	f	f	\N
51	6	11	f	f	f	f	f	f	f	\N
54	9	11	t	f	f	f	t	f	f	\N
100	9	15	t	t	t	f	f	f	f	\N
85	7	14	t	f	f	f	t	f	f	\N
101	10	15	f	f	f	f	f	f	f	\N
102	11	15	f	f	f	f	f	f	f	\N
69	3	13	f	f	f	f	f	f	f	\N
98	7	15	t	f	f	f	f	f	f	\N
70	4	13	t	f	f	f	f	f	f	\N
90	12	14	t	f	f	f	f	f	f	\N
71	5	13	t	f	f	f	f	f	f	\N
73	7	13	f	f	f	f	f	f	f	\N
104	13	15	f	f	f	f	f	f	f	\N
74	8	13	t	t	t	f	f	f	f	\N
105	14	15	t	t	t	f	f	f	f	\N
86	8	14	t	t	t	t	f	f	f	7
88	10	14	t	f	f	f	f	f	f	\N
91	13	14	t	f	f	f	\N	f	f	\N
80	2	14	t	f	f	f	f	f	f	\N
89	11	14	t	f	f	f	f	f	f	\N
81	3	14	t	t	t	t	f	f	f	2
96	5	15	t	f	f	f	f	f	f	\N
92	1	15	t	f	f	f	f	f	f	\N
94	3	15	t	t	t	t	f	f	f	4.2
95	4	15	f	f	f	f	f	f	f	\N
99	8	15	f	f	f	f	f	f	f	\N
93	2	15	t	f	f	f	f	f	f	\N
97	6	15	t	f	f	f	f	f	f	\N
107	2	16	t	f	f	f	f	f	f	\N
115	10	16	t	t	t	t	f	f	f	10.6
120	15	16	f	f	f	f	f	f	f	\N
118	13	16	t	t	t	f	f	f	f	\N
114	9	16	t	t	t	t	f	f	f	0.2
116	11	16	f	f	f	f	f	f	f	\N
108	3	16	f	f	f	f	f	f	f	\N
106	1	16	t	f	f	f	f	f	f	\N
109	4	16	t	t	f	f	f	f	f	\N
111	6	16	f	f	f	f	f	f	f	\N
110	5	16	t	f	f	f	f	f	f	\N
113	8	16	t	t	t	t	f	f	f	8.1
119	14	16	t	t	f	f	f	f	f	\N
117	12	16	t	f	f	f	f	f	f	\N
121	1	17	t	f	f	f	f	f	f	\N
184	13	20	t	f	f	f	\N	f	f	\N
163	10	19	t	t	t	t	f	f	f	1.4
203	13	21	f	f	f	f	f	f	f	\N
152	16	18	t	t	t	t	\N	f	f	10.1
164	11	19	t	f	f	f	f	f	f	\N
205	15	21	f	f	f	f	f	f	f	\N
199	9	21	t	t	t	t	f	f	f	7
206	16	21	f	f	f	f	f	f	f	\N
153	17	18	t	t	t	t	t	f	f	10.4
187	16	20	t	t	t	t	\N	f	f	10.1
122	2	17	t	f	f	f	f	f	f	\N
138	2	18	t	f	f	f	f	f	f	\N
123	3	17	t	f	f	f	f	f	f	\N
166	13	19	t	t	t	t	f	f	f	6.1
193	3	21	f	f	f	f	f	f	f	\N
144	8	18	t	t	f	f	f	f	f	\N
188	17	20	t	f	f	f	f	f	f	\N
126	6	17	t	t	t	t	f	f	f	10.1
149	13	18	t	f	f	f	\N	f	f	\N
128	8	17	t	f	f	f	f	f	f	\N
171	18	19	t	t	f	f	f	f	f	\N
129	9	17	t	f	f	f	f	f	f	\N
150	14	18	t	f	f	f	t	f	f	\N
130	10	17	t	t	t	t	f	f	f	9
136	16	17	t	f	f	f	\N	f	f	\N
125	5	17	t	f	f	f	f	f	f	\N
131	11	17	t	f	f	f	f	f	f	\N
124	4	17	t	t	t	t	f	f	f	8.4
127	7	17	t	t	t	t	t	f	f	1
132	12	17	t	f	f	f	f	f	f	\N
133	13	17	t	t	t	f	\N	f	f	\N
134	14	17	t	f	f	f	t	f	f	\N
135	15	17	t	f	f	f	\N	f	f	\N
157	4	19	t	t	t	t	f	f	f	9
158	5	19	t	f	f	f	f	f	f	\N
167	14	19	t	t	t	f	f	f	f	\N
139	3	18	f	f	f	f	f	f	f	\N
142	6	18	f	f	f	f	f	f	f	\N
147	11	18	f	f	f	f	f	f	f	\N
148	12	18	t	f	f	f	f	f	f	\N
168	15	19	t	t	t	t	f	f	f	8.4
140	4	18	t	f	f	f	f	f	f	\N
143	7	18	f	f	f	f	t	f	f	\N
146	10	18	t	f	f	f	f	f	f	\N
170	17	19	t	f	f	f	f	f	f	\N
137	1	18	t	f	f	f	f	f	f	\N
141	5	18	t	f	f	f	f	f	f	\N
194	4	21	f	f	f	f	f	f	f	\N
209	19	21	t	t	t	f	f	f	f	\N
189	18	20	t	f	f	f	f	f	f	\N
156	3	19	t	t	t	t	f	f	f	7
145	9	18	t	t	t	t	f	f	f	0.4
151	15	18	f	f	f	f	\N	f	f	\N
197	7	21	f	f	f	f	f	f	f	\N
200	10	21	f	f	f	f	f	f	f	\N
173	2	20	t	f	f	f	t	f	f	\N
196	6	21	f	f	f	f	f	f	f	\N
204	14	21	t	f	f	f	f	f	f	\N
159	6	19	t	t	t	t	f	f	f	1.1
176	5	20	t	f	f	f	f	f	f	\N
208	18	21	f	f	f	f	f	f	f	\N
210	20	21	f	f	f	f	f	f	f	\N
160	7	19	t	t	t	f	f	f	f	\N
198	8	21	f	f	f	f	f	f	f	\N
179	8	20	t	t	f	f	t	f	f	\N
182	11	20	f	f	f	f	f	f	f	\N
161	8	19	t	t	t	t	f	f	f	1
169	16	19	t	t	f	f	f	f	f	\N
207	17	21	t	t	t	t	f	f	f	3
155	2	19	t	f	f	f	f	f	f	\N
165	12	19	t	f	f	f	f	f	f	\N
186	15	20	f	f	f	f	\N	f	f	\N
154	1	19	t	f	f	f	f	f	f	\N
172	1	20	t	f	f	f	f	f	f	\N
174	3	20	f	f	f	f	t	f	f	\N
162	9	19	t	t	t	f	f	f	f	\N
183	12	20	t	f	f	f	f	f	f	\N
190	19	20	t	t	f	f	\N	f	f	\N
185	14	20	t	t	f	f	f	f	f	\N
177	6	20	f	f	f	f	f	f	f	\N
178	7	20	f	f	f	f	f	f	f	\N
180	9	20	t	t	t	t	f	f	f	0.4
175	4	20	t	f	f	f	f	f	f	\N
181	10	20	t	f	f	f	f	f	f	\N
191	1	21	t	t	t	t	f	f	f	0.1
195	5	21	t	t	t	t	f	f	f	11
192	2	21	t	t	t	f	f	f	f	\N
201	11	21	f	f	f	f	f	f	f	\N
202	12	21	f	f	f	f	f	f	f	\N
213	3	22	t	t	t	f	f	f	f	\N
216	6	22	t	t	t	f	f	f	f	\N
224	14	22	t	f	f	f	f	f	f	\N
220	10	22	f	f	f	f	f	f	f	\N
212	2	22	t	t	t	f	f	f	f	\N
219	9	22	t	t	t	t	t	f	f	0.1
222	12	22	f	f	f	f	t	f	f	\N
229	19	22	t	t	t	f	\N	f	f	\N
226	16	22	f	f	f	f	\N	f	f	\N
211	1	22	t	t	t	t	f	f	f	1
217	7	22	t	t	t	t	f	f	f	0.1
218	8	22	f	f	f	f	f	f	f	\N
227	17	22	t	t	t	f	f	f	f	\N
225	15	22	t	f	f	f	\N	f	f	\N
214	4	22	f	f	f	f	f	f	f	\N
221	11	22	f	f	f	f	t	f	f	\N
215	5	22	t	t	t	t	f	f	f	0.1
228	18	22	f	f	f	f	f	f	f	\N
223	13	22	f	f	f	f	\N	f	f	\N
231	21	22	f	f	f	f	\N	f	f	\N
230	20	22	f	f	f	f	f	f	f	\N
331	6	27	f	f	f	f	f	f	f	\N
259	6	24	t	t	t	t	f	f	f	1.1
261	8	24	f	f	f	f	f	f	f	\N
286	10	25	t	t	t	t	f	f	f	1.6
304	4	26	f	f	f	f	f	f	f	\N
333	8	27	f	f	f	f	f	f	f	\N
262	9	24	t	t	t	f	f	f	f	\N
263	10	24	f	f	f	f	f	f	f	\N
265	12	24	f	f	f	f	f	f	f	\N
318	18	26	f	f	f	f	f	f	f	\N
270	17	24	t	f	f	f	f	f	f	\N
273	20	24	f	f	f	f	f	f	f	\N
320	20	26	f	f	f	f	f	f	f	\N
255	2	24	t	f	f	f	f	f	f	\N
257	4	24	f	f	f	f	f	f	f	\N
308	8	26	f	f	f	f	f	f	f	\N
323	23	26	f	f	f	f	f	f	f	\N
288	12	25	t	t	t	f	f	f	f	\N
260	7	24	t	t	t	f	f	f	f	\N
336	11	27	f	f	f	f	f	f	f	\N
334	9	27	t	t	t	f	f	f	f	\N
341	16	27	f	f	f	f	\N	f	f	\N
242	11	23	f	f	f	f	t	f	f	\N
310	10	26	f	f	f	f	f	f	f	\N
251	20	23	t	f	f	f	f	f	f	\N
268	15	24	t	t	t	t	f	f	f	9
271	18	24	f	f	f	f	f	f	f	\N
338	13	27	f	f	f	f	\N	f	f	\N
301	1	26	t	t	t	f	f	f	f	\N
243	12	23	t	t	t	t	t	f	f	10.1
289	13	25	t	f	f	f	\N	f	f	\N
244	13	23	t	f	f	f	\N	f	f	\N
275	22	24	t	t	t	f	f	f	f	\N
248	17	23	t	f	f	f	f	f	f	\N
252	21	23	f	f	f	f	\N	f	f	\N
253	22	23	f	f	f	f	t	f	f	\N
297	21	25	f	f	f	f	\N	f	f	\N
254	1	24	t	f	f	f	f	f	f	\N
233	2	23	t	t	f	f	f	f	f	\N
327	2	27	t	f	f	f	f	f	f	\N
340	15	27	f	f	f	f	\N	f	f	\N
267	14	24	t	t	t	f	f	f	f	\N
241	10	23	t	t	t	t	f	f	f	2.4
276	23	24	f	f	f	f	f	f	f	\N
247	16	23	t	f	f	f	\N	f	f	\N
264	11	24	f	f	f	f	f	f	f	\N
249	18	23	t	f	f	f	f	f	f	\N
337	12	27	f	f	f	f	f	f	f	\N
250	19	23	t	f	f	f	\N	f	f	\N
258	5	24	t	f	f	f	f	f	f	\N
266	13	24	f	f	f	f	f	f	f	\N
236	5	23	t	t	f	f	f	f	f	\N
269	16	24	f	f	f	f	f	f	f	\N
245	14	23	t	f	f	f	f	f	f	\N
326	1	27	t	f	f	f	f	f	f	\N
303	3	26	t	t	t	t	f	f	f	11
235	4	23	t	t	f	f	f	f	f	\N
237	6	23	f	f	f	f	f	f	f	\N
238	7	23	f	f	f	f	f	f	f	\N
239	8	23	t	f	f	f	f	f	f	\N
339	14	27	t	t	t	f	t	f	f	\N
240	9	23	t	f	f	f	t	f	f	\N
246	15	23	f	f	f	f	\N	f	f	\N
272	19	24	t	t	t	t	f	f	f	10.8
274	21	24	f	f	f	f	f	f	f	\N
294	18	25	t	f	f	f	f	f	f	\N
279	3	25	f	f	f	f	f	f	f	\N
232	1	23	t	t	t	t	f	f	f	1.1
234	3	23	f	f	f	f	f	f	f	\N
283	7	25	f	f	f	f	f	f	f	\N
277	1	25	t	t	t	f	f	f	f	\N
292	16	25	t	f	f	f	\N	f	f	\N
256	3	24	t	t	t	t	f	f	f	6.4
282	6	25	f	f	f	f	f	f	f	\N
295	19	25	t	f	f	f	\N	f	f	\N
324	24	26	t	t	t	t	\N	f	f	8.6
284	8	25	t	f	f	f	f	f	f	\N
329	4	27	f	f	f	f	f	f	f	\N
278	2	25	t	t	t	t	f	f	f	9
335	10	27	f	f	f	f	f	f	f	\N
299	23	25	t	t	t	f	f	f	f	\N
300	24	25	f	f	f	f	\N	f	f	\N
281	5	25	t	t	t	f	f	f	f	\N
291	15	25	f	f	f	f	\N	f	f	\N
293	17	25	t	f	f	f	f	f	f	\N
309	9	26	t	t	t	f	f	f	f	\N
285	9	25	t	f	f	f	f	f	f	\N
296	20	25	t	f	f	f	f	f	f	\N
298	22	25	f	f	f	f	f	f	f	\N
314	14	26	t	f	f	f	f	f	f	\N
302	2	26	t	t	f	f	f	f	f	\N
321	21	26	f	f	f	f	\N	f	f	\N
325	25	26	f	f	f	f	t	f	f	\N
306	6	26	t	t	f	f	f	f	f	\N
280	4	25	t	t	t	t	f	f	f	10.1
287	11	25	f	f	f	f	f	f	f	\N
313	13	26	f	f	f	f	\N	f	f	\N
290	14	25	t	f	f	f	f	f	f	\N
311	11	26	f	f	f	f	f	f	f	\N
315	15	26	t	f	f	f	\N	f	f	\N
305	5	26	t	t	f	f	f	f	f	\N
317	17	26	t	t	t	t	f	f	f	8.4
307	7	26	t	t	f	f	f	f	f	\N
312	12	26	f	f	f	f	f	f	f	\N
319	19	26	t	t	f	f	\N	f	f	\N
316	16	26	f	f	f	f	\N	f	f	\N
322	22	26	t	t	f	f	f	f	f	\N
328	3	27	f	f	f	f	f	f	f	\N
330	5	27	t	f	f	f	f	f	f	\N
332	7	27	f	f	f	f	t	f	f	\N
352	1	28	t	f	f	f	f	f	f	\N
364	13	28	t	t	t	t	\N	f	f	10.1
410	4	30	t	t	t	f	f	f	f	\N
353	2	28	t	f	f	f	f	f	f	\N
351	26	27	f	f	f	f	f	f	f	\N
355	4	28	t	t	f	f	f	f	f	\N
417	11	30	t	f	f	f	f	f	f	\N
344	19	27	t	t	t	t	\N	f	f	8.8
347	22	27	f	f	f	f	f	f	f	\N
370	19	28	t	f	f	f	\N	f	f	\N
342	17	27	t	f	f	f	t	f	f	\N
348	23	27	f	f	f	f	f	f	f	\N
350	25	27	f	f	f	f	f	f	f	\N
345	20	27	f	f	f	f	f	f	f	\N
349	24	27	f	f	f	f	\N	f	f	\N
343	18	27	f	f	f	f	t	f	f	\N
346	21	27	f	f	f	f	\N	f	f	\N
365	14	28	t	f	f	f	f	f	f	\N
356	5	28	t	f	f	f	f	f	f	\N
358	7	28	f	f	f	f	f	f	f	\N
366	15	28	f	f	f	f	\N	f	f	\N
368	17	28	t	f	f	f	f	f	f	\N
373	22	28	f	f	f	f	f	f	f	\N
377	26	28	f	f	f	f	t	f	f	\N
354	3	28	f	f	f	f	f	f	f	\N
357	6	28	f	f	f	f	f	f	f	\N
360	9	28	t	f	f	f	f	f	f	\N
371	20	28	t	f	f	f	f	f	f	\N
359	8	28	t	f	f	f	f	f	f	\N
362	11	28	f	f	f	f	f	f	f	\N
372	21	28	f	f	f	f	\N	f	f	\N
374	23	28	t	f	f	f	f	f	f	\N
376	25	28	t	f	f	f	t	f	f	\N
361	10	28	t	t	f	f	f	f	f	\N
381	3	29	f	f	f	f	f	f	f	\N
363	12	28	t	f	f	f	f	f	f	\N
398	20	29	f	f	f	f	f	f	f	\N
367	16	28	t	f	f	f	\N	f	f	\N
399	21	29	f	f	f	f	f	f	f	\N
404	26	29	f	f	f	f	f	f	f	\N
419	13	30	t	f	f	f	\N	f	f	\N
369	18	28	t	t	t	f	f	f	f	\N
375	24	28	f	f	f	f	\N	f	f	\N
378	27	28	f	f	f	f	f	f	f	\N
379	1	29	t	f	f	f	f	f	f	\N
380	2	29	t	f	f	f	f	f	f	\N
384	6	29	f	f	f	f	f	f	f	\N
388	10	29	f	f	f	f	f	f	f	\N
400	22	29	f	f	f	f	f	f	f	\N
389	11	29	f	f	f	f	f	f	f	\N
392	14	29	t	f	f	f	f	f	f	\N
386	8	29	f	f	f	f	f	f	f	\N
396	18	29	f	f	f	f	f	f	f	\N
390	12	29	f	f	f	f	f	f	f	\N
391	13	29	f	f	f	f	f	f	f	\N
393	15	29	f	f	f	f	f	f	f	\N
397	19	29	t	f	f	f	f	f	f	\N
401	23	29	f	f	f	f	f	f	f	\N
403	25	29	f	f	f	f	f	f	f	\N
405	27	29	f	f	f	f	f	f	f	\N
416	10	30	t	t	t	f	f	f	f	\N
383	5	29	t	f	f	f	f	f	f	\N
408	2	30	t	t	t	f	t	f	f	\N
387	9	29	t	f	f	f	f	f	f	\N
395	17	29	t	f	f	f	f	f	f	\N
402	24	29	f	f	f	f	f	f	f	\N
394	16	29	f	f	f	f	f	f	f	\N
406	28	29	f	f	f	f	f	f	f	\N
382	4	29	f	f	f	f	f	f	f	\N
385	7	29	f	f	f	f	f	f	f	\N
420	14	30	t	f	f	f	f	f	f	\N
412	6	30	t	t	t	f	f	f	f	\N
409	3	30	t	f	f	f	t	f	f	\N
413	7	30	t	t	t	t	f	f	f	4.6
415	9	30	t	f	f	f	f	f	f	\N
423	17	30	t	f	f	f	f	f	f	\N
411	5	30	t	t	t	t	f	f	f	2.6
418	12	30	t	t	t	t	f	f	f	8.1
414	8	30	t	f	f	f	t	f	f	\N
422	16	30	t	f	f	f	\N	f	f	\N
407	1	30	t	t	t	t	f	f	f	6.1
421	15	30	t	f	f	f	\N	f	f	\N
527	31	33	t	f	f	f	f	f	f	\N
508	12	33	f	f	f	f	f	f	f	\N
481	16	32	t	t	t	t	\N	f	f	10.1
488	23	32	t	f	f	f	t	f	f	\N
449	14	31	t	t	t	t	f	f	f	1
509	13	33	f	f	f	f	f	f	f	\N
491	26	32	f	f	f	f	f	f	f	\N
498	2	33	t	f	f	f	f	f	f	\N
450	15	31	t	t	t	f	\N	f	f	\N
525	29	33	f	f	f	f	f	f	f	\N
515	19	33	t	t	f	f	f	f	f	\N
484	19	32	t	t	t	t	\N	f	f	5
454	19	31	t	t	t	f	\N	f	f	\N
430	24	30	t	f	f	f	\N	f	f	\N
455	20	31	f	f	f	f	f	f	f	\N
426	20	30	t	f	f	f	t	f	f	\N
458	23	31	f	f	f	f	f	f	f	\N
442	7	31	t	f	f	f	f	f	f	\N
431	25	30	t	t	t	f	f	f	f	\N
495	30	32	t	f	f	f	f	f	f	\N
427	21	30	t	t	t	t	\N	f	f	2.4
444	9	31	t	t	t	t	f	f	f	0.4
425	19	30	t	f	f	f	\N	f	f	\N
446	11	31	f	f	f	f	f	f	f	\N
461	26	31	t	f	f	f	t	f	f	\N
445	10	31	f	f	f	f	f	f	f	\N
428	22	30	t	t	t	t	f	f	f	0.1
434	28	30	t	f	f	f	f	f	f	\N
457	22	31	t	f	f	f	f	f	f	\N
424	18	30	t	f	f	f	f	f	f	\N
460	25	31	f	f	f	f	t	f	f	\N
435	29	30	t	f	f	f	\N	f	f	\N
465	30	31	t	f	f	f	f	f	f	\N
528	32	33	f	f	f	f	f	f	f	\N
432	26	30	t	t	t	f	f	f	f	\N
437	2	31	t	f	f	f	f	f	f	\N
439	4	31	f	f	f	f	f	f	f	\N
448	13	31	f	f	f	f	\N	f	f	\N
429	23	30	t	t	t	t	f	f	f	5
452	17	31	t	f	f	f	f	f	f	\N
433	27	30	t	f	f	f	f	f	f	\N
468	3	32	f	f	f	f	f	f	f	\N
469	4	32	t	f	f	f	f	f	f	\N
473	8	32	t	t	t	t	f	f	f	9
478	13	32	t	f	f	f	\N	f	f	\N
474	9	32	t	t	t	t	t	f	f	0.4
486	21	32	f	f	f	f	\N	f	f	\N
487	22	32	f	f	f	f	t	f	f	\N
440	5	31	t	f	f	f	f	f	f	\N
483	18	32	t	f	f	f	f	f	f	\N
490	25	32	t	f	f	f	f	f	f	\N
471	6	32	f	f	f	f	f	f	f	\N
496	31	32	f	f	f	f	f	f	f	\N
477	12	32	t	f	f	f	t	f	f	\N
494	29	32	f	f	f	f	\N	f	f	\N
467	2	32	t	f	f	f	f	f	f	\N
451	16	31	f	f	f	f	\N	f	f	\N
456	21	31	f	f	f	f	\N	f	f	\N
443	8	31	f	f	f	f	f	f	f	\N
453	18	31	f	f	f	f	f	f	f	\N
464	29	31	f	f	f	f	\N	f	f	\N
441	6	31	t	f	f	f	f	f	f	\N
447	12	31	f	f	f	f	f	f	f	\N
462	27	31	f	f	f	f	f	f	f	\N
475	10	32	t	f	f	f	f	f	f	\N
436	1	31	t	f	f	f	f	f	f	\N
482	17	32	t	f	f	f	f	f	f	\N
438	3	31	t	t	t	f	f	f	f	\N
493	28	32	t	f	f	f	f	f	f	\N
489	24	32	f	f	f	f	\N	f	f	\N
492	27	32	f	f	f	f	f	f	f	\N
459	24	31	t	t	t	f	\N	f	f	\N
463	28	31	f	f	f	f	t	f	f	\N
466	1	32	t	f	f	f	f	f	f	\N
470	5	32	t	f	f	f	f	f	f	\N
472	7	32	f	f	f	f	f	f	f	\N
476	11	32	f	f	f	f	t	f	f	\N
480	15	32	f	f	f	f	\N	f	f	\N
485	20	32	t	t	t	t	f	f	f	11
513	17	33	t	t	t	t	f	f	f	10.6
502	6	33	t	f	f	f	f	f	f	\N
523	27	33	f	f	f	f	f	f	f	\N
524	28	33	f	f	f	f	f	f	f	\N
479	14	32	t	t	t	t	f	f	f	2
518	22	33	t	f	f	f	f	f	f	\N
512	16	33	f	f	f	f	f	f	f	\N
499	3	33	t	t	t	t	f	f	f	8.8
526	30	33	t	f	f	f	f	f	f	\N
504	8	33	f	f	f	f	f	f	f	\N
516	20	33	f	f	f	f	f	f	f	\N
517	21	33	f	f	f	f	f	f	f	\N
522	26	33	t	f	f	f	f	f	f	\N
520	24	33	t	t	t	t	f	f	f	5
505	9	33	t	t	t	t	f	f	f	0.8
510	14	33	t	f	f	f	f	f	f	\N
500	4	33	f	f	f	f	f	f	f	\N
497	1	33	t	f	f	f	f	f	f	\N
506	10	33	f	f	f	f	f	f	f	\N
511	15	33	t	f	f	f	f	f	f	\N
514	18	33	f	f	f	f	f	f	f	\N
521	25	33	f	f	f	f	f	f	f	\N
532	4	34	f	f	f	f	t	f	f	\N
501	5	33	t	f	f	f	f	f	f	\N
531	3	34	t	t	t	t	f	f	f	2.4
503	7	33	t	f	f	f	f	f	f	\N
507	11	33	f	f	f	f	f	f	f	\N
519	23	33	f	f	f	f	f	f	f	\N
529	1	34	t	t	t	f	t	f	f	\N
530	2	34	t	t	t	t	f	f	f	0.1
535	7	34	t	t	t	t	f	f	f	4.1
533	5	34	t	t	t	t	t	f	f	10.1
534	6	34	t	t	t	t	t	f	f	7
569	8	35	f	f	f	f	f	f	f	\N
599	4	36	t	f	f	f	f	f	f	\N
620	25	36	t	f	f	f	f	f	f	\N
570	9	35	t	f	f	f	f	f	f	\N
603	8	36	t	t	t	t	f	f	f	11
581	20	35	f	f	f	f	f	f	f	\N
582	21	35	f	f	f	f	\N	f	f	\N
584	23	35	f	f	f	f	f	f	f	\N
614	19	36	t	t	t	t	\N	f	f	2
588	27	35	f	f	f	f	f	f	f	\N
538	10	34	f	f	f	f	t	f	f	\N
540	12	34	f	f	f	f	f	f	f	\N
621	26	36	t	f	f	f	f	f	f	\N
604	9	36	t	t	t	t	f	f	f	4.6
545	17	34	t	t	t	t	f	f	f	4.1
557	29	34	f	f	f	f	\N	f	f	\N
560	32	34	f	f	f	f	f	f	f	\N
615	20	36	t	t	t	t	f	f	f	5
607	12	36	t	f	f	f	f	f	f	\N
624	29	36	t	f	f	f	\N	f	f	\N
547	19	34	t	t	t	t	\N	f	f	1.2
549	21	34	f	f	f	f	\N	f	f	\N
555	27	34	f	f	f	f	f	f	f	\N
622	27	36	t	t	t	t	t	f	f	2.8
595	34	35	t	t	t	t	f	f	f	8.1
537	9	34	t	t	t	t	f	f	f	4.1
546	18	34	f	f	f	f	f	f	f	\N
553	25	34	f	f	f	f	f	f	f	\N
563	2	35	t	f	f	f	f	f	f	\N
554	26	34	t	t	t	t	f	f	f	2.2
539	11	34	f	f	f	f	f	f	f	\N
542	14	34	t	f	f	f	f	f	f	\N
544	16	34	f	f	f	f	\N	f	f	\N
548	20	34	f	f	f	f	f	f	f	\N
576	15	35	t	f	f	f	\N	f	f	\N
580	19	35	t	f	f	f	\N	f	f	\N
550	22	34	t	t	t	f	f	f	f	\N
583	22	35	t	t	t	f	f	f	f	\N
565	4	35	f	f	f	f	f	f	f	\N
558	30	34	t	t	t	f	f	f	f	\N
551	23	34	f	f	f	f	f	f	f	\N
536	8	34	f	f	f	f	f	f	f	\N
592	31	35	t	f	f	f	t	f	f	\N
610	15	36	t	t	t	t	\N	f	f	0.4
568	7	35	t	t	t	t	f	f	f	2
552	24	34	t	t	t	t	\N	f	f	1.1
571	10	35	f	f	f	f	f	f	f	\N
561	33	34	t	f	f	f	\N	f	f	\N
541	13	34	f	f	f	f	\N	f	f	\N
586	25	35	f	f	f	f	t	f	f	\N
543	15	34	t	f	f	f	\N	f	f	\N
556	28	34	f	f	f	f	f	f	f	\N
590	29	35	f	f	f	f	\N	f	f	\N
559	31	34	t	f	f	f	f	f	f	\N
593	32	35	f	f	f	f	f	f	f	\N
579	18	35	f	f	f	f	f	f	f	\N
628	33	36	t	f	f	f	\N	f	f	\N
591	30	35	t	f	f	f	f	f	f	\N
619	24	36	t	t	t	t	\N	f	f	1.8
567	6	35	t	t	t	t	f	f	f	10.1
594	33	35	t	t	f	f	\N	f	f	\N
577	16	35	f	f	f	f	\N	f	f	\N
562	1	35	t	f	f	f	f	f	f	\N
572	11	35	f	f	f	f	f	f	f	\N
573	12	35	f	f	f	f	f	f	f	\N
575	14	35	t	f	f	f	f	f	f	\N
589	28	35	f	f	f	f	t	f	f	\N
597	2	36	t	f	f	f	f	f	f	\N
587	26	35	t	t	f	f	t	f	f	\N
613	18	36	t	f	f	f	t	f	f	\N
564	3	35	t	f	f	f	f	f	f	\N
596	1	36	t	f	f	f	f	f	f	\N
566	5	35	t	f	f	f	f	f	f	\N
574	13	35	f	f	f	f	\N	f	f	\N
616	21	36	t	f	f	f	\N	f	f	\N
578	17	35	t	f	f	f	f	f	f	\N
606	11	36	t	f	f	f	f	f	f	\N
585	24	35	t	f	f	f	\N	f	f	\N
626	31	36	t	t	t	f	f	f	f	\N
611	16	36	t	t	t	t	\N	f	f	4.1
612	17	36	t	f	f	f	t	f	f	\N
617	22	36	t	f	f	f	f	f	f	\N
627	32	36	t	t	t	t	f	f	f	5
618	23	36	t	f	f	f	f	f	f	\N
605	10	36	t	f	f	f	f	f	f	\N
601	6	36	t	f	f	f	f	f	f	\N
608	13	36	t	f	f	f	\N	f	f	\N
602	7	36	t	f	f	f	t	f	f	\N
623	28	36	t	f	f	f	f	f	f	\N
609	14	36	t	t	t	t	t	f	f	9
625	30	36	t	f	f	f	f	f	f	\N
600	5	36	t	f	f	f	f	f	f	\N
598	3	36	t	t	t	t	f	f	f	3
642	12	37	f	f	f	f	t	f	f	\N
629	34	36	t	f	f	f	f	f	f	\N
630	35	36	t	f	f	f	f	f	f	\N
667	1	38	t	t	t	f	f	f	f	\N
673	7	38	f	f	f	f	f	f	f	\N
674	8	38	f	f	f	f	f	f	f	\N
689	23	38	f	f	f	f	f	f	f	\N
647	17	37	t	t	t	t	f	f	f	10.6
691	25	38	f	f	f	f	t	f	f	\N
685	19	38	t	f	f	f	\N	f	f	\N
668	2	38	t	t	t	t	f	f	f	4.1
633	3	37	t	t	t	t	f	f	f	8.8
672	6	38	f	f	f	f	f	f	f	\N
679	13	38	f	f	f	f	\N	f	f	\N
684	18	38	f	f	f	f	f	f	f	\N
634	4	37	f	f	f	f	f	f	f	\N
669	3	38	f	f	f	f	f	f	f	\N
645	15	37	t	f	f	f	\N	f	f	\N
640	10	37	f	f	f	f	f	f	f	\N
646	16	37	f	f	f	f	\N	f	f	\N
658	28	37	f	f	f	f	f	f	f	\N
632	2	37	t	f	f	f	f	f	f	\N
671	5	38	t	t	t	t	f	f	f	1.1
687	21	38	f	f	f	f	\N	f	f	\N
677	11	38	f	f	f	f	f	f	f	\N
636	6	37	t	f	f	f	f	f	f	\N
690	24	38	f	f	f	f	\N	f	f	\N
693	27	38	f	f	f	f	f	f	f	\N
670	4	38	f	f	f	f	f	f	f	\N
676	10	38	f	f	f	f	f	f	f	\N
639	9	37	t	t	t	t	t	f	f	0.8
660	30	37	t	f	f	f	f	f	f	\N
651	21	37	f	f	f	f	\N	f	f	\N
654	24	37	t	t	t	t	\N	f	f	5
653	23	37	f	f	f	f	t	f	f	\N
656	26	37	t	f	f	f	f	f	f	\N
659	29	37	f	f	f	f	\N	f	f	\N
663	33	37	t	f	f	f	\N	f	f	\N
664	34	37	t	f	f	f	f	f	f	\N
637	7	37	t	f	f	f	f	f	f	\N
644	14	37	t	f	f	f	f	f	f	\N
649	19	37	t	t	t	t	\N	f	f	5
643	13	37	f	f	f	f	\N	f	f	\N
666	36	37	t	f	f	f	f	f	f	\N
631	1	37	t	f	f	f	f	f	f	\N
662	32	37	f	f	f	f	t	f	f	\N
665	35	37	t	t	t	t	f	f	f	8.4
635	5	37	t	f	f	f	f	f	f	\N
655	25	37	f	f	f	f	f	f	f	\N
661	31	37	t	f	f	f	f	f	f	\N
648	18	37	f	f	f	f	f	f	f	\N
650	20	37	f	f	f	f	f	f	f	\N
652	22	37	t	f	f	f	t	f	f	\N
657	27	37	f	f	f	f	f	f	f	\N
638	8	37	f	f	f	f	f	f	f	\N
641	11	37	f	f	f	f	t	f	f	\N
680	14	38	t	f	f	f	f	f	f	\N
688	22	38	f	f	f	f	f	f	f	\N
675	9	38	t	f	f	f	f	f	f	\N
682	16	38	f	f	f	f	\N	f	f	\N
692	26	38	f	f	f	f	t	f	f	\N
678	12	38	f	f	f	f	f	f	f	\N
681	15	38	f	f	f	f	\N	f	f	\N
683	17	38	t	f	f	f	f	f	f	\N
686	20	38	f	f	f	f	f	f	f	\N
700	34	38	f	f	f	f	f	f	f	\N
737	34	39	t	t	t	f	f	f	f	\N
777	36	40	t	t	t	f	f	f	f	\N
707	4	39	t	t	f	f	f	f	f	\N
696	30	38	t	t	t	f	f	f	f	\N
695	29	38	f	f	f	f	\N	f	f	\N
697	31	38	f	f	f	f	t	f	f	\N
698	32	38	f	f	f	f	f	f	f	\N
699	33	38	f	f	f	f	\N	f	f	\N
703	37	38	f	f	f	f	f	f	f	\N
701	35	38	f	f	f	f	t	f	f	\N
741	38	39	t	f	f	f	t	f	f	\N
702	36	38	t	f	f	f	f	f	f	\N
694	28	38	f	f	f	f	t	f	f	\N
709	6	39	t	t	t	f	f	f	f	\N
715	12	39	t	f	f	f	f	f	f	\N
745	4	40	t	f	f	f	f	f	f	\N
725	22	39	t	t	t	t	f	f	f	0.1
717	14	39	t	f	f	f	f	f	f	\N
738	35	39	t	f	f	f	t	f	f	\N
726	23	39	t	f	f	f	f	f	f	\N
739	36	39	t	f	f	f	f	f	f	\N
706	3	39	t	f	f	f	f	f	f	\N
736	33	39	t	t	t	f	\N	f	f	\N
713	10	39	t	t	t	f	f	f	f	\N
724	21	39	t	t	f	f	\N	f	f	\N
710	7	39	t	t	f	f	f	f	f	\N
730	27	39	t	f	f	f	f	f	f	\N
783	3	41	t	t	t	t	f	f	f	4.2
732	29	39	t	f	f	f	\N	f	f	\N
720	17	39	t	f	f	f	f	f	f	\N
750	9	40	t	t	t	t	f	f	f	5
740	37	39	t	t	t	f	f	f	f	\N
790	10	41	t	f	f	f	f	f	f	\N
721	18	39	t	t	t	f	f	f	f	\N
787	7	41	t	f	f	f	f	f	f	\N
723	20	39	t	f	f	f	f	f	f	\N
765	24	40	t	t	t	f	\N	f	f	\N
728	25	39	t	f	f	f	t	f	f	\N
795	15	41	t	t	t	t	\N	f	f	2
731	28	39	t	f	f	f	t	f	f	\N
773	32	40	t	t	t	f	f	f	f	\N
714	11	39	t	f	f	f	f	f	f	\N
766	25	40	t	f	f	f	f	f	f	\N
792	12	41	t	f	f	f	t	f	f	\N
716	13	39	t	t	t	f	\N	f	f	\N
747	6	40	t	f	f	f	f	f	f	\N
704	1	39	t	f	f	f	f	f	f	\N
780	39	40	t	f	f	f	f	f	f	\N
705	2	39	t	f	f	f	f	f	f	\N
748	7	40	t	f	f	f	f	f	f	\N
708	5	39	t	f	f	f	f	f	f	\N
722	19	39	t	f	f	f	\N	f	f	\N
742	1	40	t	f	f	f	f	f	f	\N
733	30	39	t	f	f	f	f	f	f	\N
718	15	39	t	f	f	f	\N	f	f	\N
758	17	40	t	f	f	f	f	f	f	\N
719	16	39	t	f	f	f	\N	f	f	\N
755	14	40	t	t	t	t	f	f	f	2.6
727	24	39	t	f	f	f	\N	f	f	\N
752	11	40	t	f	f	f	f	f	f	\N
734	31	39	t	f	f	f	t	f	f	\N
735	32	39	t	f	f	f	f	f	f	\N
711	8	39	t	f	f	f	f	f	f	\N
781	1	41	t	f	f	f	f	f	f	\N
712	9	39	t	f	f	f	f	f	f	\N
763	22	40	t	f	f	f	f	f	f	\N
729	26	39	t	t	t	f	t	f	f	\N
776	35	40	t	f	f	f	f	f	f	\N
761	20	40	t	t	f	f	t	f	f	\N
749	8	40	t	t	t	f	t	f	f	\N
760	19	40	t	t	t	f	\N	f	f	\N
762	21	40	t	f	f	f	\N	f	f	\N
754	13	40	t	f	f	f	\N	f	f	\N
764	23	40	t	f	f	f	f	f	f	\N
759	18	40	t	f	f	f	f	f	f	\N
768	27	40	t	t	t	f	f	f	f	\N
772	31	40	t	t	t	t	f	f	f	1.4
774	33	40	t	f	f	f	\N	f	f	\N
779	38	40	t	f	f	f	f	f	f	\N
769	28	40	t	f	f	f	f	f	f	\N
743	2	40	t	f	f	f	t	f	f	\N
775	34	40	t	f	f	f	f	f	f	\N
751	10	40	t	f	f	f	f	f	f	\N
744	3	40	t	t	t	f	t	f	f	\N
778	37	40	t	f	f	f	f	f	f	\N
753	12	40	t	f	f	f	f	f	f	\N
756	15	40	t	t	t	f	\N	f	f	\N
746	5	40	t	f	f	f	f	f	f	\N
767	26	40	t	f	f	f	f	f	f	\N
757	16	40	t	t	f	f	\N	f	f	\N
771	30	40	t	f	f	f	t	f	f	\N
770	29	40	t	f	f	f	\N	f	f	\N
784	4	41	t	f	f	f	f	f	f	\N
789	9	41	t	t	t	t	t	f	f	3
793	13	41	t	f	f	f	\N	f	f	\N
788	8	41	t	t	t	t	f	f	f	10.6
791	11	41	t	f	f	f	t	f	f	\N
782	2	41	t	f	f	f	f	f	f	\N
794	14	41	t	t	t	t	f	f	f	4.4
785	5	41	t	f	f	f	f	f	f	\N
786	6	41	t	f	f	f	f	f	f	\N
831	11	42	t	t	f	f	t	f	f	\N
832	12	42	t	f	f	f	t	f	f	\N
835	15	42	t	f	f	f	\N	f	f	\N
840	20	42	t	f	f	f	f	f	f	\N
807	27	41	t	t	t	t	f	f	f	2.1
818	38	41	t	f	f	f	f	f	f	\N
806	26	41	t	f	f	f	f	f	f	\N
808	28	41	t	f	f	f	f	f	f	\N
809	29	41	t	f	f	f	\N	f	f	\N
819	39	41	t	f	f	f	f	f	f	\N
805	25	41	t	f	f	f	f	f	f	\N
814	34	41	t	f	f	f	f	f	f	\N
815	35	41	t	f	f	f	f	f	f	\N
802	22	41	t	f	f	f	t	f	f	\N
839	19	42	t	t	f	f	\N	f	f	\N
810	30	41	t	f	f	f	f	f	f	\N
825	5	42	t	f	f	f	f	f	f	\N
820	40	41	t	t	t	f	f	f	f	\N
827	7	42	t	f	f	f	f	f	f	\N
830	10	42	t	f	f	f	f	f	f	\N
799	19	41	t	t	t	t	\N	f	f	1.4
833	13	42	t	f	f	f	\N	f	f	\N
801	21	41	t	f	f	f	\N	f	f	\N
813	33	41	t	f	f	f	\N	f	f	\N
837	17	42	t	t	t	f	f	f	f	\N
796	16	41	t	t	t	t	\N	f	f	6.4
797	17	41	t	f	f	f	f	f	f	\N
798	18	41	t	f	f	f	f	f	f	\N
836	16	42	t	t	t	f	\N	f	f	\N
838	18	42	t	f	f	f	f	f	f	\N
800	20	41	t	t	t	t	f	f	f	6.2
841	21	42	t	f	f	f	\N	f	f	\N
821	1	42	t	f	f	f	f	f	f	\N
811	31	41	t	t	t	f	f	f	f	\N
823	3	42	t	t	t	f	f	f	f	\N
812	32	41	t	t	t	t	t	f	f	6.2
816	36	41	t	t	t	t	f	f	f	10.4
829	9	42	t	t	t	t	t	f	f	4.4
817	37	41	t	f	f	f	t	f	f	\N
803	23	41	t	f	f	f	t	f	f	\N
834	14	42	t	f	f	f	f	f	f	\N
842	22	42	t	f	f	f	t	f	f	\N
804	24	41	t	t	t	t	\N	f	f	2
824	4	42	t	f	f	f	f	f	f	\N
828	8	42	t	t	t	f	f	f	f	\N
822	2	42	t	f	f	f	f	f	f	\N
826	6	42	t	f	f	f	f	f	f	\N
843	23	42	t	f	f	f	t	f	f	\N
873	12	43	t	t	t	t	f	f	f	1.1
870	9	43	t	f	f	f	f	f	f	\N
879	18	43	t	f	f	f	f	f	f	\N
896	35	43	t	f	f	f	f	f	f	\N
883	22	43	t	t	f	f	f	f	f	\N
902	41	43	t	f	f	f	f	f	f	\N
864	3	43	t	f	f	f	f	f	f	\N
877	16	43	t	f	f	f	f	f	f	\N
884	23	43	t	t	t	t	f	f	f	2.1
886	25	43	t	t	t	t	f	f	f	2.1
920	17	44	t	t	t	t	f	f	f	8.6
862	1	43	t	t	t	f	f	f	f	\N
844	24	42	t	t	t	f	\N	f	f	\N
887	26	43	t	t	t	t	f	f	f	3
846	26	42	t	f	f	f	f	f	f	\N
876	15	43	t	f	f	f	f	f	f	\N
845	25	42	t	f	f	f	f	f	f	\N
892	31	43	t	f	f	f	f	f	f	\N
904	1	44	t	f	f	f	t	f	f	\N
897	36	43	t	f	f	f	f	f	f	\N
855	35	42	t	t	t	f	f	f	f	\N
881	20	43	t	f	f	f	f	f	f	\N
860	40	42	t	f	f	f	f	f	f	\N
875	14	43	t	f	f	f	f	f	f	\N
854	34	42	t	f	f	f	f	f	f	\N
923	20	44	f	f	f	f	f	f	f	\N
857	37	42	t	f	f	f	t	f	f	\N
880	19	43	t	f	f	f	f	f	f	\N
851	31	42	t	f	f	f	f	f	f	\N
898	37	43	t	f	f	f	f	f	f	\N
890	29	43	t	f	f	f	f	f	f	\N
848	28	42	t	t	t	f	f	f	f	\N
894	33	43	t	f	f	f	f	f	f	\N
853	33	42	t	f	f	f	\N	f	f	\N
924	21	44	f	f	f	f	\N	f	f	\N
858	38	42	t	f	f	f	f	f	f	\N
903	42	43	t	f	f	f	f	f	f	\N
847	27	42	t	f	f	f	f	f	f	\N
861	41	42	t	f	f	f	t	f	f	\N
878	17	43	t	f	f	f	f	f	f	\N
905	2	44	t	f	f	f	f	f	f	\N
899	38	43	t	t	t	t	f	f	f	4.1
849	29	42	t	t	t	f	\N	f	f	\N
865	4	43	t	t	f	f	f	f	f	\N
907	4	44	f	f	f	f	t	f	f	\N
900	39	43	t	f	f	f	f	f	f	\N
868	7	43	t	t	f	f	f	f	f	\N
859	39	42	t	t	t	t	f	f	f	10.2
910	7	44	f	f	f	f	f	f	f	\N
856	36	42	t	f	f	f	f	f	f	\N
885	24	43	t	f	f	f	f	f	f	\N
850	30	42	t	f	f	f	f	f	f	\N
852	32	42	t	f	f	f	t	f	f	\N
888	27	43	t	f	f	f	f	f	f	\N
867	6	43	t	t	f	f	f	f	f	\N
889	28	43	t	f	f	f	f	f	f	\N
872	11	43	t	f	f	f	f	f	f	\N
863	2	43	t	t	f	f	f	f	f	\N
874	13	43	t	f	f	f	f	f	f	\N
866	5	43	t	t	f	f	f	f	f	\N
869	8	43	t	f	f	f	f	f	f	\N
908	5	44	t	f	f	f	t	f	f	\N
882	21	43	t	t	f	f	f	f	f	\N
922	19	44	t	t	f	f	\N	f	f	\N
912	9	44	t	t	t	t	f	f	f	1.6
891	30	43	t	t	t	f	f	f	f	\N
917	14	44	t	f	f	f	f	f	f	\N
893	32	43	t	f	f	f	f	f	f	\N
909	6	44	f	f	f	f	t	f	f	\N
913	10	44	f	f	f	f	t	f	f	\N
871	10	43	t	t	f	f	f	f	f	\N
918	15	44	f	f	f	f	\N	f	f	\N
901	40	43	t	f	f	f	f	f	f	\N
921	18	44	f	f	f	f	f	f	f	\N
915	12	44	f	f	f	f	f	f	f	\N
906	3	44	f	f	f	f	f	f	f	\N
911	8	44	f	f	f	f	f	f	f	\N
895	34	43	t	t	t	t	f	f	f	10.1
914	11	44	f	f	f	f	f	f	f	\N
919	16	44	f	f	f	f	\N	f	f	\N
916	13	44	f	f	f	f	\N	f	f	\N
989	43	45	t	f	f	f	f	f	f	\N
956	10	45	f	f	f	f	f	f	f	\N
985	39	45	t	t	f	f	f	f	f	\N
960	14	45	t	f	f	f	f	f	f	\N
962	16	45	f	f	f	f	f	f	f	\N
970	24	45	f	f	f	f	f	f	f	\N
973	27	45	f	f	f	f	f	f	f	\N
979	33	45	f	f	f	f	f	f	f	\N
981	35	45	f	f	f	f	f	f	f	\N
952	6	45	f	f	f	f	f	f	f	\N
987	41	45	t	f	f	f	f	f	f	\N
964	18	45	f	f	f	f	f	f	f	\N
947	1	45	t	f	f	f	f	f	f	\N
951	5	45	t	f	f	f	f	f	f	\N
968	22	45	f	f	f	f	f	f	f	\N
974	28	45	f	f	f	f	f	f	f	\N
977	31	45	f	f	f	f	f	f	f	\N
978	32	45	f	f	f	f	f	f	f	\N
949	3	45	f	f	f	f	f	f	f	\N
950	4	45	f	f	f	f	f	f	f	\N
958	12	45	f	f	f	f	f	f	f	\N
931	28	44	f	f	f	f	f	f	f	\N
934	31	44	f	f	f	f	f	f	f	\N
937	34	44	f	f	f	f	t	f	f	\N
927	24	44	f	f	f	f	\N	f	f	\N
1009	19	46	t	t	t	f	\N	f	f	\N
943	40	44	t	f	f	f	f	f	f	\N
935	32	44	f	f	f	f	f	f	f	\N
936	33	44	f	f	f	f	\N	f	f	\N
926	23	44	f	f	f	f	f	f	f	\N
929	26	44	f	f	f	f	f	f	f	\N
986	40	45	t	f	f	f	f	f	f	\N
1005	15	46	f	f	f	f	\N	f	f	\N
988	42	45	t	f	f	f	f	f	f	\N
942	39	44	t	t	t	f	f	f	f	\N
990	44	45	f	f	f	f	f	f	f	\N
933	30	44	t	f	f	f	f	f	f	\N
940	37	44	f	f	f	f	f	f	f	\N
932	29	44	f	f	f	f	\N	f	f	\N
954	8	45	f	f	f	f	f	f	f	\N
945	42	44	t	f	f	f	f	f	f	\N
961	15	45	f	f	f	f	f	f	f	\N
946	43	44	t	f	f	f	\N	f	f	\N
925	22	44	f	f	f	f	f	f	f	\N
969	23	45	f	f	f	f	f	f	f	\N
939	36	44	t	f	f	f	f	f	f	\N
928	25	44	f	f	f	f	f	f	f	\N
930	27	44	f	f	f	f	f	f	f	\N
938	35	44	f	f	f	f	f	f	f	\N
941	38	44	f	f	f	f	f	f	f	\N
944	41	44	t	f	f	f	f	f	f	\N
966	20	45	f	f	f	f	f	f	f	\N
971	25	45	f	f	f	f	f	f	f	\N
984	38	45	f	f	f	f	f	f	f	\N
965	19	45	t	t	t	t	f	f	f	10.4
948	2	45	t	f	f	f	f	f	f	\N
957	11	45	f	f	f	f	f	f	f	\N
963	17	45	t	t	t	t	f	f	f	5
972	26	45	f	f	f	f	f	f	f	\N
975	29	45	f	f	f	f	f	f	f	\N
976	30	45	t	f	f	f	f	f	f	\N
980	34	45	f	f	f	f	f	f	f	\N
953	7	45	f	f	f	f	f	f	f	\N
955	9	45	t	t	t	f	f	f	f	\N
959	13	45	f	f	f	f	f	f	f	\N
967	21	45	f	f	f	f	f	f	f	\N
982	36	45	t	f	f	f	f	f	f	\N
983	37	45	f	f	f	f	f	f	f	\N
1010	20	46	t	f	f	f	f	f	f	\N
1001	11	46	f	f	f	f	f	f	f	\N
1003	13	46	t	f	f	f	\N	f	f	\N
1004	14	46	t	f	f	f	f	f	f	\N
995	5	46	t	f	f	f	t	f	f	\N
993	3	46	f	f	f	f	f	f	f	\N
1007	17	46	t	t	t	f	f	f	f	\N
1006	16	46	t	t	t	f	\N	f	f	\N
994	4	46	t	f	f	f	t	f	f	\N
996	6	46	f	f	f	f	t	f	f	\N
997	7	46	f	f	f	f	f	f	f	\N
999	9	46	t	t	t	t	f	f	f	2.1
991	1	46	t	f	f	f	t	f	f	\N
992	2	46	t	f	f	f	f	f	f	\N
998	8	46	t	t	t	f	f	f	f	\N
1002	12	46	t	f	f	f	f	f	f	\N
1008	18	46	t	f	f	f	f	f	f	\N
1000	10	46	t	f	f	f	t	f	f	\N
1016	26	46	f	f	f	f	f	f	f	\N
1053	18	47	t	f	f	f	t	f	f	\N
1048	13	47	t	f	f	f	\N	f	f	\N
1018	28	46	t	t	t	f	f	f	f	\N
1052	17	47	t	f	f	f	t	f	f	\N
1026	36	46	t	f	f	f	f	f	f	\N
1032	42	46	t	f	f	f	f	f	f	\N
1011	21	46	f	f	f	f	\N	f	f	\N
1012	22	46	f	f	f	f	f	f	f	\N
1017	27	46	f	f	f	f	f	f	f	\N
1014	24	46	f	f	f	f	\N	f	f	\N
1021	31	46	f	f	f	f	f	f	f	\N
1023	33	46	f	f	f	f	\N	f	f	\N
1054	19	47	t	f	f	f	\N	f	f	\N
1031	41	46	t	f	f	f	f	f	f	\N
1019	29	46	f	f	f	f	\N	f	f	\N
1020	30	46	t	f	f	f	f	f	f	\N
1028	38	46	f	f	f	f	f	f	f	\N
1034	44	46	f	f	f	f	t	f	f	\N
1055	20	47	t	f	f	f	f	f	f	\N
1022	32	46	t	f	f	f	f	f	f	\N
1024	34	46	f	f	f	f	t	f	f	\N
1025	35	46	f	f	f	f	f	f	f	\N
1044	9	47	t	f	f	f	f	f	f	\N
1056	21	47	t	t	t	t	\N	f	f	1.8
1029	39	46	t	t	t	t	f	f	f	6.1
1038	3	47	t	f	f	f	f	f	f	\N
1030	40	46	t	f	f	f	f	f	f	\N
1015	25	46	t	f	f	f	f	f	f	\N
1027	37	46	f	f	f	f	f	f	f	\N
1035	45	46	f	f	f	f	\N	f	f	\N
1045	10	47	t	t	t	t	f	f	f	6.6
1013	23	46	t	f	f	f	f	f	f	\N
1049	14	47	t	f	f	f	t	f	f	\N
1033	43	46	t	f	f	f	\N	f	f	\N
1046	11	47	t	f	f	f	f	f	f	\N
1058	23	47	t	t	t	t	f	f	f	0.1
1036	1	47	t	t	t	f	f	f	f	\N
1037	2	47	t	t	t	t	f	f	f	4.1
1043	8	47	t	f	f	f	f	f	f	\N
1047	12	47	t	t	t	t	f	f	f	0.1
1039	4	47	t	t	t	t	f	f	f	9
1059	24	47	t	f	f	f	\N	f	f	\N
1040	5	47	t	t	t	t	f	f	f	1.6
1042	7	47	t	t	t	t	t	f	f	0.6
1050	15	47	t	f	f	f	\N	f	f	\N
1057	22	47	t	t	t	f	f	f	f	\N
1041	6	47	t	t	t	t	f	f	f	8.1
1051	16	47	t	f	f	f	\N	f	f	\N
1101	20	48	t	f	f	f	t	f	f	\N
1060	25	47	t	t	t	t	f	f	f	6.1
1080	45	47	t	f	f	f	\N	f	f	\N
1074	39	47	t	f	f	f	f	f	f	\N
1076	41	47	t	f	f	f	f	f	f	\N
1062	27	47	t	f	f	f	t	f	f	\N
1063	28	47	t	f	f	f	f	f	f	\N
1067	32	47	t	f	f	f	f	f	f	\N
1071	36	47	t	f	f	f	t	f	f	\N
1070	35	47	t	f	f	f	f	f	f	\N
1075	40	47	t	f	f	f	f	f	f	\N
1106	25	48	t	t	t	t	f	f	f	8.1
1136	8	49	f	f	f	f	f	f	f	\N
1139	11	49	f	f	f	f	f	f	f	\N
1078	43	47	t	t	t	t	\N	f	f	5
1099	18	48	t	f	f	f	f	f	f	\N
1125	44	48	f	f	f	f	f	f	f	\N
1084	3	48	f	f	f	f	t	f	f	\N
1065	30	47	t	t	t	f	f	f	f	\N
1132	4	49	f	f	f	f	t	f	f	\N
1090	9	48	t	f	f	f	f	f	f	\N
1118	37	48	f	f	f	f	f	f	f	\N
1073	38	47	t	t	t	t	f	f	f	10.1
1133	5	49	t	f	f	f	t	f	f	\N
1079	44	47	t	f	f	f	f	f	f	\N
1134	6	49	f	f	f	f	t	f	f	\N
1138	10	49	f	f	f	f	t	f	f	\N
1129	1	49	t	f	f	f	t	f	f	\N
1061	26	47	t	t	t	t	f	f	f	9
1131	3	49	f	f	f	f	f	f	f	\N
1064	29	47	t	f	f	f	\N	f	f	\N
1105	24	48	f	f	f	f	\N	f	f	\N
1068	33	47	t	f	f	f	\N	f	f	\N
1093	12	48	t	t	t	f	f	f	f	\N
1140	12	49	f	f	f	f	f	f	f	\N
1130	2	49	t	f	f	f	f	f	f	\N
1069	34	47	t	t	t	t	f	f	f	2.1
1104	23	48	t	t	t	f	f	f	f	\N
1077	42	47	t	f	f	f	f	f	f	\N
1135	7	49	f	f	f	f	f	f	f	\N
1081	46	47	t	f	f	f	f	f	f	\N
1107	26	48	f	f	f	f	f	f	f	\N
1066	31	47	t	f	f	f	f	f	f	\N
1072	37	47	t	f	f	f	f	f	f	\N
1123	42	48	t	f	f	f	f	f	f	\N
1137	9	49	t	t	t	f	f	f	f	\N
1141	13	49	f	f	f	f	\N	f	f	\N
1112	31	48	f	f	f	f	f	f	f	\N
1113	32	48	t	f	f	f	f	f	f	\N
1119	38	48	f	f	f	f	f	f	f	\N
1128	47	48	t	t	t	t	f	f	f	10.8
1111	30	48	t	t	t	f	t	f	f	\N
1121	40	48	t	f	f	f	t	f	f	\N
1122	41	48	t	f	f	f	f	f	f	\N
1083	2	48	t	t	t	t	t	f	f	6.1
1087	6	48	f	f	f	f	f	f	f	\N
1124	43	48	t	t	t	t	\N	f	f	3
1115	34	48	f	f	f	f	f	f	f	\N
1117	36	48	t	f	f	f	f	f	f	\N
1089	8	48	t	f	f	f	t	f	f	\N
1120	39	48	t	f	f	f	f	f	f	\N
1096	15	48	f	f	f	f	\N	f	f	\N
1109	28	48	t	f	f	f	f	f	f	\N
1114	33	48	f	f	f	f	\N	f	f	\N
1116	35	48	f	f	f	f	f	f	f	\N
1126	45	48	f	f	f	f	\N	f	f	\N
1097	16	48	t	f	f	f	\N	f	f	\N
1098	17	48	t	f	f	f	f	f	f	\N
1086	5	48	t	t	t	f	f	f	f	\N
1110	29	48	f	f	f	f	\N	f	f	\N
1127	46	48	t	f	f	f	f	f	f	\N
1091	10	48	t	t	t	t	f	f	f	4.2
1095	14	48	t	f	f	f	f	f	f	\N
1103	22	48	f	f	f	f	f	f	f	\N
1082	1	48	t	t	t	f	f	f	f	\N
1092	11	48	f	f	f	f	f	f	f	\N
1085	4	48	t	t	t	t	f	f	f	11
1094	13	48	t	f	f	f	\N	f	f	\N
1100	19	48	t	f	f	f	\N	f	f	\N
1102	21	48	f	f	f	f	\N	f	f	\N
1108	27	48	f	f	f	f	f	f	f	\N
1088	7	48	f	f	f	f	f	f	f	\N
1175	47	49	t	f	f	f	f	f	f	\N
1167	39	49	t	t	t	f	f	f	f	\N
1176	48	49	f	f	f	f	f	f	f	\N
1144	16	49	f	f	f	f	\N	f	f	\N
1145	17	49	t	t	t	t	f	f	f	5
1148	20	49	f	f	f	f	f	f	f	\N
1165	37	49	f	f	f	f	f	f	f	\N
1172	44	49	f	f	f	f	t	f	f	\N
1173	45	49	f	f	f	f	\N	f	f	\N
1159	31	49	f	f	f	f	f	f	f	\N
1161	33	49	f	f	f	f	\N	f	f	\N
1163	35	49	f	f	f	f	f	f	f	\N
1169	41	49	t	f	f	f	f	f	f	\N
1146	18	49	f	f	f	f	f	f	f	\N
1154	26	49	f	f	f	f	f	f	f	\N
1155	27	49	f	f	f	f	f	f	f	\N
1174	46	49	f	f	f	f	t	f	f	\N
1153	25	49	f	f	f	f	f	f	f	\N
1156	28	49	f	f	f	f	f	f	f	\N
1149	21	49	f	f	f	f	\N	f	f	\N
1150	22	49	f	f	f	f	f	f	f	\N
1142	14	49	t	f	f	f	f	f	f	\N
1152	24	49	f	f	f	f	\N	f	f	\N
1164	36	49	t	f	f	f	f	f	f	\N
1151	23	49	f	f	f	f	f	f	f	\N
1160	32	49	f	f	f	f	f	f	f	\N
1162	34	49	f	f	f	f	t	f	f	\N
1170	42	49	t	f	f	f	f	f	f	\N
1171	43	49	t	f	f	f	\N	f	f	\N
1157	29	49	f	f	f	f	\N	f	f	\N
1158	30	49	t	f	f	f	f	f	f	\N
1166	38	49	f	f	f	f	f	f	f	\N
1143	15	49	f	f	f	f	\N	f	f	\N
1190	14	50	t	t	t	t	f	f	f	1
1199	23	50	f	f	f	f	f	f	f	\N
1147	19	49	t	t	t	t	\N	f	f	10.4
1168	40	49	t	f	f	f	f	f	f	\N
1189	13	50	f	f	f	f	\N	f	f	\N
1217	41	50	t	t	t	t	f	f	f	4.1
1224	48	50	f	f	f	f	f	f	f	\N
1193	17	50	t	f	f	f	f	f	f	\N
1198	22	50	f	f	f	f	f	f	f	\N
1212	36	50	t	t	t	t	f	f	f	1.8
1213	37	50	f	f	f	f	f	f	f	\N
1220	44	50	f	f	f	f	t	f	f	\N
1204	28	50	f	f	f	f	f	f	f	\N
1184	8	50	f	f	f	f	f	f	f	\N
1210	34	50	f	f	f	f	t	f	f	\N
1191	15	50	f	f	f	f	\N	f	f	\N
1205	29	50	f	f	f	f	\N	f	f	\N
1215	39	50	t	f	f	f	f	f	f	\N
1223	47	50	t	f	f	f	f	f	f	\N
1181	5	50	t	f	f	f	t	f	f	\N
1185	9	50	t	t	t	t	f	f	f	0.2
1197	21	50	f	f	f	f	\N	f	f	\N
1203	27	50	f	f	f	f	f	f	f	\N
1211	35	50	f	f	f	f	f	f	f	\N
1221	45	50	f	f	f	f	\N	f	f	\N
1195	19	50	t	t	t	t	\N	f	f	6.8
1209	33	50	f	f	f	f	\N	f	f	\N
1182	6	50	f	f	f	f	t	f	f	\N
1219	43	50	t	f	f	f	\N	f	f	\N
1214	38	50	f	f	f	f	f	f	f	\N
1222	46	50	f	f	f	f	t	f	f	\N
1186	10	50	f	f	f	f	t	f	f	\N
1177	1	50	t	f	f	f	t	f	f	\N
1180	4	50	f	f	f	f	t	f	f	\N
1192	16	50	f	f	f	f	\N	f	f	\N
1196	20	50	f	f	f	f	f	f	f	\N
1194	18	50	f	f	f	f	f	f	f	\N
1206	30	50	t	f	f	f	f	f	f	\N
1200	24	50	f	f	f	f	\N	f	f	\N
1178	2	50	t	f	f	f	f	f	f	\N
1179	3	50	f	f	f	f	f	f	f	\N
1202	26	50	f	f	f	f	f	f	f	\N
1218	42	50	t	t	f	f	f	f	f	\N
1201	25	50	f	f	f	f	f	f	f	\N
1207	31	50	f	f	f	f	f	f	f	\N
1208	32	50	f	f	f	f	f	f	f	\N
1183	7	50	f	f	f	f	f	f	f	\N
1187	11	50	f	f	f	f	f	f	f	\N
1188	12	50	f	f	f	f	f	f	f	\N
1216	40	50	t	t	t	f	f	f	f	\N
1225	49	50	f	f	f	f	t	f	f	\N
1290	15	52	t	f	f	f	\N	f	f	\N
1285	10	52	f	f	f	f	t	f	f	\N
1234	9	51	t	t	t	f	f	f	f	\N
1279	4	52	f	f	f	f	t	f	f	\N
1245	20	51	t	f	f	f	f	f	f	\N
1246	21	51	f	f	f	f	\N	f	f	\N
1287	12	52	f	f	f	f	f	f	f	\N
1288	13	52	f	f	f	f	\N	f	f	\N
1257	32	51	t	f	f	f	f	f	f	\N
1264	39	51	t	t	t	f	f	f	f	\N
1289	14	52	t	f	f	f	f	f	f	\N
1266	41	51	t	f	f	f	f	f	f	\N
1267	42	51	t	f	f	f	f	f	f	\N
1271	46	51	t	f	f	f	t	f	f	\N
1275	50	51	f	f	f	f	t	f	f	\N
1227	2	51	t	f	f	f	f	f	f	\N
1239	14	51	t	f	f	f	f	f	f	\N
1233	8	51	t	t	t	t	f	f	f	1.1
1270	45	51	f	f	f	f	\N	f	f	\N
1263	38	51	f	f	f	f	f	f	f	\N
1230	5	51	t	f	f	f	t	f	f	\N
1244	19	51	t	t	t	t	\N	f	f	10.1
1249	24	51	f	f	f	f	\N	f	f	\N
1269	44	51	f	f	f	f	t	f	f	\N
1242	17	51	t	t	t	t	f	f	f	4.1
1251	26	51	f	f	f	f	f	f	f	\N
1252	27	51	f	f	f	f	f	f	f	\N
1254	29	51	f	f	f	f	\N	f	f	\N
1258	33	51	f	f	f	f	\N	f	f	\N
1262	37	51	f	f	f	f	f	f	f	\N
1272	47	51	t	f	f	f	f	f	f	\N
1273	48	51	t	f	f	f	f	f	f	\N
1228	3	51	f	f	f	f	f	f	f	\N
1238	13	51	t	f	f	f	\N	f	f	\N
1241	16	51	t	t	t	t	\N	f	f	4.1
1250	25	51	t	f	f	f	f	f	f	\N
1259	34	51	f	f	f	f	t	f	f	\N
1261	36	51	t	f	f	f	f	f	f	\N
1265	40	51	t	f	f	f	f	f	f	\N
1232	7	51	f	f	f	f	f	f	f	\N
1240	15	51	f	f	f	f	\N	f	f	\N
1247	22	51	f	f	f	f	f	f	f	\N
1248	23	51	t	f	f	f	f	f	f	\N
1253	28	51	t	t	t	t	f	f	f	4.1
1256	31	51	f	f	f	f	f	f	f	\N
1260	35	51	f	f	f	f	f	f	f	\N
1229	4	51	t	f	f	f	t	f	f	\N
1243	18	51	t	f	f	f	f	f	f	\N
1255	30	51	t	f	f	f	f	f	f	\N
1268	43	51	t	f	f	f	\N	f	f	\N
1226	1	51	t	f	f	f	t	f	f	\N
1235	10	51	t	f	f	f	t	f	f	\N
1236	11	51	f	f	f	f	f	f	f	\N
1237	12	51	t	f	f	f	f	f	f	\N
1274	49	51	f	f	f	f	t	f	f	\N
1231	6	51	f	f	f	f	t	f	f	\N
1278	3	52	t	f	f	f	f	f	f	\N
1284	9	52	t	f	f	f	f	f	f	\N
1280	5	52	t	f	f	f	t	f	f	\N
1295	20	52	f	f	f	f	f	f	f	\N
1296	21	52	f	f	f	f	\N	f	f	\N
1276	1	52	t	f	f	f	t	f	f	\N
1292	17	52	t	f	f	f	f	f	f	\N
1286	11	52	f	f	f	f	f	f	f	\N
1293	18	52	f	f	f	f	f	f	f	\N
1277	2	52	t	f	f	f	f	f	f	\N
1282	7	52	t	t	t	t	f	f	f	1.4
1283	8	52	f	f	f	f	f	f	f	\N
1291	16	52	f	f	f	f	\N	f	f	\N
1294	19	52	t	f	f	f	\N	f	f	\N
1281	6	52	t	t	t	t	t	f	f	10.1
1357	31	53	f	f	f	f	f	f	f	\N
1367	41	53	t	t	t	f	f	f	f	\N
1361	35	53	f	f	f	f	f	f	f	\N
1297	22	52	t	t	t	f	f	f	f	\N
1299	24	52	t	f	f	f	\N	f	f	\N
1300	25	52	f	f	f	f	f	f	f	\N
1301	26	52	t	t	f	f	f	f	f	\N
1303	28	52	f	f	f	f	f	f	f	\N
1307	32	52	f	f	f	f	f	f	f	\N
1308	33	52	t	t	f	f	\N	f	f	\N
1311	36	52	t	f	f	f	f	f	f	\N
1316	41	52	t	f	f	f	f	f	f	\N
1366	40	53	t	t	t	f	f	f	f	\N
1309	34	52	t	t	t	t	t	f	f	6.1
1321	46	52	f	f	f	f	t	f	f	\N
1314	39	52	t	f	f	f	f	f	f	\N
1364	38	53	f	f	f	f	f	f	f	\N
1318	43	52	t	f	f	f	\N	f	f	\N
1319	44	52	f	f	f	f	t	f	f	\N
1322	47	52	t	f	f	f	f	f	f	\N
1305	30	52	t	f	f	f	f	f	f	\N
1313	38	52	f	f	f	f	f	f	f	\N
1344	18	53	f	f	f	f	f	f	f	\N
1310	35	52	t	f	f	f	f	f	f	\N
1354	28	53	f	f	f	f	f	f	f	\N
1317	42	52	t	t	f	f	f	f	f	\N
1326	51	52	f	f	f	f	t	f	f	\N
1304	29	52	f	f	f	f	\N	f	f	\N
1306	31	52	t	f	f	f	f	f	f	\N
1372	46	53	f	f	f	f	t	f	f	\N
1315	40	52	t	f	f	f	f	f	f	\N
1324	49	52	f	f	f	f	t	f	f	\N
1325	50	52	f	f	f	f	t	f	f	\N
1298	23	52	f	f	f	f	f	f	f	\N
1302	27	52	f	f	f	f	f	f	f	\N
1312	37	52	t	t	t	t	f	f	f	8.1
1323	48	52	f	f	f	f	f	f	f	\N
1320	45	52	f	f	f	f	\N	f	f	\N
1330	4	53	f	f	f	f	t	f	f	\N
1333	7	53	f	f	f	f	f	f	f	\N
1338	12	53	f	f	f	f	f	f	f	\N
1343	17	53	t	f	f	f	f	f	f	\N
1347	21	53	f	f	f	f	\N	f	f	\N
1363	37	53	f	f	f	f	f	f	f	\N
1371	45	53	f	f	f	f	\N	f	f	\N
1374	48	53	f	f	f	f	f	f	f	\N
1346	20	53	f	f	f	f	f	f	f	\N
1339	13	53	f	f	f	f	\N	f	f	\N
1350	24	53	f	f	f	f	\N	f	f	\N
1341	15	53	f	f	f	f	\N	f	f	\N
1362	36	53	t	t	t	f	f	f	f	\N
1351	25	53	f	f	f	f	f	f	f	\N
1365	39	53	t	f	f	f	f	f	f	\N
1358	32	53	f	f	f	f	f	f	f	\N
1327	1	53	t	f	f	f	t	f	f	\N
1370	44	53	f	f	f	f	t	f	f	\N
1356	30	53	t	f	f	f	f	f	f	\N
1375	49	53	f	f	f	f	t	f	f	\N
1373	47	53	t	f	f	f	f	f	f	\N
1329	3	53	f	f	f	f	f	f	f	\N
1359	33	53	f	f	f	f	\N	f	f	\N
1345	19	53	t	t	t	t	\N	f	f	8.1
1360	34	53	f	f	f	f	t	f	f	\N
1332	6	53	f	f	f	f	t	f	f	\N
1369	43	53	t	f	f	f	\N	f	f	\N
1328	2	53	t	f	f	f	f	f	f	\N
1331	5	53	t	f	f	f	t	f	f	\N
1337	11	53	f	f	f	f	f	f	f	\N
1342	16	53	f	f	f	f	\N	f	f	\N
1349	23	53	f	f	f	f	f	f	f	\N
1355	29	53	f	f	f	f	\N	f	f	\N
1335	9	53	t	t	t	f	f	f	f	\N
1336	10	53	f	f	f	f	t	f	f	\N
1368	42	53	t	t	t	f	f	f	f	\N
1334	8	53	f	f	f	f	f	f	f	\N
1348	22	53	f	f	f	f	f	f	f	\N
1352	26	53	f	f	f	f	f	f	f	\N
1353	27	53	f	f	f	f	f	f	f	\N
1340	14	53	t	t	t	f	f	f	f	\N
1430	52	54	t	f	f	f	f	f	f	\N
1382	4	54	t	t	t	t	f	f	f	4.6
1378	52	53	f	f	f	f	t	f	f	\N
1377	51	53	f	f	f	f	t	f	f	\N
1376	50	53	f	f	f	f	t	f	f	\N
1453	22	55	t	t	t	f	f	f	f	\N
1408	30	54	t	t	t	f	f	f	f	\N
1443	12	55	f	f	f	f	f	f	f	\N
1449	18	55	f	f	f	f	f	f	f	\N
1390	12	54	t	t	t	f	f	f	f	\N
1422	44	54	t	f	f	f	f	f	f	\N
1396	18	54	t	f	f	f	t	f	f	\N
1409	31	54	t	f	f	f	f	f	f	\N
1402	24	54	t	f	f	f	\N	f	f	\N
1407	29	54	t	f	f	f	\N	f	f	\N
1403	25	54	t	t	t	t	f	f	f	8.1
1404	26	54	t	t	t	t	f	f	f	4.6
1395	17	54	t	f	f	f	t	f	f	\N
1410	32	54	t	f	f	f	f	f	f	\N
1427	49	54	t	f	f	f	f	f	f	\N
1398	20	54	t	f	f	f	f	f	f	\N
1401	23	54	t	t	t	f	f	f	f	\N
1405	27	54	t	f	f	f	t	f	f	\N
1414	36	54	t	f	f	f	t	f	f	\N
1406	28	54	t	f	f	f	f	f	f	\N
1419	41	54	t	f	f	f	f	f	f	\N
1392	14	54	t	f	f	f	t	f	f	\N
1412	34	54	t	t	t	f	f	f	f	\N
1425	47	54	t	t	t	f	t	f	f	\N
1420	42	54	t	f	f	f	f	f	f	\N
1416	38	54	t	t	t	f	f	f	f	\N
1379	1	54	t	t	t	f	f	f	f	\N
1386	8	54	t	f	f	f	f	f	f	\N
1426	48	54	t	t	t	t	f	f	f	4.6
1428	50	54	t	f	f	f	f	f	f	\N
1429	51	54	t	f	f	f	f	f	f	\N
1391	13	54	t	f	f	f	\N	f	f	\N
1385	7	54	t	t	t	f	t	f	f	\N
1394	16	54	t	f	f	f	\N	f	f	\N
1387	9	54	t	f	f	f	f	f	f	\N
1411	33	54	t	f	f	f	\N	f	f	\N
1423	45	54	t	f	f	f	\N	f	f	\N
1424	46	54	t	f	f	f	f	f	f	\N
1415	37	54	t	f	f	f	f	f	f	\N
1431	53	54	t	f	f	f	f	f	f	\N
1399	21	54	t	t	t	f	\N	f	f	\N
1389	11	54	t	f	f	f	f	f	f	\N
1397	19	54	t	f	f	f	\N	f	f	\N
1413	35	54	t	f	f	f	f	f	f	\N
1418	40	54	t	f	f	f	f	f	f	\N
1384	6	54	t	t	t	f	f	f	f	\N
1388	10	54	t	t	t	f	f	f	f	\N
1421	43	54	t	t	t	f	\N	f	f	\N
1381	3	54	t	f	f	f	f	f	f	\N
1400	22	54	t	t	t	f	f	f	f	\N
1393	15	54	t	f	f	f	\N	f	f	\N
1417	39	54	t	f	f	f	f	f	f	\N
1380	2	54	t	t	t	t	f	f	f	10.1
1383	5	54	t	t	t	f	f	f	f	\N
1434	3	55	t	f	f	f	f	f	f	\N
1439	8	55	f	f	f	f	f	f	f	\N
1444	13	55	f	f	f	f	\N	f	f	\N
1452	21	55	f	f	f	f	\N	f	f	\N
1440	9	55	t	f	f	f	f	f	f	\N
1448	17	55	t	f	f	f	f	f	f	\N
1438	7	55	t	t	t	t	f	f	f	0.1
1436	5	55	t	f	f	f	f	f	f	\N
1433	2	55	t	f	f	f	f	f	f	\N
1442	11	55	f	f	f	f	f	f	f	\N
1435	4	55	f	f	f	f	f	f	f	\N
1437	6	55	t	t	t	t	f	f	f	10.6
1446	15	55	t	f	f	f	\N	f	f	\N
1450	19	55	t	f	f	f	\N	f	f	\N
1445	14	55	t	f	f	f	f	f	f	\N
1441	10	55	f	f	f	f	f	f	f	\N
1432	1	55	t	f	f	f	f	f	f	\N
1451	20	55	f	f	f	f	f	f	f	\N
1447	16	55	f	f	f	f	\N	f	f	\N
1499	14	56	t	t	t	f	f	f	f	\N
1472	41	55	t	f	f	f	f	f	f	\N
1466	35	55	t	f	f	f	t	f	f	\N
1475	44	55	f	f	f	f	f	f	f	\N
1455	24	55	t	f	f	f	\N	f	f	\N
1515	30	56	t	f	f	f	f	f	f	\N
1523	38	56	f	f	f	f	t	f	f	\N
1468	37	55	t	t	t	t	f	f	f	10.6
1454	23	55	f	f	f	f	f	f	f	\N
1456	25	55	f	f	f	f	t	f	f	\N
1516	31	56	f	f	f	f	t	f	f	\N
1505	20	56	f	f	f	f	f	f	f	\N
1465	34	55	t	t	t	t	f	f	f	4.6
1463	32	55	f	f	f	f	f	f	f	\N
1496	11	56	f	f	f	f	f	f	f	\N
1467	36	55	t	f	f	f	f	f	f	\N
1482	51	55	f	f	f	f	f	f	f	\N
1527	42	56	t	f	f	f	f	f	f	\N
1491	6	56	f	f	f	f	f	f	f	\N
1473	42	55	t	t	t	f	f	f	f	\N
1477	46	55	f	f	f	f	f	f	f	\N
1459	28	55	f	f	f	f	t	f	f	\N
1474	43	55	t	f	f	f	\N	f	f	\N
1507	22	56	f	f	f	f	f	f	f	\N
1457	26	55	t	t	f	f	t	f	f	\N
1469	38	55	f	f	f	f	t	f	f	\N
1479	48	55	f	f	f	f	f	f	f	\N
1460	29	55	f	f	f	f	\N	f	f	\N
1476	45	55	f	f	f	f	\N	f	f	\N
1481	50	55	f	f	f	f	f	f	f	\N
1461	30	55	t	f	f	f	f	f	f	\N
1484	53	55	f	f	f	f	f	f	f	\N
1470	39	55	t	f	f	f	t	f	f	\N
1485	54	55	t	f	f	f	f	f	f	\N
1480	49	55	f	f	f	f	f	f	f	\N
1458	27	55	f	f	f	f	f	f	f	\N
1464	33	55	t	t	f	f	\N	f	f	\N
1471	40	55	t	f	f	f	f	f	f	\N
1462	31	55	t	f	f	f	t	f	f	\N
1478	47	55	t	f	f	f	f	f	f	\N
1524	39	56	t	f	f	f	t	f	f	\N
1483	52	55	t	f	f	f	f	f	f	\N
1492	7	56	f	f	f	f	f	f	f	\N
1494	9	56	t	t	t	f	f	f	f	\N
1519	34	56	f	f	f	f	f	f	f	\N
1511	26	56	f	f	f	f	t	f	f	\N
1501	16	56	f	f	f	f	\N	f	f	\N
1510	25	56	f	f	f	f	t	f	f	\N
1514	29	56	f	f	f	f	\N	f	f	\N
1517	32	56	f	f	f	f	f	f	f	\N
1504	19	56	t	t	t	t	\N	f	f	8.6
1508	23	56	f	f	f	f	f	f	f	\N
1521	36	56	t	t	t	f	f	f	f	\N
1506	21	56	f	f	f	f	\N	f	f	\N
1488	3	56	f	f	f	f	f	f	f	\N
1503	18	56	f	f	f	f	f	f	f	\N
1525	40	56	t	t	t	f	f	f	f	\N
1529	44	56	f	f	f	f	f	f	f	\N
1495	10	56	f	f	f	f	f	f	f	\N
1526	41	56	t	t	t	f	f	f	f	\N
1487	2	56	t	f	f	f	f	f	f	\N
1489	4	56	f	f	f	f	f	f	f	\N
1490	5	56	t	f	f	f	f	f	f	\N
1500	15	56	f	f	f	f	\N	f	f	\N
1498	13	56	f	f	f	f	\N	f	f	\N
1528	43	56	t	f	f	f	\N	f	f	\N
1530	45	56	f	f	f	f	\N	f	f	\N
1486	1	56	t	f	f	f	f	f	f	\N
1493	8	56	f	f	f	f	f	f	f	\N
1513	28	56	f	f	f	f	t	f	f	\N
1520	35	56	f	f	f	f	t	f	f	\N
1522	37	56	f	f	f	f	f	f	f	\N
1502	17	56	t	f	f	f	f	f	f	\N
1509	24	56	f	f	f	f	\N	f	f	\N
1512	27	56	f	f	f	f	f	f	f	\N
1518	33	56	f	f	f	f	\N	f	f	\N
1497	12	56	f	f	f	f	f	f	f	\N
1579	39	57	t	f	f	f	t	f	f	\N
1581	41	57	t	f	f	f	f	f	f	\N
1586	46	57	t	t	t	f	f	f	f	\N
1549	9	57	t	f	f	f	f	f	f	\N
1551	11	57	f	f	f	f	f	f	f	\N
1550	10	57	t	t	t	t	f	f	f	3
1573	33	57	f	f	f	f	\N	f	f	\N
1574	34	57	f	f	f	f	f	f	f	\N
1532	47	56	t	f	f	f	f	f	f	\N
1537	52	56	f	f	f	f	f	f	f	\N
1585	45	57	f	f	f	f	\N	f	f	\N
1539	54	56	t	f	f	f	f	f	f	\N
1531	46	56	f	f	f	f	f	f	f	\N
1534	49	56	f	f	f	f	f	f	f	\N
1540	55	56	f	f	f	f	t	f	f	\N
1538	53	56	f	f	f	f	f	f	f	\N
1533	48	56	f	f	f	f	f	f	f	\N
1535	50	56	f	f	f	f	f	f	f	\N
1536	51	56	f	f	f	f	f	f	f	\N
1587	47	57	t	f	f	f	f	f	f	\N
1543	3	57	f	f	f	f	f	f	f	\N
1552	12	57	t	f	f	f	f	f	f	\N
1547	7	57	f	f	f	f	f	f	f	\N
1546	6	57	f	f	f	f	f	f	f	\N
1555	15	57	f	f	f	f	\N	f	f	\N
1576	36	57	t	f	f	f	f	f	f	\N
1583	43	57	t	f	f	f	\N	f	f	\N
1542	2	57	t	f	f	f	f	f	f	\N
1545	5	57	t	f	f	f	f	f	f	\N
1567	27	57	f	f	f	f	f	f	f	\N
1563	23	57	t	f	f	f	f	f	f	\N
1565	25	57	t	f	f	f	t	f	f	\N
1553	13	57	t	t	t	t	\N	f	f	4.1
1588	48	57	t	f	f	f	f	f	f	\N
1557	17	57	t	f	f	f	f	f	f	\N
1561	21	57	f	f	f	f	\N	f	f	\N
1580	40	57	t	f	f	f	f	f	f	\N
1559	19	57	t	f	f	f	\N	f	f	\N
1578	38	57	f	f	f	f	t	f	f	\N
1577	37	57	f	f	f	f	f	f	f	\N
1584	44	57	f	f	f	f	f	f	f	\N
1548	8	57	t	f	f	f	f	f	f	\N
1560	20	57	t	f	f	f	f	f	f	\N
1544	4	57	t	t	t	t	f	f	f	10.4
1582	42	57	t	t	f	f	f	f	f	\N
1566	26	57	f	f	f	f	t	f	f	\N
1554	14	57	t	f	f	f	f	f	f	\N
1564	24	57	f	f	f	f	\N	f	f	\N
1569	29	57	f	f	f	f	\N	f	f	\N
1572	32	57	t	f	f	f	f	f	f	\N
1556	16	57	t	f	f	f	\N	f	f	\N
1575	35	57	f	f	f	f	t	f	f	\N
1570	30	57	t	f	f	f	f	f	f	\N
1571	31	57	f	f	f	f	t	f	f	\N
1541	1	57	t	f	f	f	f	f	f	\N
1558	18	57	t	t	f	f	f	f	f	\N
1562	22	57	f	f	f	f	f	f	f	\N
1568	28	57	t	f	f	f	t	f	f	\N
1590	50	57	f	f	f	f	f	f	f	\N
1589	49	57	f	f	f	f	f	f	f	\N
1592	52	57	f	f	f	f	f	f	f	\N
1596	56	57	f	f	f	f	t	f	f	\N
1595	55	57	f	f	f	f	t	f	f	\N
1593	53	57	f	f	f	f	f	f	f	\N
1606	10	58	t	t	t	t	f	f	f	10.6
1641	45	58	t	t	t	t	\N	f	f	1.4
1653	57	58	t	f	f	f	f	f	f	\N
1591	51	57	t	t	t	t	f	f	f	10.1
1629	33	58	t	t	t	t	\N	f	f	6.1
1594	54	57	t	f	f	f	f	f	f	\N
1609	13	58	t	t	t	f	\N	f	f	\N
1610	14	58	t	f	f	f	t	f	f	\N
1649	53	58	t	f	f	f	f	f	f	\N
1599	3	58	t	f	f	f	f	f	f	\N
1607	11	58	t	f	f	f	f	f	f	\N
1638	42	58	t	t	t	f	f	f	f	\N
1651	55	58	t	f	f	f	f	f	f	\N
1616	20	58	t	f	f	f	f	f	f	\N
1624	28	58	t	f	f	f	f	f	f	\N
1625	29	58	t	f	f	f	\N	f	f	\N
1618	22	58	t	t	t	f	f	f	f	\N
1627	31	58	t	f	f	f	f	f	f	\N
1630	34	58	t	t	t	t	f	f	f	10.1
1647	51	58	t	t	t	t	f	f	f	2.1
1645	49	58	t	t	t	t	f	f	f	2.4
1612	16	58	t	f	f	f	\N	f	f	\N
1621	25	58	t	f	f	f	f	f	f	\N
1603	7	58	t	t	t	t	t	f	f	2.4
1608	12	58	t	f	f	f	f	f	f	\N
1597	1	58	t	f	f	f	f	f	f	\N
1601	5	58	t	f	f	f	f	f	f	\N
1605	9	58	t	f	f	f	f	f	f	\N
1622	26	58	t	t	t	t	f	f	f	2.1
1632	36	58	t	f	f	f	t	f	f	\N
1600	4	58	t	t	t	t	f	f	f	2.1
1639	43	58	t	f	f	f	\N	f	f	\N
1615	19	58	t	f	f	f	\N	f	f	\N
1642	46	58	t	t	t	f	f	f	f	\N
1602	6	58	t	t	t	t	f	f	f	8.1
1650	54	58	t	f	f	f	t	f	f	\N
1636	40	58	t	f	f	f	f	f	f	\N
1611	15	58	t	f	f	f	\N	f	f	\N
1617	21	58	t	t	t	t	\N	f	f	8.4
1626	30	58	t	f	f	f	f	f	f	\N
1620	24	58	t	f	f	f	\N	f	f	\N
1628	32	58	t	f	f	f	f	f	f	\N
1646	50	58	t	f	f	f	f	f	f	\N
1631	35	58	t	f	f	f	f	f	f	\N
1614	18	58	t	t	t	t	t	f	f	6.1
1643	47	58	t	f	f	f	t	f	f	\N
1644	48	58	t	f	f	f	f	f	f	\N
1635	39	58	t	f	f	f	f	f	f	\N
1613	17	58	t	f	f	f	t	f	f	\N
1648	52	58	t	f	f	f	f	f	f	\N
1619	23	58	t	f	f	f	f	f	f	\N
1637	41	58	t	f	f	f	f	f	f	\N
1623	27	58	t	f	f	f	t	f	f	\N
1652	56	58	t	f	f	f	f	f	f	\N
1633	37	58	t	t	t	t	f	f	f	6.1
1640	44	58	t	t	t	t	f	f	f	9
1634	38	58	t	f	f	f	f	f	f	\N
1604	8	58	t	f	f	f	f	f	f	\N
1598	2	58	t	f	f	f	f	f	f	\N
1660	7	59	f	f	f	f	f	f	f	\N
1656	3	59	f	f	f	f	f	f	f	\N
1657	4	59	f	f	f	f	f	f	f	\N
1658	5	59	t	f	f	f	f	f	f	\N
1659	6	59	f	f	f	f	f	f	f	\N
1655	2	59	t	f	f	f	f	f	f	\N
1654	1	59	t	f	f	f	f	f	f	\N
1661	8	59	f	f	f	f	f	f	f	\N
1663	10	59	f	f	f	f	f	f	f	\N
1691	38	59	f	f	f	f	t	f	f	\N
1711	58	59	t	f	f	f	f	f	f	\N
1670	17	59	t	f	f	f	f	f	f	\N
1679	26	59	f	f	f	f	t	f	f	\N
1694	41	59	t	t	t	t	f	f	f	0.1
1697	44	59	f	f	f	f	f	f	f	\N
1706	53	59	f	f	f	f	f	f	f	\N
1666	13	59	f	f	f	f	\N	f	f	\N
1681	28	59	f	f	f	f	t	f	f	\N
1709	56	59	f	f	f	f	t	f	f	\N
1667	14	59	t	t	t	f	f	f	f	\N
1683	30	59	t	f	f	f	f	f	f	\N
1689	36	59	t	t	t	t	f	f	f	0.1
1692	39	59	t	f	f	f	t	f	f	\N
1700	47	59	t	f	f	f	f	f	f	\N
1665	12	59	f	f	f	f	f	f	f	\N
1677	24	59	f	f	f	f	\N	f	f	\N
1687	34	59	f	f	f	f	f	f	f	\N
1690	37	59	f	f	f	f	f	f	f	\N
1695	42	59	t	f	f	f	f	f	f	\N
1707	54	59	t	f	f	f	f	f	f	\N
1708	55	59	f	f	f	f	t	f	f	\N
1668	15	59	f	f	f	f	\N	f	f	\N
1669	16	59	f	f	f	f	\N	f	f	\N
1675	22	59	f	f	f	f	f	f	f	\N
1688	35	59	f	f	f	f	t	f	f	\N
1662	9	59	t	t	t	f	f	f	f	\N
1664	11	59	f	f	f	f	f	f	f	\N
1699	46	59	f	f	f	f	f	f	f	\N
1672	19	59	t	t	t	t	\N	f	f	10.1
1673	20	59	f	f	f	f	f	f	f	\N
1674	21	59	f	f	f	f	\N	f	f	\N
1676	23	59	f	f	f	f	f	f	f	\N
1684	31	59	f	f	f	f	t	f	f	\N
1696	43	59	t	f	f	f	\N	f	f	\N
1698	45	59	f	f	f	f	\N	f	f	\N
1701	48	59	f	f	f	f	f	f	f	\N
1671	18	59	f	f	f	f	f	f	f	\N
1680	27	59	f	f	f	f	f	f	f	\N
1703	50	59	f	f	f	f	f	f	f	\N
1710	57	59	f	f	f	f	t	f	f	\N
1682	29	59	f	f	f	f	\N	f	f	\N
1693	40	59	t	t	t	f	f	f	f	\N
1705	52	59	f	f	f	f	f	f	f	\N
1678	25	59	f	f	f	f	t	f	f	\N
1686	33	59	f	f	f	f	\N	f	f	\N
1685	32	59	f	f	f	f	f	f	f	\N
1702	49	59	f	f	f	f	f	f	f	\N
1704	51	59	f	f	f	f	f	f	f	\N
1713	2	60	t	f	f	f	f	f	f	\N
1718	7	60	t	f	f	f	f	f	f	\N
1719	8	60	t	t	f	f	f	f	f	\N
1724	13	60	t	f	f	f	\N	f	f	\N
1716	5	60	t	f	f	f	t	f	f	\N
1721	10	60	t	f	f	f	t	f	f	\N
1712	1	60	t	f	f	f	t	f	f	\N
1715	4	60	t	f	f	f	t	f	f	\N
1720	9	60	t	t	t	t	f	f	f	1.6
1722	11	60	t	f	f	f	f	f	f	\N
1725	14	60	t	t	f	f	f	f	f	\N
1726	15	60	t	t	t	t	\N	f	f	1.4
1727	16	60	t	t	t	t	\N	f	f	8.1
1717	6	60	t	f	f	f	t	f	f	\N
1728	17	60	t	f	f	f	f	f	f	\N
1723	12	60	t	f	f	f	f	f	f	\N
1714	3	60	t	t	t	t	f	f	f	5
1789	19	61	t	t	t	t	\N	f	f	6.2
1766	55	60	t	f	f	f	f	f	f	\N
1755	44	60	t	f	f	f	t	f	f	\N
1739	28	60	t	f	f	f	f	f	f	\N
1748	37	60	t	f	f	f	f	f	f	\N
1756	45	60	t	f	f	f	\N	f	f	\N
1741	30	60	t	f	f	f	f	f	f	\N
1742	31	60	t	t	t	f	f	f	f	\N
1795	25	61	t	f	f	f	f	f	f	\N
1736	25	60	t	f	f	f	f	f	f	\N
1752	41	60	t	t	t	t	f	f	f	10.4
1743	32	60	t	t	t	t	f	f	f	9
1765	54	60	t	f	f	f	f	f	f	\N
1751	40	60	t	t	f	f	f	f	f	\N
1800	30	61	t	f	f	f	f	f	f	\N
1737	26	60	t	f	f	f	f	f	f	\N
1744	33	60	t	f	f	f	\N	f	f	\N
1770	59	60	t	t	t	t	f	f	f	1.1
1775	5	61	t	f	f	f	t	f	f	\N
1750	39	60	t	f	f	f	f	f	f	\N
1763	52	60	t	f	f	f	t	f	f	\N
1731	20	60	t	t	t	t	f	f	f	7
1788	18	61	t	f	f	f	f	f	f	\N
1734	23	60	t	f	f	f	f	f	f	\N
1762	51	60	t	f	f	f	t	f	f	\N
1767	56	60	t	t	t	f	f	f	f	\N
1772	2	61	t	f	f	f	f	f	f	\N
1764	53	60	t	t	t	f	t	f	f	\N
1732	21	60	t	f	f	f	\N	f	f	\N
1769	58	60	t	f	f	f	f	f	f	\N
1733	22	60	t	f	f	f	f	f	f	\N
1745	34	60	t	f	f	f	t	f	f	\N
1738	27	60	t	t	t	t	f	f	f	5
1784	14	61	t	f	f	f	f	f	f	\N
1753	42	60	t	f	f	f	f	f	f	\N
1768	57	60	t	f	f	f	f	f	f	\N
1729	18	60	t	f	f	f	f	f	f	\N
1749	38	60	t	f	f	f	f	f	f	\N
1754	43	60	t	f	f	f	\N	f	f	\N
1757	46	60	t	f	f	f	t	f	f	\N
1746	35	60	t	f	f	f	f	f	f	\N
1730	19	60	t	t	f	f	\N	f	f	\N
1760	49	60	t	f	f	f	t	f	f	\N
1761	50	60	t	t	f	f	t	f	f	\N
1747	36	60	t	t	t	t	f	f	f	9
1759	48	60	t	f	f	f	f	f	f	\N
1740	29	60	t	f	f	f	\N	f	f	\N
1758	47	60	t	f	f	f	f	f	f	\N
1735	24	60	t	t	t	t	\N	f	f	2.6
1794	24	61	f	f	f	f	\N	f	f	\N
1799	29	61	f	f	f	f	\N	f	f	\N
1777	7	61	f	f	f	f	f	f	f	\N
1796	26	61	f	f	f	f	f	f	f	\N
1801	31	61	f	f	f	f	f	f	f	\N
1776	6	61	f	f	f	f	t	f	f	\N
1790	20	61	t	f	f	f	f	f	f	\N
1779	9	61	t	t	t	f	f	f	f	\N
1792	22	61	f	f	f	f	f	f	f	\N
1774	4	61	t	f	f	f	t	f	f	\N
1778	8	61	t	t	t	f	f	f	f	\N
1797	27	61	f	f	f	f	f	f	f	\N
1780	10	61	t	f	f	f	t	f	f	\N
1781	11	61	f	f	f	f	f	f	f	\N
1793	23	61	t	f	f	f	f	f	f	\N
1782	12	61	t	f	f	f	f	f	f	\N
1783	13	61	t	f	f	f	\N	f	f	\N
1787	17	61	t	t	t	f	f	f	f	\N
1791	21	61	f	f	f	f	\N	f	f	\N
1771	1	61	t	f	f	f	t	f	f	\N
1773	3	61	f	f	f	f	f	f	f	\N
1785	15	61	f	f	f	f	\N	f	f	\N
1786	16	61	t	t	f	f	\N	f	f	\N
1798	28	61	t	t	f	f	f	f	f	\N
1802	32	61	t	f	f	f	f	f	f	\N
1845	15	62	f	f	f	f	f	f	f	\N
1861	31	62	f	f	f	f	f	f	f	\N
1812	42	61	t	f	f	f	f	f	f	\N
1886	56	62	f	f	f	f	f	f	f	\N
1840	10	62	f	f	f	f	f	f	f	\N
1869	39	62	t	f	f	f	f	f	f	\N
1841	11	62	f	f	f	f	f	f	f	\N
1827	57	61	t	t	t	t	f	f	f	2.1
1830	60	61	t	f	f	f	t	f	f	\N
1820	50	61	f	f	f	f	t	f	f	\N
1849	19	62	t	t	t	t	f	f	f	4.8
1806	36	61	t	f	f	f	f	f	f	\N
1854	24	62	f	f	f	f	f	f	f	\N
1858	28	62	f	f	f	f	f	f	f	\N
1809	39	61	t	t	f	f	f	f	f	\N
1863	33	62	f	f	f	f	f	f	f	\N
1821	51	61	t	f	f	f	t	f	f	\N
1823	53	61	f	f	f	f	t	f	f	\N
1803	33	61	f	f	f	f	\N	f	f	\N
1885	55	62	f	f	f	f	f	f	f	\N
1813	43	61	t	f	f	f	\N	f	f	\N
1814	44	61	f	f	f	f	t	f	f	\N
1889	59	62	f	f	f	f	f	f	f	\N
1834	4	62	f	f	f	f	f	f	f	\N
1857	27	62	f	f	f	f	f	f	f	\N
1828	58	61	t	t	t	f	f	f	f	\N
1805	35	61	f	f	f	f	f	f	f	\N
1843	13	62	f	f	f	f	f	f	f	\N
1818	48	61	t	f	f	f	f	f	f	\N
1815	45	61	f	f	f	f	\N	f	f	\N
1847	17	62	t	f	f	f	f	f	f	\N
1817	47	61	t	f	f	f	f	f	f	\N
1868	38	62	f	f	f	f	f	f	f	\N
1824	54	61	t	f	f	f	f	f	f	\N
1825	55	61	f	f	f	f	f	f	f	\N
1826	56	61	f	f	f	f	f	f	f	\N
1819	49	61	f	f	f	f	t	f	f	\N
1822	52	61	f	f	f	f	t	f	f	\N
1808	38	61	f	f	f	f	f	f	f	\N
1875	45	62	f	f	f	f	f	f	f	\N
1811	41	61	t	f	f	f	f	f	f	\N
1829	59	61	f	f	f	f	f	f	f	\N
1804	34	61	f	f	f	f	t	f	f	\N
1844	14	62	t	t	t	f	f	f	f	\N
1810	40	61	t	f	f	f	f	f	f	\N
1856	26	62	f	f	f	f	f	f	f	\N
1816	46	61	t	f	f	f	t	f	f	\N
1807	37	61	f	f	f	f	f	f	f	\N
1887	57	62	f	f	f	f	f	f	f	\N
1882	52	62	f	f	f	f	f	f	f	\N
1835	5	62	t	f	f	f	f	f	f	\N
1853	23	62	f	f	f	f	f	f	f	\N
1855	25	62	f	f	f	f	f	f	f	\N
1872	42	62	t	f	f	f	f	f	f	\N
1838	8	62	f	f	f	f	f	f	f	\N
1862	32	62	f	f	f	f	f	f	f	\N
1865	35	62	f	f	f	f	f	f	f	\N
1839	9	62	t	t	t	f	f	f	f	\N
1851	21	62	f	f	f	f	f	f	f	\N
1864	34	62	f	f	f	f	f	f	f	\N
1832	2	62	t	f	f	f	f	f	f	\N
1848	18	62	f	f	f	f	f	f	f	\N
1867	37	62	f	f	f	f	f	f	f	\N
1870	40	62	t	t	t	f	f	f	f	\N
1876	46	62	f	f	f	f	f	f	f	\N
1871	41	62	t	t	t	f	f	f	f	\N
1833	3	62	f	f	f	f	f	f	f	\N
1836	6	62	f	f	f	f	f	f	f	\N
1842	12	62	f	f	f	f	f	f	f	\N
1846	16	62	f	f	f	f	f	f	f	\N
1852	22	62	f	f	f	f	f	f	f	\N
1859	29	62	f	f	f	f	f	f	f	\N
1837	7	62	f	f	f	f	f	f	f	\N
1860	30	62	t	f	f	f	f	f	f	\N
1877	47	62	t	f	f	f	f	f	f	\N
1850	20	62	f	f	f	f	f	f	f	\N
1883	53	62	f	f	f	f	f	f	f	\N
1873	43	62	t	f	f	f	f	f	f	\N
1831	1	62	t	f	f	f	f	f	f	\N
1874	44	62	f	f	f	f	f	f	f	\N
1878	48	62	f	f	f	f	f	f	f	\N
1879	49	62	f	f	f	f	f	f	f	\N
1881	51	62	f	f	f	f	f	f	f	\N
1888	58	62	t	f	f	f	f	f	f	\N
1880	50	62	f	f	f	f	f	f	f	\N
1866	36	62	t	t	t	f	f	f	f	\N
1884	54	62	t	f	f	f	f	f	f	\N
1947	56	63	f	f	f	f	f	f	f	\N
1922	31	63	f	f	f	f	f	f	f	\N
1939	48	63	f	f	f	f	f	f	f	\N
1890	60	62	t	t	t	f	f	f	f	\N
1891	61	62	f	f	f	f	f	f	f	\N
1895	4	63	f	f	f	f	f	f	f	\N
1942	51	63	f	f	f	f	f	f	f	\N
1911	20	63	f	f	f	f	f	f	f	\N
1919	28	63	f	f	f	f	f	f	f	\N
1949	58	63	t	t	t	t	f	f	f	10.1
1894	3	63	f	f	f	f	f	f	f	\N
1897	6	63	f	f	f	f	f	f	f	\N
1909	18	63	f	f	f	f	f	f	f	\N
1928	37	63	f	f	f	f	t	f	f	\N
1946	55	63	f	f	f	f	f	f	f	\N
1892	1	63	t	t	t	f	f	f	f	\N
1902	11	63	f	f	f	f	t	f	f	\N
1905	14	63	t	f	f	f	f	f	f	\N
1910	19	63	t	t	t	t	\N	f	f	1.4
1912	21	63	f	f	f	f	\N	f	f	\N
1907	16	63	f	f	f	f	\N	f	f	\N
1914	23	63	f	f	f	f	t	f	f	\N
1927	36	63	t	f	f	f	f	f	f	\N
1945	54	63	t	t	t	f	f	f	f	\N
1940	49	63	f	f	f	f	f	f	f	\N
1901	10	63	f	f	f	f	f	f	f	\N
1918	27	63	f	f	f	f	f	f	f	\N
1953	62	63	f	f	f	f	\N	f	f	\N
1950	59	63	f	f	f	f	f	f	f	\N
1893	2	63	t	t	t	t	f	f	f	0.1
1898	7	63	f	f	f	f	f	f	f	\N
1896	5	63	t	t	t	t	f	f	f	10.1
1903	12	63	f	f	f	f	t	f	f	\N
1900	9	63	t	t	t	t	t	f	f	4.1
1906	15	63	f	f	f	f	\N	f	f	\N
1913	22	63	f	f	f	f	t	f	f	\N
1952	61	63	f	f	f	f	f	f	f	\N
1915	24	63	f	f	f	f	\N	f	f	\N
1930	39	63	t	t	t	f	f	f	f	\N
1908	17	63	t	t	t	t	f	f	f	4.1
1951	60	63	t	f	f	f	f	f	f	\N
1917	26	63	f	f	f	f	f	f	f	\N
1925	34	63	f	f	f	f	f	f	f	\N
1937	46	63	f	f	f	f	f	f	f	\N
1931	40	63	t	f	f	f	f	f	f	\N
1916	25	63	f	f	f	f	f	f	f	\N
1929	38	63	f	f	f	f	f	f	f	\N
1899	8	63	f	f	f	f	f	f	f	\N
1933	42	63	t	f	f	f	t	f	f	\N
1936	45	63	f	f	f	f	\N	f	f	\N
1904	13	63	f	f	f	f	\N	f	f	\N
1924	33	63	f	f	f	f	\N	f	f	\N
1935	44	63	f	f	f	f	f	f	f	\N
1938	47	63	t	t	t	t	f	f	f	4.2
1943	52	63	f	f	f	f	f	f	f	\N
1948	57	63	f	f	f	f	f	f	f	\N
1920	29	63	f	f	f	f	\N	f	f	\N
1923	32	63	f	f	f	f	t	f	f	\N
1932	41	63	t	f	f	f	t	f	f	\N
1941	50	63	f	f	f	f	f	f	f	\N
1926	35	63	f	f	f	f	f	f	f	\N
1921	30	63	t	t	t	f	f	f	f	\N
1944	53	63	f	f	f	f	f	f	f	\N
1934	43	63	t	t	t	t	\N	f	f	10.4
1955	2	64	t	f	f	f	f	f	f	\N
1954	1	64	t	f	f	f	f	f	f	\N
1957	4	64	t	f	f	f	f	f	f	\N
1956	3	64	t	t	t	t	f	f	f	4.6
1963	10	64	t	f	f	f	f	f	f	\N
1959	6	64	t	f	f	f	f	f	f	\N
1981	28	64	t	t	t	t	f	f	f	6.1
1973	20	64	t	f	f	f	f	f	f	\N
2017	1	65	t	t	t	t	f	f	f	11
1986	33	64	t	f	f	f	\N	f	f	\N
1987	34	64	t	f	f	f	f	f	f	\N
1989	36	64	t	f	f	f	f	f	f	\N
2040	24	65	t	t	t	f	\N	f	f	\N
1991	38	64	t	f	f	f	f	f	f	\N
1982	29	64	t	t	t	t	\N	f	f	8.1
2005	52	64	t	t	t	t	f	f	f	1.1
2003	50	64	t	t	t	t	f	f	f	4.6
2019	3	65	t	t	t	f	f	f	f	\N
1962	9	64	t	t	t	f	t	f	f	\N
1992	39	64	t	t	t	f	f	f	f	\N
2010	57	64	t	t	t	t	f	f	f	8.1
2025	9	65	t	t	t	t	f	f	f	2.1
1960	7	64	t	f	f	f	f	f	f	\N
1970	17	64	t	t	t	t	f	f	f	2.1
2000	47	64	t	f	f	f	f	f	f	\N
1984	31	64	t	f	f	f	f	f	f	\N
2034	18	65	f	f	f	f	f	f	f	\N
1997	44	64	t	f	f	f	f	f	f	\N
1966	13	64	t	f	f	f	\N	f	f	\N
1988	35	64	t	t	t	t	f	f	f	0.1
2039	23	65	f	f	f	f	f	f	f	\N
2008	55	64	t	t	t	t	f	f	f	1.8
2004	51	64	t	f	f	f	f	f	f	\N
2043	27	65	f	f	f	f	f	f	f	\N
2016	63	64	t	f	f	f	t	f	f	\N
1961	8	64	t	t	t	t	f	f	f	0.2
2006	53	64	t	t	t	t	f	f	f	8.1
1968	15	64	t	f	f	f	\N	f	f	\N
2049	33	65	t	f	f	f	\N	f	f	\N
1976	23	64	t	f	f	f	t	f	f	\N
1964	11	64	t	t	t	f	t	f	f	\N
1985	32	64	t	f	f	f	t	f	f	\N
1978	25	64	t	f	f	f	f	f	f	\N
1993	40	64	t	f	f	f	f	f	f	\N
1979	26	64	t	f	f	f	f	f	f	\N
2014	61	64	t	f	f	f	f	f	f	\N
1974	21	64	t	f	f	f	\N	f	f	\N
1980	27	64	t	f	f	f	f	f	f	\N
1975	22	64	t	f	f	f	t	f	f	\N
1994	41	64	t	f	f	f	t	f	f	\N
1983	30	64	t	f	f	f	f	f	f	\N
1990	37	64	t	f	f	f	t	f	f	\N
1971	18	64	t	f	f	f	f	f	f	\N
1995	42	64	t	f	f	f	t	f	f	\N
2015	62	64	t	f	f	f	\N	f	f	\N
1967	14	64	t	f	f	f	f	f	f	\N
1972	19	64	t	t	t	t	\N	f	f	10.2
2031	15	65	t	f	f	f	\N	f	f	\N
1998	45	64	t	f	f	f	\N	f	f	\N
1999	46	64	t	f	f	f	f	f	f	\N
2036	20	65	f	f	f	f	f	f	f	\N
2009	56	64	t	f	f	f	f	f	f	\N
2012	59	64	t	f	f	f	f	f	f	\N
1958	5	64	t	f	f	f	f	f	f	\N
2018	2	65	t	t	f	f	f	f	f	\N
1965	12	64	t	f	f	f	t	f	f	\N
2002	49	64	t	f	f	f	f	f	f	\N
2013	60	64	t	f	f	f	f	f	f	\N
1969	16	64	t	t	t	t	\N	f	f	1.1
2037	21	65	f	f	f	f	\N	f	f	\N
1996	43	64	t	f	f	f	\N	f	f	\N
2007	54	64	t	f	f	f	f	f	f	\N
1977	24	64	t	t	t	t	\N	f	f	10.1
2001	48	64	t	f	f	f	f	f	f	\N
2011	58	64	t	t	t	t	f	f	f	0.1
2021	5	65	t	t	f	f	f	f	f	\N
2029	13	65	f	f	f	f	\N	f	f	\N
2042	26	65	t	t	t	f	t	f	f	\N
2030	14	65	t	f	f	f	f	f	f	\N
2022	6	65	t	t	f	f	f	f	f	\N
2033	17	65	t	t	t	f	f	f	f	\N
2048	32	65	f	f	f	f	f	f	f	\N
2032	16	65	f	f	f	f	\N	f	f	\N
2044	28	65	f	f	f	f	t	f	f	\N
2020	4	65	f	f	f	f	f	f	f	\N
2024	8	65	f	f	f	f	f	f	f	\N
2041	25	65	f	f	f	f	t	f	f	\N
2045	29	65	f	f	f	f	\N	f	f	\N
2027	11	65	f	f	f	f	f	f	f	\N
2028	12	65	f	f	f	f	f	f	f	\N
2047	31	65	t	f	f	f	t	f	f	\N
2035	19	65	t	t	f	f	\N	f	f	\N
2046	30	65	t	t	t	t	f	f	f	6.1
2026	10	65	f	f	f	f	f	f	f	\N
2038	22	65	t	t	f	f	f	f	f	\N
2023	7	65	t	t	f	f	f	f	f	\N
2067	51	65	f	f	f	f	f	f	f	\N
2078	62	65	f	f	f	f	\N	f	f	\N
2092	12	66	f	f	f	f	f	f	f	\N
2090	10	66	f	f	f	f	f	f	f	\N
2079	63	65	f	f	f	f	f	f	f	\N
2068	52	65	t	t	f	f	f	f	f	\N
2059	43	65	t	t	t	f	\N	f	f	\N
2066	50	65	f	f	f	f	f	f	f	\N
2061	45	65	f	f	f	f	\N	f	f	\N
2051	35	65	t	t	f	f	t	f	f	\N
2062	46	65	f	f	f	f	f	f	f	\N
2063	47	65	t	t	t	f	f	f	f	\N
2069	53	65	f	f	f	f	f	f	f	\N
2075	59	65	f	f	f	f	t	f	f	\N
2054	38	65	f	f	f	f	t	f	f	\N
2058	42	65	t	f	f	f	f	f	f	\N
2064	48	65	f	f	f	f	f	f	f	\N
2050	34	65	t	t	t	f	f	f	f	\N
2057	41	65	t	f	f	f	f	f	f	\N
2070	54	65	t	t	t	f	f	f	f	\N
2074	58	65	t	t	t	f	f	f	f	\N
2053	37	65	t	f	f	f	f	f	f	\N
2077	61	65	f	f	f	f	f	f	f	\N
2080	64	65	t	f	f	f	f	f	f	\N
2056	40	65	t	f	f	f	f	f	f	\N
2076	60	65	t	f	f	f	f	f	f	\N
2071	55	65	t	t	f	f	t	f	f	\N
2052	36	65	t	f	f	f	f	f	f	\N
2055	39	65	t	t	t	t	t	f	f	6.1
2060	44	65	f	f	f	f	f	f	f	\N
2065	49	65	f	f	f	f	f	f	f	\N
2072	56	65	f	f	f	f	t	f	f	\N
2073	57	65	f	f	f	f	t	f	f	\N
2081	1	66	t	t	t	t	f	f	f	6.1
2095	15	66	f	f	f	f	\N	f	f	\N
2101	21	66	f	f	f	f	\N	f	f	\N
2103	23	66	f	f	f	f	f	f	f	\N
2106	26	66	f	f	f	f	f	f	f	\N
2107	27	66	f	f	f	f	f	f	f	\N
2108	28	66	f	f	f	f	f	f	f	\N
2109	29	66	f	f	f	f	\N	f	f	\N
2093	13	66	f	f	f	f	\N	f	f	\N
2114	34	66	f	f	f	f	f	f	f	\N
2088	8	66	f	f	f	f	t	f	f	\N
2096	16	66	f	f	f	f	\N	f	f	\N
2097	17	66	t	t	t	f	f	f	f	\N
2104	24	66	f	f	f	f	\N	f	f	\N
2105	25	66	f	f	f	f	f	f	f	\N
2111	31	66	f	f	f	f	f	f	f	\N
2084	4	66	f	f	f	f	f	f	f	\N
2085	5	66	t	t	t	t	f	f	f	2.4
2086	6	66	f	f	f	f	f	f	f	\N
2115	35	66	f	f	f	f	f	f	f	\N
2099	19	66	t	t	t	f	\N	f	f	\N
2100	20	66	f	f	f	f	t	f	f	\N
2102	22	66	f	f	f	f	f	f	f	\N
2082	2	66	t	t	t	f	t	f	f	\N
2112	32	66	f	f	f	f	f	f	f	\N
2087	7	66	f	f	f	f	f	f	f	\N
2091	11	66	f	f	f	f	f	f	f	\N
2098	18	66	f	f	f	f	f	f	f	\N
2083	3	66	f	f	f	f	t	f	f	\N
2089	9	66	t	t	t	t	f	f	f	4.8
2094	14	66	t	f	f	f	f	f	f	\N
2110	30	66	t	t	t	t	t	f	f	10.1
2113	33	66	f	f	f	f	\N	f	f	\N
2116	36	66	t	f	f	f	f	f	f	\N
2137	57	66	f	f	f	f	f	f	f	\N
2151	6	67	f	f	f	f	f	f	f	\N
2138	58	66	t	t	t	f	f	f	f	\N
2128	48	66	f	f	f	f	t	f	f	\N
2133	53	66	f	f	f	f	f	f	f	\N
2135	55	66	f	f	f	f	f	f	f	\N
2120	40	66	t	f	f	f	t	f	f	\N
2167	22	67	f	f	f	f	f	f	f	\N
2123	43	66	t	t	t	f	\N	f	f	\N
2188	43	67	t	f	f	f	\N	f	f	\N
2191	46	67	f	f	f	f	f	f	f	\N
2119	39	66	t	t	t	t	f	f	f	10.6
2126	46	66	f	f	f	f	f	f	f	\N
2131	51	66	f	f	f	f	f	f	f	\N
2136	56	66	f	f	f	f	f	f	f	\N
2141	61	66	f	f	f	f	f	f	f	\N
2122	42	66	t	f	f	f	f	f	f	\N
2148	3	67	f	f	f	f	f	f	f	\N
2144	64	66	t	f	f	f	f	f	f	\N
2145	65	66	f	f	f	f	f	f	f	\N
2183	38	67	f	f	f	f	f	f	f	\N
2121	41	66	t	f	f	f	f	f	f	\N
2127	47	66	t	t	t	f	f	f	f	\N
2129	49	66	f	f	f	f	f	f	f	\N
2192	47	67	t	f	f	f	t	f	f	\N
2134	54	66	t	t	t	f	f	f	f	\N
2143	63	66	f	f	f	f	f	f	f	\N
2139	59	66	f	f	f	f	f	f	f	\N
2140	60	66	t	f	f	f	f	f	f	\N
2142	62	66	f	f	f	f	\N	f	f	\N
2125	45	66	f	f	f	f	\N	f	f	\N
2130	50	66	f	f	f	f	f	f	f	\N
2117	37	66	f	f	f	f	f	f	f	\N
2118	38	66	f	f	f	f	f	f	f	\N
2124	44	66	f	f	f	f	f	f	f	\N
2132	52	66	f	f	f	f	f	f	f	\N
2180	35	67	f	f	f	f	f	f	f	\N
2184	39	67	t	f	f	f	f	f	f	\N
2193	48	67	f	f	f	f	f	f	f	\N
2149	4	67	f	f	f	f	f	f	f	\N
2177	32	67	f	f	f	f	f	f	f	\N
2171	26	67	f	f	f	f	f	f	f	\N
2185	40	67	t	t	t	f	f	f	f	\N
2155	10	67	f	f	f	f	f	f	f	\N
2179	34	67	f	f	f	f	f	f	f	\N
2181	36	67	t	t	t	t	t	f	f	4.1
2182	37	67	f	f	f	f	f	f	f	\N
2187	42	67	t	f	f	f	f	f	f	\N
2157	12	67	f	f	f	f	f	f	f	\N
2147	2	67	t	f	f	f	f	f	f	\N
2152	7	67	f	f	f	f	t	f	f	\N
2170	25	67	f	f	f	f	f	f	f	\N
2172	27	67	f	f	f	f	t	f	f	\N
2176	31	67	f	f	f	f	f	f	f	\N
2154	9	67	t	t	t	t	f	f	f	0.1
2163	18	67	f	f	f	f	t	f	f	\N
2158	13	67	f	f	f	f	\N	f	f	\N
2190	45	67	f	f	f	f	\N	f	f	\N
2169	24	67	f	f	f	f	\N	f	f	\N
2146	1	67	t	f	f	f	f	f	f	\N
2156	11	67	f	f	f	f	f	f	f	\N
2165	20	67	f	f	f	f	f	f	f	\N
2166	21	67	f	f	f	f	\N	f	f	\N
2159	14	67	t	t	t	t	t	f	f	1.2
2173	28	67	f	f	f	f	f	f	f	\N
2168	23	67	f	f	f	f	f	f	f	\N
2178	33	67	f	f	f	f	\N	f	f	\N
2160	15	67	f	f	f	f	\N	f	f	\N
2161	16	67	f	f	f	f	\N	f	f	\N
2186	41	67	t	t	t	t	f	f	f	8.1
2153	8	67	f	f	f	f	f	f	f	\N
2162	17	67	t	f	f	f	t	f	f	\N
2174	29	67	f	f	f	f	\N	f	f	\N
2164	19	67	t	t	t	t	\N	f	f	4.1
2189	44	67	f	f	f	f	f	f	f	\N
2175	30	67	t	f	f	f	f	f	f	\N
2150	5	67	t	f	f	f	f	f	f	\N
2215	4	68	t	f	f	f	t	f	f	\N
2219	8	68	t	t	t	f	f	f	f	\N
2213	2	68	t	f	f	f	f	f	f	\N
2206	61	67	f	f	f	f	f	f	f	\N
2196	51	67	f	f	f	f	f	f	f	\N
2198	53	67	f	f	f	f	f	f	f	\N
2216	5	68	t	f	f	f	t	f	f	\N
2205	60	67	t	t	t	t	f	f	f	10.2
2208	63	67	f	f	f	f	f	f	f	\N
2210	65	67	f	f	f	f	f	f	f	\N
2204	59	67	f	f	f	f	f	f	f	\N
2201	56	67	f	f	f	f	f	f	f	\N
2207	62	67	f	f	f	f	\N	f	f	\N
2211	66	67	f	f	f	f	f	f	f	\N
2202	57	67	f	f	f	f	f	f	f	\N
2227	16	68	t	t	t	f	\N	f	f	\N
2209	64	67	t	f	f	f	f	f	f	\N
2195	50	67	f	f	f	f	f	f	f	\N
2197	52	67	f	f	f	f	f	f	f	\N
2199	54	67	t	f	f	f	t	f	f	\N
2200	55	67	f	f	f	f	f	f	f	\N
2212	1	68	t	f	f	f	t	f	f	\N
2203	58	67	t	f	f	f	t	f	f	\N
2194	49	67	f	f	f	f	f	f	f	\N
2214	3	68	t	t	t	f	f	f	f	\N
2225	14	68	t	f	f	f	f	f	f	\N
2228	17	68	t	t	t	f	f	f	f	\N
2217	6	68	t	f	f	f	t	f	f	\N
2218	7	68	t	f	f	f	f	f	f	\N
2222	11	68	t	t	t	f	f	f	f	\N
2223	12	68	t	f	f	f	f	f	f	\N
2221	10	68	t	f	f	f	t	f	f	\N
2226	15	68	t	f	f	f	\N	f	f	\N
2220	9	68	t	t	t	f	f	f	f	\N
2224	13	68	t	f	f	f	\N	f	f	\N
2235	24	68	t	t	t	t	\N	f	f	6.2
2266	55	68	t	t	t	f	f	f	f	\N
2299	21	69	t	t	f	f	\N	f	f	\N
2274	63	68	t	f	f	f	f	f	f	\N
2257	46	68	t	f	f	f	t	f	f	\N
2250	39	68	t	t	t	f	f	f	f	\N
2275	64	68	t	f	f	f	f	f	f	\N
2297	19	69	t	t	f	f	\N	f	f	\N
2277	66	68	t	f	f	f	f	f	f	\N
2255	44	68	t	f	f	f	t	f	f	\N
2229	18	68	t	f	f	f	f	f	f	\N
2231	20	68	t	f	f	f	f	f	f	\N
2273	62	68	t	f	f	f	\N	f	f	\N
2247	36	68	t	f	f	f	f	f	f	\N
2300	22	69	t	t	f	f	f	f	f	\N
2244	33	68	t	f	f	f	\N	f	f	\N
2248	37	68	t	f	f	f	f	f	f	\N
2251	40	68	t	f	f	f	f	f	f	\N
2252	41	68	t	f	f	f	f	f	f	\N
2267	56	68	t	f	f	f	f	f	f	\N
2259	48	68	t	f	f	f	f	f	f	\N
2292	14	69	t	f	f	f	f	f	f	\N
2236	25	68	t	f	f	f	f	f	f	\N
2258	47	68	t	f	f	f	f	f	f	\N
2260	49	68	t	f	f	f	t	f	f	\N
2240	29	68	t	t	t	t	\N	f	f	10.8
2265	54	68	t	f	f	f	f	f	f	\N
2278	67	68	t	f	f	f	f	f	f	\N
2269	58	68	t	t	t	f	f	f	f	\N
2237	26	68	t	f	f	f	f	f	f	\N
2256	45	68	t	f	f	f	\N	f	f	\N
2233	22	68	t	f	f	f	f	f	f	\N
2272	61	68	t	f	f	f	t	f	f	\N
2262	51	68	t	f	f	f	t	f	f	\N
2253	42	68	t	f	f	f	f	f	f	\N
2271	60	68	t	f	f	f	t	f	f	\N
2249	38	68	t	f	f	f	f	f	f	\N
2242	31	68	t	f	f	f	f	f	f	\N
2232	21	68	t	f	f	f	\N	f	f	\N
2238	27	68	t	f	f	f	f	f	f	\N
2294	16	69	t	t	t	t	\N	f	f	2
2246	35	68	t	t	t	f	f	f	f	\N
2239	28	68	t	t	t	t	f	f	f	10.4
2241	30	68	t	f	f	f	f	f	f	\N
2254	43	68	t	f	f	f	\N	f	f	\N
2245	34	68	t	f	f	f	t	f	f	\N
2261	50	68	t	t	t	f	t	f	f	\N
2276	65	68	t	f	f	f	f	f	f	\N
2263	52	68	t	t	t	f	t	f	f	\N
2270	59	68	t	f	f	f	f	f	f	\N
2303	25	69	t	t	t	t	f	f	f	9
2230	19	68	t	t	t	t	\N	f	f	6.1
2298	20	69	t	f	f	f	f	f	f	\N
2243	32	68	t	f	f	f	f	f	f	\N
2287	9	69	t	t	t	f	f	f	f	\N
2291	13	69	t	f	f	f	\N	f	f	\N
2296	18	69	t	f	f	f	f	f	f	\N
2301	23	69	t	t	t	f	f	f	f	\N
2264	53	68	t	t	t	t	t	f	f	11
2234	23	68	t	f	f	f	f	f	f	\N
2283	5	69	t	t	f	f	t	f	f	\N
2288	10	69	t	t	f	f	t	f	f	\N
2268	57	68	t	t	t	t	f	f	f	4.4
2280	2	69	t	t	f	f	f	f	f	\N
2281	3	69	t	t	t	t	f	f	f	4.1
2302	24	69	t	t	t	t	\N	f	f	10.4
2282	4	69	t	t	f	f	t	f	f	\N
2286	8	69	t	t	f	f	f	f	f	\N
2279	1	69	t	t	t	f	t	f	f	\N
2290	12	69	t	t	t	f	f	f	f	\N
2289	11	69	t	t	f	f	f	f	f	\N
2295	17	69	t	t	t	t	f	f	f	1.6
2285	7	69	t	t	f	f	f	f	f	\N
2293	15	69	t	f	f	f	\N	f	f	\N
2304	26	69	t	t	t	t	f	f	f	6.1
2284	6	69	t	t	f	f	t	f	f	\N
2318	40	69	t	f	f	f	f	f	f	\N
2334	56	69	t	f	f	f	f	f	f	\N
2317	39	69	t	t	t	f	f	f	f	\N
2308	30	69	t	t	t	f	f	f	f	\N
2311	33	69	t	f	f	f	\N	f	f	\N
2327	49	69	t	f	f	f	t	f	f	\N
2342	64	69	t	f	f	f	f	f	f	\N
2326	48	69	t	t	t	t	f	f	f	4.1
2338	60	69	t	f	f	f	t	f	f	\N
2306	28	69	t	t	t	t	f	f	f	8.6
2344	66	69	t	t	t	f	f	f	f	\N
2346	68	69	t	f	f	f	t	f	f	\N
2312	34	69	t	t	t	t	t	f	f	0.1
2339	61	69	t	f	f	f	t	f	f	\N
2314	36	69	t	f	f	f	f	f	f	\N
2319	41	69	t	f	f	f	f	f	f	\N
2322	44	69	t	f	f	f	t	f	f	\N
2343	65	69	t	t	t	f	f	f	f	\N
2329	51	69	t	f	f	f	t	f	f	\N
2341	63	69	t	t	t	t	f	f	f	0.1
2324	46	69	t	f	f	f	t	f	f	\N
2330	52	69	t	t	f	f	t	f	f	\N
2335	57	69	t	t	f	f	f	f	f	\N
2316	38	69	t	t	t	t	f	f	f	2.1
2323	45	69	t	f	f	f	\N	f	f	\N
2340	62	69	t	f	f	f	\N	f	f	\N
2331	53	69	t	t	t	t	t	f	f	11
2307	29	69	t	t	t	t	\N	f	f	11
2313	35	69	t	t	f	f	f	f	f	\N
2321	43	69	t	t	t	t	\N	f	f	0.2
2328	50	69	t	t	f	f	t	f	f	\N
2337	59	69	t	f	f	f	f	f	f	\N
2320	42	69	t	f	f	f	f	f	f	\N
2332	54	69	t	t	t	t	f	f	f	10.1
2333	55	69	t	t	f	f	f	f	f	\N
2336	58	69	t	t	t	t	f	f	f	1
2305	27	69	t	f	f	f	f	f	f	\N
2309	31	69	t	f	f	f	f	f	f	\N
2315	37	69	t	f	f	f	f	f	f	\N
2325	47	69	t	t	t	t	f	f	f	2.2
2345	67	69	t	f	f	f	f	f	f	\N
2310	32	69	t	f	f	f	f	f	f	\N
2353	7	70	f	f	f	f	f	f	f	\N
2361	15	70	f	f	f	f	\N	f	f	\N
2366	20	70	f	f	f	f	f	f	f	\N
2368	22	70	f	f	f	f	f	f	f	\N
2355	9	70	t	t	t	f	f	f	f	\N
2363	17	70	t	t	t	t	f	f	f	4.6
2364	18	70	f	f	f	f	f	f	f	\N
2357	11	70	f	f	f	f	f	f	f	\N
2354	8	70	f	f	f	f	f	f	f	\N
2351	5	70	t	f	f	f	f	f	f	\N
2367	21	70	f	f	f	f	\N	f	f	\N
2352	6	70	f	f	f	f	f	f	f	\N
2348	2	70	t	f	f	f	f	f	f	\N
2350	4	70	f	f	f	f	f	f	f	\N
2365	19	70	t	t	f	f	\N	f	f	\N
2360	14	70	t	f	f	f	f	f	f	\N
2362	16	70	f	f	f	f	\N	f	f	\N
2347	1	70	t	f	f	f	f	f	f	\N
2349	3	70	f	f	f	f	f	f	f	\N
2356	10	70	f	f	f	f	f	f	f	\N
2358	12	70	f	f	f	f	f	f	f	\N
2359	13	70	f	f	f	f	\N	f	f	\N
2369	23	70	f	f	f	f	f	f	f	\N
2398	52	70	f	f	f	f	f	f	f	\N
2384	38	70	f	f	f	f	t	f	f	\N
2392	46	70	f	f	f	f	f	f	f	\N
2373	27	70	f	f	f	f	f	f	f	\N
2374	28	70	f	f	f	f	t	f	f	\N
2389	43	70	t	f	f	f	\N	f	f	\N
2407	61	70	f	f	f	f	f	f	f	\N
2401	55	70	f	f	f	f	t	f	f	\N
2411	65	70	f	f	f	f	t	f	f	\N
2414	68	70	t	f	f	f	f	f	f	\N
2400	54	70	t	f	f	f	f	f	f	\N
2408	62	70	f	f	f	f	\N	f	f	\N
2381	35	70	f	f	f	f	t	f	f	\N
2403	57	70	f	f	f	f	t	f	f	\N
2418	3	71	t	t	t	t	f	f	f	10.2
2406	60	70	t	f	f	f	f	f	f	\N
2395	49	70	f	f	f	f	f	f	f	\N
2372	26	70	f	f	f	f	t	f	f	\N
2376	30	70	t	f	f	f	f	f	f	\N
2379	33	70	f	f	f	f	\N	f	f	\N
2409	63	70	f	f	f	f	f	f	f	\N
2383	37	70	f	f	f	f	f	f	f	\N
2388	42	70	t	f	f	f	f	f	f	\N
2415	69	70	t	f	f	f	f	f	f	\N
2377	31	70	f	f	f	f	t	f	f	\N
2378	32	70	f	f	f	f	f	f	f	\N
2397	51	70	f	f	f	f	f	f	f	\N
2424	9	71	t	t	t	f	f	f	f	\N
2382	36	70	t	f	f	f	f	f	f	\N
2394	48	70	f	f	f	f	f	f	f	\N
2402	56	70	f	f	f	f	t	f	f	\N
2386	40	70	t	f	f	f	f	f	f	\N
2435	20	71	f	f	f	f	f	f	f	\N
2393	47	70	t	f	f	f	f	f	f	\N
2375	29	70	f	f	f	f	\N	f	f	\N
2380	34	70	f	f	f	f	f	f	f	\N
2437	22	71	t	f	f	f	f	f	f	\N
2431	16	71	f	f	f	f	\N	f	f	\N
2385	39	70	t	t	t	f	t	f	f	\N
2404	58	70	t	t	t	t	f	f	f	1.1
2371	25	70	f	f	f	f	t	f	f	\N
2410	64	70	t	f	f	f	f	f	f	\N
2405	59	70	f	f	f	f	t	f	f	\N
2412	66	70	f	f	f	f	f	f	f	\N
2413	67	70	f	f	f	f	f	f	f	\N
2370	24	70	f	f	f	f	\N	f	f	\N
2387	41	70	t	f	f	f	f	f	f	\N
2390	44	70	f	f	f	f	f	f	f	\N
2391	45	70	f	f	f	f	\N	f	f	\N
2396	50	70	f	f	f	f	f	f	f	\N
2399	53	70	f	f	f	f	f	f	f	\N
2432	17	71	t	t	t	t	f	f	f	6.1
2430	15	71	t	f	f	f	\N	f	f	\N
2420	5	71	t	f	f	f	t	f	f	\N
2422	7	71	t	f	f	f	f	f	f	\N
2429	14	71	t	f	f	f	f	f	f	\N
2421	6	71	t	f	f	f	t	f	f	\N
2428	13	71	f	f	f	f	\N	f	f	\N
2436	21	71	f	f	f	f	\N	f	f	\N
2416	1	71	t	f	f	f	t	f	f	\N
2438	23	71	f	f	f	f	f	f	f	\N
2433	18	71	f	f	f	f	f	f	f	\N
2417	2	71	t	f	f	f	f	f	f	\N
2419	4	71	f	f	f	f	t	f	f	\N
2425	10	71	f	f	f	f	t	f	f	\N
2426	11	71	f	f	f	f	f	f	f	\N
2423	8	71	f	f	f	f	f	f	f	\N
2427	12	71	f	f	f	f	f	f	f	\N
2434	19	71	t	t	f	f	\N	f	f	\N
2508	23	72	f	f	f	f	t	f	f	\N
2439	24	71	t	t	t	t	\N	f	f	10.1
2464	49	71	f	f	f	f	t	f	f	\N
2465	50	71	f	f	f	f	t	f	f	\N
2467	52	71	t	t	f	f	t	f	f	\N
2511	26	72	f	f	f	f	f	f	f	\N
2455	40	71	t	f	f	f	f	f	f	\N
2481	66	71	f	f	f	f	f	f	f	\N
2448	33	71	t	f	f	f	\N	f	f	\N
2474	59	71	f	f	f	f	f	f	f	\N
2453	38	71	f	f	f	f	f	f	f	\N
2494	9	72	t	f	f	f	t	f	f	\N
2505	20	72	f	f	f	f	f	f	f	\N
2463	48	71	f	f	f	f	f	f	f	\N
2466	51	71	f	f	f	f	t	f	f	\N
2512	27	72	f	f	f	f	f	f	f	\N
2502	17	72	t	f	f	f	f	f	f	\N
2488	3	72	f	f	f	f	f	f	f	\N
2470	55	71	t	t	f	f	f	f	f	\N
2486	1	72	t	f	f	f	f	f	f	\N
2456	41	71	t	f	f	f	f	f	f	\N
2483	68	71	t	f	f	f	t	f	f	\N
2457	42	71	t	f	f	f	f	f	f	\N
2459	44	71	f	f	f	f	t	f	f	\N
2471	56	71	f	f	f	f	f	f	f	\N
2472	57	71	f	f	f	f	f	f	f	\N
2497	12	72	f	f	f	f	t	f	f	\N
2480	65	71	t	f	f	f	f	f	f	\N
2446	31	71	t	f	f	f	f	f	f	\N
2440	25	71	f	f	f	f	f	f	f	\N
2443	28	71	f	f	f	f	f	f	f	\N
2504	19	72	t	f	f	f	\N	f	f	\N
2451	36	71	t	f	f	f	f	f	f	\N
2454	39	71	t	t	t	f	f	f	f	\N
2441	26	71	t	f	f	f	f	f	f	\N
2444	29	71	f	f	f	f	\N	f	f	\N
2477	62	71	f	f	f	f	\N	f	f	\N
2449	34	71	t	f	f	f	t	f	f	\N
2461	46	71	f	f	f	f	t	f	f	\N
2447	32	71	f	f	f	f	f	f	f	\N
2460	45	71	f	f	f	f	\N	f	f	\N
2496	11	72	f	f	f	f	t	f	f	\N
2462	47	71	t	f	f	f	f	f	f	\N
2468	53	71	f	f	f	f	t	f	f	\N
2485	70	71	f	f	f	f	f	f	f	\N
2515	30	72	t	f	f	f	f	f	f	\N
2516	31	72	f	f	f	f	f	f	f	\N
2450	35	71	t	t	f	f	f	f	f	\N
2517	32	72	f	f	f	f	t	f	f	\N
2458	43	71	t	f	f	f	\N	f	f	\N
2476	61	71	f	f	f	f	t	f	f	\N
2478	63	71	f	f	f	f	f	f	f	\N
2495	10	72	f	f	f	f	f	f	f	\N
2484	69	71	t	f	f	f	t	f	f	\N
2501	16	72	f	f	f	f	\N	f	f	\N
2469	54	71	t	f	f	f	f	f	f	\N
2503	18	72	f	f	f	f	f	f	f	\N
2475	60	71	t	f	f	f	t	f	f	\N
2493	8	72	f	f	f	f	f	f	f	\N
2479	64	71	t	f	f	f	f	f	f	\N
2442	27	71	f	f	f	f	f	f	f	\N
2513	28	72	f	f	f	f	f	f	f	\N
2452	37	71	t	f	f	f	f	f	f	\N
2487	2	72	t	f	f	f	f	f	f	\N
2499	14	72	t	f	f	f	f	f	f	\N
2473	58	71	t	t	t	t	f	f	f	1.1
2509	24	72	f	f	f	f	\N	f	f	\N
2445	30	71	t	f	f	f	f	f	f	\N
2482	67	71	f	f	f	f	f	f	f	\N
2491	6	72	f	f	f	f	f	f	f	\N
2498	13	72	f	f	f	f	\N	f	f	\N
2507	22	72	f	f	f	f	t	f	f	\N
2489	4	72	f	f	f	f	f	f	f	\N
2490	5	72	t	f	f	f	f	f	f	\N
2514	29	72	f	f	f	f	\N	f	f	\N
2492	7	72	f	f	f	f	f	f	f	\N
2500	15	72	f	f	f	f	\N	f	f	\N
2506	21	72	f	f	f	f	\N	f	f	\N
2510	25	72	f	f	f	f	f	f	f	\N
2552	67	72	f	f	f	f	f	f	f	\N
2613	57	73	t	f	f	f	f	f	f	\N
2541	56	72	f	f	f	f	f	f	f	\N
2568	12	73	t	f	f	f	f	f	f	\N
2616	60	73	t	t	t	t	f	f	f	6.2
2545	60	72	t	f	f	f	f	f	f	\N
2546	61	72	f	f	f	f	f	f	f	\N
2557	1	73	t	f	f	f	f	f	f	\N
2601	45	73	t	f	f	f	f	f	f	\N
2620	64	73	t	f	f	f	f	f	f	\N
2583	27	73	t	t	t	t	f	f	f	8.6
2554	69	72	t	t	t	t	f	f	f	1.1
2519	34	72	f	f	f	f	f	f	f	\N
2574	18	73	t	f	f	f	f	f	f	\N
2563	7	73	t	f	f	f	f	f	f	\N
2521	36	72	t	f	f	f	f	f	f	\N
2531	46	72	f	f	f	f	f	f	f	\N
2609	53	73	t	t	t	f	f	f	f	\N
2543	58	72	t	f	f	f	f	f	f	\N
2556	71	72	f	f	f	f	f	f	f	\N
2591	35	73	t	f	f	f	f	f	f	\N
2569	13	73	t	f	f	f	f	f	f	\N
2593	37	73	t	f	f	f	f	f	f	\N
2604	48	73	t	f	f	f	f	f	f	\N
2577	21	73	t	f	f	f	f	f	f	\N
2607	51	73	t	f	f	f	f	f	f	\N
2605	49	73	t	f	f	f	f	f	f	\N
2526	41	72	t	f	f	f	t	f	f	\N
2547	62	72	f	f	f	f	\N	f	f	\N
2520	35	72	f	f	f	f	f	f	f	\N
2534	49	72	f	f	f	f	f	f	f	\N
2555	70	72	f	f	f	f	f	f	f	\N
2529	44	72	f	f	f	f	f	f	f	\N
2542	57	72	f	f	f	f	f	f	f	\N
2518	33	72	f	f	f	f	\N	f	f	\N
2522	37	72	f	f	f	f	t	f	f	\N
2550	65	72	f	f	f	f	f	f	f	\N
2525	40	72	t	f	f	f	f	f	f	\N
2537	52	72	f	f	f	f	f	f	f	\N
2549	64	72	t	t	t	t	t	f	f	1.2
2538	53	72	f	f	f	f	f	f	f	\N
2548	63	72	f	f	f	f	t	f	f	\N
2523	38	72	f	f	f	f	f	f	f	\N
2524	39	72	t	f	f	f	f	f	f	\N
2527	42	72	t	t	t	f	t	f	f	\N
2539	54	72	t	f	f	f	f	f	f	\N
2528	43	72	t	f	f	f	\N	f	f	\N
2532	47	72	t	f	f	f	f	f	f	\N
2536	51	72	f	f	f	f	f	f	f	\N
2530	45	72	f	f	f	f	\N	f	f	\N
2553	68	72	t	t	t	f	f	f	f	\N
2535	50	72	f	f	f	f	f	f	f	\N
2533	48	72	f	f	f	f	f	f	f	\N
2540	55	72	f	f	f	f	f	f	f	\N
2544	59	72	f	f	f	f	f	f	f	\N
2551	66	72	f	f	f	f	f	f	f	\N
2592	36	73	t	t	t	t	f	f	f	2.2
2611	55	73	t	f	f	f	f	f	f	\N
2566	10	73	t	f	f	f	f	f	f	\N
2623	67	73	t	t	t	t	f	f	f	11
2578	22	73	t	f	f	f	f	f	f	\N
2606	50	73	t	t	f	f	f	f	f	\N
2621	65	73	t	f	f	f	f	f	f	\N
2582	26	73	t	f	f	f	f	f	f	\N
2589	33	73	t	f	f	f	f	f	f	\N
2612	56	73	t	t	t	f	f	f	f	\N
2558	2	73	t	f	f	f	f	f	f	\N
2595	39	73	t	f	f	f	f	f	f	\N
2619	63	73	t	f	f	f	f	f	f	\N
2603	47	73	t	f	f	f	f	f	f	\N
2567	11	73	t	f	f	f	f	f	f	\N
2608	52	73	t	f	f	f	f	f	f	\N
2622	66	73	t	f	f	f	f	f	f	\N
2565	9	73	t	t	t	t	f	f	f	0.1
2571	15	73	t	t	t	t	f	f	f	4.1
2599	43	73	t	f	f	f	f	f	f	\N
2562	6	73	t	f	f	f	f	f	f	\N
2618	62	73	t	t	t	f	f	f	f	\N
2610	54	73	t	f	f	f	f	f	f	\N
2581	25	73	t	f	f	f	f	f	f	\N
2584	28	73	t	f	f	f	f	f	f	\N
2596	40	73	t	t	f	f	f	f	f	\N
2594	38	73	t	f	f	f	f	f	f	\N
2597	41	73	t	t	t	t	f	f	f	4.1
2625	69	73	t	f	f	f	f	f	f	\N
2572	16	73	t	t	t	t	f	f	f	10.1
2628	72	73	t	f	f	f	f	f	f	\N
2614	58	73	t	f	f	f	f	f	f	\N
2576	20	73	t	t	t	t	f	f	f	10.4
2627	71	73	t	f	f	f	f	f	f	\N
2615	59	73	t	t	t	t	f	f	f	5
2590	34	73	t	f	f	f	f	f	f	\N
2617	61	73	t	f	f	f	f	f	f	\N
2575	19	73	t	t	f	f	f	f	f	\N
2573	17	73	t	f	f	f	f	f	f	\N
2600	44	73	t	f	f	f	f	f	f	\N
2570	14	73	t	t	f	f	f	f	f	\N
2588	32	73	t	t	t	t	f	f	f	10.4
2561	5	73	t	f	f	f	f	f	f	\N
2626	70	73	t	f	f	f	f	f	f	\N
2580	24	73	t	t	t	t	f	f	f	6.1
2587	31	73	t	t	t	f	f	f	f	\N
2586	30	73	t	f	f	f	f	f	f	\N
2602	46	73	t	f	f	f	f	f	f	\N
2598	42	73	t	f	f	f	f	f	f	\N
2624	68	73	t	f	f	f	f	f	f	\N
2585	29	73	t	f	f	f	f	f	f	\N
2559	3	73	t	t	t	t	f	f	f	10.4
2564	8	73	t	t	f	f	f	f	f	\N
2560	4	73	t	f	f	f	f	f	f	\N
2579	23	73	t	f	f	f	f	f	f	\N
2630	2	74	t	t	t	f	t	f	f	\N
2629	1	74	t	t	t	t	f	f	f	10.1
2656	28	74	f	f	f	f	f	f	f	\N
2641	13	74	f	f	f	f	\N	f	f	\N
2704	3	75	t	f	f	f	t	f	f	\N
2719	18	75	t	f	f	f	f	f	f	\N
2716	15	75	t	f	f	f	\N	f	f	\N
2720	19	75	t	f	f	f	\N	f	f	\N
2659	31	74	t	f	f	f	f	f	f	\N
2724	23	75	t	t	t	f	f	f	f	\N
2665	37	74	t	f	f	f	f	f	f	\N
2725	24	75	t	f	f	f	\N	f	f	\N
2650	22	74	t	t	t	t	f	f	f	0.1
2655	27	74	f	f	f	f	f	f	f	\N
2670	42	74	t	f	f	f	f	f	f	\N
2713	12	75	t	t	t	f	f	f	f	\N
2671	43	74	t	t	f	f	\N	f	f	\N
2669	41	74	t	f	f	f	f	f	f	\N
2678	50	74	f	f	f	f	f	f	f	\N
2695	67	74	f	f	f	f	f	f	f	\N
2649	21	74	f	f	f	f	\N	f	f	\N
2714	13	75	t	f	f	f	\N	f	f	\N
2679	51	74	f	f	f	f	f	f	f	\N
2717	16	75	t	f	f	f	\N	f	f	\N
2701	73	74	t	f	f	f	\N	f	f	\N
2658	30	74	t	t	t	t	t	f	f	7
2664	36	74	t	f	f	f	f	f	f	\N
2640	12	74	f	f	f	f	f	f	f	\N
2690	62	74	f	f	f	f	\N	f	f	\N
2642	14	74	t	f	f	f	f	f	f	\N
2657	29	74	f	f	f	f	\N	f	f	\N
2691	63	74	f	f	f	f	f	f	f	\N
2723	22	75	t	t	t	f	f	f	f	\N
2667	39	74	t	f	f	f	f	f	f	\N
2721	20	75	t	f	f	f	t	f	f	\N
2693	65	74	t	t	f	f	f	f	f	\N
2703	2	75	t	t	t	t	t	f	f	6.1
2648	20	74	f	f	f	f	t	f	f	\N
2681	53	74	f	f	f	f	f	f	f	\N
2687	59	74	f	f	f	f	f	f	f	\N
2702	1	75	t	t	t	f	f	f	f	\N
2647	19	74	t	f	f	f	\N	f	f	\N
2673	45	74	f	f	f	f	\N	f	f	\N
2722	21	75	t	t	t	f	\N	f	f	\N
2696	68	74	t	f	f	f	f	f	f	\N
2666	38	74	f	f	f	f	f	f	f	\N
2637	9	74	t	f	f	f	f	f	f	\N
2708	7	75	t	t	t	f	f	f	f	\N
2635	7	74	t	t	t	t	f	f	f	3
2675	47	74	t	t	t	f	f	f	f	\N
2638	10	74	f	f	f	f	f	f	f	\N
2662	34	74	t	t	t	f	f	f	f	\N
2653	25	74	f	f	f	f	f	f	f	\N
2682	54	74	t	t	t	f	f	f	f	\N
2694	66	74	f	f	f	f	t	f	f	\N
2663	35	74	t	f	f	f	f	f	f	\N
2645	17	74	t	f	f	f	f	f	f	\N
2672	44	74	f	f	f	f	f	f	f	\N
2660	32	74	f	f	f	f	f	f	f	\N
2697	69	74	t	t	f	f	f	f	f	\N
2634	6	74	t	t	t	f	f	f	f	\N
2651	23	74	f	f	f	f	f	f	f	\N
2633	5	74	t	t	t	t	f	f	f	1
2654	26	74	t	t	f	f	f	f	f	\N
2680	52	74	t	f	f	f	f	f	f	\N
2631	3	74	t	f	f	f	t	f	f	\N
2674	46	74	f	f	f	f	f	f	f	\N
2661	33	74	t	f	f	f	\N	f	f	\N
2676	48	74	f	f	f	f	t	f	f	\N
2683	55	74	t	f	f	f	f	f	f	\N
2684	56	74	f	f	f	f	f	f	f	\N
2685	57	74	f	f	f	f	f	f	f	\N
2688	60	74	t	f	f	f	f	f	f	\N
2686	58	74	t	f	f	f	f	f	f	\N
2643	15	74	t	f	f	f	\N	f	f	\N
2692	64	74	t	f	f	f	f	f	f	\N
2652	24	74	t	f	f	f	\N	f	f	\N
2677	49	74	f	f	f	f	f	f	f	\N
2636	8	74	f	f	f	f	t	f	f	\N
2689	61	74	f	f	f	f	f	f	f	\N
2698	70	74	f	f	f	f	f	f	f	\N
2700	72	74	f	f	f	f	f	f	f	\N
2632	4	74	f	f	f	f	f	f	f	\N
2699	71	74	t	f	f	f	f	f	f	\N
2644	16	74	f	f	f	f	\N	f	f	\N
2639	11	74	f	f	f	f	f	f	f	\N
2646	18	74	f	f	f	f	f	f	f	\N
2668	40	74	t	f	f	f	t	f	f	\N
2726	25	75	t	t	t	t	f	f	f	8.1
2707	6	75	t	t	t	t	f	f	f	5
2712	11	75	t	f	f	f	f	f	f	\N
2715	14	75	t	f	f	f	f	f	f	\N
2709	8	75	t	f	f	f	t	f	f	\N
2710	9	75	t	f	f	f	f	f	f	\N
2711	10	75	t	t	t	t	f	f	f	4.1
2705	4	75	t	t	t	t	f	f	f	10.2
2718	17	75	t	f	f	f	f	f	f	\N
2706	5	75	t	t	t	f	f	f	f	\N
2808	33	76	t	f	f	f	f	f	f	\N
2767	66	75	t	t	t	f	t	f	f	\N
2782	7	76	t	f	f	f	f	f	f	\N
2786	11	76	f	f	f	f	f	f	f	\N
2752	51	75	t	f	f	f	f	f	f	\N
2768	67	75	t	f	f	f	f	f	f	\N
2812	37	76	t	f	f	f	f	f	f	\N
2772	71	75	t	f	f	f	f	f	f	\N
2777	2	76	t	f	f	f	f	f	f	\N
2762	61	75	t	f	f	f	f	f	f	\N
2817	42	76	t	f	f	f	f	f	f	\N
2785	10	76	f	f	f	f	f	f	f	\N
2811	36	76	t	f	f	f	f	f	f	\N
2790	15	76	t	f	f	f	f	f	f	\N
2795	20	76	f	f	f	f	f	f	f	\N
2744	43	75	t	t	t	t	\N	f	f	2.1
2796	21	76	f	f	f	f	f	f	f	\N
2792	17	76	t	t	t	t	f	f	f	0.4
2756	55	75	t	f	f	f	f	f	f	\N
2788	13	76	f	f	f	f	f	f	f	\N
2775	74	75	t	t	t	f	t	f	f	\N
2804	29	76	f	f	f	f	f	f	f	\N
2781	6	76	t	f	f	f	f	f	f	\N
2801	26	76	t	f	f	f	f	f	f	\N
2810	35	76	t	t	t	t	f	f	f	1.6
2798	23	76	f	f	f	f	f	f	f	\N
2764	63	75	t	t	t	t	f	f	f	2
2818	43	76	t	f	f	f	f	f	f	\N
2733	32	75	t	f	f	f	f	f	f	\N
2729	28	75	t	f	f	f	f	f	f	\N
2819	44	76	f	f	f	f	f	f	f	\N
2803	28	76	f	f	f	f	f	f	f	\N
2741	40	75	t	f	f	f	t	f	f	\N
2789	14	76	t	f	f	f	f	f	f	\N
2799	24	76	t	t	t	f	f	f	f	\N
2736	35	75	t	f	f	f	f	f	f	\N
2747	46	75	t	f	f	f	f	f	f	\N
2813	38	76	f	f	f	f	f	f	f	\N
2814	39	76	t	t	t	t	f	f	f	8.4
2816	41	76	t	f	f	f	f	f	f	\N
2797	22	76	t	f	f	f	f	f	f	\N
2776	1	76	t	f	f	f	f	f	f	\N
2783	8	76	f	f	f	f	f	f	f	\N
2794	19	76	t	t	t	f	f	f	f	\N
2770	69	75	t	t	t	t	f	f	f	4.1
2807	32	76	f	f	f	f	f	f	f	\N
2758	57	75	t	f	f	f	f	f	f	\N
2737	36	75	t	f	f	f	f	f	f	\N
2738	37	75	t	f	f	f	f	f	f	\N
2746	45	75	t	f	f	f	\N	f	f	\N
2759	58	75	t	f	f	f	f	f	f	\N
2753	52	75	t	f	f	f	f	f	f	\N
2787	12	76	f	f	f	f	f	f	f	\N
2765	64	75	t	f	f	f	f	f	f	\N
2760	59	75	t	f	f	f	f	f	f	\N
2774	73	75	t	f	f	f	\N	f	f	\N
2809	34	76	t	f	f	f	f	f	f	\N
2763	62	75	t	f	f	f	\N	f	f	\N
2735	34	75	t	t	t	t	f	f	f	2
2739	38	75	t	t	t	t	f	f	f	10.8
2743	42	75	t	f	f	f	f	f	f	\N
2745	44	75	t	f	f	f	f	f	f	\N
2754	53	75	t	f	f	f	f	f	f	\N
2748	47	75	t	t	t	t	f	f	f	10.1
2757	56	75	t	f	f	f	f	f	f	\N
2766	65	75	t	t	t	f	f	f	f	\N
2769	68	75	t	f	f	f	f	f	f	\N
2742	41	75	t	f	f	f	f	f	f	\N
2773	72	75	t	f	f	f	f	f	f	\N
2734	33	75	t	f	f	f	\N	f	f	\N
2751	50	75	t	f	f	f	f	f	f	\N
2728	27	75	t	f	f	f	f	f	f	\N
2731	30	75	t	t	t	f	t	f	f	\N
2740	39	75	t	f	f	f	f	f	f	\N
2749	48	75	t	t	t	t	t	f	f	10.4
2750	49	75	t	f	f	f	f	f	f	\N
2755	54	75	t	t	t	t	f	f	f	5
2732	31	75	t	f	f	f	f	f	f	\N
2761	60	75	t	f	f	f	f	f	f	\N
2771	70	75	t	f	f	f	f	f	f	\N
2727	26	75	t	t	t	t	f	f	f	10.2
2730	29	75	t	f	f	f	\N	f	f	\N
2802	27	76	f	f	f	f	f	f	f	\N
2820	45	76	f	f	f	f	f	f	f	\N
2780	5	76	t	f	f	f	f	f	f	\N
2805	30	76	t	f	f	f	f	f	f	\N
2806	31	76	t	f	f	f	f	f	f	\N
2815	40	76	t	f	f	f	f	f	f	\N
2779	4	76	f	f	f	f	f	f	f	\N
2791	16	76	f	f	f	f	f	f	f	\N
2778	3	76	t	t	t	t	f	f	f	0.1
2800	25	76	f	f	f	f	f	f	f	\N
2784	9	76	t	t	t	t	f	f	f	8.2
2793	18	76	f	f	f	f	f	f	f	\N
2821	46	76	f	f	f	f	f	f	f	\N
2882	32	77	f	f	f	f	f	f	f	\N
2822	47	76	t	f	f	f	f	f	f	\N
2832	57	76	f	f	f	f	f	f	f	\N
2828	53	76	f	f	f	f	f	f	f	\N
2892	42	77	t	t	t	t	f	f	f	1.4
2849	74	76	t	f	f	f	f	f	f	\N
2845	70	76	f	f	f	f	f	f	f	\N
2831	56	76	f	f	f	f	f	f	f	\N
2834	59	76	f	f	f	f	f	f	f	\N
2847	72	76	f	f	f	f	f	f	f	\N
2865	15	77	f	f	f	f	\N	f	f	\N
2848	73	76	t	f	f	f	f	f	f	\N
2823	48	76	f	f	f	f	f	f	f	\N
2884	34	77	f	f	f	f	f	f	f	\N
2835	60	76	t	f	f	f	f	f	f	\N
2888	38	77	f	f	f	f	t	f	f	\N
2846	71	76	t	f	f	f	f	f	f	\N
2826	51	76	f	f	f	f	f	f	f	\N
2880	30	77	t	f	f	f	f	f	f	\N
2896	46	77	f	f	f	f	f	f	f	\N
2827	52	76	t	t	t	t	f	f	f	2
2824	49	76	f	f	f	f	f	f	f	\N
2897	47	77	t	f	f	f	f	f	f	\N
2840	65	76	t	f	f	f	f	f	f	\N
2858	8	77	f	f	f	f	f	f	f	\N
2843	68	76	t	f	f	f	f	f	f	\N
2836	61	76	f	f	f	f	f	f	f	\N
2878	28	77	f	f	f	f	t	f	f	\N
2829	54	76	t	f	f	f	f	f	f	\N
2839	64	76	t	f	f	f	f	f	f	\N
2842	67	76	f	f	f	f	f	f	f	\N
2867	17	77	t	f	f	f	f	f	f	\N
2844	69	76	t	f	f	f	f	f	f	\N
2837	62	76	f	f	f	f	f	f	f	\N
2838	63	76	f	f	f	f	f	f	f	\N
2850	75	76	t	f	f	f	f	f	f	\N
2876	26	77	f	f	f	f	t	f	f	\N
2830	55	76	t	t	t	t	f	f	f	0.1
2895	45	77	f	f	f	f	\N	f	f	\N
2833	58	76	t	t	t	t	f	f	f	3
2841	66	76	f	f	f	f	f	f	f	\N
2825	50	76	f	f	f	f	f	f	f	\N
2873	23	77	f	f	f	f	f	f	f	\N
2890	40	77	t	t	t	t	f	f	f	2
2893	43	77	t	f	f	f	\N	f	f	\N
2868	18	77	f	f	f	f	f	f	f	\N
2870	20	77	f	f	f	f	f	f	f	\N
2861	11	77	f	f	f	f	f	f	f	\N
2863	13	77	f	f	f	f	\N	f	f	\N
2881	31	77	f	f	f	f	t	f	f	\N
2852	2	77	t	f	f	f	f	f	f	\N
2851	1	77	t	f	f	f	f	f	f	\N
2854	4	77	f	f	f	f	f	f	f	\N
2856	6	77	f	f	f	f	f	f	f	\N
2857	7	77	f	f	f	f	f	f	f	\N
2864	14	77	t	t	t	t	f	f	f	10.6
2899	49	77	f	f	f	f	f	f	f	\N
2900	50	77	f	f	f	f	f	f	f	\N
2872	22	77	f	f	f	f	f	f	f	\N
2855	5	77	t	f	f	f	f	f	f	\N
2866	16	77	f	f	f	f	\N	f	f	\N
2883	33	77	f	f	f	f	\N	f	f	\N
2887	37	77	f	f	f	f	f	f	f	\N
2853	3	77	f	f	f	f	f	f	f	\N
2889	39	77	t	f	f	f	t	f	f	\N
2894	44	77	f	f	f	f	f	f	f	\N
2877	27	77	f	f	f	f	f	f	f	\N
2860	10	77	f	f	f	f	f	f	f	\N
2862	12	77	f	f	f	f	f	f	f	\N
2875	25	77	f	f	f	f	t	f	f	\N
2885	35	77	f	f	f	f	t	f	f	\N
2871	21	77	f	f	f	f	\N	f	f	\N
2874	24	77	f	f	f	f	\N	f	f	\N
2886	36	77	t	t	t	t	f	f	f	8.8
2859	9	77	t	t	t	t	f	f	f	7
2891	41	77	t	t	t	t	f	f	f	9
2869	19	77	t	t	t	f	\N	f	f	\N
2898	48	77	f	f	f	f	f	f	f	\N
2879	29	77	f	f	f	f	\N	f	f	\N
2944	18	78	f	f	f	f	f	f	f	\N
2946	20	78	f	f	f	f	f	f	f	\N
2939	13	78	f	f	f	f	f	f	f	\N
2948	22	78	t	t	t	t	f	f	f	0.6
2940	14	78	t	f	f	f	f	f	f	\N
2951	25	78	f	f	f	f	f	f	f	\N
2945	19	78	t	f	f	f	f	f	f	\N
2949	23	78	f	f	f	f	f	f	f	\N
2969	43	78	t	f	f	f	f	f	f	\N
2950	24	78	t	f	f	f	f	f	f	\N
2962	36	78	t	f	f	f	f	f	f	\N
2929	3	78	t	f	f	f	f	f	f	\N
2938	12	78	f	f	f	f	f	f	f	\N
2968	42	78	t	t	t	t	f	f	f	4.2
2941	15	78	t	f	f	f	f	f	f	\N
2965	39	78	t	f	f	f	f	f	f	\N
2960	34	78	t	t	t	t	f	f	f	5
2918	68	77	t	t	t	f	f	f	f	\N
2924	74	77	f	f	f	f	f	f	f	\N
2928	2	78	t	f	f	f	f	f	f	\N
2955	29	78	f	f	f	f	f	f	f	\N
2964	38	78	f	f	f	f	f	f	f	\N
2910	60	77	t	t	t	t	f	f	f	6.6
2916	66	77	f	f	f	f	f	f	f	\N
2917	67	77	f	f	f	f	f	f	f	\N
2902	52	77	f	f	f	f	f	f	f	\N
2909	59	77	f	f	f	f	t	f	f	\N
2903	53	77	f	f	f	f	f	f	f	\N
2915	65	77	f	f	f	f	t	f	f	\N
2901	51	77	f	f	f	f	f	f	f	\N
2922	72	77	f	f	f	f	f	f	f	\N
2925	75	77	t	f	f	f	f	f	f	\N
2967	41	78	t	f	f	f	f	f	f	\N
2904	54	77	t	f	f	f	f	f	f	\N
2905	55	77	f	f	f	f	t	f	f	\N
2913	63	77	f	f	f	f	f	f	f	\N
2942	16	78	f	f	f	f	f	f	f	\N
2947	21	78	f	f	f	f	f	f	f	\N
2954	28	78	f	f	f	f	f	f	f	\N
2919	69	77	t	t	t	f	f	f	f	\N
2921	71	77	f	f	f	f	f	f	f	\N
2934	8	78	f	f	f	f	f	f	f	\N
2932	6	78	t	t	t	t	f	f	f	3
2927	1	78	t	f	f	f	f	f	f	\N
2914	64	77	t	t	t	f	f	f	f	\N
2937	11	78	f	f	f	f	f	f	f	\N
2957	31	78	t	f	f	f	f	f	f	\N
2923	73	77	t	t	t	t	\N	f	f	2.1
2907	57	77	f	f	f	f	t	f	f	\N
2906	56	77	f	f	f	f	t	f	f	\N
2911	61	77	f	f	f	f	f	f	f	\N
2926	76	77	f	f	f	f	\N	f	f	\N
2908	58	77	t	f	f	f	f	f	f	\N
2912	62	77	f	f	f	f	\N	f	f	\N
2920	70	77	f	f	f	f	t	f	f	\N
2959	33	78	t	t	t	t	f	f	f	1.1
2963	37	78	t	t	t	t	f	f	f	1.1
2966	40	78	t	f	f	f	f	f	f	\N
2936	10	78	f	f	f	f	f	f	f	\N
2953	27	78	f	f	f	f	f	f	f	\N
2958	32	78	f	f	f	f	f	f	f	\N
2956	30	78	t	f	f	f	f	f	f	\N
2961	35	78	t	f	f	f	f	f	f	\N
2931	5	78	t	f	f	f	f	f	f	\N
2933	7	78	t	t	t	t	f	f	f	10.1
2952	26	78	t	t	t	f	f	f	f	\N
2930	4	78	f	f	f	f	f	f	f	\N
2935	9	78	t	f	f	f	f	f	f	\N
2943	17	78	t	f	f	f	f	f	f	\N
2971	45	78	f	f	f	f	f	f	f	\N
3004	1	79	t	f	f	f	t	f	f	\N
2984	58	78	t	f	f	f	f	f	f	\N
2973	47	78	t	f	f	f	f	f	f	\N
2998	72	78	f	f	f	f	f	f	f	\N
3016	13	79	t	t	t	t	\N	f	f	4.1
3022	19	79	t	f	f	f	\N	f	f	\N
3007	4	79	t	t	t	t	t	f	f	10.1
3002	76	78	t	t	t	t	f	f	f	10.1
2982	56	78	f	f	f	f	f	f	f	\N
3017	14	79	t	f	f	f	f	f	f	\N
3038	35	79	t	f	f	f	f	f	f	\N
2994	68	78	t	t	t	f	f	f	f	\N
2991	65	78	t	t	t	t	f	f	f	2
2980	54	78	t	f	f	f	f	f	f	\N
2986	60	78	t	f	f	f	f	f	f	\N
2976	50	78	f	f	f	f	f	f	f	\N
2987	61	78	f	f	f	f	f	f	f	\N
2972	46	78	f	f	f	f	f	f	f	\N
2996	70	78	f	f	f	f	f	f	f	\N
3036	33	79	t	t	f	f	\N	f	f	\N
2999	73	78	t	f	f	f	f	f	f	\N
3000	74	78	t	f	f	f	f	f	f	\N
2975	49	78	f	f	f	f	f	f	f	\N
2977	51	78	f	f	f	f	f	f	f	\N
2974	48	78	f	f	f	f	f	f	f	\N
2995	69	78	t	t	t	f	f	f	f	\N
3039	36	79	t	f	f	f	f	f	f	\N
2997	71	78	t	t	t	f	f	f	f	\N
2985	59	78	f	f	f	f	f	f	f	\N
2978	52	78	t	f	f	f	f	f	f	\N
2981	55	78	t	f	f	f	f	f	f	\N
2983	57	78	f	f	f	f	f	f	f	\N
2989	63	78	f	f	f	f	f	f	f	\N
2993	67	78	f	f	f	f	f	f	f	\N
2992	66	78	f	f	f	f	f	f	f	\N
2970	44	78	f	f	f	f	f	f	f	\N
3001	75	78	t	f	f	f	f	f	f	\N
2979	53	78	f	f	f	f	f	f	f	\N
3003	77	78	f	f	f	f	f	f	f	\N
2988	62	78	f	f	f	f	f	f	f	\N
3034	31	79	t	f	f	f	f	f	f	\N
3021	18	79	t	t	f	f	f	f	f	\N
2990	64	78	t	t	t	f	f	f	f	\N
3028	25	79	t	f	f	f	f	f	f	\N
3042	39	79	t	f	f	f	f	f	f	\N
3030	27	79	t	f	f	f	f	f	f	\N
3033	30	79	t	f	f	f	f	f	f	\N
3006	3	79	t	f	f	f	f	f	f	\N
3005	2	79	t	f	f	f	f	f	f	\N
3010	7	79	t	t	t	f	f	f	f	\N
3031	28	79	t	f	f	f	f	f	f	\N
3018	15	79	t	f	f	f	\N	f	f	\N
3008	5	79	t	f	f	f	t	f	f	\N
3009	6	79	t	t	t	t	t	f	f	4.1
3014	11	79	t	f	f	f	f	f	f	\N
3023	20	79	t	f	f	f	f	f	f	\N
3035	32	79	t	f	f	f	f	f	f	\N
3024	21	79	t	t	t	f	\N	f	f	\N
3041	38	79	t	f	f	f	f	f	f	\N
3015	12	79	t	f	f	f	f	f	f	\N
3019	16	79	t	f	f	f	\N	f	f	\N
3020	17	79	t	f	f	f	f	f	f	\N
3026	23	79	t	f	f	f	f	f	f	\N
3037	34	79	t	t	t	t	t	f	f	0.1
3027	24	79	t	f	f	f	\N	f	f	\N
3013	10	79	t	t	t	t	t	f	f	1.8
3029	26	79	t	t	f	f	f	f	f	\N
3040	37	79	t	t	t	t	f	f	f	6.1
3032	29	79	t	f	f	f	\N	f	f	\N
3011	8	79	t	f	f	f	f	f	f	\N
3012	9	79	t	f	f	f	f	f	f	\N
3025	22	79	t	t	t	f	f	f	f	\N
3068	65	79	t	t	f	f	f	f	f	\N
3091	10	80	t	t	t	f	f	f	f	\N
3083	2	80	t	f	f	f	t	f	f	\N
3078	75	79	t	f	f	f	f	f	f	\N
3101	20	80	t	f	f	f	t	f	f	\N
3048	45	79	t	t	t	t	\N	f	f	8.6
3087	6	80	f	f	f	f	f	f	f	\N
3051	48	79	t	f	f	f	f	f	f	\N
3098	17	80	t	f	f	f	f	f	f	\N
3076	73	79	t	f	f	f	\N	f	f	\N
3104	23	80	t	f	f	f	f	f	f	\N
3107	26	80	f	f	f	f	f	f	f	\N
3084	3	80	f	f	f	f	t	f	f	\N
3108	27	80	f	f	f	f	f	f	f	\N
3075	72	79	t	f	f	f	f	f	f	\N
3058	55	79	t	f	f	f	f	f	f	\N
3094	13	80	t	t	t	t	\N	f	f	10.1
3070	67	79	t	f	f	f	f	f	f	\N
3069	66	79	t	t	t	f	f	f	f	\N
3080	77	79	t	f	f	f	f	f	f	\N
3095	14	80	t	f	f	f	f	f	f	\N
3072	69	79	t	t	f	f	t	f	f	\N
3081	78	79	t	f	f	f	\N	f	f	\N
3085	4	80	t	t	t	t	f	f	f	4.4
3074	71	79	t	t	f	f	t	f	f	\N
3082	1	80	t	f	f	f	f	f	f	\N
3047	44	79	t	t	f	f	t	f	f	\N
3049	46	79	t	t	t	f	t	f	f	\N
3096	15	80	f	f	f	f	\N	f	f	\N
3057	54	79	t	f	f	f	f	f	f	\N
3102	21	80	f	f	f	f	\N	f	f	\N
3064	61	79	t	t	t	t	t	f	f	4.1
3060	57	79	t	f	f	f	f	f	f	\N
3097	16	80	t	f	f	f	\N	f	f	\N
3063	60	79	t	f	f	f	t	f	f	\N
3090	9	80	t	f	f	f	f	f	f	\N
3066	63	79	t	t	t	t	f	f	f	0.1
3077	74	79	t	f	f	f	f	f	f	\N
3092	11	80	f	f	f	f	f	f	f	\N
3073	70	79	t	t	f	f	f	f	f	\N
3071	68	79	t	t	t	t	t	f	f	5
3106	25	80	t	f	f	f	f	f	f	\N
3055	52	79	t	f	f	f	t	f	f	\N
3109	28	80	t	f	f	f	f	f	f	\N
3061	58	79	t	f	f	f	f	f	f	\N
3088	7	80	f	f	f	f	f	f	f	\N
3079	76	79	t	t	t	f	\N	f	f	\N
3045	42	79	t	t	f	f	f	f	f	\N
3099	18	80	t	t	f	f	f	f	f	\N
3050	47	79	t	f	f	f	f	f	f	\N
3065	62	79	t	f	f	f	\N	f	f	\N
3046	43	79	t	f	f	f	\N	f	f	\N
3059	56	79	t	f	f	f	f	f	f	\N
3043	40	79	t	f	f	f	f	f	f	\N
3062	59	79	t	f	f	f	f	f	f	\N
3089	8	80	t	f	f	f	t	f	f	\N
3053	50	79	t	f	f	f	t	f	f	\N
3093	12	80	t	f	f	f	f	f	f	\N
3056	53	79	t	f	f	f	t	f	f	\N
3100	19	80	t	f	f	f	\N	f	f	\N
3105	24	80	f	f	f	f	\N	f	f	\N
3067	64	79	t	t	t	t	f	f	f	8.1
3086	5	80	t	f	f	f	f	f	f	\N
3044	41	79	t	f	f	f	f	f	f	\N
3103	22	80	f	f	f	f	f	f	f	\N
3054	51	79	t	t	t	t	t	f	f	10.1
3052	49	79	t	t	t	t	t	f	f	10.6
3122	41	80	t	f	f	f	f	f	f	\N
3127	46	80	t	t	t	f	f	f	f	\N
3169	9	81	t	t	t	f	f	f	f	\N
3170	10	81	f	f	f	f	t	f	f	\N
3167	7	81	t	f	f	f	f	f	f	\N
3162	2	81	t	f	f	f	f	f	f	\N
3138	57	80	t	f	f	f	f	f	f	\N
3146	65	80	f	f	f	f	f	f	f	\N
3163	3	81	t	t	t	t	f	f	f	4.6
3165	5	81	t	f	f	f	t	f	f	\N
3168	8	81	f	f	f	f	f	f	f	\N
3171	11	81	f	f	f	f	f	f	f	\N
3166	6	81	t	f	f	f	t	f	f	\N
3172	12	81	f	f	f	f	f	f	f	\N
3164	4	81	f	f	f	f	t	f	f	\N
3161	1	81	t	f	f	f	t	f	f	\N
3123	42	80	t	t	f	f	f	f	f	\N
3131	50	80	f	f	f	f	f	f	f	\N
3140	59	80	f	f	f	f	f	f	f	\N
3110	29	80	f	f	f	f	\N	f	f	\N
3115	34	80	f	f	f	f	f	f	f	\N
3136	55	80	f	f	f	f	f	f	f	\N
3137	56	80	f	f	f	f	f	f	f	\N
3152	71	80	f	f	f	f	f	f	f	\N
3112	31	80	f	f	f	f	f	f	f	\N
3124	43	80	t	f	f	f	\N	f	f	\N
3145	64	80	t	t	t	t	f	f	f	10.1
3125	44	80	f	f	f	f	f	f	f	\N
3118	37	80	f	f	f	f	f	f	f	\N
3160	79	80	t	f	f	f	f	f	f	\N
3159	78	80	f	f	f	f	\N	f	f	\N
3139	58	80	t	f	f	f	f	f	f	\N
3154	73	80	t	f	f	f	\N	f	f	\N
3117	36	80	t	f	f	f	f	f	f	\N
3119	38	80	f	f	f	f	f	f	f	\N
3132	51	80	t	t	t	t	f	f	f	6.1
3153	72	80	f	f	f	f	f	f	f	\N
3111	30	80	t	f	f	f	t	f	f	\N
3113	32	80	t	f	f	f	f	f	f	\N
3130	49	80	f	f	f	f	f	f	f	\N
3141	60	80	t	f	f	f	f	f	f	\N
3143	62	80	f	f	f	f	\N	f	f	\N
3148	67	80	f	f	f	f	f	f	f	\N
3114	33	80	f	f	f	f	\N	f	f	\N
3133	52	80	f	f	f	f	f	f	f	\N
3120	39	80	t	f	f	f	f	f	f	\N
3128	47	80	t	f	f	f	f	f	f	\N
3126	45	80	f	f	f	f	\N	f	f	\N
3149	68	80	t	t	t	t	f	f	f	10.4
3155	74	80	f	f	f	f	t	f	f	\N
3134	53	80	f	f	f	f	f	f	f	\N
3151	70	80	f	f	f	f	f	f	f	\N
3158	77	80	f	f	f	f	f	f	f	\N
3116	35	80	f	f	f	f	f	f	f	\N
3147	66	80	f	f	f	f	t	f	f	\N
3150	69	80	t	t	f	f	f	f	f	\N
3156	75	80	t	f	f	f	t	f	f	\N
3157	76	80	f	f	f	f	\N	f	f	\N
3121	40	80	t	f	f	f	t	f	f	\N
3129	48	80	t	f	f	f	t	f	f	\N
3135	54	80	t	f	f	f	f	f	f	\N
3142	61	80	t	t	t	t	f	f	f	10.1
3144	63	80	f	f	f	f	f	f	f	\N
3175	15	81	t	t	t	t	\N	f	f	10.6
3183	23	81	f	f	f	f	f	f	f	\N
3192	32	81	f	f	f	f	f	f	f	\N
3224	64	81	t	f	f	f	f	f	f	\N
3246	6	82	t	t	t	f	f	f	f	\N
3230	70	81	f	f	f	f	f	f	f	\N
3211	51	81	f	f	f	f	t	f	f	\N
3248	8	82	t	t	t	f	f	f	f	\N
3236	76	81	t	f	f	f	\N	f	f	\N
3234	74	81	t	f	f	f	f	f	f	\N
3242	2	82	t	f	f	f	f	f	f	\N
3177	17	81	t	f	f	f	f	f	f	\N
3178	18	81	f	f	f	f	f	f	f	\N
3253	13	82	t	t	t	t	\N	f	f	10.1
3179	19	81	t	t	t	t	\N	f	f	11
3259	19	82	t	t	t	t	\N	f	f	8.1
3191	31	81	t	t	t	f	f	f	f	\N
3212	52	81	t	f	f	f	t	f	f	\N
3223	63	81	f	f	f	f	f	f	f	\N
3193	33	81	t	f	f	f	\N	f	f	\N
3232	72	81	f	f	f	f	f	f	f	\N
3215	55	81	t	f	f	f	f	f	f	\N
3181	21	81	f	f	f	f	\N	f	f	\N
3208	48	81	f	f	f	f	f	f	f	\N
3222	62	81	f	f	f	f	\N	f	f	\N
3209	49	81	f	f	f	f	t	f	f	\N
3231	71	81	t	f	f	f	t	f	f	\N
3255	15	82	t	t	t	t	\N	f	f	10.8
3185	25	81	f	f	f	f	f	f	f	\N
3258	18	82	t	t	f	f	t	f	f	\N
3243	3	82	t	t	t	f	f	f	f	\N
3221	61	81	f	f	f	f	t	f	f	\N
3225	65	81	t	f	f	f	f	f	f	\N
3194	34	81	t	f	f	f	t	f	f	\N
3240	80	81	f	f	f	f	f	f	f	\N
3226	66	81	f	f	f	f	f	f	f	\N
3198	38	81	f	f	f	f	f	f	f	\N
3238	78	81	t	f	f	f	\N	f	f	\N
3254	14	82	t	t	t	f	t	f	f	\N
3229	69	81	t	f	f	f	t	f	f	\N
3262	22	82	t	t	t	f	f	f	f	\N
3241	1	82	t	f	f	f	f	f	f	\N
3187	27	81	f	f	f	f	f	f	f	\N
3261	21	82	t	t	t	f	\N	f	f	\N
3190	30	81	t	f	f	f	f	f	f	\N
3195	35	81	t	f	f	f	f	f	f	\N
3210	50	81	f	f	f	f	t	f	f	\N
3204	44	81	f	f	f	f	t	f	f	\N
3202	42	81	t	f	f	f	f	f	f	\N
3205	45	81	f	f	f	f	\N	f	f	\N
3206	46	81	f	f	f	f	t	f	f	\N
3207	47	81	t	f	f	f	f	f	f	\N
3219	59	81	f	f	f	f	f	f	f	\N
3214	54	81	t	f	f	f	f	f	f	\N
3235	75	81	t	f	f	f	f	f	f	\N
3189	29	81	f	f	f	f	\N	f	f	\N
3217	57	81	f	f	f	f	f	f	f	\N
3239	79	81	t	f	f	f	t	f	f	\N
3220	60	81	t	t	f	f	t	f	f	\N
3174	14	81	t	t	t	f	f	f	f	\N
3184	24	81	t	t	t	t	\N	f	f	11
3182	22	81	t	f	f	f	f	f	f	\N
3218	58	81	t	f	f	f	f	f	f	\N
3196	36	81	t	t	t	t	f	f	f	1
3227	67	81	f	f	f	f	f	f	f	\N
3228	68	81	t	f	f	f	t	f	f	\N
3188	28	81	f	f	f	f	f	f	f	\N
3201	41	81	t	t	t	t	f	f	f	0.6
3197	37	81	t	f	f	f	f	f	f	\N
3203	43	81	t	f	f	f	\N	f	f	\N
3199	39	81	t	f	f	f	f	f	f	\N
3213	53	81	f	f	f	f	t	f	f	\N
3237	77	81	f	f	f	f	f	f	f	\N
3173	13	81	f	f	f	f	\N	f	f	\N
3233	73	81	t	t	f	f	\N	f	f	\N
3176	16	81	f	f	f	f	\N	f	f	\N
3180	20	81	f	f	f	f	f	f	f	\N
3186	26	81	t	f	f	f	f	f	f	\N
3200	40	81	t	t	t	f	f	f	f	\N
3216	56	81	f	f	f	f	f	f	f	\N
3266	26	82	t	t	f	f	f	f	f	\N
3245	5	82	t	f	f	f	f	f	f	\N
3257	17	82	t	f	f	f	t	f	f	\N
3247	7	82	t	t	t	f	t	f	f	\N
3260	20	82	t	t	f	f	f	f	f	\N
3250	10	82	t	t	t	f	f	f	f	\N
3251	11	82	t	f	f	f	f	f	f	\N
3263	23	82	t	f	f	f	f	f	f	\N
3244	4	82	t	t	t	t	f	f	f	4.1
3249	9	82	t	t	t	f	f	f	f	\N
3267	27	82	t	t	t	t	t	f	f	4.1
3256	16	82	t	t	t	f	\N	f	f	\N
3265	25	82	t	f	f	f	f	f	f	\N
3252	12	82	t	f	f	f	f	f	f	\N
3264	24	82	t	t	t	t	\N	f	f	8.4
3315	75	82	t	f	f	f	f	f	f	\N
3340	19	83	t	f	f	f	\N	f	f	\N
3284	44	82	t	t	f	f	f	f	f	\N
3308	68	82	t	t	t	t	f	f	f	11
3274	34	82	t	t	t	f	f	f	f	\N
3347	26	83	t	t	f	f	f	f	f	\N
3331	10	83	f	f	f	f	f	f	f	\N
3303	63	82	t	t	t	f	f	f	f	\N
3334	13	83	f	f	f	f	\N	f	f	\N
3311	71	82	t	t	f	f	f	f	f	\N
3320	80	82	t	f	f	f	f	f	f	\N
3314	74	82	t	f	f	f	f	f	f	\N
3277	37	82	t	t	t	f	f	f	f	\N
3343	22	83	t	t	t	f	t	f	f	\N
3317	77	82	t	t	t	f	f	f	f	\N
3302	62	82	t	t	t	t	\N	f	f	10.1
3324	3	83	t	f	f	f	f	f	f	\N
3309	69	82	t	t	f	f	f	f	f	\N
3312	72	82	t	f	f	f	f	f	f	\N
3272	32	82	t	t	t	f	f	f	f	\N
3280	40	82	t	t	t	f	f	f	f	\N
3297	57	82	t	f	f	f	f	f	f	\N
3304	64	82	t	t	t	t	f	f	f	10.1
3286	46	82	t	t	t	f	f	f	f	\N
3285	45	82	t	t	t	t	\N	f	f	8.8
3270	30	82	t	f	f	f	f	f	f	\N
3288	48	82	t	f	f	f	f	f	f	\N
3278	38	82	t	f	f	f	f	f	f	\N
3283	43	82	t	f	f	f	\N	f	f	\N
3268	28	82	t	f	f	f	f	f	f	\N
3296	56	82	t	t	t	t	f	f	f	10.6
3290	50	82	t	t	t	f	f	f	f	\N
3295	55	82	t	f	f	f	f	f	f	\N
3307	67	82	t	t	t	f	t	f	f	\N
3282	42	82	t	t	t	f	f	f	f	\N
3318	78	82	t	f	f	f	\N	f	f	\N
3319	79	82	t	f	f	f	f	f	f	\N
3305	65	82	t	t	f	f	f	f	f	\N
3273	33	82	t	t	f	f	\N	f	f	\N
3271	31	82	t	t	t	f	f	f	f	\N
3313	73	82	t	t	f	f	\N	f	f	\N
3275	35	82	t	f	f	f	f	f	f	\N
3287	47	82	t	f	f	f	t	f	f	\N
3291	51	82	t	t	t	t	f	f	f	6.1
3292	52	82	t	f	f	f	f	f	f	\N
3276	36	82	t	t	t	f	t	f	f	\N
3298	58	82	t	f	f	f	t	f	f	\N
3281	41	82	t	t	t	f	f	f	f	\N
3301	61	82	t	t	t	t	f	f	f	10.1
3294	54	82	t	f	f	f	t	f	f	\N
3316	76	82	t	t	t	f	\N	f	f	\N
3289	49	82	t	t	t	t	f	f	f	6.8
3321	81	82	t	t	t	t	f	f	f	10.2
3279	39	82	t	f	f	f	f	f	f	\N
3299	59	82	t	t	t	t	f	f	f	10.1
3293	53	82	t	t	t	t	f	f	f	11
3306	66	82	t	t	t	f	f	f	f	\N
3269	29	82	t	f	f	f	\N	f	f	\N
3300	60	82	t	t	f	f	f	f	f	\N
3310	70	82	t	t	t	t	f	f	f	6.1
3326	5	83	t	f	f	f	f	f	f	\N
3341	20	83	f	f	f	f	f	f	f	\N
3327	6	83	t	t	t	t	f	f	f	11
3333	12	83	f	f	f	f	t	f	f	\N
3345	24	83	t	f	f	f	\N	f	f	\N
3322	1	83	t	f	f	f	f	f	f	\N
3329	8	83	f	f	f	f	f	f	f	\N
3332	11	83	f	f	f	f	t	f	f	\N
3328	7	83	t	t	t	t	f	f	f	1.1
3335	14	83	t	f	f	f	f	f	f	\N
3346	25	83	f	f	f	f	f	f	f	\N
3325	4	83	f	f	f	f	f	f	f	\N
3330	9	83	t	f	f	f	t	f	f	\N
3336	15	83	t	f	f	f	\N	f	f	\N
3337	16	83	f	f	f	f	\N	f	f	\N
3342	21	83	f	f	f	f	\N	f	f	\N
3323	2	83	t	f	f	f	f	f	f	\N
3338	17	83	t	f	f	f	f	f	f	\N
3344	23	83	f	f	f	f	t	f	f	\N
3339	18	83	f	f	f	f	f	f	f	\N
3353	32	83	f	f	f	f	t	f	f	\N
3361	40	83	t	f	f	f	f	f	f	\N
3390	69	83	t	t	f	f	f	f	f	\N
3400	79	83	t	f	f	f	f	f	f	\N
3389	68	83	t	t	t	f	f	f	f	\N
3394	73	83	t	f	f	f	\N	f	f	\N
3356	35	83	t	f	f	f	f	f	f	\N
3373	52	83	t	f	f	f	f	f	f	\N
3374	53	83	f	f	f	f	f	f	f	\N
3358	37	83	t	t	t	t	t	f	f	6.2
3365	44	83	f	f	f	f	f	f	f	\N
3372	51	83	f	f	f	f	f	f	f	\N
3384	63	83	f	f	f	f	t	f	f	\N
3396	75	83	t	f	f	f	f	f	f	\N
3359	38	83	f	f	f	f	f	f	f	\N
3366	45	83	f	f	f	f	\N	f	f	\N
3369	48	83	f	f	f	f	f	f	f	\N
3362	41	83	t	f	f	f	t	f	f	\N
3375	54	83	t	f	f	f	f	f	f	\N
3391	70	83	f	f	f	f	f	f	f	\N
3363	42	83	t	t	f	f	t	f	f	\N
3370	49	83	f	f	f	f	f	f	f	\N
3377	56	83	f	f	f	f	f	f	f	\N
3393	72	83	f	f	f	f	t	f	f	\N
3398	77	83	f	f	f	f	f	f	f	\N
3387	66	83	f	f	f	f	f	f	f	\N
3401	80	83	f	f	f	f	f	f	f	\N
3350	29	83	f	f	f	f	\N	f	f	\N
3395	74	83	t	f	f	f	f	f	f	\N
3360	39	83	t	f	f	f	f	f	f	\N
3351	30	83	t	f	f	f	f	f	f	\N
3367	46	83	f	f	f	f	f	f	f	\N
3352	31	83	t	f	f	f	f	f	f	\N
3376	55	83	t	f	f	f	f	f	f	\N
3364	43	83	t	f	f	f	\N	f	f	\N
3371	50	83	f	f	f	f	f	f	f	\N
3378	57	83	f	f	f	f	f	f	f	\N
3348	27	83	f	f	f	f	f	f	f	\N
3381	60	83	t	f	f	f	f	f	f	\N
3383	62	83	f	f	f	f	\N	f	f	\N
3386	65	83	t	t	f	f	f	f	f	\N
3399	78	83	t	f	f	f	\N	f	f	\N
3402	81	83	t	f	f	f	f	f	f	\N
3357	36	83	t	f	f	f	f	f	f	\N
3385	64	83	t	t	t	t	t	f	f	2
3349	28	83	f	f	f	f	f	f	f	\N
3354	33	83	t	t	f	f	\N	f	f	\N
3382	61	83	f	f	f	f	f	f	f	\N
3368	47	83	t	f	f	f	f	f	f	\N
3388	67	83	f	f	f	f	f	f	f	\N
3397	76	83	t	t	t	t	\N	f	f	0.1
3392	71	83	t	t	f	f	f	f	f	\N
3403	82	83	t	f	f	f	f	f	f	\N
3379	58	83	t	f	f	f	f	f	f	\N
3380	59	83	f	f	f	f	f	f	f	\N
3355	34	83	t	t	t	t	f	f	f	9
3407	4	84	t	t	f	f	f	f	f	\N
3406	3	84	t	t	t	t	f	f	f	4.4
3404	1	84	t	f	f	f	f	f	f	\N
3405	2	84	t	f	f	f	f	f	f	\N
3408	5	84	t	f	f	f	f	f	f	\N
3467	64	84	t	t	t	t	t	f	f	2
3462	59	84	t	t	t	t	f	f	f	2
3483	80	84	t	f	f	f	f	f	f	\N
3482	79	84	t	f	f	f	f	f	f	\N
3443	40	84	t	t	f	f	f	f	f	\N
3469	66	84	t	t	t	f	f	f	f	\N
3485	82	84	t	t	t	f	f	f	f	\N
3414	11	84	t	f	f	f	t	f	f	\N
3447	44	84	t	t	t	t	f	f	f	8.1
3475	72	84	t	f	f	f	t	f	f	\N
3428	25	84	t	f	f	f	f	f	f	\N
3420	17	84	t	f	f	f	f	f	f	\N
3476	73	84	t	t	t	t	\N	f	f	5
3409	6	84	t	t	t	t	f	f	f	9
3449	46	84	t	t	t	f	f	f	f	\N
3438	35	84	t	f	f	f	f	f	f	\N
3451	48	84	t	f	f	f	f	f	f	\N
3419	16	84	t	t	t	t	\N	f	f	6.1
3474	71	84	t	t	t	t	f	f	f	3
3415	12	84	t	f	f	f	t	f	f	\N
3478	75	84	t	f	f	f	f	f	f	\N
3434	31	84	t	t	t	f	f	f	f	\N
3418	15	84	t	t	t	t	\N	f	f	1.1
3446	43	84	t	f	f	f	\N	f	f	\N
3436	33	84	t	t	t	t	\N	f	f	6.1
3458	55	84	t	f	f	f	f	f	f	\N
3450	47	84	t	f	f	f	f	f	f	\N
3413	10	84	t	t	t	t	f	f	f	10.1
3468	65	84	t	t	t	f	f	f	f	\N
3457	54	84	t	f	f	f	f	f	f	\N
3421	18	84	t	t	t	t	f	f	f	6.4
3448	45	84	t	t	f	f	\N	f	f	\N
3456	53	84	t	t	t	f	f	f	f	\N
3437	34	84	t	t	t	t	f	f	f	11
3427	24	84	t	t	t	t	\N	f	f	1.1
3459	56	84	t	t	t	f	f	f	f	\N
3433	30	84	t	f	f	f	f	f	f	\N
3429	26	84	t	t	t	t	f	f	f	2.2
3426	23	84	t	f	f	f	t	f	f	\N
3432	29	84	t	f	f	f	\N	f	f	\N
3472	69	84	t	t	t	t	f	f	f	1.1
3422	19	84	t	t	f	f	\N	f	f	\N
3410	7	84	t	t	f	f	f	f	f	\N
3484	81	84	t	t	f	f	f	f	f	\N
3442	39	84	t	f	f	f	f	f	f	\N
3440	37	84	t	t	t	t	t	f	f	6.1
3441	38	84	t	f	f	f	f	f	f	\N
3480	77	84	t	t	t	t	f	f	f	8.1
3439	36	84	t	t	t	t	f	f	f	10.2
3460	57	84	t	f	f	f	f	f	f	\N
3463	60	84	t	t	t	t	f	f	f	10.2
3435	32	84	t	t	t	t	t	f	f	6.4
3470	67	84	t	t	t	t	f	f	f	7
3412	9	84	t	t	t	t	t	f	f	2.1
3453	50	84	t	t	f	f	f	f	f	\N
3452	49	84	t	t	t	t	f	f	f	2.1
3473	70	84	t	t	t	t	f	f	f	2.2
3465	62	84	t	t	t	f	\N	f	f	\N
3479	76	84	t	t	t	t	\N	f	f	1.1
3477	74	84	t	f	f	f	f	f	f	\N
3486	83	84	t	f	f	f	t	f	f	\N
3417	14	84	t	t	f	f	f	f	f	\N
3455	52	84	t	f	f	f	f	f	f	\N
3423	20	84	t	t	t	t	f	f	f	6.4
3431	28	84	t	f	f	f	f	f	f	\N
3464	61	84	t	t	f	f	f	f	f	\N
3411	8	84	t	t	t	t	f	f	f	10.1
3430	27	84	t	t	t	t	f	f	f	2.6
3461	58	84	t	f	f	f	f	f	f	\N
3416	13	84	t	t	t	f	\N	f	f	\N
3424	21	84	t	t	f	f	\N	f	f	\N
3445	42	84	t	t	t	f	t	f	f	\N
3471	68	84	t	t	t	f	f	f	f	\N
3481	78	84	t	f	f	f	\N	f	f	\N
3425	22	84	t	t	t	f	t	f	f	\N
3466	63	84	t	t	t	t	t	f	f	11
3444	41	84	t	t	t	t	t	f	f	10.1
3454	51	84	t	t	t	t	f	f	f	3
3487	1	85	t	f	f	f	f	f	f	\N
3569	83	85	t	f	f	f	f	f	f	\N
3552	66	85	f	f	f	f	f	f	f	\N
3504	18	85	f	f	f	f	f	f	f	\N
3526	40	85	t	f	f	f	f	f	f	\N
3559	73	85	t	f	f	f	\N	f	f	\N
3507	21	85	f	f	f	f	\N	f	f	\N
3534	48	85	f	f	f	f	f	f	f	\N
3489	3	85	t	f	f	f	f	f	f	\N
3578	8	86	t	t	t	t	f	f	f	1.2
3491	5	85	t	f	f	f	f	f	f	\N
3564	78	85	t	f	f	f	\N	f	f	\N
3496	10	85	f	f	f	f	f	f	f	\N
3530	44	85	f	f	f	f	f	f	f	\N
3498	12	85	f	f	f	f	f	f	f	\N
3495	9	85	t	f	f	f	f	f	f	\N
3500	14	85	t	f	f	f	f	f	f	\N
3532	46	85	f	f	f	f	f	f	f	\N
3577	7	86	t	f	f	f	f	f	f	\N
3567	81	85	t	f	f	f	f	f	f	\N
3531	45	85	f	f	f	f	\N	f	f	\N
3541	55	85	t	f	f	f	t	f	f	\N
3536	50	85	f	f	f	f	f	f	f	\N
3503	17	85	t	f	f	f	f	f	f	\N
3535	49	85	f	f	f	f	f	f	f	\N
3488	2	85	t	f	f	f	f	f	f	\N
3513	27	85	f	f	f	f	f	f	f	\N
3537	51	85	f	f	f	f	f	f	f	\N
3490	4	85	f	f	f	f	f	f	f	\N
3580	10	86	t	f	f	f	t	f	f	\N
3542	56	85	f	f	f	f	t	f	f	\N
3499	13	85	f	f	f	f	\N	f	f	\N
3510	24	85	t	f	f	f	\N	f	f	\N
3525	39	85	t	f	f	f	t	f	f	\N
3539	53	85	f	f	f	f	f	f	f	\N
3540	54	85	t	f	f	f	f	f	f	\N
3529	43	85	t	f	f	f	\N	f	f	\N
3554	68	85	t	t	t	f	f	f	f	\N
3508	22	85	t	t	t	f	f	f	f	\N
3561	75	85	t	f	f	f	f	f	f	\N
3565	79	85	t	f	f	f	f	f	f	\N
3511	25	85	f	f	f	f	t	f	f	\N
3562	76	85	t	t	t	t	\N	f	f	0.2
3566	80	85	f	f	f	f	f	f	f	\N
3492	6	85	t	t	t	t	f	f	f	10.1
3509	23	85	f	f	f	f	f	f	f	\N
3505	19	85	t	f	f	f	\N	f	f	\N
3524	38	85	f	f	f	f	t	f	f	\N
3555	69	85	t	t	t	t	f	f	f	2.6
3560	74	85	t	f	f	f	f	f	f	\N
3543	57	85	f	f	f	f	t	f	f	\N
3520	34	85	t	t	t	t	f	f	f	4.1
3553	67	85	f	f	f	f	f	f	f	\N
3570	84	85	t	f	f	f	f	f	f	\N
3521	35	85	t	f	f	f	t	f	f	\N
3512	26	85	t	t	t	t	t	f	f	6.6
3519	33	85	t	t	t	t	\N	f	f	10.8
3522	36	85	t	f	f	f	f	f	f	\N
3493	7	85	t	t	t	t	f	f	f	1
3494	8	85	f	f	f	f	f	f	f	\N
3527	41	85	t	f	f	f	f	f	f	\N
3551	65	85	t	t	t	f	t	f	f	\N
3514	28	85	f	f	f	f	t	f	f	\N
3501	15	85	t	f	f	f	\N	f	f	\N
3516	30	85	t	f	f	f	f	f	f	\N
3515	29	85	f	f	f	f	\N	f	f	\N
3517	31	85	t	f	f	f	t	f	f	\N
3545	59	85	f	f	f	f	t	f	f	\N
3549	63	85	f	f	f	f	f	f	f	\N
3563	77	85	f	f	f	f	t	f	f	\N
3538	52	85	t	f	f	f	f	f	f	\N
3523	37	85	t	t	t	t	f	f	f	10.8
3550	64	85	t	t	t	t	f	f	f	4.1
3546	60	85	t	f	f	f	f	f	f	\N
3548	62	85	f	f	f	f	\N	f	f	\N
3556	70	85	f	f	f	f	t	f	f	\N
3544	58	85	t	f	f	f	f	f	f	\N
3547	61	85	f	f	f	f	f	f	f	\N
3497	11	85	f	f	f	f	f	f	f	\N
3506	20	85	f	f	f	f	f	f	f	\N
3533	47	85	t	f	f	f	f	f	f	\N
3557	71	85	t	t	t	t	f	f	f	6.1
3558	72	85	f	f	f	f	f	f	f	\N
3502	16	85	f	f	f	f	\N	f	f	\N
3568	82	85	t	f	f	f	f	f	f	\N
3518	32	85	f	f	f	f	f	f	f	\N
3528	42	85	t	t	t	f	f	f	f	\N
3574	4	86	t	f	f	f	t	f	f	\N
3582	12	86	t	f	f	f	f	f	f	\N
3583	13	86	t	f	f	f	\N	f	f	\N
3573	3	86	t	t	t	t	f	f	f	10.6
3571	1	86	t	f	f	f	t	f	f	\N
3585	15	86	t	f	f	f	\N	f	f	\N
3576	6	86	t	f	f	f	t	f	f	\N
3581	11	86	t	t	t	f	f	f	f	\N
3584	14	86	t	f	f	f	f	f	f	\N
3579	9	86	t	t	t	f	f	f	f	\N
3572	2	86	t	f	f	f	f	f	f	\N
3575	5	86	t	f	f	f	t	f	f	\N
3593	23	86	t	f	f	f	f	f	f	\N
3651	81	86	t	f	f	f	t	f	f	\N
3636	66	86	t	f	f	f	f	f	f	\N
3628	58	86	t	t	t	t	f	f	f	1.1
3601	31	86	t	f	f	f	f	f	f	\N
3599	29	86	t	t	f	f	\N	f	f	\N
3617	47	86	t	f	f	f	f	f	f	\N
3650	80	86	t	t	t	t	f	f	f	4.1
3587	17	86	t	t	t	t	f	f	f	8.1
3608	38	86	t	f	f	f	f	f	f	\N
3616	46	86	t	f	f	f	t	f	f	\N
3615	45	86	t	f	f	f	\N	f	f	\N
3596	26	86	t	f	f	f	f	f	f	\N
3630	60	86	t	f	f	f	t	f	f	\N
3594	24	86	t	t	t	t	\N	f	f	8.1
3600	30	86	t	f	f	f	f	f	f	\N
3595	25	86	t	f	f	f	f	f	f	\N
3634	64	86	t	f	f	f	f	f	f	\N
3609	39	86	t	t	f	f	f	f	f	\N
3646	76	86	t	f	f	f	\N	f	f	\N
3623	53	86	t	t	t	t	t	f	f	4.1
3655	85	86	t	t	t	t	f	f	f	8.1
3624	54	86	t	f	f	f	f	f	f	\N
3588	18	86	t	f	f	f	f	f	f	\N
3635	65	86	t	f	f	f	f	f	f	\N
3586	16	86	t	t	f	f	\N	f	f	\N
3598	28	86	t	t	f	f	f	f	f	\N
3640	70	86	t	f	f	f	f	f	f	\N
3618	48	86	t	f	f	f	f	f	f	\N
3633	63	86	t	f	f	f	f	f	f	\N
3620	50	86	t	t	t	t	t	f	f	10.6
3648	78	86	t	t	t	f	\N	f	f	\N
3629	59	86	t	f	f	f	f	f	f	\N
3632	62	86	t	f	f	f	\N	f	f	\N
3603	33	86	t	f	f	f	\N	f	f	\N
3639	69	86	t	f	f	f	t	f	f	\N
3605	35	86	t	t	t	t	f	f	f	2.1
3606	36	86	t	f	f	f	f	f	f	\N
3643	73	86	t	f	f	f	\N	f	f	\N
3637	67	86	t	f	f	f	f	f	f	\N
3652	82	86	t	t	t	t	f	f	f	4.1
3612	42	86	t	f	f	f	f	f	f	\N
3591	21	86	t	f	f	f	\N	f	f	\N
3592	22	86	t	f	f	f	f	f	f	\N
3589	19	86	t	t	t	t	\N	f	f	8.2
3611	41	86	t	f	f	f	f	f	f	\N
3604	34	86	t	f	f	f	t	f	f	\N
3597	27	86	t	f	f	f	f	f	f	\N
3638	68	86	t	f	f	f	t	f	f	\N
3645	75	86	t	f	f	f	f	f	f	\N
3610	40	86	t	f	f	f	f	f	f	\N
3613	43	86	t	f	f	f	\N	f	f	\N
3642	72	86	t	t	f	f	f	f	f	\N
3649	79	86	t	t	t	t	t	f	f	10.1
3614	44	86	t	f	f	f	t	f	f	\N
3619	49	86	t	f	f	f	t	f	f	\N
3602	32	86	t	f	f	f	f	f	f	\N
3625	55	86	t	t	t	t	f	f	f	6.8
3590	20	86	t	f	f	f	f	f	f	\N
3626	56	86	t	f	f	f	f	f	f	\N
3653	83	86	t	t	t	t	f	f	f	3
3641	71	86	t	f	f	f	t	f	f	\N
3621	51	86	t	f	f	f	t	f	f	\N
3644	74	86	t	f	f	f	f	f	f	\N
3647	77	86	t	t	t	f	f	f	f	\N
3654	84	86	t	t	f	f	f	f	f	\N
3607	37	86	t	f	f	f	f	f	f	\N
3627	57	86	t	t	t	t	f	f	f	10.1
3622	52	86	t	t	t	t	t	f	f	4.1
3631	61	86	t	f	f	f	t	f	f	\N
3673	18	87	f	f	f	f	f	f	f	\N
3662	7	87	t	t	f	f	f	f	f	\N
3709	54	87	t	f	f	f	f	f	f	\N
3660	5	87	t	f	f	f	f	f	f	\N
3680	25	87	f	f	f	f	f	f	f	\N
3693	38	87	f	f	f	f	f	f	f	\N
3665	10	87	f	f	f	f	f	f	f	\N
3657	2	87	t	f	f	f	f	f	f	\N
3668	13	87	f	f	f	f	f	f	f	\N
3681	26	87	t	t	t	t	f	f	f	11
3683	28	87	f	f	f	f	f	f	f	\N
3659	4	87	f	f	f	f	f	f	f	\N
3685	30	87	t	f	f	f	f	f	f	\N
3656	1	87	t	f	f	f	f	f	f	\N
3682	27	87	f	f	f	f	f	f	f	\N
3689	34	87	t	t	t	t	f	f	f	1.2
3703	48	87	f	f	f	f	f	f	f	\N
3674	19	87	t	f	f	f	f	f	f	\N
3702	47	87	t	f	f	f	f	f	f	\N
3708	53	87	f	f	f	f	f	f	f	\N
3661	6	87	t	t	t	t	f	f	f	4.2
3715	60	87	t	f	f	f	f	f	f	\N
3687	32	87	f	f	f	f	f	f	f	\N
3671	16	87	f	f	f	f	f	f	f	\N
3699	44	87	f	f	f	f	f	f	f	\N
3712	57	87	f	f	f	f	f	f	f	\N
3690	35	87	t	f	f	f	f	f	f	\N
3707	52	87	t	f	f	f	f	f	f	\N
3663	8	87	f	f	f	f	f	f	f	\N
3675	20	87	f	f	f	f	f	f	f	\N
3669	14	87	t	f	f	f	f	f	f	\N
3670	15	87	t	f	f	f	f	f	f	\N
3678	23	87	f	f	f	f	f	f	f	\N
3711	56	87	f	f	f	f	f	f	f	\N
3696	41	87	t	f	f	f	f	f	f	\N
3714	59	87	f	f	f	f	f	f	f	\N
3667	12	87	f	f	f	f	f	f	f	\N
3676	21	87	f	f	f	f	f	f	f	\N
3706	51	87	f	f	f	f	f	f	f	\N
3694	39	87	t	f	f	f	f	f	f	\N
3695	40	87	t	f	f	f	f	f	f	\N
3684	29	87	f	f	f	f	f	f	f	\N
3710	55	87	t	f	f	f	f	f	f	\N
3664	9	87	t	f	f	f	f	f	f	\N
3701	46	87	f	f	f	f	f	f	f	\N
3686	31	87	t	f	f	f	f	f	f	\N
3698	43	87	t	f	f	f	f	f	f	\N
3658	3	87	t	f	f	f	f	f	f	\N
3692	37	87	t	t	t	t	f	f	f	9
3691	36	87	t	f	f	f	f	f	f	\N
3700	45	87	f	f	f	f	f	f	f	\N
3697	42	87	t	t	t	f	f	f	f	\N
3704	49	87	f	f	f	f	f	f	f	\N
3666	11	87	f	f	f	f	f	f	f	\N
3713	58	87	t	f	f	f	f	f	f	\N
3705	50	87	f	f	f	f	f	f	f	\N
3754	13	88	f	f	f	f	f	f	f	\N
3730	75	87	t	f	f	f	f	f	f	\N
3679	24	87	t	f	f	f	f	f	f	\N
3718	63	87	f	f	f	f	f	f	f	\N
3753	12	88	f	f	f	f	f	f	f	\N
3762	21	88	f	f	f	f	f	f	f	\N
3748	7	88	f	f	f	f	f	f	f	\N
3720	65	87	t	t	t	f	f	f	f	\N
3725	70	87	f	f	f	f	f	f	f	\N
3743	2	88	t	f	f	f	f	f	f	\N
3729	74	87	t	f	f	f	f	f	f	\N
3744	3	88	f	f	f	f	f	f	f	\N
3758	17	88	t	f	f	f	f	f	f	\N
3764	23	88	f	f	f	f	f	f	f	\N
3757	16	88	f	f	f	f	f	f	f	\N
3726	71	87	t	t	t	t	f	f	f	10.1
3739	84	87	t	f	f	f	f	f	f	\N
3722	67	87	f	f	f	f	f	f	f	\N
3731	76	87	t	t	t	f	f	f	f	\N
3721	66	87	f	f	f	f	f	f	f	\N
3735	80	87	f	f	f	f	f	f	f	\N
3755	14	88	t	t	t	t	f	f	f	1
3740	85	87	t	f	f	f	f	f	f	\N
3756	15	88	f	f	f	f	f	f	f	\N
3761	20	88	f	f	f	f	f	f	f	\N
3677	22	87	t	t	t	f	f	f	f	\N
3763	22	88	f	f	f	f	f	f	f	\N
3728	73	87	t	f	f	f	f	f	f	\N
3732	77	87	f	f	f	f	f	f	f	\N
3767	26	88	f	f	f	f	f	f	f	\N
3736	81	87	t	f	f	f	f	f	f	\N
3727	72	87	f	f	f	f	f	f	f	\N
3717	62	87	f	f	f	f	f	f	f	\N
3672	17	87	t	f	f	f	f	f	f	\N
3776	35	88	f	f	f	f	f	f	f	\N
3734	79	87	t	f	f	f	f	f	f	\N
3688	33	87	t	t	t	t	f	f	f	9
3716	61	87	f	f	f	f	f	f	f	\N
3750	9	88	t	t	t	t	f	f	f	0.4
3759	18	88	f	f	f	f	f	f	f	\N
3719	64	87	t	t	t	t	f	f	f	6.4
3777	36	88	t	t	t	f	f	f	f	\N
3745	4	88	f	f	f	f	f	f	f	\N
3723	68	87	t	t	t	t	f	f	f	4.1
3778	37	88	f	f	f	f	f	f	f	\N
3738	83	87	t	f	f	f	f	f	f	\N
3747	6	88	f	f	f	f	f	f	f	\N
3751	10	88	f	f	f	f	f	f	f	\N
3775	34	88	f	f	f	f	f	f	f	\N
3752	11	88	f	f	f	f	f	f	f	\N
3724	69	87	t	t	t	t	f	f	f	6.1
3765	24	88	f	f	f	f	f	f	f	\N
3737	82	87	t	f	f	f	f	f	f	\N
3773	32	88	f	f	f	f	f	f	f	\N
3772	31	88	f	f	f	f	f	f	f	\N
3741	86	87	t	t	f	f	f	f	f	\N
3733	78	87	t	f	f	f	f	f	f	\N
3760	19	88	t	t	t	f	f	f	f	\N
3766	25	88	f	f	f	f	f	f	f	\N
3769	28	88	f	f	f	f	f	f	f	\N
3770	29	88	f	f	f	f	f	f	f	\N
3771	30	88	t	f	f	f	f	f	f	\N
3774	33	88	f	f	f	f	f	f	f	\N
3742	1	88	t	f	f	f	f	f	f	\N
3746	5	88	t	f	f	f	f	f	f	\N
3749	8	88	f	f	f	f	f	f	f	\N
3768	27	88	f	f	f	f	f	f	f	\N
3808	67	88	f	f	f	f	f	f	f	\N
3782	41	88	t	t	t	f	f	f	f	\N
3787	46	88	f	f	f	f	f	f	f	\N
3804	63	88	f	f	f	f	f	f	f	\N
3814	73	88	t	t	f	f	f	f	f	\N
3820	79	88	t	f	f	f	f	f	f	\N
3811	70	88	f	f	f	f	f	f	f	\N
3819	78	88	f	f	f	f	f	f	f	\N
3784	43	88	t	f	f	f	f	f	f	\N
3790	49	88	f	f	f	f	f	f	f	\N
3791	50	88	f	f	f	f	f	f	f	\N
3800	59	88	f	f	f	f	f	f	f	\N
3793	52	88	f	f	f	f	f	f	f	\N
3801	60	88	t	t	f	f	f	f	f	\N
3817	76	88	f	f	f	f	f	f	f	\N
3821	80	88	f	f	f	f	f	f	f	\N
3803	62	88	f	f	f	f	f	f	f	\N
3802	61	88	f	f	f	f	f	f	f	\N
3815	74	88	f	f	f	f	f	f	f	\N
3794	53	88	f	f	f	f	f	f	f	\N
3785	44	88	f	f	f	f	f	f	f	\N
3786	45	88	f	f	f	f	f	f	f	\N
3799	58	88	t	f	f	f	f	f	f	\N
3809	68	88	t	f	f	f	f	f	f	\N
3818	77	88	f	f	f	f	f	f	f	\N
3823	82	88	t	t	t	f	f	f	f	\N
3780	39	88	t	f	f	f	f	f	f	\N
3798	57	88	f	f	f	f	f	f	f	\N
3805	64	88	t	f	f	f	f	f	f	\N
3824	83	88	f	f	f	f	f	f	f	\N
3828	87	88	f	f	f	f	f	f	f	\N
3810	69	88	t	f	f	f	f	f	f	\N
3825	84	88	t	t	t	f	f	f	f	\N
3806	65	88	f	f	f	f	f	f	f	\N
3812	71	88	f	f	f	f	f	f	f	\N
3816	75	88	t	f	f	f	f	f	f	\N
3827	86	88	t	f	f	f	f	f	f	\N
3779	38	88	f	f	f	f	f	f	f	\N
3789	48	88	f	f	f	f	f	f	f	\N
3795	54	88	t	f	f	f	f	f	f	\N
3792	51	88	f	f	f	f	f	f	f	\N
3796	55	88	f	f	f	f	f	f	f	\N
3797	56	88	f	f	f	f	f	f	f	\N
3826	85	88	f	f	f	f	f	f	f	\N
3781	40	88	t	t	t	t	f	f	f	2.6
3813	72	88	f	f	f	f	f	f	f	\N
3788	47	88	t	f	f	f	f	f	f	\N
3807	66	88	f	f	f	f	f	f	f	\N
3822	81	88	f	f	f	f	f	f	f	\N
3783	42	88	t	f	f	f	f	f	f	\N
3829	1	89	t	f	f	f	t	f	f	\N
3833	5	89	t	f	f	f	t	f	f	\N
3830	2	89	t	f	f	f	f	f	f	\N
3832	4	89	f	f	f	f	t	f	f	\N
3831	3	89	f	f	f	f	f	f	f	\N
3845	17	89	t	f	f	f	f	f	f	\N
3920	4	90	f	f	f	f	f	f	f	\N
3846	18	89	f	f	f	f	f	f	f	\N
3873	45	89	f	f	f	f	\N	f	f	\N
3883	55	89	f	f	f	f	f	f	f	\N
3915	87	89	f	f	f	f	\N	f	f	\N
3841	13	89	f	f	f	f	\N	f	f	\N
3851	23	89	f	f	f	f	f	f	f	\N
3864	36	89	t	t	t	f	f	f	f	\N
3866	38	89	f	f	f	f	f	f	f	\N
3887	59	89	f	f	f	f	f	f	f	\N
3894	66	89	f	f	f	f	f	f	f	\N
3895	67	89	f	f	f	f	f	f	f	\N
3900	72	89	f	f	f	f	f	f	f	\N
3897	69	89	t	f	f	f	t	f	f	\N
3857	29	89	f	f	f	f	\N	f	f	\N
3872	44	89	f	f	f	f	t	f	f	\N
3862	34	89	f	f	f	f	t	f	f	\N
3903	75	89	t	f	f	f	f	f	f	\N
3908	80	89	f	f	f	f	f	f	f	\N
3911	83	89	f	f	f	f	f	f	f	\N
3906	78	89	f	f	f	f	\N	f	f	\N
3909	81	89	f	f	f	f	t	f	f	\N
3916	88	89	f	f	f	f	\N	f	f	\N
3869	41	89	t	t	t	f	f	f	f	\N
3858	30	89	t	f	f	f	f	f	f	\N
3870	42	89	t	f	f	f	f	f	f	\N
3881	53	89	f	f	f	f	t	f	f	\N
3912	84	89	t	t	t	f	f	f	f	\N
3892	64	89	t	f	f	f	f	f	f	\N
3855	27	89	f	f	f	f	f	f	f	\N
3867	39	89	t	f	f	f	f	f	f	\N
3878	50	89	f	f	f	f	t	f	f	\N
3875	47	89	t	f	f	f	f	f	f	\N
3879	51	89	f	f	f	f	t	f	f	\N
3914	86	89	t	f	f	f	t	f	f	\N
3838	10	89	f	f	f	f	t	f	f	\N
3893	65	89	f	f	f	f	f	f	f	\N
3891	63	89	f	f	f	f	f	f	f	\N
3848	20	89	f	f	f	f	f	f	f	\N
3860	32	89	f	f	f	f	f	f	f	\N
3863	35	89	f	f	f	f	f	f	f	\N
3899	71	89	f	f	f	f	t	f	f	\N
3888	60	89	t	t	f	f	t	f	f	\N
3834	6	89	f	f	f	f	t	f	f	\N
3835	7	89	f	f	f	f	f	f	f	\N
3847	19	89	t	t	t	f	\N	f	f	\N
3859	31	89	f	f	f	f	f	f	f	\N
3840	12	89	f	f	f	f	f	f	f	\N
3882	54	89	t	f	f	f	f	f	f	\N
3884	56	89	f	f	f	f	f	f	f	\N
3856	28	89	f	f	f	f	f	f	f	\N
3923	7	90	t	t	t	t	f	f	f	0.1
3868	40	89	t	t	t	t	f	f	f	2.4
3910	82	89	t	t	t	f	f	f	f	\N
3885	57	89	f	f	f	f	f	f	f	\N
3939	23	90	f	f	f	f	t	f	f	\N
3842	14	89	t	t	t	t	f	f	f	0.1
3901	73	89	t	t	f	f	\N	f	f	\N
3839	11	89	f	f	f	f	f	f	f	\N
3907	79	89	t	f	f	f	t	f	f	\N
3896	68	89	t	f	f	f	t	f	f	\N
3836	8	89	f	f	f	f	f	f	f	\N
3861	33	89	f	f	f	f	\N	f	f	\N
3876	48	89	f	f	f	f	f	f	f	\N
3889	61	89	f	f	f	f	t	f	f	\N
3902	74	89	f	f	f	f	f	f	f	\N
3913	85	89	f	f	f	f	f	f	f	\N
3850	22	89	f	f	f	f	f	f	f	\N
3877	49	89	f	f	f	f	t	f	f	\N
3890	62	89	f	f	f	f	\N	f	f	\N
3898	70	89	f	f	f	f	f	f	f	\N
3854	26	89	f	f	f	f	f	f	f	\N
3904	76	89	f	f	f	f	\N	f	f	\N
3905	77	89	f	f	f	f	f	f	f	\N
3865	37	89	f	f	f	f	f	f	f	\N
3852	24	89	f	f	f	f	\N	f	f	\N
3871	43	89	t	f	f	f	\N	f	f	\N
3874	46	89	f	f	f	f	t	f	f	\N
3853	25	89	f	f	f	f	f	f	f	\N
3880	52	89	f	f	f	f	t	f	f	\N
3886	58	89	t	f	f	f	f	f	f	\N
3922	6	90	t	t	t	f	f	f	f	\N
3936	20	90	f	f	f	f	f	f	f	\N
3919	3	90	t	t	t	f	f	f	f	\N
3924	8	90	f	f	f	f	f	f	f	\N
3837	9	89	t	t	t	t	f	f	f	0.6
3843	15	89	f	f	f	f	\N	f	f	\N
3844	16	89	f	f	f	f	\N	f	f	\N
3849	21	89	f	f	f	f	\N	f	f	\N
3938	22	90	t	t	t	t	t	f	f	11
3931	15	90	t	t	t	f	\N	f	f	\N
3921	5	90	t	f	f	f	f	f	f	\N
3918	2	90	t	f	f	f	f	f	f	\N
3928	12	90	f	f	f	f	t	f	f	\N
3934	18	90	f	f	f	f	f	f	f	\N
3925	9	90	t	t	t	t	t	f	f	0.1
3937	21	90	f	f	f	f	\N	f	f	\N
3930	14	90	t	t	t	t	f	f	f	0.4
3935	19	90	t	t	t	f	\N	f	f	\N
3917	1	90	t	f	f	f	f	f	f	\N
3933	17	90	t	f	f	f	f	f	f	\N
3929	13	90	f	f	f	f	\N	f	f	\N
3926	10	90	f	f	f	f	f	f	f	\N
3932	16	90	f	f	f	f	\N	f	f	\N
3927	11	90	f	f	f	f	t	f	f	\N
3992	76	90	t	t	t	t	\N	f	f	0.1
3942	26	90	t	t	t	f	f	f	f	\N
4017	12	91	t	t	t	t	f	f	f	0.1
4000	84	90	t	t	t	f	t	f	f	\N
3954	38	90	f	f	f	f	f	f	f	\N
4018	13	91	t	f	f	f	\N	f	f	\N
3970	54	90	t	f	f	f	f	f	f	\N
3952	36	90	t	t	t	f	f	f	f	\N
4012	7	91	f	f	f	f	f	f	f	\N
3965	49	90	f	f	f	f	f	f	f	\N
3974	58	90	t	f	f	f	f	f	f	\N
3988	72	90	f	f	f	f	t	f	f	\N
4019	14	91	t	f	f	f	f	f	f	\N
3997	81	90	t	t	t	f	f	f	f	\N
3981	65	90	t	t	t	t	f	f	f	0.8
3948	32	90	f	f	f	f	t	f	f	\N
4015	10	91	t	t	t	t	f	f	f	10.4
4016	11	91	f	f	f	f	f	f	f	\N
3951	35	90	t	f	f	f	f	f	f	\N
4021	16	91	t	f	f	f	\N	f	f	\N
3959	43	90	t	f	f	f	\N	f	f	\N
4009	4	91	t	t	t	t	f	f	f	4.1
4022	17	91	t	f	f	f	f	f	f	\N
4014	9	91	t	f	f	f	f	f	f	\N
3976	60	90	t	t	t	f	f	f	f	\N
3940	24	90	t	t	t	f	\N	f	f	\N
3977	61	90	f	f	f	f	f	f	f	\N
4001	85	90	t	f	f	f	f	f	f	\N
4010	5	91	t	t	t	t	f	f	f	6.4
3987	71	90	t	t	t	f	f	f	f	\N
3993	77	90	f	f	f	f	f	f	f	\N
4002	86	90	t	t	t	f	f	f	f	\N
3996	80	90	f	f	f	f	f	f	f	\N
4006	1	91	t	t	t	f	f	f	f	\N
4008	3	91	f	f	f	f	t	f	f	\N
3975	59	90	f	f	f	f	f	f	f	\N
3994	78	90	t	f	f	f	\N	f	f	\N
3960	44	90	f	f	f	f	f	f	f	\N
3967	51	90	f	f	f	f	f	f	f	\N
3945	29	90	f	f	f	f	\N	f	f	\N
3991	75	90	t	f	f	f	f	f	f	\N
3995	79	90	t	f	f	f	f	f	f	\N
3985	69	90	t	t	t	f	f	f	f	\N
3946	30	90	t	f	f	f	f	f	f	\N
3949	33	90	t	t	t	f	\N	f	f	\N
3966	50	90	f	f	f	f	f	f	f	\N
3979	63	90	f	f	f	f	t	f	f	\N
3963	47	90	t	f	f	f	f	f	f	\N
3978	62	90	f	f	f	f	\N	f	f	\N
3956	40	90	t	t	t	t	f	f	f	0.1
3998	82	90	t	t	t	f	f	f	f	\N
4007	2	91	t	t	t	t	t	f	f	2
4011	6	91	f	f	f	f	f	f	f	\N
3953	37	90	t	t	t	f	t	f	f	\N
3947	31	90	t	t	t	t	f	f	f	2.6
3958	42	90	t	t	t	t	t	f	f	0.6
4003	87	90	t	f	f	f	\N	f	f	\N
4004	88	90	f	f	f	f	\N	f	f	\N
3944	28	90	f	f	f	f	f	f	f	\N
3986	70	90	f	f	f	f	f	f	f	\N
3964	48	90	f	f	f	f	f	f	f	\N
3990	74	90	t	f	f	f	f	f	f	\N
3972	56	90	f	f	f	f	f	f	f	\N
3941	25	90	f	f	f	f	f	f	f	\N
3962	46	90	f	f	f	f	f	f	f	\N
4005	89	90	f	f	f	f	f	f	f	\N
3984	68	90	t	t	t	f	f	f	f	\N
3943	27	90	f	f	f	f	f	f	f	\N
3950	34	90	t	t	t	f	f	f	f	\N
3973	57	90	f	f	f	f	f	f	f	\N
3957	41	90	t	t	t	f	t	f	f	\N
3961	45	90	f	f	f	f	\N	f	f	\N
3968	52	90	t	f	f	f	f	f	f	\N
3969	53	90	f	f	f	f	f	f	f	\N
3971	55	90	t	f	f	f	f	f	f	\N
3980	64	90	t	t	t	f	t	f	f	\N
3982	66	90	f	f	f	f	f	f	f	\N
3989	73	90	t	t	t	f	\N	f	f	\N
3999	83	90	t	f	f	f	t	f	f	\N
3955	39	90	t	f	f	f	f	f	f	\N
3983	67	90	f	f	f	f	f	f	f	\N
4013	8	91	t	f	f	f	t	f	f	\N
4020	15	91	f	f	f	f	\N	f	f	\N
4023	18	91	t	f	f	f	f	f	f	\N
4035	30	91	t	t	t	f	t	f	f	\N
4067	62	91	f	f	f	f	\N	f	f	\N
4071	66	91	f	f	f	f	t	f	f	\N
4080	75	91	t	t	t	t	t	f	f	4.1
4074	69	91	t	t	t	t	f	f	f	1.8
4087	82	91	t	f	f	f	f	f	f	\N
4024	19	91	t	f	f	f	\N	f	f	\N
4034	29	91	f	f	f	f	\N	f	f	\N
4040	35	91	f	f	f	f	f	f	f	\N
4046	41	91	t	f	f	f	f	f	f	\N
4062	57	91	t	f	f	f	f	f	f	\N
4041	36	91	t	f	f	f	f	f	f	\N
4060	55	91	f	f	f	f	f	f	f	\N
4068	63	91	f	f	f	f	f	f	f	\N
4077	72	91	f	f	f	f	f	f	f	\N
4070	65	91	f	f	f	f	f	f	f	\N
4076	71	91	f	f	f	f	f	f	f	\N
4032	27	91	f	f	f	f	f	f	f	\N
4053	48	91	t	t	t	t	t	f	f	4.1
4061	56	91	f	f	f	f	f	f	f	\N
4027	22	91	f	f	f	f	f	f	f	\N
4029	24	91	f	f	f	f	\N	f	f	\N
4037	32	91	t	f	f	f	f	f	f	\N
4051	46	91	t	f	f	f	f	f	f	\N
4043	38	91	f	f	f	f	f	f	f	\N
4055	50	91	f	f	f	f	f	f	f	\N
4044	39	91	t	f	f	f	f	f	f	\N
4025	20	91	t	f	f	f	t	f	f	\N
4042	37	91	f	f	f	f	f	f	f	\N
4084	79	91	t	f	f	f	f	f	f	\N
4028	23	91	t	t	t	t	f	f	f	2
4048	43	91	t	t	t	t	\N	f	f	10.1
4054	49	91	f	f	f	f	f	f	f	\N
4058	53	91	f	f	f	f	f	f	f	\N
4033	28	91	t	f	f	f	f	f	f	\N
4065	60	91	t	f	f	f	f	f	f	\N
4072	67	91	f	f	f	f	f	f	f	\N
4083	78	91	f	f	f	f	\N	f	f	\N
4086	81	91	f	f	f	f	f	f	f	\N
4026	21	91	f	f	f	f	\N	f	f	\N
4036	31	91	f	f	f	f	f	f	f	\N
4039	34	91	f	f	f	f	f	f	f	\N
4049	44	91	f	f	f	f	f	f	f	\N
4059	54	91	t	t	t	f	f	f	f	\N
4082	77	91	f	f	f	f	f	f	f	\N
4063	58	91	t	f	f	f	f	f	f	\N
4081	76	91	f	f	f	f	\N	f	f	\N
4038	33	91	f	f	f	f	\N	f	f	\N
4047	42	91	t	f	f	f	f	f	f	\N
4057	52	91	f	f	f	f	f	f	f	\N
4073	68	91	t	f	f	f	f	f	f	\N
4075	70	91	f	f	f	f	f	f	f	\N
4052	47	91	t	t	t	t	f	f	f	6.1
4056	51	91	t	f	f	f	f	f	f	\N
4030	25	91	t	t	t	t	f	f	f	3
4031	26	91	f	f	f	f	f	f	f	\N
4050	45	91	f	f	f	f	\N	f	f	\N
4079	74	91	f	f	f	f	t	f	f	\N
4045	40	91	t	f	f	f	t	f	f	\N
4069	64	91	t	f	f	f	f	f	f	\N
4064	59	91	f	f	f	f	f	f	f	\N
4085	80	91	t	f	f	f	t	f	f	\N
4066	61	91	t	f	f	f	f	f	f	\N
4078	73	91	t	f	f	f	\N	f	f	\N
4088	83	91	f	f	f	f	f	f	f	\N
4089	84	91	t	f	f	f	f	f	f	\N
4095	90	91	f	f	f	f	f	f	f	\N
4092	87	91	f	f	f	f	\N	f	f	\N
4093	88	91	f	f	f	f	\N	f	f	\N
4090	85	91	f	f	f	f	f	f	f	\N
4094	89	91	f	f	f	f	f	f	f	\N
4096	1	92	t	f	f	f	f	f	f	\N
4091	86	91	t	f	f	f	f	f	f	\N
4098	3	92	f	f	f	f	f	f	f	\N
4117	22	92	f	f	f	f	f	f	f	\N
4105	10	92	t	t	t	t	f	f	f	11
4100	5	92	t	f	f	f	f	f	f	\N
4099	4	92	t	t	t	t	f	f	f	2.1
4109	14	92	t	f	f	f	f	f	f	\N
4115	20	92	t	f	f	f	f	f	f	\N
4116	21	92	f	f	f	f	\N	f	f	\N
4110	15	92	f	f	f	f	\N	f	f	\N
4114	19	92	t	f	f	f	\N	f	f	\N
4118	23	92	t	f	f	f	f	f	f	\N
4102	7	92	f	f	f	f	f	f	f	\N
4106	11	92	f	f	f	f	f	f	f	\N
4101	6	92	f	f	f	f	f	f	f	\N
4097	2	92	t	f	f	f	f	f	f	\N
4108	13	92	t	t	t	f	\N	f	f	\N
4121	26	92	f	f	f	f	t	f	f	\N
4104	9	92	t	f	f	f	f	f	f	\N
4120	25	92	t	f	f	f	t	f	f	\N
4122	27	92	f	f	f	f	f	f	f	\N
4107	12	92	t	f	f	f	f	f	f	\N
4113	18	92	t	t	f	f	f	f	f	\N
4103	8	92	t	f	f	f	f	f	f	\N
4111	16	92	t	f	f	f	\N	f	f	\N
4112	17	92	t	f	f	f	f	f	f	\N
4119	24	92	f	f	f	f	\N	f	f	\N
4176	81	92	f	f	f	f	f	f	f	\N
4145	50	92	f	f	f	f	f	f	f	\N
4150	55	92	f	f	f	f	t	f	f	\N
4151	56	92	f	f	f	f	t	f	f	\N
4161	66	92	f	f	f	f	f	f	f	\N
4159	64	92	t	t	t	t	f	f	f	1.1
4162	67	92	f	f	f	f	f	f	f	\N
4178	83	92	f	f	f	f	f	f	f	\N
4191	5	93	t	f	f	f	f	f	f	\N
4163	68	92	t	t	t	f	f	f	f	\N
4124	29	92	f	f	f	f	\N	f	f	\N
4181	86	92	t	t	t	t	f	f	f	2.1
4129	34	92	f	f	f	f	f	f	f	\N
4186	91	92	t	f	f	f	f	f	f	\N
4128	33	92	f	f	f	f	\N	f	f	\N
4154	59	92	f	f	f	f	t	f	f	\N
4169	74	92	f	f	f	f	f	f	f	\N
4125	30	92	t	f	f	f	f	f	f	\N
4138	43	92	t	f	f	f	\N	f	f	\N
4142	47	92	t	f	f	f	f	f	f	\N
4156	61	92	t	t	t	f	f	f	f	\N
4143	48	92	t	f	f	f	f	f	f	\N
4144	49	92	f	f	f	f	f	f	f	\N
4158	63	92	f	f	f	f	f	f	f	\N
4123	28	92	t	f	f	f	t	f	f	\N
4131	36	92	t	f	f	f	f	f	f	\N
4127	32	92	t	f	f	f	f	f	f	\N
4170	75	92	t	f	f	f	f	f	f	\N
4179	84	92	t	f	f	f	f	f	f	\N
4183	88	92	f	f	f	f	\N	f	f	\N
4166	71	92	f	f	f	f	f	f	f	\N
4167	72	92	f	f	f	f	f	f	f	\N
4192	6	93	t	f	f	f	f	f	f	\N
4177	82	92	t	f	f	f	f	f	f	\N
4185	90	92	f	f	f	f	f	f	f	\N
4152	57	92	t	f	f	f	t	f	f	\N
4141	46	92	t	t	t	f	f	f	f	\N
4168	73	92	t	f	f	f	\N	f	f	\N
4182	87	92	f	f	f	f	\N	f	f	\N
4133	38	92	f	f	f	f	t	f	f	\N
4148	53	92	f	f	f	f	f	f	f	\N
4136	41	92	t	f	f	f	f	f	f	\N
4174	79	92	t	f	f	f	f	f	f	\N
4180	85	92	f	f	f	f	t	f	f	\N
4126	31	92	f	f	f	f	t	f	f	\N
4153	58	92	t	f	f	f	f	f	f	\N
4157	62	92	f	f	f	f	\N	f	f	\N
4137	42	92	t	t	f	f	f	f	f	\N
4140	45	92	f	f	f	f	\N	f	f	\N
4147	52	92	f	f	f	f	f	f	f	\N
4160	65	92	f	f	f	f	t	f	f	\N
4171	76	92	f	f	f	f	\N	f	f	\N
4190	4	93	f	f	f	f	f	f	f	\N
4175	80	92	t	f	f	f	f	f	f	\N
4184	89	92	f	f	f	f	f	f	f	\N
4130	35	92	f	f	f	f	t	f	f	\N
4196	10	93	f	f	f	f	f	f	f	\N
4134	39	92	t	f	f	f	t	f	f	\N
4135	40	92	t	f	f	f	f	f	f	\N
4146	51	92	t	t	t	t	f	f	f	2.1
4165	70	92	f	f	f	f	t	f	f	\N
4172	77	92	f	f	f	f	t	f	f	\N
4173	78	92	f	f	f	f	\N	f	f	\N
4132	37	92	f	f	f	f	f	f	f	\N
4139	44	92	f	f	f	f	f	f	f	\N
4149	54	92	t	f	f	f	f	f	f	\N
4188	2	93	t	f	f	f	f	f	f	\N
4155	60	92	t	f	f	f	f	f	f	\N
4199	13	93	f	f	f	f	\N	f	f	\N
4189	3	93	t	t	t	t	f	f	f	4.8
4164	69	92	t	t	f	f	f	f	f	\N
4203	17	93	t	f	f	f	t	f	f	\N
4204	18	93	f	f	f	f	t	f	f	\N
4194	8	93	f	f	f	f	f	f	f	\N
4187	1	93	t	f	f	f	f	f	f	\N
4202	16	93	f	f	f	f	\N	f	f	\N
4195	9	93	t	t	t	t	f	f	f	2.1
4201	15	93	t	t	t	t	\N	f	f	1.1
4200	14	93	t	t	f	f	t	f	f	\N
4197	11	93	f	f	f	f	f	f	f	\N
4193	7	93	t	f	f	f	t	f	f	\N
4198	12	93	f	f	f	f	f	f	f	\N
4260	74	93	t	f	f	f	f	f	f	\N
4210	24	93	t	t	t	t	\N	f	f	1.1
4215	29	93	f	f	f	f	\N	f	f	\N
4224	38	93	f	f	f	f	f	f	f	\N
4229	43	93	t	f	f	f	\N	f	f	\N
4247	61	93	f	f	f	f	f	f	f	\N
4264	78	93	t	f	f	f	\N	f	f	\N
4209	23	93	f	f	f	f	f	f	f	\N
4218	32	93	f	f	f	f	f	f	f	\N
4243	57	93	f	f	f	f	f	f	f	\N
4255	69	93	t	f	f	f	f	f	f	\N
4259	73	93	t	t	t	t	\N	f	f	5
4220	34	93	t	f	f	f	f	f	f	\N
4222	36	93	t	t	t	t	t	f	f	10.4
4228	42	93	t	f	f	f	f	f	f	\N
4236	50	93	f	f	f	f	f	f	f	\N
4206	20	93	f	f	f	f	f	f	f	\N
4240	54	93	t	f	f	f	t	f	f	\N
4242	56	93	f	f	f	f	f	f	f	\N
4211	25	93	f	f	f	f	f	f	f	\N
4238	52	93	t	f	f	f	f	f	f	\N
4244	58	93	t	f	f	f	t	f	f	\N
4261	75	93	t	f	f	f	f	f	f	\N
4219	33	93	t	f	f	f	\N	f	f	\N
4233	47	93	t	f	f	f	t	f	f	\N
4251	65	93	t	f	f	f	f	f	f	\N
4266	80	93	f	f	f	f	f	f	f	\N
4213	27	93	f	f	f	f	t	f	f	\N
4230	44	93	f	f	f	f	f	f	f	\N
4237	51	93	f	f	f	f	f	f	f	\N
4205	19	93	t	t	f	f	\N	f	f	\N
4241	55	93	t	f	f	f	f	f	f	\N
4208	22	93	t	f	f	f	f	f	f	\N
4214	28	93	f	f	f	f	f	f	f	\N
4235	49	93	f	f	f	f	f	f	f	\N
4246	60	93	t	t	t	t	f	f	f	10.6
4253	67	93	f	f	f	f	t	f	f	\N
4239	53	93	f	f	f	f	f	f	f	\N
4257	71	93	t	f	f	f	f	f	f	\N
4248	62	93	f	f	f	f	\N	f	f	\N
4212	26	93	t	f	f	f	f	f	f	\N
4250	64	93	t	f	f	f	f	f	f	\N
4217	31	93	t	t	t	f	f	f	f	\N
4262	76	93	t	f	f	f	\N	f	f	\N
4223	37	93	t	f	f	f	f	f	f	\N
4234	48	93	f	f	f	f	f	f	f	\N
4207	21	93	f	f	f	f	\N	f	f	\N
4216	30	93	t	f	f	f	f	f	f	\N
4245	59	93	f	f	f	f	f	f	f	\N
4252	66	93	f	f	f	f	f	f	f	\N
4226	40	93	t	t	f	f	f	f	f	\N
4254	68	93	t	f	f	f	f	f	f	\N
4265	79	93	t	f	f	f	f	f	f	\N
4227	41	93	t	t	t	t	f	f	f	10.1
4249	63	93	f	f	f	f	f	f	f	\N
4256	70	93	f	f	f	f	f	f	f	\N
4263	77	93	f	f	f	f	f	f	f	\N
4231	45	93	f	f	f	f	\N	f	f	\N
4221	35	93	t	f	f	f	f	f	f	\N
4258	72	93	f	f	f	f	f	f	f	\N
4225	39	93	t	f	f	f	f	f	f	\N
4232	46	93	f	f	f	f	f	f	f	\N
4277	91	93	f	f	f	f	f	f	f	\N
4273	87	93	t	f	f	f	\N	f	f	\N
4274	88	93	f	f	f	f	\N	f	f	\N
4271	85	93	t	f	f	f	f	f	f	\N
4270	84	93	t	t	t	t	f	f	f	11
4275	89	93	f	f	f	f	f	f	f	\N
4267	81	93	t	t	f	f	f	f	f	\N
4269	83	93	t	f	f	f	f	f	f	\N
4272	86	93	t	f	f	f	f	f	f	\N
4268	82	93	t	t	f	f	t	f	f	\N
4278	92	93	f	f	f	f	f	f	f	\N
4276	90	93	t	t	t	f	f	f	f	\N
4293	15	94	f	f	f	f	\N	f	f	\N
4282	4	94	t	t	f	f	t	f	f	\N
4308	30	94	t	f	f	f	f	f	f	\N
4301	23	94	t	f	f	f	f	f	f	\N
4304	26	94	f	f	f	f	f	f	f	\N
4298	20	94	t	t	t	f	f	f	f	\N
4290	12	94	t	f	f	f	f	f	f	\N
4291	13	94	t	t	t	t	\N	f	f	10.2
4297	19	94	t	t	f	f	\N	f	f	\N
4307	29	94	f	f	f	f	\N	f	f	\N
4279	1	94	t	f	f	f	t	f	f	\N
4281	3	94	f	f	f	f	f	f	f	\N
4294	16	94	t	t	t	f	\N	f	f	\N
4296	18	94	t	t	t	f	f	f	f	\N
4300	22	94	f	f	f	f	f	f	f	\N
4306	28	94	t	f	f	f	f	f	f	\N
4284	6	94	f	f	f	f	t	f	f	\N
4289	11	94	f	f	f	f	f	f	f	\N
4288	10	94	t	t	t	f	t	f	f	\N
4302	24	94	f	f	f	f	\N	f	f	\N
4305	27	94	f	f	f	f	f	f	f	\N
4280	2	94	t	f	f	f	f	f	f	\N
4286	8	94	t	t	t	f	f	f	f	\N
4287	9	94	t	t	t	f	f	f	f	\N
4303	25	94	t	f	f	f	f	f	f	\N
4292	14	94	t	t	f	f	f	f	f	\N
4295	17	94	t	f	f	f	f	f	f	\N
4299	21	94	f	f	f	f	\N	f	f	\N
4283	5	94	t	f	f	f	t	f	f	\N
4285	7	94	f	f	f	f	f	f	f	\N
4340	62	94	f	f	f	f	\N	f	f	\N
4371	93	94	f	f	f	f	f	f	f	\N
4316	38	94	f	f	f	f	f	f	f	\N
4339	61	94	t	t	f	f	t	f	f	\N
4313	35	94	f	f	f	f	f	f	f	\N
4322	44	94	f	f	f	f	t	f	f	\N
4336	58	94	t	f	f	f	f	f	f	\N
4352	74	94	f	f	f	f	f	f	f	\N
4309	31	94	f	f	f	f	f	f	f	\N
4328	50	94	f	f	f	f	t	f	f	\N
4346	68	94	t	t	t	t	t	f	f	10.1
4318	40	94	t	t	f	f	f	f	f	\N
4332	54	94	t	f	f	f	f	f	f	\N
4348	70	94	f	f	f	f	f	f	f	\N
4366	88	94	f	f	f	f	\N	f	f	\N
4351	73	94	t	t	t	f	\N	f	f	\N
4354	76	94	f	f	f	f	\N	f	f	\N
4367	89	94	f	f	f	f	t	f	f	\N
4344	66	94	f	f	f	f	f	f	f	\N
4334	56	94	f	f	f	f	f	f	f	\N
4356	78	94	f	f	f	f	\N	f	f	\N
4329	51	94	t	t	t	t	t	f	f	4.4
4363	85	94	f	f	f	f	f	f	f	\N
4335	57	94	t	f	f	f	f	f	f	\N
4315	37	94	f	f	f	f	f	f	f	\N
4325	47	94	t	f	f	f	f	f	f	\N
4330	52	94	f	f	f	f	t	f	f	\N
4333	55	94	f	f	f	f	f	f	f	\N
4337	59	94	f	f	f	f	f	f	f	\N
4361	83	94	f	f	f	f	f	f	f	\N
4342	64	94	t	t	t	t	f	f	f	8.6
4364	86	94	t	t	f	f	t	f	f	\N
4317	39	94	t	f	f	f	f	f	f	\N
4359	81	94	f	f	f	f	t	f	f	\N
4319	41	94	t	t	t	f	f	f	f	\N
4323	45	94	f	f	f	f	\N	f	f	\N
4338	60	94	t	t	t	f	t	f	f	\N
4321	43	94	t	f	f	f	\N	f	f	\N
4350	72	94	f	f	f	f	f	f	f	\N
4370	92	94	t	f	f	f	f	f	f	\N
4358	80	94	t	f	f	f	f	f	f	\N
4347	69	94	t	t	t	t	t	f	f	10.1
4331	53	94	f	f	f	f	t	f	f	\N
4341	63	94	f	f	f	f	f	f	f	\N
4353	75	94	t	f	f	f	f	f	f	\N
4360	82	94	t	t	t	t	f	f	f	10.1
4312	34	94	f	f	f	f	t	f	f	\N
4362	84	94	t	t	t	f	f	f	f	\N
4368	90	94	f	f	f	f	f	f	f	\N
4327	49	94	f	f	f	f	t	f	f	\N
4369	91	94	t	f	f	f	f	f	f	\N
4343	65	94	f	f	f	f	f	f	f	\N
4326	48	94	t	f	f	f	f	f	f	\N
4355	77	94	f	f	f	f	f	f	f	\N
4357	79	94	t	f	f	f	t	f	f	\N
4314	36	94	t	t	t	f	f	f	f	\N
4345	67	94	f	f	f	f	f	f	f	\N
4349	71	94	f	f	f	f	t	f	f	\N
4365	87	94	f	f	f	f	\N	f	f	\N
4310	32	94	t	t	t	f	f	f	f	\N
4311	33	94	f	f	f	f	\N	f	f	\N
4320	42	94	t	t	t	f	f	f	f	\N
4324	46	94	t	t	t	f	t	f	f	\N
4374	3	95	f	f	f	f	f	f	f	\N
4372	1	95	t	t	t	t	f	f	f	1
4376	5	95	t	t	t	t	f	f	f	0.1
4377	6	95	f	f	f	f	f	f	f	\N
4373	2	95	t	t	t	f	f	f	f	\N
4375	4	95	t	t	t	f	f	f	f	\N
4378	7	95	f	f	f	f	f	f	f	\N
4466	1	96	t	t	t	t	f	f	f	0.1
4480	15	96	f	f	f	f	\N	f	f	\N
4396	25	95	t	t	t	f	f	f	f	\N
4472	7	96	f	f	f	f	f	f	f	\N
4447	76	95	f	f	f	f	\N	f	f	\N
4423	52	95	f	f	f	f	f	f	f	\N
4390	19	95	t	t	t	f	\N	f	f	\N
4448	77	95	f	f	f	f	f	f	f	\N
4477	12	96	f	f	f	f	t	f	f	\N
4406	35	95	f	f	f	f	f	f	f	\N
4389	18	95	t	f	f	f	f	f	f	\N
4484	19	96	t	f	f	f	\N	f	f	\N
4426	55	95	f	f	f	f	f	f	f	\N
4427	56	95	f	f	f	f	f	f	f	\N
4449	78	95	f	f	f	f	\N	f	f	\N
4460	89	95	f	f	f	f	f	f	f	\N
4434	63	95	f	f	f	f	t	f	f	\N
4422	51	95	t	f	f	f	f	f	f	\N
4430	59	95	f	f	f	f	f	f	f	\N
4424	53	95	f	f	f	f	f	f	f	\N
4436	65	95	f	f	f	f	f	f	f	\N
4456	85	95	f	f	f	f	f	f	f	\N
4438	67	95	f	f	f	f	f	f	f	\N
4482	17	96	t	f	f	f	f	f	f	\N
4385	14	95	t	f	f	f	f	f	f	\N
4440	69	95	t	t	f	f	f	f	f	\N
4409	38	95	f	f	f	f	f	f	f	\N
4485	20	96	f	f	f	f	f	f	f	\N
4459	88	95	f	f	f	f	\N	f	f	\N
4441	70	95	f	f	f	f	f	f	f	\N
4443	72	95	f	f	f	f	t	f	f	\N
4473	8	96	f	f	f	f	f	f	f	\N
4379	8	95	t	t	t	f	f	f	f	\N
4425	54	95	t	t	t	f	f	f	f	\N
4410	39	95	t	t	f	f	f	f	f	\N
4432	61	95	t	f	f	f	f	f	f	\N
4413	42	95	t	f	f	f	t	f	f	\N
4401	30	95	t	t	t	t	f	f	f	0.1
4457	86	95	t	f	f	f	f	f	f	\N
4461	90	95	f	f	f	f	t	f	f	\N
4414	43	95	t	t	f	f	\N	f	f	\N
4386	15	95	f	f	f	f	\N	f	f	\N
4400	29	95	f	f	f	f	\N	f	f	\N
4408	37	95	f	f	f	f	t	f	f	\N
4429	58	95	t	t	t	f	f	f	f	\N
4445	74	95	f	f	f	f	f	f	f	\N
4454	83	95	f	f	f	f	t	f	f	\N
4420	49	95	f	f	f	f	f	f	f	\N
4446	75	95	t	t	t	f	f	f	f	\N
4416	45	95	f	f	f	f	\N	f	f	\N
4465	94	95	t	t	f	f	f	f	f	\N
4383	12	95	t	t	t	t	t	f	f	1
4453	82	95	t	t	t	f	f	f	f	\N
4431	60	95	t	f	f	f	f	f	f	\N
4442	71	95	f	f	f	f	f	f	f	\N
4428	57	95	t	t	t	f	f	f	f	\N
4437	66	95	f	f	f	f	f	f	f	\N
4463	92	95	t	t	t	f	f	f	f	\N
4450	79	95	t	t	t	f	f	f	f	\N
4458	87	95	f	f	f	f	\N	f	f	\N
4382	11	95	f	f	f	f	t	f	f	\N
4387	16	95	t	t	f	f	\N	f	f	\N
4451	80	95	t	t	t	f	f	f	f	\N
4384	13	95	t	f	f	f	\N	f	f	\N
4417	46	95	t	f	f	f	f	f	f	\N
4407	36	95	t	f	f	f	f	f	f	\N
4433	62	95	f	f	f	f	\N	f	f	\N
4411	40	95	t	f	f	f	f	f	f	\N
4452	81	95	f	f	f	f	f	f	f	\N
4393	22	95	f	f	f	f	t	f	f	\N
4397	26	95	f	f	f	f	f	f	f	\N
4404	33	95	f	f	f	f	\N	f	f	\N
4462	91	95	t	t	t	f	f	f	f	\N
4395	24	95	f	f	f	f	\N	f	f	\N
4398	27	95	f	f	f	f	f	f	f	\N
4474	9	96	t	f	f	f	t	f	f	\N
4419	48	95	t	t	t	f	f	f	f	\N
4399	28	95	t	t	f	f	f	f	f	\N
4421	50	95	f	f	f	f	f	f	f	\N
4455	84	95	t	t	f	f	t	f	f	\N
4439	68	95	t	f	f	f	f	f	f	\N
4435	64	95	t	f	f	f	t	f	f	\N
4467	2	96	t	t	t	f	f	f	f	\N
4381	10	95	t	t	t	f	f	f	f	\N
4402	31	95	f	f	f	f	f	f	f	\N
4444	73	95	t	f	f	f	\N	f	f	\N
4412	41	95	t	f	f	f	t	f	f	\N
4415	44	95	f	f	f	f	f	f	f	\N
4481	16	96	f	f	f	f	\N	f	f	\N
4391	20	95	t	f	f	f	f	f	f	\N
4380	9	95	t	t	t	t	t	f	f	0.1
4418	47	95	t	t	t	f	f	f	f	\N
4392	21	95	f	f	f	f	\N	f	f	\N
4483	18	96	f	f	f	f	f	f	f	\N
4403	32	95	t	f	f	f	t	f	f	\N
4388	17	95	t	t	t	f	f	f	f	\N
4405	34	95	f	f	f	f	f	f	f	\N
4464	93	95	f	f	f	f	f	f	f	\N
4394	23	95	t	t	f	f	t	f	f	\N
4471	6	96	f	f	f	f	f	f	f	\N
4476	11	96	f	f	f	f	t	f	f	\N
4469	4	96	f	f	f	f	f	f	f	\N
4478	13	96	f	f	f	f	\N	f	f	\N
4475	10	96	f	f	f	f	f	f	f	\N
4479	14	96	t	f	f	f	f	f	f	\N
4468	3	96	f	f	f	f	f	f	f	\N
4470	5	96	t	t	t	t	f	f	f	0.8
4494	29	96	f	f	f	f	\N	f	f	\N
4528	63	96	f	f	f	f	t	f	f	\N
4539	74	96	f	f	f	f	f	f	f	\N
4493	28	96	f	f	f	f	f	f	f	\N
4510	45	96	f	f	f	f	\N	f	f	\N
4521	56	96	f	f	f	f	f	f	f	\N
4529	64	96	t	f	f	f	t	f	f	\N
4534	69	96	t	t	f	f	f	f	f	\N
4536	71	96	f	f	f	f	f	f	f	\N
4509	44	96	f	f	f	f	f	f	f	\N
4545	80	96	f	f	f	f	f	f	f	\N
4548	83	96	f	f	f	f	t	f	f	\N
4522	57	96	f	f	f	f	f	f	f	\N
4523	58	96	t	f	f	f	f	f	f	\N
4524	59	96	f	f	f	f	f	f	f	\N
4487	22	96	f	f	f	f	t	f	f	\N
4497	32	96	f	f	f	f	t	f	f	\N
4515	50	96	f	f	f	f	f	f	f	\N
4518	53	96	f	f	f	f	f	f	f	\N
4544	79	96	t	f	f	f	f	f	f	\N
4532	67	96	f	f	f	f	f	f	f	\N
4506	41	96	t	f	f	f	t	f	f	\N
4508	43	96	t	t	f	f	\N	f	f	\N
4519	54	96	t	t	t	f	f	f	f	\N
4486	21	96	f	f	f	f	\N	f	f	\N
4491	26	96	f	f	f	f	f	f	f	\N
4495	30	96	t	t	t	t	f	f	f	0.2
4525	60	96	t	f	f	f	f	f	f	\N
4537	72	96	f	f	f	f	t	f	f	\N
4507	42	96	t	f	f	f	t	f	f	\N
4505	40	96	t	f	f	f	f	f	f	\N
4513	48	96	f	f	f	f	f	f	f	\N
4516	51	96	f	f	f	f	f	f	f	\N
4520	55	96	f	f	f	f	f	f	f	\N
4526	61	96	f	f	f	f	f	f	f	\N
4501	36	96	t	f	f	f	f	f	f	\N
4502	37	96	f	f	f	f	t	f	f	\N
4530	65	96	f	f	f	f	f	f	f	\N
4533	68	96	t	f	f	f	f	f	f	\N
4543	78	96	f	f	f	f	\N	f	f	\N
4499	34	96	f	f	f	f	f	f	f	\N
4503	38	96	f	f	f	f	f	f	f	\N
4540	75	96	t	t	t	f	f	f	f	\N
4541	76	96	f	f	f	f	\N	f	f	\N
4488	23	96	f	f	f	f	t	f	f	\N
4489	24	96	f	f	f	f	\N	f	f	\N
4512	47	96	t	t	t	f	f	f	f	\N
4527	62	96	f	f	f	f	\N	f	f	\N
4535	70	96	f	f	f	f	f	f	f	\N
4542	77	96	f	f	f	f	f	f	f	\N
4490	25	96	f	f	f	f	f	f	f	\N
4496	31	96	f	f	f	f	f	f	f	\N
4500	35	96	f	f	f	f	f	f	f	\N
4504	39	96	t	f	f	f	f	f	f	\N
4547	82	96	t	f	f	f	f	f	f	\N
4538	73	96	t	f	f	f	\N	f	f	\N
4514	49	96	f	f	f	f	f	f	f	\N
4517	52	96	f	f	f	f	f	f	f	\N
4531	66	96	f	f	f	f	f	f	f	\N
4498	33	96	f	f	f	f	\N	f	f	\N
4546	81	96	f	f	f	f	f	f	f	\N
4492	27	96	f	f	f	f	f	f	f	\N
4511	46	96	f	f	f	f	f	f	f	\N
4554	89	96	f	f	f	f	f	f	f	\N
4555	90	96	f	f	f	f	t	f	f	\N
4557	92	96	f	f	f	f	f	f	f	\N
4552	87	96	f	f	f	f	\N	f	f	\N
4567	7	97	f	f	f	f	t	f	f	\N
4551	86	96	t	f	f	f	f	f	f	\N
4559	94	96	f	f	f	f	f	f	f	\N
4556	91	96	f	f	f	f	f	f	f	\N
4560	95	96	f	f	f	f	t	f	f	\N
4553	88	96	f	f	f	f	\N	f	f	\N
4566	6	97	f	f	f	f	f	f	f	\N
4549	84	96	t	f	f	f	t	f	f	\N
4550	85	96	f	f	f	f	f	f	f	\N
4558	93	96	f	f	f	f	f	f	f	\N
4564	4	97	t	t	t	t	f	f	f	10.4
4571	11	97	f	f	f	f	f	f	f	\N
4562	2	97	t	t	t	t	f	f	f	6.1
4572	12	97	t	t	t	f	f	f	f	\N
4574	14	97	t	f	f	f	t	f	f	\N
4565	5	97	t	t	t	f	f	f	f	\N
4569	9	97	t	t	t	f	f	f	f	\N
4573	13	97	t	f	f	f	\N	f	f	\N
4561	1	97	t	t	t	f	f	f	f	\N
4563	3	97	f	f	f	f	f	f	f	\N
4568	8	97	t	t	t	t	f	f	f	1.2
4570	10	97	t	t	t	t	f	f	f	1.1
4647	87	97	f	f	f	f	\N	f	f	\N
4655	95	97	t	t	t	f	f	f	f	\N
4629	69	97	t	t	t	t	f	f	f	6.1
4614	54	97	t	t	t	t	t	f	f	7
4619	59	97	f	f	f	f	f	f	f	\N
4622	62	97	f	f	f	f	\N	f	f	\N
4620	60	97	t	f	f	f	f	f	f	\N
4575	15	97	f	f	f	f	\N	f	f	\N
4628	68	97	t	f	f	f	f	f	f	\N
4587	27	97	f	f	f	f	t	f	f	\N
4597	37	97	f	f	f	f	f	f	f	\N
4635	75	97	t	t	t	t	f	f	f	11
4606	46	97	t	f	f	f	f	f	f	\N
4609	49	97	f	f	f	f	f	f	f	\N
4612	52	97	f	f	f	f	f	f	f	\N
4613	53	97	f	f	f	f	f	f	f	\N
4649	89	97	f	f	f	f	f	f	f	\N
4632	72	97	f	f	f	f	f	f	f	\N
4642	82	97	t	t	t	t	t	f	f	6.1
4607	47	97	t	t	t	t	t	f	f	8.2
4643	83	97	f	f	f	f	f	f	f	\N
4621	61	97	t	f	f	f	f	f	f	\N
4588	28	97	t	t	t	t	f	f	f	4.1
4623	63	97	f	f	f	f	f	f	f	\N
4599	39	97	t	t	t	f	f	f	f	\N
4648	88	97	f	f	f	f	\N	f	f	\N
4590	30	97	t	t	t	f	f	f	f	\N
4594	34	97	f	f	f	f	f	f	f	\N
4650	90	97	f	f	f	f	f	f	f	\N
4604	44	97	f	f	f	f	f	f	f	\N
4634	74	97	f	f	f	f	f	f	f	\N
4645	85	97	f	f	f	f	f	f	f	\N
4592	32	97	t	f	f	f	f	f	f	\N
4601	41	97	t	f	f	f	f	f	f	\N
4615	55	97	f	f	f	f	f	f	f	\N
4602	42	97	t	f	f	f	f	f	f	\N
4654	94	97	t	t	t	t	f	f	f	4.8
4624	64	97	t	f	f	f	f	f	f	\N
4584	24	97	f	f	f	f	\N	f	f	\N
4652	92	97	t	t	t	t	f	f	f	1.1
4603	43	97	t	t	t	t	\N	f	f	1.2
4608	48	97	t	t	t	t	f	f	f	10.6
4611	51	97	t	f	f	f	f	f	f	\N
4626	66	97	f	f	f	f	f	f	f	\N
4618	58	97	t	t	t	t	t	f	f	1.1
4598	38	97	f	f	f	f	f	f	f	\N
4639	79	97	t	t	t	t	f	f	f	10.1
4581	21	97	f	f	f	f	\N	f	f	\N
4605	45	97	f	f	f	f	\N	f	f	\N
4631	71	97	f	f	f	f	f	f	f	\N
4577	17	97	t	t	t	t	t	f	f	6.1
4591	31	97	f	f	f	f	f	f	f	\N
4585	25	97	t	t	t	t	f	f	f	10.1
4637	77	97	f	f	f	f	f	f	f	\N
4653	93	97	f	f	f	f	t	f	f	\N
4658	2	98	t	f	f	f	t	f	f	\N
4576	16	97	t	t	t	t	\N	f	f	4.1
4640	80	97	t	t	t	t	f	f	f	6.1
4617	57	97	t	t	t	t	f	f	f	10.1
4625	65	97	f	f	f	f	f	f	f	\N
4630	70	97	f	f	f	f	f	f	f	\N
4636	76	97	f	f	f	f	\N	f	f	\N
4586	26	97	f	f	f	f	f	f	f	\N
4593	33	97	f	f	f	f	\N	f	f	\N
4616	56	97	f	f	f	f	f	f	f	\N
4663	7	98	f	f	f	f	f	f	f	\N
4662	6	98	f	f	f	f	f	f	f	\N
4583	23	97	t	t	t	f	f	f	f	\N
4627	67	97	f	f	f	f	t	f	f	\N
4644	84	97	t	t	t	t	f	f	f	2
4633	73	97	t	f	f	f	\N	f	f	\N
4667	11	98	f	f	f	f	f	f	f	\N
4580	20	97	t	f	f	f	f	f	f	\N
4651	91	97	t	t	t	t	f	f	f	1.1
4656	96	97	f	f	f	f	f	f	f	\N
4589	29	97	f	f	f	f	\N	f	f	\N
4595	35	97	f	f	f	f	f	f	f	\N
4582	22	97	f	f	f	f	f	f	f	\N
4596	36	97	t	f	f	f	t	f	f	\N
4610	50	97	f	f	f	f	f	f	f	\N
4641	81	97	f	f	f	f	f	f	f	\N
4600	40	97	t	f	f	f	f	f	f	\N
4638	78	97	f	f	f	f	\N	f	f	\N
4578	18	97	t	f	f	f	t	f	f	\N
4665	9	98	t	t	t	t	f	f	f	7
4657	1	98	t	f	f	f	f	f	f	\N
4671	15	98	f	f	f	f	\N	f	f	\N
4579	19	97	t	t	t	t	\N	f	f	10.4
4646	86	97	t	f	f	f	f	f	f	\N
4661	5	98	t	f	f	f	f	f	f	\N
4672	16	98	t	t	t	t	\N	f	f	4.1
4670	14	98	t	f	f	f	f	f	f	\N
4659	3	98	f	f	f	f	t	f	f	\N
4668	12	98	t	f	f	f	f	f	f	\N
4664	8	98	t	t	t	t	t	f	f	9
4666	10	98	t	f	f	f	f	f	f	\N
4660	4	98	t	f	f	f	f	f	f	\N
4669	13	98	t	f	f	f	\N	f	f	\N
4679	23	98	t	f	f	f	f	f	f	\N
4705	49	98	f	f	f	f	f	f	f	\N
4706	50	98	f	f	f	f	f	f	f	\N
4707	51	98	t	f	f	f	f	f	f	\N
4721	65	98	f	f	f	f	f	f	f	\N
4723	67	98	f	f	f	f	f	f	f	\N
4696	40	98	t	f	f	f	t	f	f	\N
4681	25	98	t	f	f	f	f	f	f	\N
4684	28	98	t	t	t	f	f	f	f	\N
4676	20	98	t	f	f	f	t	f	f	\N
4683	27	98	f	f	f	f	f	f	f	\N
4722	66	98	f	f	f	f	t	f	f	\N
4701	45	98	f	f	f	f	\N	f	f	\N
4714	58	98	t	t	t	t	f	f	f	8.1
4715	59	98	f	f	f	f	f	f	f	\N
4724	68	98	t	f	f	f	f	f	f	\N
4674	18	98	t	f	f	f	f	f	f	\N
4682	26	98	f	f	f	f	f	f	f	\N
4717	61	98	t	f	f	f	f	f	f	\N
4699	43	98	t	f	f	f	\N	f	f	\N
4716	60	98	t	f	f	f	f	f	f	\N
4726	70	98	f	f	f	f	f	f	f	\N
4677	21	98	f	f	f	f	\N	f	f	\N
4685	29	98	f	f	f	f	\N	f	f	\N
4686	30	98	t	f	f	f	t	f	f	\N
4720	64	98	t	f	f	f	f	f	f	\N
4689	33	98	f	f	f	f	\N	f	f	\N
4697	41	98	t	f	f	f	f	f	f	\N
4702	46	98	t	f	f	f	f	f	f	\N
4695	39	98	t	t	t	t	f	f	f	2
4704	48	98	t	f	f	f	t	f	f	\N
4708	52	98	f	f	f	f	f	f	f	\N
4725	69	98	t	f	f	f	f	f	f	\N
4673	17	98	t	t	t	t	f	f	f	3
4680	24	98	f	f	f	f	\N	f	f	\N
4711	55	98	f	f	f	f	f	f	f	\N
4727	71	98	f	f	f	f	f	f	f	\N
4694	38	98	f	f	f	f	f	f	f	\N
4703	47	98	t	f	f	f	f	f	f	\N
4709	53	98	f	f	f	f	f	f	f	\N
4712	56	98	f	f	f	f	f	f	f	\N
4688	32	98	t	f	f	f	f	f	f	\N
4710	54	98	t	f	f	f	f	f	f	\N
4718	62	98	f	f	f	f	\N	f	f	\N
4692	36	98	t	f	f	f	f	f	f	\N
4700	44	98	f	f	f	f	f	f	f	\N
4698	42	98	t	f	f	f	f	f	f	\N
4690	34	98	f	f	f	f	f	f	f	\N
4691	35	98	f	f	f	f	f	f	f	\N
4678	22	98	f	f	f	f	f	f	f	\N
4687	31	98	f	f	f	f	f	f	f	\N
4693	37	98	f	f	f	f	f	f	f	\N
4713	57	98	t	t	t	f	f	f	f	\N
4719	63	98	f	f	f	f	f	f	f	\N
4675	19	98	t	t	t	f	\N	f	f	\N
4800	47	99	t	f	f	f	t	f	f	\N
4753	97	98	t	f	f	f	f	f	f	\N
4783	30	99	t	f	f	f	f	f	f	\N
4786	33	99	t	t	t	t	\N	f	f	10.2
4738	82	98	t	t	t	f	f	f	f	\N
4745	89	98	f	f	f	f	f	f	f	\N
4728	72	98	f	f	f	f	f	f	f	\N
4737	81	98	f	f	f	f	f	f	f	\N
4733	77	98	f	f	f	f	f	f	f	\N
4734	78	98	f	f	f	f	\N	f	f	\N
4749	93	98	f	f	f	f	f	f	f	\N
4744	88	98	f	f	f	f	\N	f	f	\N
4801	48	99	t	f	f	f	f	f	f	\N
4729	73	98	t	f	f	f	\N	f	f	\N
4731	75	98	t	f	f	f	t	f	f	\N
4785	32	99	t	f	f	f	f	f	f	\N
4747	91	98	t	f	f	f	t	f	f	\N
4739	83	98	f	f	f	f	f	f	f	\N
4762	9	99	t	f	f	f	f	f	f	\N
4748	92	98	t	t	t	t	f	f	f	8.4
4752	96	98	f	f	f	f	f	f	f	\N
4787	34	99	t	t	t	t	f	f	f	4.1
4767	14	99	t	f	f	f	t	f	f	\N
4736	80	98	t	t	t	f	t	f	f	\N
4741	85	98	f	f	f	f	f	f	f	\N
4732	76	98	f	f	f	f	\N	f	f	\N
4770	17	99	t	f	f	f	t	f	f	\N
4792	39	99	t	f	f	f	f	f	f	\N
4735	79	98	t	t	t	f	f	f	f	\N
4751	95	98	t	f	f	f	f	f	f	\N
4730	74	98	f	f	f	f	t	f	f	\N
4777	24	99	t	f	f	f	\N	f	f	\N
4742	86	98	t	f	f	f	f	f	f	\N
4780	27	99	t	f	f	f	t	f	f	\N
4784	31	99	t	f	f	f	f	f	f	\N
4750	94	98	t	t	t	f	f	f	f	\N
4746	90	98	f	f	f	f	f	f	f	\N
4743	87	98	f	f	f	f	\N	f	f	\N
4774	21	99	t	t	t	t	\N	f	f	1.6
4740	84	98	t	t	t	t	f	f	f	8.1
4776	23	99	t	f	f	f	f	f	f	\N
4798	45	99	t	t	t	t	\N	f	f	4.8
4761	8	99	t	f	f	f	f	f	f	\N
4795	42	99	t	t	t	f	f	f	f	\N
4772	19	99	t	f	f	f	\N	f	f	\N
4797	44	99	t	t	t	t	f	f	f	11
4803	50	99	t	f	f	f	f	f	f	\N
4758	5	99	t	f	f	f	f	f	f	\N
4790	37	99	t	t	t	t	f	f	f	10.2
4788	35	99	t	f	f	f	f	f	f	\N
4759	6	99	t	t	t	t	f	f	f	10.1
4778	25	99	t	f	f	f	f	f	f	\N
4763	10	99	t	t	t	t	f	f	f	9
4796	43	99	t	f	f	f	\N	f	f	\N
4769	16	99	t	f	f	f	\N	f	f	\N
4802	49	99	t	t	t	t	f	f	f	6.8
4755	2	99	t	f	f	f	f	f	f	\N
4756	3	99	t	f	f	f	f	f	f	\N
4773	20	99	t	f	f	f	f	f	f	\N
4765	12	99	t	f	f	f	f	f	f	\N
4781	28	99	t	f	f	f	f	f	f	\N
4757	4	99	t	t	t	t	f	f	f	8.1
4766	13	99	t	t	t	f	\N	f	f	\N
4771	18	99	t	t	t	t	t	f	f	10.1
4754	1	99	t	f	f	f	f	f	f	\N
4764	11	99	t	f	f	f	f	f	f	\N
4775	22	99	t	t	t	f	f	f	f	\N
4794	41	99	t	f	f	f	f	f	f	\N
4760	7	99	t	t	t	t	t	f	f	0.8
4789	36	99	t	f	f	f	t	f	f	\N
4768	15	99	t	f	f	f	\N	f	f	\N
4782	29	99	t	f	f	f	\N	f	f	\N
4799	46	99	t	t	t	f	f	f	f	\N
4791	38	99	t	f	f	f	f	f	f	\N
4793	40	99	t	f	f	f	f	f	f	\N
4779	26	99	t	t	t	t	f	f	f	6.1
4852	1	100	t	f	f	f	f	f	f	\N
4810	57	99	t	f	f	f	f	f	f	\N
4857	6	100	f	f	f	f	f	f	f	\N
4864	13	100	f	f	f	f	\N	f	f	\N
4879	28	100	f	f	f	f	f	f	f	\N
4818	65	99	t	t	t	f	f	f	f	\N
4846	93	99	t	f	f	f	t	f	f	\N
4824	71	99	t	t	t	t	f	f	f	6.1
4808	55	99	t	f	f	f	f	f	f	\N
4811	58	99	t	f	f	f	t	f	f	\N
4805	52	99	t	f	f	f	f	f	f	\N
4826	73	99	t	f	f	f	\N	f	f	\N
4806	53	99	t	f	f	f	f	f	f	\N
4819	66	99	t	t	t	f	f	f	f	\N
4822	69	99	t	t	t	t	f	f	f	3
4831	78	99	t	f	f	f	\N	f	f	\N
4828	75	99	t	f	f	f	f	f	f	\N
4841	88	99	t	f	f	f	\N	f	f	\N
4825	72	99	t	f	f	f	f	f	f	\N
4827	74	99	t	f	f	f	f	f	f	\N
4842	89	99	t	f	f	f	f	f	f	\N
4845	92	99	t	f	f	f	f	f	f	\N
4848	95	99	t	t	t	f	f	f	f	\N
4850	97	99	t	t	t	t	t	f	f	6.1
4814	61	99	t	t	t	f	f	f	f	\N
4823	70	99	t	t	t	t	f	f	f	6.1
4821	68	99	t	t	t	f	f	f	f	\N
4830	77	99	t	f	f	f	f	f	f	\N
4832	79	99	t	f	f	f	f	f	f	\N
4837	84	99	t	f	f	f	f	f	f	\N
4833	80	99	t	f	f	f	f	f	f	\N
4844	91	99	t	f	f	f	f	f	f	\N
4804	51	99	t	t	t	t	f	f	f	6.1
4847	94	99	t	f	f	f	f	f	f	\N
4809	56	99	t	f	f	f	f	f	f	\N
4836	83	99	t	f	f	f	f	f	f	\N
4851	98	99	t	t	t	t	f	f	f	1.4
4816	63	99	t	t	t	t	f	f	f	4.1
4839	86	99	t	t	t	t	f	f	f	6.1
4840	87	99	t	f	f	f	\N	f	f	\N
4812	59	99	t	f	f	f	f	f	f	\N
4815	62	99	t	f	f	f	\N	f	f	\N
4835	82	99	t	f	f	f	t	f	f	\N
4838	85	99	t	f	f	f	f	f	f	\N
4843	90	99	t	f	f	f	f	f	f	\N
4807	54	99	t	f	f	f	t	f	f	\N
4829	76	99	t	t	t	t	\N	f	f	1
4834	81	99	t	f	f	f	f	f	f	\N
4813	60	99	t	f	f	f	f	f	f	\N
4820	67	99	t	f	f	f	t	f	f	\N
4849	96	99	t	f	f	f	f	f	f	\N
4817	64	99	t	t	t	t	f	f	f	4.1
4870	19	100	t	t	t	t	\N	f	f	3
4862	11	100	f	f	f	f	t	f	f	\N
4878	27	100	f	f	f	f	f	f	f	\N
4868	17	100	t	t	t	t	f	f	f	6.6
4873	22	100	f	f	f	f	t	f	f	\N
4853	2	100	t	f	f	f	f	f	f	\N
4872	21	100	f	f	f	f	\N	f	f	\N
4856	5	100	t	f	f	f	f	f	f	\N
4855	4	100	f	f	f	f	f	f	f	\N
4861	10	100	f	f	f	f	f	f	f	\N
4865	14	100	t	f	f	f	f	f	f	\N
4876	25	100	f	f	f	f	f	f	f	\N
4877	26	100	f	f	f	f	f	f	f	\N
4866	15	100	f	f	f	f	\N	f	f	\N
4869	18	100	f	f	f	f	f	f	f	\N
4854	3	100	f	f	f	f	f	f	f	\N
4860	9	100	t	t	t	t	t	f	f	1.8
4867	16	100	f	f	f	f	\N	f	f	\N
4874	23	100	f	f	f	f	t	f	f	\N
4875	24	100	f	f	f	f	\N	f	f	\N
4858	7	100	f	f	f	f	f	f	f	\N
4859	8	100	f	f	f	f	f	f	f	\N
4871	20	100	f	f	f	f	f	f	f	\N
4863	12	100	f	f	f	f	t	f	f	\N
4923	72	100	f	f	f	f	t	f	f	\N
4884	33	100	f	f	f	f	\N	f	f	\N
4900	49	100	f	f	f	f	f	f	f	\N
4907	56	100	f	f	f	f	f	f	f	\N
4930	79	100	t	t	t	t	f	f	f	2.1
4914	63	100	f	f	f	f	t	f	f	\N
4940	89	100	f	f	f	f	f	f	f	\N
4921	70	100	f	f	f	f	f	f	f	\N
4926	75	100	t	f	f	f	f	f	f	\N
4924	73	100	t	f	f	f	\N	f	f	\N
4927	76	100	f	f	f	f	\N	f	f	\N
4948	97	100	f	f	f	f	f	f	f	\N
4889	38	100	f	f	f	f	f	f	f	\N
4932	81	100	f	f	f	f	f	f	f	\N
4910	59	100	f	f	f	f	f	f	f	\N
4915	64	100	t	f	f	f	t	f	f	\N
4934	83	100	f	f	f	f	t	f	f	\N
4936	85	100	f	f	f	f	f	f	f	\N
4944	93	100	f	f	f	f	f	f	f	\N
4888	37	100	f	f	f	f	t	f	f	\N
4912	61	100	f	f	f	f	f	f	f	\N
4939	88	100	f	f	f	f	\N	f	f	\N
4942	91	100	f	f	f	f	f	f	f	\N
4917	66	100	f	f	f	f	f	f	f	\N
4919	68	100	t	f	f	f	f	f	f	\N
4925	74	100	f	f	f	f	f	f	f	\N
4945	94	100	f	f	f	f	f	f	f	\N
4887	36	100	t	f	f	f	f	f	f	\N
4916	65	100	f	f	f	f	f	f	f	\N
4938	87	100	f	f	f	f	\N	f	f	\N
4935	84	100	t	t	t	t	t	f	f	10.1
4906	55	100	f	f	f	f	f	f	f	\N
4929	78	100	f	f	f	f	\N	f	f	\N
4908	57	100	f	f	f	f	f	f	f	\N
4913	62	100	f	f	f	f	\N	f	f	\N
4928	77	100	f	f	f	f	f	f	f	\N
4937	86	100	t	f	f	f	f	f	f	\N
4883	32	100	f	f	f	f	t	f	f	\N
4904	53	100	f	f	f	f	f	f	f	\N
4886	35	100	f	f	f	f	f	f	f	\N
4896	45	100	f	f	f	f	\N	f	f	\N
4949	98	100	f	f	f	f	f	f	f	\N
4903	52	100	f	f	f	f	f	f	f	\N
4933	82	100	t	t	t	f	f	f	f	\N
4909	58	100	t	t	t	t	f	f	f	10.1
4918	67	100	f	f	f	f	f	f	f	\N
4946	95	100	f	f	f	f	t	f	f	\N
4891	40	100	t	f	f	f	f	f	f	\N
4947	96	100	f	f	f	f	t	f	f	\N
4898	47	100	t	f	f	f	f	f	f	\N
4899	48	100	f	f	f	f	f	f	f	\N
4902	51	100	f	f	f	f	f	f	f	\N
4950	99	100	t	t	t	t	f	f	f	6.2
4905	54	100	t	f	f	f	f	f	f	\N
4894	43	100	t	f	f	f	\N	f	f	\N
4895	44	100	f	f	f	f	f	f	f	\N
4941	90	100	f	f	f	f	t	f	f	\N
4943	92	100	f	f	f	f	f	f	f	\N
4911	60	100	t	f	f	f	f	f	f	\N
4922	71	100	f	f	f	f	f	f	f	\N
4885	34	100	f	f	f	f	f	f	f	\N
4901	50	100	f	f	f	f	f	f	f	\N
4882	31	100	f	f	f	f	f	f	f	\N
4890	39	100	t	t	t	f	f	f	f	\N
4920	69	100	t	f	f	f	f	f	f	\N
4931	80	100	f	f	f	f	f	f	f	\N
4880	29	100	f	f	f	f	\N	f	f	\N
4881	30	100	t	f	f	f	f	f	f	\N
4892	41	100	t	f	f	f	t	f	f	\N
4893	42	100	t	f	f	f	t	f	f	\N
4897	46	100	f	f	f	f	f	f	f	\N
4952	2	101	t	f	f	f	f	f	f	\N
4951	1	101	t	f	f	f	f	f	f	\N
4989	39	101	t	f	f	f	t	f	f	\N
4974	24	101	t	t	t	f	\N	f	f	\N
5028	78	101	t	f	f	f	\N	f	f	\N
4995	45	101	f	f	f	f	\N	f	f	\N
4999	49	101	f	f	f	f	f	f	f	\N
4981	31	101	t	t	t	t	t	f	f	0.2
4991	41	101	t	t	t	t	f	f	f	8.1
5005	55	101	t	f	f	f	t	f	f	\N
4985	35	101	t	f	f	f	t	f	f	\N
4983	33	101	t	f	f	f	\N	f	f	\N
4998	48	101	f	f	f	f	f	f	f	\N
4959	9	101	t	t	t	t	f	f	f	6.1
4996	46	101	f	f	f	f	f	f	f	\N
5002	52	101	t	f	f	f	f	f	f	\N
5008	58	101	t	f	f	f	f	f	f	\N
4971	21	101	f	f	f	f	\N	f	f	\N
5016	66	101	f	f	f	f	f	f	f	\N
4990	40	101	t	t	t	t	f	f	f	1.1
4953	3	101	t	t	t	t	f	f	f	2.2
4968	18	101	f	f	f	f	f	f	f	\N
5003	53	101	f	f	f	f	f	f	f	\N
5027	77	101	f	f	f	f	t	f	f	\N
5038	88	101	f	f	f	f	\N	f	f	\N
5004	54	101	t	f	f	f	f	f	f	\N
5009	59	101	f	f	f	f	t	f	f	\N
5022	72	101	f	f	f	f	f	f	f	\N
5029	79	101	t	f	f	f	f	f	f	\N
5039	89	101	f	f	f	f	f	f	f	\N
5021	71	101	t	f	f	f	f	f	f	\N
4987	37	101	t	f	f	f	f	f	f	\N
4954	4	101	f	f	f	f	f	f	f	\N
5000	50	101	f	f	f	f	f	f	f	\N
5001	51	101	f	f	f	f	f	f	f	\N
4962	12	101	f	f	f	f	f	f	f	\N
4997	47	101	t	f	f	f	f	f	f	\N
5023	73	101	t	t	t	t	\N	f	f	3
5014	64	101	t	f	f	f	f	f	f	\N
5010	60	101	t	t	t	t	f	f	f	6.1
5012	62	101	f	f	f	f	\N	f	f	\N
4975	25	101	f	f	f	f	t	f	f	\N
5025	75	101	t	f	f	f	f	f	f	\N
5015	65	101	t	f	f	f	t	f	f	\N
5026	76	101	t	f	f	f	\N	f	f	\N
5030	80	101	f	f	f	f	f	f	f	\N
5036	86	101	t	f	f	f	f	f	f	\N
5024	74	101	t	f	f	f	f	f	f	\N
4993	43	101	t	f	f	f	\N	f	f	\N
5017	67	101	f	f	f	f	f	f	f	\N
5041	91	101	f	f	f	f	f	f	f	\N
5035	85	101	t	f	f	f	t	f	f	\N
5046	96	101	f	f	f	f	f	f	f	\N
5013	63	101	f	f	f	f	f	f	f	\N
4994	44	101	f	f	f	f	f	f	f	\N
4967	17	101	t	f	f	f	f	f	f	\N
5032	82	101	t	t	t	f	f	f	f	\N
5042	92	101	f	f	f	f	t	f	f	\N
4976	26	101	t	f	f	f	t	f	f	\N
5043	93	101	t	t	t	t	f	f	f	8.6
4969	19	101	t	t	t	f	\N	f	f	\N
4970	20	101	f	f	f	f	f	f	f	\N
4965	15	101	t	t	t	f	\N	f	f	\N
4977	27	101	f	f	f	f	f	f	f	\N
5045	95	101	f	f	f	f	f	f	f	\N
4986	36	101	t	t	t	t	f	f	f	8.1
4988	38	101	f	f	f	f	t	f	f	\N
5020	70	101	f	f	f	f	t	f	f	\N
4980	30	101	t	f	f	f	f	f	f	\N
4966	16	101	f	f	f	f	\N	f	f	\N
4992	42	101	t	f	f	f	f	f	f	\N
5006	56	101	f	f	f	f	t	f	f	\N
4956	6	101	t	f	f	f	f	f	f	\N
5018	68	101	t	f	f	f	f	f	f	\N
4961	11	101	f	f	f	f	f	f	f	\N
4957	7	101	t	f	f	f	f	f	f	\N
5007	57	101	f	f	f	f	t	f	f	\N
5011	61	101	f	f	f	f	f	f	f	\N
5031	81	101	t	t	t	f	f	f	f	\N
4955	5	101	t	f	f	f	f	f	f	\N
4978	28	101	f	f	f	f	t	f	f	\N
4972	22	101	t	f	f	f	f	f	f	\N
5019	69	101	t	f	f	f	f	f	f	\N
4973	23	101	f	f	f	f	f	f	f	\N
4979	29	101	f	f	f	f	\N	f	f	\N
5033	83	101	t	f	f	f	f	f	f	\N
4963	13	101	f	f	f	f	\N	f	f	\N
4982	32	101	f	f	f	f	f	f	f	\N
5034	84	101	t	t	t	t	f	f	f	9
4984	34	101	t	f	f	f	f	f	f	\N
5044	94	101	f	f	f	f	f	f	f	\N
4960	10	101	f	f	f	f	f	f	f	\N
5037	87	101	t	f	f	f	\N	f	f	\N
4964	14	101	t	t	t	t	f	f	f	10.1
5040	90	101	t	t	t	t	f	f	f	0.6
4958	8	101	f	f	f	f	f	f	f	\N
5048	98	101	f	f	f	f	f	f	f	\N
5102	52	102	f	f	f	f	f	f	f	\N
5049	99	101	t	f	f	f	f	f	f	\N
5050	100	101	f	f	f	f	f	f	f	\N
5047	97	101	f	f	f	f	f	f	f	\N
5078	28	102	t	f	f	f	f	f	f	\N
5075	25	102	t	f	f	f	f	f	f	\N
5095	45	102	f	f	f	f	f	f	f	\N
5109	59	102	f	f	f	f	f	f	f	\N
5064	14	102	t	t	f	f	f	f	f	\N
5130	80	102	t	f	f	f	f	f	f	\N
5131	81	102	f	f	f	f	f	f	f	\N
5066	16	102	t	t	t	f	f	f	f	\N
5145	95	102	t	f	f	f	f	f	f	\N
5055	5	102	t	f	f	f	f	f	f	\N
5054	4	102	t	f	f	f	f	f	f	\N
5083	33	102	f	f	f	f	f	f	f	\N
5060	10	102	t	f	f	f	f	f	f	\N
5079	29	102	f	f	f	f	f	f	f	\N
5098	48	102	t	f	f	f	f	f	f	\N
5105	55	102	f	f	f	f	f	f	f	\N
5062	12	102	t	f	f	f	f	f	f	\N
5111	61	102	t	f	f	f	f	f	f	\N
5120	70	102	f	f	f	f	f	f	f	\N
5071	21	102	f	f	f	f	f	f	f	\N
5148	98	102	t	f	f	f	f	f	f	\N
5056	6	102	f	f	f	f	f	f	f	\N
5149	99	102	t	f	f	f	f	f	f	\N
5072	22	102	f	f	f	f	f	f	f	\N
5090	40	102	t	t	f	f	f	f	f	\N
5121	71	102	f	f	f	f	f	f	f	\N
5094	44	102	f	f	f	f	f	f	f	\N
5141	91	102	t	f	f	f	f	f	f	\N
5089	39	102	t	f	f	f	f	f	f	\N
5107	57	102	t	f	f	f	f	f	f	\N
5084	34	102	f	f	f	f	f	f	f	\N
5144	94	102	t	t	t	f	f	f	f	\N
5057	7	102	f	f	f	f	f	f	f	\N
5118	68	102	t	f	f	f	f	f	f	\N
5127	77	102	f	f	f	f	f	f	f	\N
5150	100	102	f	f	f	f	f	f	f	\N
5134	84	102	t	t	t	f	f	f	f	\N
5051	1	102	t	f	f	f	f	f	f	\N
5151	101	102	f	f	f	f	f	f	f	\N
5068	18	102	t	f	f	f	f	f	f	\N
5137	87	102	f	f	f	f	f	f	f	\N
5108	58	102	t	f	f	f	f	f	f	\N
5142	92	102	t	f	f	f	f	f	f	\N
5070	20	102	t	t	t	f	f	f	f	\N
5074	24	102	f	f	f	f	f	f	f	\N
5081	31	102	f	f	f	f	f	f	f	\N
5058	8	102	t	t	f	f	f	f	f	\N
5119	69	102	t	f	f	f	f	f	f	\N
5143	93	102	f	f	f	f	f	f	f	\N
5128	78	102	f	f	f	f	f	f	f	\N
5067	17	102	t	f	f	f	f	f	f	\N
5110	60	102	t	t	t	f	f	f	f	\N
5113	63	102	f	f	f	f	f	f	f	\N
5069	19	102	t	t	f	f	f	f	f	\N
5124	74	102	f	f	f	f	f	f	f	\N
5053	3	102	f	f	f	f	f	f	f	\N
5059	9	102	t	t	t	t	f	f	f	2.4
5082	32	102	t	t	t	f	f	f	f	\N
5129	79	102	t	f	f	f	f	f	f	\N
5138	88	102	f	f	f	f	f	f	f	\N
5139	89	102	f	f	f	f	f	f	f	\N
5140	90	102	f	f	f	f	f	f	f	\N
5101	51	102	t	f	f	f	f	f	f	\N
5065	15	102	f	f	f	f	f	f	f	\N
5125	75	102	t	f	f	f	f	f	f	\N
5123	73	102	t	t	t	f	f	f	f	\N
5136	86	102	t	f	f	f	f	f	f	\N
5146	96	102	f	f	f	f	f	f	f	\N
5073	23	102	t	f	f	f	f	f	f	\N
5077	27	102	f	f	f	f	f	f	f	\N
5133	83	102	f	f	f	f	f	f	f	\N
5103	53	102	f	f	f	f	f	f	f	\N
5106	56	102	f	f	f	f	f	f	f	\N
5135	85	102	f	f	f	f	f	f	f	\N
5126	76	102	f	f	f	f	f	f	f	\N
5052	2	102	t	f	f	f	f	f	f	\N
5147	97	102	t	f	f	f	f	f	f	\N
5061	11	102	f	f	f	f	f	f	f	\N
5117	67	102	f	f	f	f	f	f	f	\N
5085	35	102	f	f	f	f	f	f	f	\N
5076	26	102	f	f	f	f	f	f	f	\N
5132	82	102	t	t	f	f	f	f	f	\N
5104	54	102	t	f	f	f	f	f	f	\N
5091	41	102	t	t	t	f	f	f	f	\N
5112	62	102	f	f	f	f	f	f	f	\N
5093	43	102	t	f	f	f	f	f	f	\N
5152	1	103	t	t	t	f	f	f	f	\N
5114	64	102	t	f	f	f	f	f	f	\N
5122	72	102	f	f	f	f	f	f	f	\N
5063	13	102	t	f	f	f	f	f	f	\N
5096	46	102	t	f	f	f	f	f	f	\N
5087	37	102	f	f	f	f	f	f	f	\N
5088	38	102	f	f	f	f	f	f	f	\N
5099	49	102	f	f	f	f	f	f	f	\N
5100	50	102	f	f	f	f	f	f	f	\N
5115	65	102	f	f	f	f	f	f	f	\N
5080	30	102	t	f	f	f	f	f	f	\N
5097	47	102	t	f	f	f	f	f	f	\N
5092	42	102	t	f	f	f	f	f	f	\N
5116	66	102	f	f	f	f	f	f	f	\N
5158	7	103	f	f	f	f	f	f	f	\N
5154	3	103	f	f	f	f	f	f	f	\N
5156	5	103	t	t	t	f	f	f	f	\N
5086	36	102	t	t	t	f	f	f	f	\N
5159	8	103	f	f	f	f	f	f	f	\N
5157	6	103	f	f	f	f	f	f	f	\N
5153	2	103	t	t	t	t	f	f	f	10.1
5160	9	103	t	f	f	f	t	f	f	\N
5155	4	103	f	f	f	f	f	f	f	\N
5206	55	103	f	f	f	f	f	f	f	\N
5207	56	103	f	f	f	f	f	f	f	\N
5189	38	103	f	f	f	f	f	f	f	\N
5195	44	103	f	f	f	f	f	f	f	\N
5164	13	103	f	f	f	f	\N	f	f	\N
5176	25	103	f	f	f	f	f	f	f	\N
5179	28	103	f	f	f	f	f	f	f	\N
5209	58	103	t	f	f	f	f	f	f	\N
5177	26	103	f	f	f	f	f	f	f	\N
5173	22	103	f	f	f	f	t	f	f	\N
5182	31	103	f	f	f	f	f	f	f	\N
5186	35	103	f	f	f	f	f	f	f	\N
5196	45	103	f	f	f	f	\N	f	f	\N
5205	54	103	t	t	t	t	f	f	f	10.6
5180	29	103	f	f	f	f	\N	f	f	\N
5162	11	103	f	f	f	f	t	f	f	\N
5163	12	103	f	f	f	f	t	f	f	\N
5161	10	103	f	f	f	f	f	f	f	\N
5172	21	103	f	f	f	f	\N	f	f	\N
5169	18	103	f	f	f	f	f	f	f	\N
5174	23	103	f	f	f	f	t	f	f	\N
5178	27	103	f	f	f	f	f	f	f	\N
5190	39	103	t	f	f	f	f	f	f	\N
5200	49	103	f	f	f	f	f	f	f	\N
5166	15	103	f	f	f	f	\N	f	f	\N
5203	52	103	f	f	f	f	f	f	f	\N
5170	19	103	t	f	f	f	\N	f	f	\N
5181	30	103	t	t	t	f	f	f	f	\N
5183	32	103	f	f	f	f	t	f	f	\N
5197	46	103	f	f	f	f	f	f	f	\N
5202	51	103	f	f	f	f	f	f	f	\N
5175	24	103	f	f	f	f	\N	f	f	\N
5171	20	103	f	f	f	f	f	f	f	\N
5204	53	103	f	f	f	f	f	f	f	\N
5168	17	103	t	f	f	f	f	f	f	\N
5188	37	103	f	f	f	f	t	f	f	\N
5191	40	103	t	f	f	f	f	f	f	\N
5198	47	103	t	t	t	t	f	f	f	5
5201	50	103	f	f	f	f	f	f	f	\N
5208	57	103	f	f	f	f	f	f	f	\N
5165	14	103	t	f	f	f	f	f	f	\N
5167	16	103	f	f	f	f	\N	f	f	\N
5185	34	103	f	f	f	f	f	f	f	\N
5192	41	103	t	f	f	f	t	f	f	\N
5199	48	103	f	f	f	f	f	f	f	\N
5187	36	103	t	f	f	f	f	f	f	\N
5194	43	103	t	t	t	t	\N	f	f	1
5184	33	103	f	f	f	f	\N	f	f	\N
5193	42	103	t	f	f	f	t	f	f	\N
5224	73	103	t	f	f	f	\N	f	f	\N
5227	76	103	f	f	f	f	\N	f	f	\N
5241	90	103	f	f	f	f	t	f	f	\N
5225	74	103	f	f	f	f	f	f	f	\N
5237	86	103	t	f	f	f	f	f	f	\N
5238	87	103	f	f	f	f	\N	f	f	\N
5245	94	103	f	f	f	f	f	f	f	\N
5246	95	103	f	f	f	f	t	f	f	\N
5216	65	103	f	f	f	f	f	f	f	\N
5219	68	103	t	f	f	f	f	f	f	\N
5221	70	103	f	f	f	f	f	f	f	\N
5226	75	103	t	t	t	t	f	f	f	4.2
5231	80	103	f	f	f	f	f	f	f	\N
5233	82	103	t	f	f	f	f	f	f	\N
5239	88	103	f	f	f	f	\N	f	f	\N
5222	71	103	f	f	f	f	f	f	f	\N
5251	100	103	f	f	f	f	t	f	f	\N
5214	63	103	f	f	f	f	t	f	f	\N
5250	99	103	t	f	f	f	f	f	f	\N
5242	91	103	f	f	f	f	f	f	f	\N
5244	93	103	f	f	f	f	f	f	f	\N
5249	98	103	f	f	f	f	f	f	f	\N
5236	85	103	f	f	f	f	f	f	f	\N
5211	60	103	t	f	f	f	f	f	f	\N
5213	62	103	f	f	f	f	\N	f	f	\N
5223	72	103	f	f	f	f	t	f	f	\N
5218	67	103	f	f	f	f	f	f	f	\N
5243	92	103	f	f	f	f	f	f	f	\N
5229	78	103	f	f	f	f	\N	f	f	\N
5230	79	103	t	f	f	f	f	f	f	\N
5217	66	103	f	f	f	f	f	f	f	\N
5232	81	103	f	f	f	f	f	f	f	\N
5234	83	103	f	f	f	f	t	f	f	\N
5235	84	103	t	f	f	f	t	f	f	\N
5212	61	103	f	f	f	f	f	f	f	\N
5220	69	103	t	t	t	t	f	f	f	10.1
5248	97	103	f	f	f	f	f	f	f	\N
5253	102	103	f	f	f	f	\N	f	f	\N
5210	59	103	f	f	f	f	f	f	f	\N
5240	89	103	f	f	f	f	f	f	f	\N
5247	96	103	f	f	f	f	t	f	f	\N
5215	64	103	t	f	f	f	t	f	f	\N
5228	77	103	f	f	f	f	f	f	f	\N
5252	101	103	f	f	f	f	f	f	f	\N
\.


--
-- TOC entry 4695 (class 0 OID 91930)
-- Dependencies: 240
-- Data for Name: messages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.messages (id, room_id, from_id, to_id, from_id_connected, to_id_connected, message, sent_at, read) FROM stdin;
\.


--
-- TOC entry 4683 (class 0 OID 91818)
-- Dependencies: 228
-- Data for Name: profile_pictures; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.profile_pictures (id, user_id, file_name, file_type, file_data, file_url) FROM stdin;
\.


--
-- TOC entry 4689 (class 0 OID 91865)
-- Dependencies: 234
-- Data for Name: requests; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.requests (id, from_id, to_id, accepted, processed, created_at) FROM stdin;
\.


--
-- TOC entry 4693 (class 0 OID 91907)
-- Dependencies: 238
-- Data for Name: rooms; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.rooms (id, user_id1, user_id2, user1_connected, user2_connected, created_at) FROM stdin;
\.


--
-- TOC entry 4437 (class 0 OID 91014)
-- Dependencies: 217
-- Data for Name: spatial_ref_sys; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.spatial_ref_sys (srid, auth_name, auth_srid, srtext, proj4text) FROM stdin;
\.


--
-- TOC entry 4677 (class 0 OID 91773)
-- Dependencies: 222
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, email, password, about_me, dog_name) FROM stdin;
1	mhawkeswood0@canalblog.com	$2a$10$JCerbeLgT7./DX4y5.z0yOi7N9ELead1jHTbJV/13gCpcQGs4fIxC	De-engineered client-driven firmware	Ringtail
2	dsconce1@comcast.net	$2a$10$mpukiZccr81QMrhl30hk6.ltIl9VopDm6GV6wJhtblZOMcuwUS052	Vision-oriented zero defect help-desk	Tortoise, indian star
3	dlademann2@domainmarket.com	$2a$10$2IrO1kNwbnrVKCglIy0fXeLVe7ndydTvnz1TKPi4UfnBPjV7XU5Oi	Intuitive demand-driven approach	Yellow-rumped siskin
4	acrathorne3@facebook.com	$2a$10$pckwfCIj84lY7GtGARffguZR3QqJj9AsOy8JC6CPYriUNrxQGucgi	Advanced bandwidth-monitored model	Boa, columbian rainbow
5	lschimek4@sciencedaily.com	$2a$10$tQ.uKIfU6gLcDyjodsqzeeBQhNuvCg3syb423rUz.fgyOZVM19iN2	Reactive value-added approach	Deer, roe
6	fclague5@1und1.de	$2a$10$pNQ8cWXIDPAjN9spJNlWSeH9j2yP6EQ.Qk5SA38l1tfKvMqqvq7dG	Front-line eco-centric archive	Capuchin, brown
7	rbrame6@google.ca	$2a$10$KAdYTdLtguqy73dvX1.jVOLsb9UaH7EQiqSc74tz944lKIDsI6KBK	Extended fault-tolerant conglomeration	Bird, black-throated butcher
8	asemper7@technorati.com	$2a$10$I6d2px7Sxy8x7GT8hhdRM.fkTZBqA0DI0WK06oQOEZpYZ/fn5FqJS	Mandatory 6th generation implementation	Spotted hyena
9	adach8@pagesperso-orange.fr	$2a$10$4ucUXsnwwrIM8vGtO.2QWu7KXbHcfCaDVtvkXVQjUr7/sl55ZlIca	Devolved non-volatile encoding	Indian giant squirrel
10	brozier9@lycos.com	$2a$10$zAnW3qReJYfNoFq6jpZeyelAKAyT.1kta7Tar0Dygq3mBlpCrW5BG	Reduced static utilisation	Mexican wolf
11	nforsdykea@hexun.com	$2a$10$gJSQQdY6CmLQiuhJlK50m.t6T3aXxJkDQyHyuc7zanWyr.d/ieyxe	Extended encompassing monitoring	Squirrel, richardson's ground
12	hforsbeyb@hc360.com	$2a$10$cQF68rWa.S3Nl7./.hzP7udddqN4Mf9DChuO.c/x/2qbV68dZEFTq	Business-focused bottom-line orchestration	Black-throated butcher bird
13	dfinicjc@cornell.edu	$2a$10$DTdHTOQTfuvYNa0Pj/vvPuziICio4qwHFdJneG91uBZ0B2BxHyZM6	Triple-buffered tangible strategy	King vulture
14	abeidebeked@weebly.com	$2a$10$rP1jv1R6lCdjJv2sBACIjOV1notZ1IS6u5rcm02ZYOW.nDTnCsave	Focused zero tolerance instruction set	Bleu, blue-breasted cordon
15	godaree@plala.or.jp	$2a$10$s9GvNDqcLQkPmpHIfXv1qO3LzoFvG.TqZlfaE67KFBAC3sk9pW7we	Upgradable client-driven infrastructure	Blacksmith plover
16	lsichardtf@cpanel.net	$2a$10$8LRLtdaqSDflOElQWO41aumzfyOioUZ57.3MPwhqnGtTZ/mJBLory	Mandatory background monitoring	Sloth, two-toed
17	gdoeg@homestead.com	$2a$10$49adw37aBwyGx4L7OnjTp.PKqYyFYwo/uNL6H5vPc.dfySVBMuDg6	Multi-lateral multi-state synergy	Lion, southern sea
18	cseeviourh@virginia.edu	$2a$10$8bLa2YTxk9Z8C1uR3wiTK.JcXyKeO2dbh4ccBdn87fBzjHLM8lIR.	Synergized 24/7 definition	Uinta ground squirrel
19	fbeminsteri@ocn.ne.jp	$2a$10$DMHpNSaz/cGrRJBw.oMw3OU1KGQNGy7s4xZ.RHA4dvk8laXt.TXm.	Re-engineered contextually-based secured line	Stork, white
20	cdobsonsj@angelfire.com	$2a$10$kJiJYH6EIu5czVMkc8og9OwgCqfUBmO2s846tMMYk62cnPebWlRMK	Cross-group 3rd generation ability	Tortoise, indian star
21	mgoadk@craigslist.org	$2a$10$5Gz4fsUXOVNxu/mk9lLfR.nptS9P4Jj5.LONABSHfOCEIbQurjale	Up-sized clear-thinking focus group	Dog, black-tailed prairie
22	sbeavanl@etsy.com	$2a$10$9a96F6QMK8J1gSBpSLhQ6egdOFPoHDG6ts8igxGoFW6fxHFKOqktS	Enterprise-wide zero administration superstructure	Tortoise, desert
23	mnezeym@paypal.com	$2a$10$ypP5m62MsJiqixmdfwyYOucbTkbnV4uoyIiLgYIn4YwFX5qLBwiFK	Object-based intermediate data-warehouse	Bald eagle
24	etubridyn@whitehouse.gov	$2a$10$00m8WlNfnJzkY67.PWOTxOCE9NkPzy6BEt9m.E/WkqZUtObXmC/L.	Persistent high-level toolset	African clawless otter
25	ldewso@hatena.ne.jp	$2a$10$0a8fP.2.dNiGivzD4hPGousRVfCESH1vweQET84ghS4FYovH4G902	Synergized upward-trending knowledge user	White rhinoceros
26	aearlp@miitbeian.gov.cn	$2a$10$.d2qqqybvGxj7XxtWRr0VuaW8QCpxOwMA/u/1ikXDfBj2NO1yJupK	Business-focused tangible intranet	Slender loris
27	ecarruthq@foxnews.com	$2a$10$Wy12qbExQIFzpdf/xtk0kO8pgop8hMlQt1OA0n6R5dK5r9BaCqdcG	Adaptive grid-enabled definition	Trumpeter swan
28	tkrysiakr@engadget.com	$2a$10$hxgNSo3lJPPgcUyMpO7ca.rVpLw4nTTo8f8BPk/qhurICqLsvyXeG	Mandatory intermediate pricing structure	Pie, rufous tree
29	ifaass@artisteer.com	$2a$10$pUwNRU.HmTh4ALpjJPVC8eFu9XihSKZAOA7z22syo8xW2daTuWQYC	Optional leading edge attitude	Dolphin, bottle-nose
30	cpackt@shutterfly.com	$2a$10$PSyGEtX9pqfA3uf2MJ2wvuh.9IlRmUkA9RjXHZvufyKs5gPCrXGB2	Enhanced client-server ability	Curve-billed thrasher
31	cbenettiniu@ucla.edu	$2a$10$gqOdq7GyXu9nMXD0dWoeLOMsZq/G4eILHADyin5nfVmAFRbXOAQzm	Universal didactic contingency	Feathertail glider
32	akirkwoodv@sphinn.com	$2a$10$cSivSBPLSxpdNG0swMnLlu9L7hqrD6h/3v/fqkJU954y1d93.DGsa	User-centric content-based encryption	Snowy egret
33	bwardesworthw@merriam-webster.com	$2a$10$CX6HmGqMIIR4Q0kVh2bebuqVU/E3L3L8F/hkB9je9jwvGQK.Orvfm	Extended empowering hardware	Wallaby, agile
34	wpavlatax@reuters.com	$2a$10$nmUkgtiMzb2KUEZvlwA7fuiG3.bIU5AuUnJNN99oozSiwTvu0cSy2	Future-proofed high-level info-mediaries	Opossum, american virginia
35	rkerswilly@mashable.com	$2a$10$S.kJxd0998/I3gCWyuSLh.lJG2PlJ4mccArhCXwAHevj0JycW4ZcW	Proactive value-added service-desk	Anaconda (unidentified)
36	jfinanz@godaddy.com	$2a$10$dlhR/EDnfBb6PfKPEkkLBu.h5bObp/zZmkyIfS9gMTta/xbULR8da	Robust disintermediate software	Olive baboon
37	cbamling10@xinhuanet.com	$2a$10$1UKgFvPBEB4QKow2lXHdOOIYDMAce64JhmjHumukU5WehUJzrYreO	Public-key analyzing policy	Gull, lava
38	aformigli11@aol.com	$2a$10$/nBiQ8GyyPdgWkjiK0fNnOqX7SKf23jbPWroxXq9a/DEStNc0rt8W	Switchable bandwidth-monitored hierarchy	Lizard, frilled
39	apaladini12@4shared.com	$2a$10$yV41cYiA0Cn6WIbPdzNIhONsX/vGDo5Y5ferXYycRi4aX52C7/SUS	Focused client-server pricing structure	Stork, white
40	jdonnersberg13@typepad.com	$2a$10$VMevdufDPYpP3WSijItKLukPt54mshM3jS3wCgF3D39PT.CysxqZK	User-friendly leading edge emulation	Owl, great horned
41	vredsull14@g.co	$2a$10$l7kAe0G9PrMC2cA5NIk4Dunw0fn7Ol929cknk0Of7/NQ53/Fx8fsi	Organic interactive architecture	Black rhinoceros
42	clates15@addthis.com	$2a$10$A8VtPk/5g6L79xoWiTR8AumvJeoh4pG8HiH8.8gKoe0Lu6jRo0psW	Ameliorated encompassing collaboration	Barbet, levaillant's
43	rcathro16@ed.gov	$2a$10$zFe/oDxVZ4Mhfc8jIsZunuR1bloiNAfzeGvEFVFI5AwoO7a4D3.3e	Extended 5th generation process improvement	Hornbill, leadbeateri's ground
44	ksatford17@theguardian.com	$2a$10$bQ.WDDW4ED/RAQmJFB8w6.25qt3oJ4Ldc1hdfw9HpXqGAyxcyBUxy	Automated background initiative	Macaque, pig-tailed
45	ajodkowski18@illinois.edu	$2a$10$0phPkFEzuCa/yW/kGsOzNeU/zIZZ5EIwebUmFm5aGabOeN8x.VyOO	Progressive user-facing internet solution	Gazelle, thomson's
46	idouthwaite19@geocities.com	$2a$10$MDU2GdgtoKtcJGaJ/KFo1.9xwqjJwCgQIf81.Hy3VbfHfPCQAJ5ia	Vision-oriented human-resource intranet	Pigeon, feral rock
47	kdjurevic1a@smh.com.au	$2a$10$fN2t1g1IDQXBsxHpqedjoO4fR5iuEiAXGQXg.Q5v9oE1sCtQseDU2	Pre-emptive cohesive instruction set	Phascogale, brush-tailed
48	ehedditch1b@de.vu	$2a$10$44fK2jCHSwTNmm0EYbynzu6pvlXIhAxzoxrgSf5ssxHZBEI8vQRx6	Mandatory optimal application	Little grebe
49	jbowman1c@1und1.de	$2a$10$ZOIy9fbFEliUf4qpmKNMsenBYl14izEATo7dt59npIryoPOKed0Zy	Universal executive flexibility	White-eye, cape
50	pgullis1d@japanpost.jp	$2a$10$vOLhClVYktU3hsBGbpYrMuAz0i6GrK/ojRBDQQWgNSeSlWdvJWIzO	Integrated secondary customer loyalty	Worm snake (unidentified)
51	cespin1e@sitemeter.com	$2a$10$/sLl0oXnTwxEGc4A..8SyuuJDRL8zCtbSA/2eLv48TCE3RQyMNQvm	Ameliorated demand-driven paradigm	Bandicoot, short-nosed
52	jtuffley1f@ehow.com	$2a$10$.bXhmniO2fL1ozPwQ4cGJ.C62dM3obfyMWWzL0.8uxtzTDrHxLR6u	Virtual needs-based challenge	Anteater, australian spiny
53	atonbye1g@mayoclinic.com	$2a$10$q.avgwYP4cYuQ2u6OLzcReDya82MT1idoJpc4OzOfi3HYw.6BGbVm	Horizontal reciprocal access	Fairy penguin
54	edartnall1h@youtube.com	$2a$10$DdPRGDXfZY1P5iiGE0igeOkcPtbX/ZcqcIxJmgi4AEzYr7rZtQC7m	Polarised human-resource strategy	Turtle, eastern box
55	tcastello1i@livejournal.com	$2a$10$1IAhkj5AHsx/Xd3YMiTB8O0sEgRyTjSL91FmWGz5O3h.3NmCTpZn6	Grass-roots asynchronous methodology	Black-faced kangaroo
56	orentilll1j@google.ru	$2a$10$FZnUEbyFpRZT7LemKA6oDOu57NTrDGUC9DQ4aLkdhNJPNafvk6F9C	Versatile background local area network	Little brown bat
57	ghelm1k@sun.com	$2a$10$Irol4u/RQklBtRnA33frqujc9TsmK..rVgfVKDtiZB73vOz24lIUq	Devolved static toolset	Skink, african
58	apicard1l@i2i.jp	$2a$10$2UOcnfm.Kvm.ZMoLS1EzZ.PbmZq22fJvcFz0h/xyfP3qlMqRnUl5K	Cross-platform cohesive budgetary management	Malay squirrel (unidentified)
59	hbergin1m@indiegogo.com	$2a$10$WUI3NC1w4/nBdJ/2HLA17uOzyZmr10H27gT4cA7ugUk.xq90dErjK	Function-based client-server architecture	Swallow-tail gull
60	lweek1n@reverbnation.com	$2a$10$4N/4XCE132w0PcQW3SHOEOXNgyzdm.QuMlzNPqx8OeQO8m4YLaS9C	Reverse-engineered dedicated adapter	Swan, trumpeter
61	qstruttman1o@oakley.com	$2a$10$03DE63O3uppyQcJXAVu2jeeCnzdMvFjiJ8ZG3bwsAtJA5oKXNlsqi	Multi-lateral optimizing parallelism	Blue-footed booby
62	hrodear1p@wikimedia.org	$2a$10$0b5cE2rrIkqi5YedrKG6VewfZkU5aoVTHHAT6SjwbMtB2kyQzBkdy	Triple-buffered homogeneous hierarchy	Tammar wallaby
63	sgreedy1q@php.net	$2a$10$Juke3IPvmO7wALh3JvXtWe1W8Kw9/fkJNaip8LFZdV4wfy0e1gtyi	Intuitive client-driven array	Common grenadier
64	rmessenger1r@pen.io	$2a$10$fJsHuiywThDJxJauEQL4K.d/hNLOA3S3O.ZnXLDB/pv6EpCfAEbfS	Triple-buffered secondary framework	Blue-footed booby
65	akelley1s@shutterfly.com	$2a$10$3VzAAZ.ke7rITHXM9hUJWuNbuU6FHNEGJzngQ89EbsVf9..Ta9n4y	Multi-tiered mission-critical standardization	Goanna lizard
66	eendacott1t@skype.com	$2a$10$ahc15NACFGnnpDdTKIbcuutPlvUCnO3ah/j5PsFIjMynJ8DzXx75u	Object-based global project	Gull, lava
67	bmcdill1u@1und1.de	$2a$10$6XoYnm.WkRhx3W.SdHRUYu8aD1Tg1PLkwcnwIgBsTd3jxwCV8cK46	Exclusive explicit access	Oryx, beisa
68	bdimeo1v@army.mil	$2a$10$I.hepmPmmheMvoBUjPZDNO3HEg3A7o4yGRM09wOMs3/hpFnqDFNSO	Multi-lateral 3rd generation approach	Koala
69	gbark1w@auda.org.au	$2a$10$R8z2ZXIwZ2.e0gq7EAFLa.Psm.y2TRBwazSQ8VDkkR0hDftl7XD.O	Advanced motivating complexity	Partridge, coqui
70	jhendren1x@360.cn	$2a$10$HjH35jrnq6KcpjGiWee3fODRZvn33dDLBGF0HeraLzRHhvBHpOgau	Balanced systemic attitude	Grenadier, common
71	dbilam1y@bing.com	$2a$10$ktXl.lf056aAUPln56zzEugMmscmt/avlMi0l23onuxEtVHWyZ81C	Automated coherent adapter	Jungle cat
72	trykert1z@utexas.edu	$2a$10$osx75UbB9iIMe7vVwORrAu.QFYxHswRtDH/39mSZl3FXAFT099JFK	Monitored optimal access	Red-winged blackbird
73	dblyde20@rambler.ru	$2a$10$duV7EmdDAnayxN3AqxSweOUsp1.bIWC3ICOad0CxxH.wg6owoalc6	Cross-group national adapter	Seal, northern elephant
74	barlow21@hc360.com	$2a$10$NbGmjFgiwqk.DzYUNAUrSu1hYcQUTxVNNi/fthFDmkW0D5FLYFHBG	Self-enabling grid-enabled moderator	Owl, australian masked
75	llerway22@tinyurl.com	$2a$10$saQ4SXxRvHWM.jskrvZE/OInYRRZwuXGEQDAitsOTfKBjdy8R1X5m	Quality-focused systemic forecast	Northern phalarope
76	scossom23@jalbum.net	$2a$10$fOSlAhOGQcp8kumvq6PJuO.wqJ9lXqXWhAAU7t127FSF4nwvn.Uqu	Implemented intermediate middleware	Turtle, snake-necked
77	slosselyong24@technorati.com	$2a$10$WQARmND8EKKnFp13JzG0ou0dK80nLwWZVNg8zMhxng9NvMwDzIT5O	Quality-focused exuding superstructure	Heron, green-backed
78	mlyon25@latimes.com	$2a$10$XGYTyPcfXzVLiAOenBCCguW6h9dsSov0LEAkGg4jHJhesOjpLmetm	Optimized radical support	Chilean flamingo
79	cnannini26@latimes.com	$2a$10$3bQa40QoItuTEk20mRDugeRoy0WLFra9V079WN8GBLBYkHsMYdHgu	Distributed object-oriented info-mediaries	Otter, north american river
80	mfulker27@printfriendly.com	$2a$10$LiVnkVFWNDXIFFeIRNCcEeipOOdOEQZyVZcHRLjQ2cgEDRZf.l5e.	Re-contextualized tertiary archive	Dama wallaby
81	wtarbox28@phoca.cz	$2a$10$qO3h9ZzlhOV7Dq4LnzXf8edlp7kw3j8jZtP6hC7vHvUoi6N5ByPoq	Universal coherent infrastructure	Western patch-nosed snake
82	mplampeyn29@ibm.com	$2a$10$3JSuvI8NCFDac8WCr46tFODAEhd6QV99JsjitKcufvootNZsB7UqK	Persevering disintermediate benchmark	Raccoon dog
83	cwakeman2a@amazon.co.jp	$2a$10$ReVuPnofN/0ckK3r6wOOK.Ht1j3xkoPTHmDw4PmLdP8hP1Kc29ER6	Progressive high-level software	Blue-faced booby
84	clelievre2b@china.com.cn	$2a$10$vZ28Q6Ey9vz0iS80NLSZw.xNPxyusfJYatxrBcL21MQm6lAjlOSWm	Multi-lateral context-sensitive moderator	European shelduck
85	rstallion2c@com.com	$2a$10$Uxo3dG5HRm68Zd1ceKAzFe52u..TPhmi7Cq1ktDGrXwynHWQlss26	Robust multi-state data-warehouse	Brolga crane
86	srhoddie2d@imgur.com	$2a$10$h0M9ueZT1YKfKSpiA20wiuUExa/01VAYDLyram0.rNqeGXHWPhQJ.	Persistent motivating matrix	Tiger snake
87	mcurley2e@va.gov	$2a$10$7CjY5Zip08sqD2/z5wc8Z.cJoYaGE./XDjrF1pGjV3I.JCsarp3rq	Automated reciprocal infrastructure	Netted rock dragon
88	oralphs2f@hp.com	$2a$10$WJ6jd9rA/jmEw9tSGQECN.yv4GjaT2vnKGd.QJ182ryQvr0BIq4G6	Decentralized user-facing challenge	Screamer, crested
89	wsturte2g@ow.ly	$2a$10$da/0FNTey1Gu9CLNNCUOg.VyE7UjPUxdgu16kpAeTeFLEtjuD0OMC	Stand-alone methodical neural-net	Turtle, snake-necked
90	rbrickham2h@twitter.com	$2a$10$n6iA8RX3D0wSMBDUbgytGeSabjY8/CsDSXXiYjwdOhZOk0zQCALb6	Object-based empowering alliance	Horned puffin
91	tdecruse2i@quantcast.com	$2a$10$lHtJzgi1KIq80/hcaCS6zOvhdB8j93zVQq7amlaAjNIaicfa.TJri	Operative 24 hour paradigm	Violet-crested turaco
92	mrozycki2j@nih.gov	$2a$10$fh0h2wbv0dW.7nO5h64j5.PrcNSlaeA5Q3.2y613S7Q0ywVG9wTf6	Virtual non-volatile software	Tiger
93	lclemmitt2k@dailymail.co.uk	$2a$10$3T85HeqjhdHEUuVjXW04veoWs9PWdBQbqfIMox8xtMKUnMFZgv0S2	Multi-tiered content-based alliance	Lark, horned
94	rlumby2l@ftc.gov	$2a$10$nW1w1K84CqgjKeRNjghFh.lNp9u2agQCvf4OL0e1d3oWWtY.QOUGO	Progressive systemic algorithm	Armadillo, giant
95	mrandall2m@diigo.com	$2a$10$jdfZfuvbJCrKWRT9Fzf9muh2o6f.g5KlMbqnrVc2YM1TwfGqGiv.e	Secured leading edge service-desk	Red deer
96	gtumini2n@51.la	$2a$10$NyMvHQDatbin8Yi3mAYH3u8ZHyZ6BRD7eGk0u.xhIc1z.sIKxIbVK	Organized exuding challenge	American bison
97	ktrahear2o@so-net.ne.jp	$2a$10$opz.zljniPRv4MtKZznt5OHWsRSFpgCN65EuPtvf3t1PoWZhYzeMi	Ergonomic empowering superstructure	Colobus, black and white
98	crayhill2p@tripod.com	$2a$10$g5WmVHda4jSVJ71jG8tsp.PMRJJ94LnmbV.husDM7yf25egKoe.XG	Operative zero administration frame	Arctic ground squirrel
99	emeir2q@mozilla.org	$2a$10$fdUQWQYRAHKZFCKL4YvWBuddW4PW59HSg60YMgHdPPkgJvdo9XaSm	Networked analyzing productivity	Common dolphin
100	rcossem2r@squarespace.com	$2a$10$7MBuq/J4emoA2GgneUG40OqL.71iyjbH0ROrGsp1ARRSWFzwEc6JW	Re-engineered leading edge alliance	American marten
101	tblasl2s@rakuten.co.jp	$2a$10$UW33UNA0f4l7Se5WxOIzVencrmUEwuOwEU57Zdt.n6KePsNlS/vCC	Open-architected 3rd generation customer loyalty	Yellow-billed stork
102	pbazylets2t@netlog.com	$2a$10$Kf8cobTr17HJ1DJGoenhA.ID95D9P2wZgleduxsQv2kfIiyjEQjZS	Cross-platform global algorithm	Carpet python
103	coakley2u@springer.com	$2a$10$nA0rWnZ7Imox2YOgIQxg4eQKC2jEtgsfbM0YcMKqcLaJpza3rWY6C	Intuitive even-keeled utilisation	Hawk, galapagos
\.


--
-- TOC entry 4712 (class 0 OID 0)
-- Dependencies: 223
-- Name: biographical_data_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.biographical_data_id_seq', 103, true);


--
-- TOC entry 4713 (class 0 OID 0)
-- Dependencies: 231
-- Name: connections_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.connections_id_seq', 1, false);


--
-- TOC entry 4714 (class 0 OID 0)
-- Dependencies: 229
-- Name: jwt_blacklist_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.jwt_blacklist_id_seq', 1, false);


--
-- TOC entry 4715 (class 0 OID 0)
-- Dependencies: 225
-- Name: locations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.locations_id_seq', 86, true);


--
-- TOC entry 4716 (class 0 OID 0)
-- Dependencies: 235
-- Name: matches_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.matches_id_seq', 5253, true);


--
-- TOC entry 4717 (class 0 OID 0)
-- Dependencies: 239
-- Name: messages_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.messages_id_seq', 1, false);


--
-- TOC entry 4718 (class 0 OID 0)
-- Dependencies: 227
-- Name: profile_pictures_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.profile_pictures_id_seq', 1, false);


--
-- TOC entry 4719 (class 0 OID 0)
-- Dependencies: 233
-- Name: requests_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.requests_id_seq', 1, false);


--
-- TOC entry 4720 (class 0 OID 0)
-- Dependencies: 237
-- Name: rooms_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.rooms_id_seq', 1, false);


--
-- TOC entry 4721 (class 0 OID 0)
-- Dependencies: 221
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_id_seq', 103, true);


--
-- TOC entry 4483 (class 2606 OID 91789)
-- Name: biographical_data biographical_data_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.biographical_data
    ADD CONSTRAINT biographical_data_pkey PRIMARY KEY (id);


--
-- TOC entry 4496 (class 2606 OID 91851)
-- Name: connections connections_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.connections
    ADD CONSTRAINT connections_pkey PRIMARY KEY (id);


--
-- TOC entry 4498 (class 2606 OID 91853)
-- Name: connections connections_user_id1_user_id2_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.connections
    ADD CONSTRAINT connections_user_id1_user_id2_key UNIQUE (user_id1, user_id2);


--
-- TOC entry 4494 (class 2606 OID 91840)
-- Name: jwt_blacklist jwt_blacklist_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.jwt_blacklist
    ADD CONSTRAINT jwt_blacklist_pkey PRIMARY KEY (id);


--
-- TOC entry 4486 (class 2606 OID 91806)
-- Name: locations locations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT locations_pkey PRIMARY KEY (id);


--
-- TOC entry 4503 (class 2606 OID 91899)
-- Name: matches matches_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_pkey PRIMARY KEY (id);


--
-- TOC entry 4505 (class 2606 OID 91901)
-- Name: matches matches_user_id1_user_id2_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_user_id1_user_id2_key UNIQUE (user_id1, user_id2);


--
-- TOC entry 4511 (class 2606 OID 91939)
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- TOC entry 4490 (class 2606 OID 91826)
-- Name: profile_pictures profile_pictures_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profile_pictures
    ADD CONSTRAINT profile_pictures_pkey PRIMARY KEY (id);


--
-- TOC entry 4492 (class 2606 OID 91828)
-- Name: profile_pictures profile_pictures_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profile_pictures
    ADD CONSTRAINT profile_pictures_user_id_key UNIQUE (user_id);


--
-- TOC entry 4500 (class 2606 OID 91873)
-- Name: requests requests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requests
    ADD CONSTRAINT requests_pkey PRIMARY KEY (id);


--
-- TOC entry 4507 (class 2606 OID 91916)
-- Name: rooms rooms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rooms
    ADD CONSTRAINT rooms_pkey PRIMARY KEY (id);


--
-- TOC entry 4509 (class 2606 OID 91918)
-- Name: rooms rooms_user_id1_user_id2_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rooms
    ADD CONSTRAINT rooms_user_id1_user_id2_key UNIQUE (user_id1, user_id2);


--
-- TOC entry 4488 (class 2606 OID 91808)
-- Name: locations unique_user_id; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT unique_user_id UNIQUE (user_id);


--
-- TOC entry 4481 (class 2606 OID 91778)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- TOC entry 4484 (class 1259 OID 91814)
-- Name: idx_locations_geom; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_locations_geom ON public.locations USING gist (geom);


--
-- TOC entry 4501 (class 1259 OID 91884)
-- Name: unique_request; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX unique_request ON public.requests USING btree (LEAST(from_id, to_id), GREATEST(from_id, to_id));


--
-- TOC entry 4524 (class 2620 OID 91903)
-- Name: users after_user_insert; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER after_user_insert AFTER INSERT ON public.users FOR EACH ROW EXECUTE FUNCTION public.update_matches();


--
-- TOC entry 4525 (class 2620 OID 91816)
-- Name: locations set_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER set_geom BEFORE INSERT OR UPDATE ON public.locations FOR EACH ROW EXECUTE FUNCTION public.update_geom();


--
-- TOC entry 4526 (class 2620 OID 91905)
-- Name: locations update_compatible_distance_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_compatible_distance_trigger AFTER INSERT OR UPDATE ON public.locations FOR EACH ROW EXECUTE FUNCTION public.update_compatible_distance();


--
-- TOC entry 4527 (class 2620 OID 91956)
-- Name: rooms update_messages_connected_status_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_messages_connected_status_trigger AFTER INSERT OR UPDATE OF user1_connected, user2_connected ON public.rooms FOR EACH ROW EXECUTE FUNCTION public.update_messages_connected_status();


--
-- TOC entry 4512 (class 2606 OID 91790)
-- Name: biographical_data biographical_data_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.biographical_data
    ADD CONSTRAINT biographical_data_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 4515 (class 2606 OID 91854)
-- Name: connections connections_user_id1_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.connections
    ADD CONSTRAINT connections_user_id1_fkey FOREIGN KEY (user_id1) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 4516 (class 2606 OID 91859)
-- Name: connections connections_user_id2_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.connections
    ADD CONSTRAINT connections_user_id2_fkey FOREIGN KEY (user_id2) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 4513 (class 2606 OID 91809)
-- Name: locations locations_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT locations_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 4521 (class 2606 OID 91945)
-- Name: messages messages_from_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_from_id_fkey FOREIGN KEY (from_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- TOC entry 4522 (class 2606 OID 91940)
-- Name: messages messages_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(id) ON DELETE SET NULL;


--
-- TOC entry 4523 (class 2606 OID 91950)
-- Name: messages messages_to_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_to_id_fkey FOREIGN KEY (to_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- TOC entry 4514 (class 2606 OID 91829)
-- Name: profile_pictures profile_pictures_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profile_pictures
    ADD CONSTRAINT profile_pictures_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 4517 (class 2606 OID 91874)
-- Name: requests requests_from_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requests
    ADD CONSTRAINT requests_from_id_fkey FOREIGN KEY (from_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 4518 (class 2606 OID 91879)
-- Name: requests requests_to_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requests
    ADD CONSTRAINT requests_to_id_fkey FOREIGN KEY (to_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 4519 (class 2606 OID 91919)
-- Name: rooms rooms_user_id1_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rooms
    ADD CONSTRAINT rooms_user_id1_fkey FOREIGN KEY (user_id1) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 4520 (class 2606 OID 91924)
-- Name: rooms rooms_user_id2_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rooms
    ADD CONSTRAINT rooms_user_id2_fkey FOREIGN KEY (user_id2) REFERENCES public.users(id) ON DELETE CASCADE;


-- Completed on 2024-08-02 21:32:29 EEST

--
-- PostgreSQL database dump complete
--

