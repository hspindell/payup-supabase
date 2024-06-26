
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

CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";

CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "pgsodium" WITH SCHEMA "pgsodium";

COMMENT ON SCHEMA "public" IS 'standard public schema';

CREATE EXTENSION IF NOT EXISTS "http" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";

CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";

CREATE OR REPLACE FUNCTION "public"."add_circle_owner_as_member"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$begin
  insert into public.profiles_circles(profile_id, circle_id)
  values(new.owner_id, new.id);

  return new;
end$$;

ALTER FUNCTION "public"."add_circle_owner_as_member"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."add_entry_for_pool_admin_trigger"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$begin
  insert into public.entries(profile_id, pool_id)
  values(new.admin_id, new.id);

  return new;
end$$;

ALTER FUNCTION "public"."add_entry_for_pool_admin_trigger"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."create_profile_for_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$begin
  insert into public.profiles(id, username)
  values(new.id, new.email);

  return new;
end$$;

ALTER FUNCTION "public"."create_profile_for_user"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";

CREATE TABLE IF NOT EXISTS "public"."circles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "title" "text" DEFAULT 'My Circle'::"text" NOT NULL,
    "owner_id" "uuid" DEFAULT "auth"."uid"() NOT NULL
);

ALTER TABLE "public"."circles" OWNER TO "postgres";

COMMENT ON TABLE "public"."circles" IS 'Collections of users who may frequently participate in pools together';

CREATE TABLE IF NOT EXISTS "public"."entries" (
    "profile_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "pool_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "complete" boolean DEFAULT false NOT NULL,
    "title" "text" DEFAULT ''::"text" NOT NULL,
    CONSTRAINT "entries_title_check" CHECK (("length"("title") < 100))
);

ALTER TABLE "public"."entries" OWNER TO "postgres";

COMMENT ON TABLE "public"."entries" IS 'Record of participation in a pool';

CREATE TABLE IF NOT EXISTS "public"."golfers" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "first_name" "text" DEFAULT ''::"text" NOT NULL,
    "last_name" "text" DEFAULT ''::"text" NOT NULL,
    "country" "text" DEFAULT ''::"text" NOT NULL
);

ALTER TABLE "public"."golfers" OWNER TO "postgres";

ALTER TABLE "public"."golfers" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."golfers_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

CREATE TABLE IF NOT EXISTS "public"."pools" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "circle_id" "uuid",
    "is_public" boolean DEFAULT false NOT NULL,
    "details" "text",
    "title" "text" DEFAULT ''::"text" NOT NULL,
    "admin_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    CONSTRAINT "pools_description_check" CHECK (("length"("details") < 500)),
    CONSTRAINT "pools_title_check" CHECK (("length"("title") < 100))
);

ALTER TABLE "public"."pools" OWNER TO "postgres";

COMMENT ON COLUMN "public"."pools"."is_public" IS 'When a pool is public, anyone can join. When it is private, it will be hidden without an invite link or membership in its originating circle.';

COMMENT ON COLUMN "public"."pools"."details" IS 'Add more details about the pool such as stakes and payout instructions.';

CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "username" "text" DEFAULT "auth"."uid"() NOT NULL
);

ALTER TABLE "public"."profiles" OWNER TO "postgres";

COMMENT ON TABLE "public"."profiles" IS 'User details';

CREATE TABLE IF NOT EXISTS "public"."profiles_circles" (
    "profile_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "circle_id" "uuid" NOT NULL
);

ALTER TABLE "public"."profiles_circles" OWNER TO "postgres";

COMMENT ON TABLE "public"."profiles_circles" IS 'Defines the many-to-many membership of profiles in circles';

ALTER TABLE ONLY "public"."circles"
    ADD CONSTRAINT "circles_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."entries"
    ADD CONSTRAINT "entries_pkey" PRIMARY KEY ("profile_id", "pool_id");

ALTER TABLE ONLY "public"."golfers"
    ADD CONSTRAINT "golfers_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."pools"
    ADD CONSTRAINT "pools_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."profiles_circles"
    ADD CONSTRAINT "profiles_circles_pkey" PRIMARY KEY ("profile_id", "circle_id");

ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");

CREATE OR REPLACE TRIGGER "add_circle_owner_as_member_trigger" AFTER INSERT ON "public"."circles" FOR EACH ROW EXECUTE FUNCTION "public"."add_circle_owner_as_member"();

CREATE OR REPLACE TRIGGER "add_entry_for_pool_admin_trigger" AFTER INSERT ON "public"."pools" FOR EACH ROW EXECUTE FUNCTION "public"."add_entry_for_pool_admin_trigger"();

ALTER TABLE ONLY "public"."circles"
    ADD CONSTRAINT "circles_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "public"."profiles"("id");

ALTER TABLE ONLY "public"."pools"
    ADD CONSTRAINT "pools_admin_id_fkey" FOREIGN KEY ("admin_id") REFERENCES "public"."profiles"("id");

ALTER TABLE ONLY "public"."pools"
    ADD CONSTRAINT "pools_circle_id_fkey" FOREIGN KEY ("circle_id") REFERENCES "public"."circles"("id");

ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id");

ALTER TABLE ONLY "public"."entries"
    ADD CONSTRAINT "profiles_pools_pool_id_fkey" FOREIGN KEY ("pool_id") REFERENCES "public"."pools"("id");

ALTER TABLE ONLY "public"."entries"
    ADD CONSTRAINT "profiles_pools_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id");

ALTER TABLE ONLY "public"."profiles_circles"
    ADD CONSTRAINT "public_users_circles_circle_id_fkey" FOREIGN KEY ("circle_id") REFERENCES "public"."circles"("id");

ALTER TABLE ONLY "public"."profiles_circles"
    ADD CONSTRAINT "public_users_circles_user_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id");

CREATE POLICY "Enable insert for authenticated users only" ON "public"."circles" FOR INSERT TO "authenticated" WITH CHECK (true);

CREATE POLICY "Enable insert for authenticated users only" ON "public"."pools" FOR INSERT TO "authenticated" WITH CHECK (true);

CREATE POLICY "Enable insert for authenticated users only" ON "public"."profiles" FOR INSERT TO "authenticated" WITH CHECK (true);

CREATE POLICY "Enable insert if pool is public" ON "public"."entries" FOR INSERT TO "authenticated" WITH CHECK ((("profile_id" = "auth"."uid"()) AND (EXISTS ( SELECT "pools"."id",
    "pools"."created_at",
    "pools"."circle_id",
    "pools"."is_public",
    "pools"."details",
    "pools"."title",
    "pools"."admin_id"
   FROM "public"."pools"
  WHERE (("pools"."id" = "entries"."pool_id") AND "pools"."is_public")))));

CREATE POLICY "Enable read access for all users" ON "public"."entries" FOR SELECT USING (true);

CREATE POLICY "Enable read access for authenticated users" ON "public"."circles" FOR SELECT TO "authenticated" USING (true);

CREATE POLICY "Enable read access for authenticated users" ON "public"."profiles" FOR SELECT TO "authenticated" USING (true);

CREATE POLICY "Enable read access for authenticated users" ON "public"."profiles_circles" FOR SELECT TO "authenticated" USING (true);

CREATE POLICY "Enable read access if public or user belongs to its circle" ON "public"."pools" FOR SELECT TO "authenticated" USING (("is_public" OR ("circle_id" IN ( SELECT "pf"."circle_id"
   FROM "public"."profiles_circles" "pf"
  WHERE ("pf"."profile_id" = "auth"."uid"())))));

CREATE POLICY "Enable update for users based on user_id" ON "public"."profiles" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "id"));

CREATE POLICY "Insert entry if user in pool's circle" ON "public"."entries" FOR INSERT TO "authenticated" WITH CHECK ((("profile_id" = "auth"."uid"()) AND ("pool_id" IN ( SELECT "pools"."id"
   FROM (("public"."pools"
     JOIN "public"."circles" ON (("pools"."circle_id" = "circles"."id")))
     JOIN "public"."profiles_circles" ON (("circles"."id" = "profiles_circles"."circle_id")))
  WHERE ("profiles_circles"."profile_id" = "auth"."uid"())))));

ALTER TABLE "public"."circles" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."entries" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."golfers" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."pools" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."profiles_circles" ENABLE ROW LEVEL SECURITY;

ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";

GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";

GRANT ALL ON FUNCTION "public"."add_circle_owner_as_member"() TO "anon";
GRANT ALL ON FUNCTION "public"."add_circle_owner_as_member"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_circle_owner_as_member"() TO "service_role";

GRANT ALL ON FUNCTION "public"."add_entry_for_pool_admin_trigger"() TO "anon";
GRANT ALL ON FUNCTION "public"."add_entry_for_pool_admin_trigger"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_entry_for_pool_admin_trigger"() TO "service_role";

GRANT ALL ON FUNCTION "public"."create_profile_for_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_profile_for_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_profile_for_user"() TO "service_role";

GRANT ALL ON TABLE "public"."circles" TO "anon";
GRANT ALL ON TABLE "public"."circles" TO "authenticated";
GRANT ALL ON TABLE "public"."circles" TO "service_role";

GRANT ALL ON TABLE "public"."entries" TO "anon";
GRANT ALL ON TABLE "public"."entries" TO "authenticated";
GRANT ALL ON TABLE "public"."entries" TO "service_role";

GRANT ALL ON TABLE "public"."golfers" TO "anon";
GRANT ALL ON TABLE "public"."golfers" TO "authenticated";
GRANT ALL ON TABLE "public"."golfers" TO "service_role";

GRANT ALL ON SEQUENCE "public"."golfers_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."golfers_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."golfers_id_seq" TO "service_role";

GRANT ALL ON TABLE "public"."pools" TO "anon";
GRANT ALL ON TABLE "public"."pools" TO "authenticated";
GRANT ALL ON TABLE "public"."pools" TO "service_role";

GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";

GRANT ALL ON TABLE "public"."profiles_circles" TO "anon";
GRANT ALL ON TABLE "public"."profiles_circles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles_circles" TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "service_role";

RESET ALL;
