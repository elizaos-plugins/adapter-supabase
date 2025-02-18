
-- Enable pgvector extension

-- -- Drop existing tables and extensions
-- DROP EXTENSION IF EXISTS vector CASCADE;
  -- DROP EXTENSION IF EXISTS fuzzystrmatch CASCADE;

--  -- Drop the triggers 
  -- DROP TRIGGER IF EXISTS convert_timestamp ON participants;
  -- DROP TRIGGER IF EXISTS create_room ON rooms;
  -- DROP TRIGGER IF EXISTS insert_into_memories ON memories;
  -- DROP FUNCTION remove_memories(text,uuid);
  -- DROP FUNCTION count_memories(text,uuid,boolean);

  DROP TABLE IF EXISTS relationships CASCADE;
  DROP TABLE IF EXISTS participants CASCADE;
  DROP TABLE IF EXISTS logs CASCADE;
  DROP TABLE IF EXISTS goals CASCADE;
-- DROP TABLE IF EXISTS memories CASCADE;
  DROP TABLE IF EXISTS memories_384 CASCADE;
  DROP TABLE IF EXISTS memories_768 CASCADE;
  DROP TABLE IF EXISTS memories_1024 CASCADE;
  DROP TABLE IF EXISTS memories_1536 CASCADE;
  DROP TABLE IF EXISTS rooms CASCADE;
  DROP TABLE IF EXISTS cache CASCADE;
  DROP TABLE IF EXISTS accounts CASCADE;
  DROP TABLE IF EXISTS knowledge CASCADE;


-- -- Create Extensions
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;


BEGIN;

CREATE TABLE accounts (
    "id" UUID PRIMARY KEY,
    "createdAt" TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    "name" TEXT,
    "username" TEXT,
    "email" TEXT NOT NULL,
    "avatarUrl" TEXT,
    "details" JSONB DEFAULT '{}'::jsonb
);

CREATE TABLE rooms (
    "id" UUID PRIMARY KEY,
    "createdAt" TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Create tables for both vector sizes
CREATE TABLE memories_1536 (
    "id" UUID PRIMARY KEY,
    "type" TEXT NOT NULL,
    "createdAt" TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    "content" JSONB NOT NULL,
    "embedding" vector(1536),
    "userId" UUID REFERENCES accounts("id"),
    "agentId" UUID REFERENCES accounts("id"),
    "roomId" UUID REFERENCES rooms("id"),
    "unique" BOOLEAN DEFAULT true NOT NULL,
    CONSTRAINT fk_room FOREIGN KEY ("roomId") REFERENCES rooms("id") ON DELETE CASCADE,
    CONSTRAINT fk_user FOREIGN KEY ("userId") REFERENCES accounts("id") ON DELETE CASCADE,
    CONSTRAINT fk_agent FOREIGN KEY ("agentId") REFERENCES accounts("id") ON DELETE CASCADE
);

CREATE TABLE memories_1024 (
    "id" UUID PRIMARY KEY,
    "type" TEXT NOT NULL,
    "createdAt" TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    "content" JSONB NOT NULL,
    "embedding" vector(1024),  -- Ollama mxbai-embed-large
    "userId" UUID REFERENCES accounts("id"),
    "agentId" UUID REFERENCES accounts("id"),
    "roomId" UUID REFERENCES rooms("id"),
    "unique" BOOLEAN DEFAULT true NOT NULL,
    CONSTRAINT fk_room FOREIGN KEY ("roomId") REFERENCES rooms("id") ON DELETE CASCADE,
    CONSTRAINT fk_user FOREIGN KEY ("userId") REFERENCES accounts("id") ON DELETE CASCADE,
    CONSTRAINT fk_agent FOREIGN KEY ("agentId") REFERENCES accounts("id") ON DELETE CASCADE
);

CREATE TABLE memories_768 (
    "id" UUID PRIMARY KEY,
    "type" TEXT NOT NULL,
    "createdAt" TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    "content" JSONB NOT NULL,
    "embedding" vector(768),  -- Gaianet nomic-embed
    "userId" UUID REFERENCES accounts("id"),
    "agentId" UUID REFERENCES accounts("id"),
    "roomId" UUID REFERENCES rooms("id"),
    "unique" BOOLEAN DEFAULT true NOT NULL,
    CONSTRAINT fk_room FOREIGN KEY ("roomId") REFERENCES rooms("id") ON DELETE CASCADE,
    CONSTRAINT fk_user FOREIGN KEY ("userId") REFERENCES accounts("id") ON DELETE CASCADE,
    CONSTRAINT fk_agent FOREIGN KEY ("agentId") REFERENCES accounts("id") ON DELETE CASCADE
);

CREATE TABLE memories_384 (
    "id" UUID PRIMARY KEY,
    "type" TEXT NOT NULL,
    "createdAt" TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    "content" JSONB NOT NULL,
    "embedding" vector(384),
    "userId" UUID REFERENCES accounts("id"),
    "agentId" UUID REFERENCES accounts("id"),
    "roomId" UUID REFERENCES rooms("id"),
    "unique" BOOLEAN DEFAULT true NOT NULL,
    CONSTRAINT fk_room FOREIGN KEY ("roomId") REFERENCES rooms("id") ON DELETE CASCADE,
    CONSTRAINT fk_user FOREIGN KEY ("userId") REFERENCES accounts("id") ON DELETE CASCADE,
    CONSTRAINT fk_agent FOREIGN KEY ("agentId") REFERENCES accounts("id") ON DELETE CASCADE
);

-- Update view to include Ollama table
CREATE VIEW memories AS
    SELECT * FROM memories_1536
    UNION ALL
    SELECT * FROM memories_1024
    UNION ALL
    SELECT * FROM memories_768
    UNION ALL
    SELECT * FROM memories_384;


CREATE TABLE goals (
    "id" UUID PRIMARY KEY,
    "createdAt" TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    "userId" UUID REFERENCES accounts("id"),
    "name" TEXT,
    "status" TEXT,
    "description" TEXT,
    "roomId" UUID REFERENCES rooms("id"),
    "objectives" JSONB DEFAULT '[]'::jsonb NOT NULL,
    CONSTRAINT fk_room FOREIGN KEY ("roomId") REFERENCES rooms("id") ON DELETE CASCADE,
    CONSTRAINT fk_user FOREIGN KEY ("userId") REFERENCES accounts("id") ON DELETE CASCADE
);

CREATE TABLE logs (
    "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "createdAt" TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    "userId" UUID NOT NULL REFERENCES accounts("id"),
    "body" JSONB NOT NULL,
    "type" TEXT NOT NULL,
    "roomId" UUID NOT NULL REFERENCES rooms("id"),
    CONSTRAINT fk_room FOREIGN KEY ("roomId") REFERENCES rooms("id") ON DELETE CASCADE,
    CONSTRAINT fk_user FOREIGN KEY ("userId") REFERENCES accounts("id") ON DELETE CASCADE
);

CREATE TABLE participants (
    "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "createdAt" TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    "userId" UUID REFERENCES accounts("id"),
    "roomId" UUID REFERENCES rooms("id"),
    "userState" TEXT,
    "last_message_read" TEXT,
    UNIQUE("userId", "roomId"),
    CONSTRAINT fk_room FOREIGN KEY ("roomId") REFERENCES rooms("id") ON DELETE CASCADE,
    CONSTRAINT fk_user FOREIGN KEY ("userId") REFERENCES accounts("id") ON DELETE CASCADE
);

CREATE TABLE relationships (
    "id" UUID PRIMARY KEY,
    "createdAt" TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    "userA" UUID NOT NULL REFERENCES accounts("id"),
    "userB" UUID NOT NULL REFERENCES accounts("id"),
    "status" TEXT,
    "userId" UUID NOT NULL REFERENCES accounts("id"),
    CONSTRAINT fk_user_a FOREIGN KEY ("userA") REFERENCES accounts("id") ON DELETE CASCADE,
    CONSTRAINT fk_user_b FOREIGN KEY ("userB") REFERENCES accounts("id") ON DELETE CASCADE,
    CONSTRAINT fk_user FOREIGN KEY ("userId") REFERENCES accounts("id") ON DELETE CASCADE
);

CREATE TABLE cache (
    "key" TEXT NOT NULL,
    "agentId" TEXT NOT NULL,
    "value" JSONB DEFAULT '{}'::jsonb,
    "createdAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMP,
    PRIMARY KEY ("key", "agentId")
);

CREATE TABLE knowledge (
    "id" UUID PRIMARY KEY,
    "agentId" UUID REFERENCES accounts("id"),
    "content" JSONB NOT NULL,
    "embedding" vector(1536),
    "createdAt" TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    "isMain" BOOLEAN DEFAULT FALSE,
    "originalId" UUID REFERENCES knowledge("id"),
    "chunkIndex" INTEGER,
    "isShared" BOOLEAN DEFAULT FALSE,
    CHECK(("isShared" = true AND "agentId" IS NULL) OR ("isShared" = false AND "agentId" IS NOT NULL))
);

-- Add index for Ollama table
CREATE INDEX idx_memories_1024_embedding ON memories_1024 USING hnsw ("embedding" vector_cosine_ops);
CREATE INDEX idx_memories_1024_type_room ON memories_1024("type", "roomId");
CREATE INDEX idx_memories_768_embedding ON memories_768 USING hnsw ("embedding" vector_cosine_ops);
CREATE INDEX idx_memories_768_type_room ON memories_768("type", "roomId");
CREATE INDEX idx_memories_1536_embedding ON memories_1536 USING hnsw ("embedding" vector_cosine_ops);
CREATE INDEX idx_memories_384_embedding ON memories_384 USING hnsw ("embedding" vector_cosine_ops);
CREATE INDEX idx_memories_1536_type_room ON memories_1536("type", "roomId");
CREATE INDEX idx_memories_384_type_room ON memories_384("type", "roomId");
CREATE INDEX idx_participants_user ON participants("userId");
CREATE INDEX idx_participants_room ON participants("roomId");
CREATE INDEX idx_relationships_users ON relationships("userA", "userB");
CREATE INDEX idx_knowledge_agent ON knowledge("agentId");
CREATE INDEX idx_knowledge_agent_main ON knowledge("agentId", "isMain");
CREATE INDEX idx_knowledge_original ON knowledge("originalId");
CREATE INDEX idx_knowledge_created ON knowledge("agentId", "createdAt");
CREATE INDEX idx_knowledge_shared ON knowledge("isShared");
CREATE INDEX idx_knowledge_embedding ON knowledge USING ivfflat (embedding vector_cosine_ops);

COMMIT;


CREATE OR REPLACE FUNCTION public.create_room("roomId" UUID DEFAULT NULL)
RETURNS UUID
LANGUAGE plpgsql
AS $function$
DECLARE
    new_room_id UUID;
BEGIN
    IF "roomId" IS NULL THEN
        new_room_id := gen_random_uuid();  -- Generate a new UUID if roomId is not provided
    ELSE
        new_room_id := "roomId";  -- Use the provided roomId
    END IF;

    INSERT INTO rooms (id) VALUES (new_room_id);  -- Insert the new room into the rooms table
    RETURN new_room_id;  -- Return the new room ID
END;
$function$;

CREATE OR REPLACE FUNCTION insert_into_memories()
RETURNS TRIGGER AS $$
BEGIN
    -- Check the size of the embedding vector using vector_dims
    IF vector_dims(NEW.embedding) = 1536 THEN
        INSERT INTO memories_1536 ("id", "type", "createdAt", "content", "embedding", "userId", "agentId", "roomId", "unique")
        VALUES (NEW."id", NEW."type", NEW."createdAt", NEW."content", NEW."embedding", NEW."userId", NEW."agentId", NEW."roomId", COALESCE(NEW."unique", true));  -- Set default to true if NULL
    ELSIF vector_dims(NEW.embedding) = 1024 THEN
        INSERT INTO memories_1024 ("id", "type", "createdAt", "content", "embedding", "userId", "agentId", "roomId", "unique")
        VALUES (NEW."id", NEW."type", NEW."createdAt", NEW."content", NEW."embedding", NEW."userId", NEW."agentId", NEW."roomId", COALESCE(NEW."unique", true));  -- Set default to true if NULL
    ELSIF vector_dims(NEW.embedding) = 768 THEN
        INSERT INTO memories_768 ("id", "type", "createdAt", "content", "embedding", "userId", "agentId", "roomId", "unique")
        VALUES (NEW."id", NEW."type", NEW."createdAt", NEW."content", NEW."embedding", NEW."userId", NEW."agentId", NEW."roomId", COALESCE(NEW."unique", true));  -- Set default to true if NULL
    ELSIF vector_dims(NEW.embedding) = 384 THEN
        INSERT INTO memories_384 ("id", "type", "createdAt", "content", "embedding", "userId", "agentId", "roomId", "unique")
        VALUES (NEW."id", NEW."type", NEW."createdAt", NEW."content", NEW."embedding", NEW."userId", NEW."agentId", NEW."roomId", COALESCE(NEW."unique", true));  -- Set default to true if NULL
    ELSE
        RAISE EXCEPTION 'Invalid embedding size: %', vector_dims(NEW.embedding);
    END IF;

    RETURN NEW;  -- Return the new row
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER memories_insert_trigger
INSTEAD OF INSERT ON memories
FOR EACH ROW
EXECUTE FUNCTION insert_into_memories();

CREATE OR REPLACE FUNCTION convert_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if createdAt is a BIGINT (milliseconds) and convert it to TIMESTAMPTZ
    IF NEW."createdAt" IS NOT NULL AND pg_typeof(NEW."createdAt") = 'bigint'::regtype THEN
        -- Convert milliseconds to seconds and set the createdAt field
        NEW."createdAt" := to_timestamp(NEW."createdAt" / 1000.0);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Create triggers for the rooms and participants tables
CREATE TRIGGER convert_timestamp_rooms
BEFORE INSERT ON public.rooms
FOR EACH ROW
EXECUTE FUNCTION convert_timestamp();

CREATE TRIGGER convert_timestamp_participants
BEFORE INSERT ON public.participants
FOR EACH ROW
EXECUTE FUNCTION convert_timestamp();

CREATE TRIGGER convert_timestamp_memories_1536
BEFORE INSERT ON memories_1536
FOR EACH ROW
EXECUTE FUNCTION convert_timestamp();

CREATE TRIGGER convert_timestamp_memories_1024
BEFORE INSERT ON memories_1024
FOR EACH ROW
EXECUTE FUNCTION convert_timestamp();

CREATE TRIGGER convert_timestamp_memories_768
BEFORE INSERT ON memories_768
FOR EACH ROW
EXECUTE FUNCTION convert_timestamp();

CREATE TRIGGER convert_timestamp_memories_384
BEFORE INSERT ON memories_384
FOR EACH ROW
EXECUTE FUNCTION convert_timestamp();

-- CREATE OR REPLACE FUNCTION public.get_embedding_list(
--     query_table_name TEXT,
--     query_threshold INTEGER,
--     query_input TEXT,
--     query_field_name TEXT,
--     query_field_sub_name TEXT,
--     query_match_count INTEGER
-- )

CREATE OR REPLACE FUNCTION "public"."get_embedding_list"(
    "query_table_name" "text", 
    "query_threshold" integer, 
    "query_input" "text", 
    "query_field_name" "text", 
    "query_field_sub_name" "text", 
    "query_match_count" integer
)
RETURNS TABLE("embedding" "vector", "levenshtein_score" integer)
LANGUAGE "plpgsql"
AS $$
DECLARE
    QUERY TEXT;
BEGIN
    -- Check the length of query_input
    IF LENGTH(query_input) > 255 THEN
        -- For inputs longer than 255 characters, use exact match only
        QUERY := format('
            SELECT
                embedding,
                0 AS levenshtein_score -- Default value for levenshtein_score
            FROM
                memories
            WHERE
                type = $1 AND
                (content->>''%s'')::TEXT = $2
            LIMIT
                $3
        ', query_field_name);
        -- Execute the query with adjusted parameters for exact match
        RETURN QUERY EXECUTE QUERY USING query_table_name, query_input, query_match_count;
    ELSE
        -- For inputs of 255 characters or less, use Levenshtein distance
        QUERY := format('
            SELECT
                embedding,
                levenshtein(
                    $2,
                    LEFT((content->>''%s'')::TEXT, 255)
                ) AS levenshtein_score
            FROM
                memories
            WHERE
                type = $1 AND
                levenshtein(
                    $2,
                    LEFT((content->>''%s'')::TEXT, 255)
                ) <= $3
            ORDER BY
                levenshtein_score
            LIMIT
                $4
        ', query_field_name, query_field_name);
        -- Execute the query with original parameters for Levenshtein distance
        RETURN QUERY EXECUTE QUERY USING query_table_name, query_input, query_threshold, query_match_count;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION "public"."get_goals"(query_roomid uuid, query_userid uuid DEFAULT NULL, only_in_progress boolean DEFAULT true, row_count integer DEFAULT 5) RETURNS SETOF "public"."goals"
LANGUAGE "plpgsql"
AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM goals
    WHERE
        (query_userid IS NULL OR "userId" = query_userid)
        AND ("roomId" = query_roomid)
        AND (NOT only_in_progress OR status = 'IN_PROGRESS')
    LIMIT row_count;
END;
$$;

ALTER FUNCTION "public"."get_goals"("query_roomid" "uuid", "query_userid" "uuid", "only_in_progress" boolean, "row_count" integer) OWNER TO "postgres";

-- DROP FUNCTION check_similarity_and_insert(text,uuid,jsonb,uuid,vector,double precision,timestamp with time zone);

CREATE OR REPLACE FUNCTION "public"."check_similarity_and_insert"("query_table_name" "text", "query_userid" "uuid", "query_content" "jsonb", "query_roomid" "uuid", "query_embedding" "vector", "similarity_threshold" double precision, "query_createdAt" timestamp with time zone)
RETURNS "void"
LANGUAGE "plpgsql"
AS $$
DECLARE
    similar_found BOOLEAN := FALSE;
    select_query TEXT;
    insert_query TEXT;
BEGIN
    -- Only perform the similarity check if query_embedding is not NULL
    IF query_embedding IS NOT NULL THEN
        -- Build a dynamic query to check for existing similar embeddings using cosine distance
        select_query := format(
            'SELECT EXISTS (' ||
                'SELECT 1 ' ||
                'FROM memories ' ||
                'WHERE "userId" = %L ' ||
                'AND "roomId" = %L ' ||
                'AND type = %L ' ||  -- Filter by the 'type' field using query_table_name
                'AND embedding <=> %L < %L ' ||
                'LIMIT 1' ||
            ')',
            query_userid,
            query_roomid,
            query_table_name,  -- Use query_table_name to filter by 'type'
            query_embedding,
            similarity_threshold
        );

        -- Execute the query to check for similarity
        EXECUTE select_query INTO similar_found;
    END IF;

    -- Prepare the insert query with 'unique' field set based on the presence of similar records or NULL query_embedding
    insert_query := format(
        'INSERT INTO memories ("userId", content, "roomId", type, embedding, "unique", createdAt) ' ||  -- Insert into the 'memories' table
        'VALUES (%L, %L, %L, %L, %L, %L, %L)',
        query_userid,
        query_content,
        query_roomid,
        query_table_name,  -- Use query_table_name as the 'type' value
        query_embedding,
        NOT similar_found OR query_embedding IS NULL  -- Set 'unique' to true if no similar record is found or query_embedding is NULL
    );

    -- Execute the insert query
    EXECUTE insert_query;
END;
$$;

ALTER FUNCTION "public"."check_similarity_and_insert"("query_table_name" "text", "query_userid" "uuid", "query_content" "jsonb", "query_roomid" "uuid", "query_embedding" "vector", "similarity_threshold" double precision, "query_createdAt" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."remove_memories"("query_table_name" "text", "query_roomid" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $_$DECLARE
    dynamic_query TEXT;
BEGIN
    dynamic_query := format('DELETE FROM memories WHERE "roomId" = $1 AND type = $2');
    EXECUTE dynamic_query USING query_roomid, query_table_name;
END;
$_$;


ALTER FUNCTION "public"."remove_memories"("query_table_name" "text", "query_roomid" "uuid") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."search_memories"(
    "query_table_name" "text", 
    "query_roomid" "uuid", 
    "query_embedding" "vector", 
    "query_match_threshold" double precision, 
    "query_match_count" integer, 
    "query_unique" boolean
)
RETURNS TABLE("id" "uuid", "userId" "uuid", "content" "jsonb", "createdAt" timestamp with time zone, "similarity" double precision, "roomId" "uuid", "embedding" "vector")
LANGUAGE "plpgsql"
AS $$
DECLARE
    query TEXT;
BEGIN
    query := format($fmt$
        SELECT
            id,
            "userId",
            content,
            "createdAt",
            1 - (embedding <=> %L) AS similarity, -- Use '<=>' for cosine distance
            "roomId",
            embedding
        FROM memories
        WHERE (1 - (embedding <=> %L) > %L)
        AND type = %L
        %s -- Additional condition for 'unique' column
        %s -- Additional condition for 'roomId'
        ORDER BY similarity DESC
        LIMIT %L
        $fmt$,
        query_embedding,
        query_embedding,
        query_match_threshold,
        query_table_name,
        CASE WHEN query_unique THEN ' AND "unique" IS TRUE' ELSE '' END,
        CASE WHEN query_roomid IS NOT NULL THEN format(' AND "roomId" = %L', query_roomid) ELSE '' END,
        query_match_count
    );

    RAISE NOTICE 'Executing query: %', query;  -- Debugging line to print the query

    RETURN QUERY EXECUTE query;
END;
$$;


ALTER FUNCTION "public"."search_memories"("query_table_name" "text", "query_roomid" "uuid", "query_embedding" "vector", "query_match_threshold" double precision, "query_match_count" integer, "query_unique" boolean) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."count_memories"("query_table_name" "text", "query_roomid" "uuid", "query_unique" boolean DEFAULT false) RETURNS bigint
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    query TEXT;
    total BIGINT;
BEGIN
    -- Initialize the base query
    query := format('SELECT COUNT(*) FROM memories WHERE type = %L', query_table_name);

    -- Add condition for roomId if not null, ensuring proper spacing
    IF query_roomid IS NOT NULL THEN
        query := query || format(' AND "roomId" = %L', query_roomid);
    END IF;

    -- Add condition for unique if TRUE, ensuring proper spacing
    IF query_unique THEN
        query := query || ' AND "unique" = TRUE';  -- Use double quotes if "unique" is a reserved keyword or potentially problematic
    END IF;

    -- Debug: Output the constructed query
    RAISE NOTICE 'Executing query: %', query;

    -- Execute the constructed query
    EXECUTE query INTO total;
    RETURN total;
END;
$$;


ALTER FUNCTION "public"."count_memories"("query_table_name" "text", "query_roomid" "uuid", "query_unique" boolean) OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."accounts" (
    "id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "createdAt" timestamp with time zone DEFAULT ("now"() AT TIME ZONE 'utc'::"text") NOT NULL,
    "name" "text",
    "username" "text",
    "email" "text" NOT NULL,
    "avatarUrl" "text",
    "details" "jsonb" DEFAULT '{}'::"jsonb",
    "is_agent" boolean DEFAULT false NOT NULL,
    "location" "text",
    "profile_line" "text",
    "signed_tos" boolean DEFAULT false NOT NULL
);


CREATE OR REPLACE FUNCTION "public"."get_participant_userState"("roomId" "uuid", "userId" "uuid")
RETURNS "text"
LANGUAGE "plpgsql"
AS $$
BEGIN
    RETURN (
        SELECT userState
        FROM participants
        WHERE "roomId" = $1 AND "userId" = $2
    );
END;
$$;

CREATE OR REPLACE FUNCTION "public"."set_participant_userState"("roomId" "uuid", "userId" "uuid", "state" "text")
RETURNS "void"
LANGUAGE "plpgsql"
AS $$
BEGIN
    UPDATE participants
    SET userState = $3
    WHERE "roomId" = $1 AND "userId" = $2;
END;
$$;


COMMIT;
