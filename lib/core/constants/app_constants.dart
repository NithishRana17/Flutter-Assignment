/// Supabase configuration constants
class SupabaseConfig {
  static const String supabaseUrl = 'https://vyknsijppznyeawoekgd.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ5a25zaWpwcHpueWVhd29la2dkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY1ODcyNTMsImV4cCI6MjA4MjE2MzI1M30.Pa1Jm-IjnfKE95fCsg-VPwNDUcVd4qc0TZt5JEH4zA4';
}

/// Gemini AI configuration - PASTE YOUR API KEY HERE
class GeminiConfig {
  // TODO: Paste your Gemini API key below
  static const String apiKey = 'YOUR_GEMINI_API_KEY_HERE';
}

/// App-wide constants
class AppConstants {
  static const String appName = 'Logbook Lite';
  static const String appVersion = '1.0.0';
  
  // Flight types
  static const List<String> flightTypes = [
    'Solo',         // Flying alone
    'Dual',         // Flying with instructor
    'PIC',          // Pilot in Command
    'SIC',          // Second in Command
    'Cross-Country',// XC flight > 50nm
    'Night',        // Night flying
    'IMC',          // Actual Instrument (weather)
    'Simulated',    // Simulated instrument (hood/foggles)
  ];
  
  // Mutually exclusive pairs - selecting one removes the other
  static const Map<String, List<String>> exclusiveTypes = {
    'Solo': ['Dual', 'PIC', 'SIC'],  // Solo excludes Dual, PIC, and SIC
    'Dual': ['Solo'],                 // Dual excludes Solo only
    'PIC': ['SIC', 'Solo'],           // PIC excludes SIC and Solo
    'SIC': ['Solo', 'PIC'],           // SIC excludes Solo and PIC
    'IMC': ['Simulated'],             // Can't be actual AND simulated instrument
    'Simulated': ['IMC'],             // Can't be simulated AND actual instrument
  };
  
  // Pilot types
  static const List<String> pilotTypes = ['Student', 'Instructor'];
  
  // License types
  static const List<String> licenseTypes = ['FAA', 'EASA'];
  
  // Sync status
  static const String statusDraft = 'draft';
  static const String statusQueued = 'queued';
  static const String statusSynced = 'synced';
}
