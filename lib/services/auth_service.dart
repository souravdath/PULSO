import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Sign up a new user
  Future<AuthResponse> signUp(
    String email,
    String password,
    String name,
  ) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
    );

    // If sign up is successful, create the profile in our 'users' table
    if (response.user != null) {
      await _supabase.from('users').insert({
        'user_id': response.user!.id,
        'name': name,
      });
    }
    return response;
  }

  // Sign in existing user
  Future<AuthResponse> signIn(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign in with Google
  Future<AuthResponse> signInWithGoogle() async {
    try {
      // Initialize Google Sign-In without serverClientId
      // This uses the native platform configuration from Firebase
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      // Sign out first to ensure account picker shows
      await googleSignIn.signOut();

      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Google Sign-In was cancelled');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Verify we have the required tokens
      if (googleAuth.idToken == null) {
        throw Exception('Failed to get ID token from Google Sign-In');
      }

      // Sign in to Supabase with the Google ID token
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );

      // If sign in is successful and it's a new user, create the profile in our 'users' table
      if (response.user != null) {
        // Check if user already exists
        final existingUser = await _supabase
            .from('users')
            .select()
            .eq('user_id', response.user!.id)
            .maybeSingle();

        // If user doesn't exist, create profile
        if (existingUser == null) {
          await _supabase.from('users').insert({
            'user_id': response.user!.id,
            'name': googleUser.displayName ?? 'User',
          });
        }
      }

      return response;
    } on AuthException {
      // Re-throw Supabase auth exceptions
      rethrow;
    } catch (e) {
      // Wrap other exceptions in a more descriptive error
      throw Exception('Google Sign-In failed: ${e.toString()}');
    }
  }
  // Get current user profile with secure ID check
  Future<Map<String, dynamic>?> fetchCurrentUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      // Fetch basic user info
      final userData = await _supabase
          .from('users')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      // Fetch medical history
      final medicalData = await _supabase
          .from('medical_history')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      
      return {
        'user': userData,
        'medical': medicalData,
      };
    } catch (e) {
      print('Error fetching profile: $e');
      return null;
    }
  }

  // Check if user has medical history
  Future<bool> hasMedicalHistory() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      final data = await _supabase
          .from('medical_history')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      return data != null;
    } catch (e) {
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}

Future<void> saveMedicalHistory({
  required int age,
  required String gender,
  required String conditions,
}) async {
  final user = Supabase.instance.client.auth.currentUser;

  if (user != null) {
    await Supabase.instance.client.from('medical_history').insert({
      'user_id': user.id,
      'age_at_record': age,
      'gender': gender,
      'existing_conditions': conditions,
    });
  }
}
