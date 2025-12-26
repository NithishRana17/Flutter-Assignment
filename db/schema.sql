-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Profiles table (extends auth.users)
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  pilot_type TEXT CHECK (pilot_type IN ('Student', 'Instructor')),
  license_type TEXT CHECK (license_type IN ('FAA', 'EASA')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Logbook entries table
CREATE TABLE logbook_entries (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  date DATE NOT NULL,
  dep_icao VARCHAR(4) NOT NULL,
  arr_icao VARCHAR(4) NOT NULL,
  aircraft_reg TEXT NOT NULL,
  flight_type TEXT[] DEFAULT '{}',
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  total_hours NUMERIC(5,2) NOT NULL CHECK (total_hours >= 0),
  pic_hours NUMERIC(5,2) DEFAULT 0 CHECK (pic_hours >= 0),
  sic_hours NUMERIC(5,2) DEFAULT 0 CHECK (sic_hours >= 0),
  dual_hours NUMERIC(5,2) DEFAULT 0 CHECK (dual_hours >= 0),
  dual_given_hours NUMERIC(5,2) DEFAULT 0 CHECK (dual_given_hours >= 0),
  solo_hours NUMERIC(5,2) DEFAULT 0 CHECK (solo_hours >= 0),
  night_hours NUMERIC(5,2) DEFAULT 0 CHECK (night_hours >= 0),
  xc_hours NUMERIC(5,2) DEFAULT 0 CHECK (xc_hours >= 0),
  instrument_hours NUMERIC(5,2) DEFAULT 0 CHECK (instrument_hours >= 0),
  remarks TEXT,
  tags JSONB DEFAULT '[]',
  status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'queued', 'synced')),
  is_deleted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Function to auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email)
  VALUES (NEW.id, NEW.email);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for auto-profile creation
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Row Level Security (RLS)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE logbook_entries ENABLE ROW LEVEL SECURITY;

-- Profiles: Users can only access their own profile
CREATE POLICY "Users can view own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

-- Logbook: Users can only access their own entries
CREATE POLICY "Users can view own entries"
  ON logbook_entries FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own entries"
  ON logbook_entries FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own entries"
  ON logbook_entries FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own entries"
  ON logbook_entries FOR DELETE
  USING (auth.uid() = user_id);

-- Indexes for performance
CREATE INDEX idx_logbook_user_id ON logbook_entries(user_id);
CREATE INDEX idx_logbook_date ON logbook_entries(date);
CREATE INDEX idx_logbook_status ON logbook_entries(status);
