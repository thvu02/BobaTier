import 'package:cloud_functions/cloud_functions.dart';

Future<bool> reserveUsername(String username) async {
  try {
    final callable = FirebaseFunctions.instance.httpsCallable('onUsernameReserve');
    await callable.call({'username': username});
    return true;
  } on FirebaseFunctionsException catch (e) {
    if (e.code == 'already-exists') return false;
    rethrow;
  }
}