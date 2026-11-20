-- Permanent deletion support for admin-managed records.
-- Preserve historical rows by clearing nullable user/profile references when an account is removed.
DO $$
DECLARE c record; cols text;
BEGIN
  FOR c IN
    SELECT con.conname, rel.relname AS table_name, ns.nspname AS schema_name, con.conrelid
    FROM pg_constraint con
    JOIN pg_class rel ON rel.oid = con.conrelid
    JOIN pg_namespace ns ON ns.oid = rel.relnamespace
    WHERE con.contype = 'f'
      AND con.confrelid = 'auth.users'::regclass
      AND NOT (ns.nspname = 'public' AND rel.relname = 'profiles')
      AND ns.nspname = 'public'
      AND NOT EXISTS (
        SELECT 1 FROM unnest(con.conkey) AS key(attnum)
        JOIN pg_attribute a ON a.attrelid = con.conrelid AND a.attnum = key.attnum
        WHERE a.attnotnull
      )
  LOOP
    SELECT string_agg(quote_ident(a.attname), ', ' ORDER BY k.ord) INTO cols
    FROM pg_constraint oldc
    JOIN unnest(oldc.conkey) WITH ORDINALITY k(attnum,ord) ON true
    JOIN pg_attribute a ON a.attrelid=oldc.conrelid AND a.attnum=k.attnum
    WHERE oldc.conname=c.conname AND oldc.conrelid=c.conrelid;
    EXECUTE format('ALTER TABLE %I.%I DROP CONSTRAINT %I', c.schema_name, c.table_name, c.conname);
    EXECUTE format('ALTER TABLE %I.%I ADD CONSTRAINT %I FOREIGN KEY (%s) REFERENCES auth.users(id) ON DELETE SET NULL', c.schema_name, c.table_name, c.conname, cols);
  END LOOP;
END $$;

-- Profile references that are nullable should not prevent removal of an auth account.
DO $$
DECLARE c record; cols text;
BEGIN
  FOR c IN
    SELECT con.conname, rel.relname AS table_name, ns.nspname AS schema_name, con.conrelid
    FROM pg_constraint con
    JOIN pg_class rel ON rel.oid=con.conrelid
    JOIN pg_namespace ns ON ns.oid=rel.relnamespace
    WHERE con.contype='f' AND con.confrelid='public.profiles'::regclass
      AND NOT (ns.nspname='public' AND rel.relname='profiles')
      AND ns.nspname='public'
      AND NOT EXISTS (
        SELECT 1 FROM unnest(con.conkey) AS key(attnum)
        JOIN pg_attribute a ON a.attrelid=con.conrelid AND a.attnum=key.attnum
        WHERE a.attnotnull
      )
  LOOP
    SELECT string_agg(quote_ident(a.attname), ', ' ORDER BY k.ord) INTO cols
    FROM pg_constraint oldc
    JOIN unnest(oldc.conkey) WITH ORDINALITY k(attnum,ord) ON true
    JOIN pg_attribute a ON a.attrelid=oldc.conrelid AND a.attnum=k.attnum
    WHERE oldc.conname=c.conname AND oldc.conrelid=c.conrelid;
    EXECUTE format('ALTER TABLE %I.%I DROP CONSTRAINT %I',c.schema_name,c.table_name,c.conname);
    EXECUTE format('ALTER TABLE %I.%I ADD CONSTRAINT %I FOREIGN KEY (%s) REFERENCES public.profiles(id) ON DELETE SET NULL',c.schema_name,c.table_name,c.conname,cols);
  END LOOP;
END $$;

-- Admin-only destructive operations; existing delete policies already enforce this for core tables.
-- Add the missing delete policy for appointment-private data.
DROP POLICY IF EXISTS appointment_private_delete_admin ON public.appointment_private_details;
CREATE POLICY appointment_private_delete_admin ON public.appointment_private_details
FOR DELETE TO authenticated USING (
  EXISTS (SELECT 1 FROM public.appointments a WHERE a.id=appointment_id AND private.is_admin(a.organization_id))
);
