import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Sign up a new user
  Future<AuthResponse> signUp(String email, String password, String name) async {
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