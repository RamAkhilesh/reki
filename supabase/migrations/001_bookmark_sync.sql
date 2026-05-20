-- ─────────────────────────────────────────────────────────────
-- Migration: bookmark sync conflict resolution
--
-- Run this in the Supabase SQL editor (Dashboard → SQL → New query).
-- ─────────────────────────────────────────────────────────────

-- 1. Soft-delete column
ALTER TABLE public.bookmarks
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz;

-- 2. Canonical created_at default (harmless if already set)
ALTER TABLE public.bookmarks
  ALTER COLUMN created_at SET DEFAULT now();

-- 3. Unique constraint required for ON CONFLICT upsert
ALTER TABLE public.bookmarks
  DROP CONSTRAINT IF EXISTS bookmarks_user_media_unique;
ALTER TABLE public.bookmarks
  ADD CONSTRAINT bookmarks_user_media_unique
  UNIQUE (user_id, media_item_id);

-- 4. Trigger: server-side updated_at for all writes
--    Fires BEFORE INSERT OR UPDATE so device clock never reaches the column.
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS bookmarks_set_updated_at ON public.bookmarks;
CREATE TRIGGER bookmarks_set_updated_at
  BEFORE INSERT OR UPDATE ON public.bookmarks
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- 5. RPC: conditional upsert — local wins only when its timestamp is newer.
--
--    p_local_updated_at is the device-clock timestamp used ONLY for the
--    WHERE comparison.  The trigger always overwrites updated_at with
--    server now(), so the stored value is always authoritative.
--
--    ON CONFLICT … DO UPDATE … WHERE:
--      • WHERE false  → row unchanged (remote was newer; client silently ignored)
--      • WHERE true   → UPDATE fires → BEFORE UPDATE trigger sets updated_at = now()
CREATE OR REPLACE FUNCTION public.sync_bookmark(
  p_user_id          uuid,
  p_media_item_id    uuid,
  p_status           text,
  p_rating           int,
  p_notes            text,
  p_deleted_at       timestamptz,
  p_local_updated_at timestamptz
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO bookmarks (
    user_id, media_item_id,
    status, rating, notes, deleted_at,
    created_at, updated_at
  )
  VALUES (
    p_user_id, p_media_item_id,
    p_status, p_rating, p_notes, p_deleted_at,
    now(),
    -- Provided so ON CONFLICT can compare via EXCLUDED.updated_at.
    -- The trigger will override this with now() before the row is written.
    p_local_updated_at
  )
  ON CONFLICT (user_id, media_item_id) DO UPDATE
    SET
      status     = EXCLUDED.status,
      rating     = EXCLUDED.rating,
      notes      = EXCLUDED.notes,
      deleted_at = EXCLUDED.deleted_at
    -- Only apply if local data is genuinely newer than the current server row.
    WHERE bookmarks.updated_at < p_local_updated_at;
END;
$$;

-- Grant execute to the authenticated role used by the Supabase anon/service key.
GRANT EXECUTE ON FUNCTION public.sync_bookmark TO authenticated;
GRANT EXECUTE ON FUNCTION public.sync_bookmark TO service_role;
