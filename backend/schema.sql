-- Create a custom type for tag status
CREATE TYPE tag_status AS ENUM ('unassigned', 'active');

-- Table for Albums
CREATE TABLE public.albums (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    cover_url TEXT,
    is_private BOOLEAN DEFAULT FALSE,
    pin_code TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table for Tags (NFC Hardware identifiers)
CREATE TABLE public.tags (
    uuid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    status tag_status DEFAULT 'unassigned',
    album_id UUID REFERENCES public.albums(id) ON DELETE SET NULL,
    batch_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table for Media (Photos and Videos within an album)
CREATE TABLE public.media (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    album_id UUID REFERENCES public.albums(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('image', 'video')),
    url TEXT NOT NULL,
    order_index INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security (RLS)
ALTER TABLE public.albums ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.media ENABLE ROW LEVEL SECURITY;

-- Policies for Albums
CREATE POLICY "Users can view their own albums" ON public.albums
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own albums" ON public.albums
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Policies for Tags
CREATE POLICY "Anyone can view active tags (to see content)" ON public.tags
    FOR SELECT USING (status = 'active');

-- Policies for Media
CREATE POLICY "Users can view media of their albums" ON public.media
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.albums 
            WHERE albums.id = media.album_id AND albums.user_id = auth.uid()
        )
    );

-- 1. Create a bucket for souvenir media
INSERT INTO storage.buckets (id, name, public) 
VALUES ('souvenir-media', 'souvenir-media', true);

-- 2. Policy: Anyone can view images (since these are souvenirs to share)
CREATE POLICY "Public Access" ON storage.objects
  FOR SELECT USING (bucket_id = 'souvenir-media');

-- 3. Policy: Authenticated users can upload to their own folders
-- We will use a folder structure: /souvenir-media/{album_id}/{file_name}
CREATE POLICY "Users can upload media to their albums" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'souvenir-media' AND
    (auth.role() = 'authenticated')
  );

-- Policy: Allow the fabrication script (using anon key for now) to register new tags
-- In production, this should be restricted to a service role or admin user.
CREATE POLICY "Enable insert for fabrication" ON public.tags
    FOR INSERT WITH CHECK (true);

-- 1. Add privacy and tracking columns to albums
ALTER TABLE public.albums ADD COLUMN IF NOT EXISTS is_published BOOLEAN DEFAULT FALSE;
ALTER TABLE public.albums ADD COLUMN IF NOT EXISTS last_scanned_at TIMESTAMPTZ;

-- 2. REFINED RLS POLICIES (Cleaning up and hardening)

-- Drop old policies to avoid conflicts
DROP POLICY IF EXISTS "Users can view their own albums" ON public.albums;
DROP POLICY IF EXISTS "Users can create their own albums" ON public.albums;
DROP POLICY IF EXISTS "Anyone can view active tags (to see content)" ON public.tags;
DROP POLICY IF EXISTS "Users can view media of their albums" ON public.media;

-- ALBUMS
-- Owners can do anything
CREATE POLICY "Owners have full access to their albums" ON public.albums
    FOR ALL USING (auth.uid() = user_id);

-- Public can ONLY view if is_published is true (for Instant App)
CREATE POLICY "Public can view published albums" ON public.albums
    FOR SELECT USING (is_published = true);

-- MEDIA
-- Owners can do anything
CREATE POLICY "Owners have full access to their media" ON public.media
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.albums 
            WHERE albums.id = media.album_id AND albums.user_id = auth.uid()
        )
    );

-- Public can ONLY view if parent album is published
CREATE POLICY "Public can view media of published albums" ON public.media
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.albums 
            WHERE albums.id = media.album_id AND albums.is_published = true
        )
    );

-- TAGS
-- Anyone can see tags to check if they are unassigned or active
CREATE POLICY "Public can view tags" ON public.tags
    FOR SELECT USING (true);

-- Only fabrication (or later admins) can insert tags
-- Already handled by "Enable insert for fabrication" policy

-- 3. Function to log a scan (To be called by Instant App)
CREATE OR REPLACE FUNCTION public.log_album_scan(tag_uuid UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE public.albums
    SET last_scanned_at = NOW()
    FROM public.tags
    WHERE public.tags.album_id = public.albums.id
    AND public.tags.uuid = tag_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 1. Function to handle user deletion and "liberate" tags
CREATE OR REPLACE FUNCTION public.handle_user_deletion()
RETURNS TRIGGER AS $$
BEGIN
    -- Find all albums of the deleted user
    -- For each tag linked to those albums, set it back to unassigned
    UPDATE public.tags
    SET status = 'unassigned', 
        album_id = NULL
    WHERE album_id IN (
        SELECT id FROM public.albums WHERE user_id = OLD.id
    );

    -- Delete albums (this will cascade to Media thanks to the FK)
    DELETE FROM public.albums WHERE user_id = OLD.id;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Trigger on auth.users (requires manual setup or admin permissions)
-- Note: In Supabase, you often need to create this on the 'auth' schema.
-- Since we are in the 'public' schema, we can at least have the function ready.
-- Trigger: CREATE TRIGGER on_auth_user_deleted
-- BEFORE DELETE ON auth.users
-- FOR EACH ROW EXECUTE FUNCTION public.handle_user_deletion();

-- Modify albums table to allow "Legacy" mode (orphaned albums)
ALTER TABLE public.albums ALTER COLUMN user_id DROP NOT NULL;

-- Update the Foreign Key to NOT delete the album when the user is deleted
-- (This allows the user to choose to leave the album behind)
ALTER TABLE public.albums 
DROP CONSTRAINT IF EXISTS albums_user_id_fkey,
ADD CONSTRAINT albums_user_id_fkey 
    FOREIGN KEY (user_id) 
    REFERENCES auth.users(id) 
    ON DELETE SET NULL;

-- Fix RLS for Media Insertion
-- We need to allow insertion if the user owns the target album
DROP POLICY IF EXISTS "Owners have full access to their media" ON public.media;

CREATE POLICY "Owners can manage their media" ON public.media
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.albums 
            WHERE albums.id = media.album_id AND albums.user_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.albums 
            WHERE albums.id = media.album_id AND albums.user_id = auth.uid()
        )
    );
