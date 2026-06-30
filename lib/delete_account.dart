import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

Future<void> deleteAccount() async {
  final user = Supabase.instance.client.auth.currentUser;

  if (user == null) return;

  final res = await http.post(
    Uri.parse('https://ikqsbkfnjamvkevsxqpr.supabase.co/functions/v1/delete-account'), // paste it here
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken}'
    },
    body: '{"userId": "${user.id}"}',
  );

  if (res.statusCode == 200) {
    await Supabase.instance.client.auth.signOut();
  } else {
    throw Exception('Failed to delete account: ${res.statusCode}');
  }
}
